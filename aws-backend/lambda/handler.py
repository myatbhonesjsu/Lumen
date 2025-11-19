"""
Lumen Skincare Analysis - AWS Lambda Handler
Orchestrates skin analysis pipeline with Hugging Face and AWS Bedrock
"""

import json
import os
import boto3
import requests
import uuid
from datetime import datetime
from decimal import Decimal
import base64
from io import BytesIO

# No additional imports needed for basic HuggingFace analysis

# AWS clients
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
bedrock = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
opensearch = boto3.client('opensearchserverless')

# Environment variables
ANALYSES_TABLE = os.environ['ANALYSES_TABLE']
PRODUCTS_TABLE = os.environ['PRODUCTS_TABLE']
S3_BUCKET = os.environ['S3_BUCKET']
HUGGINGFACE_URL = os.environ['HUGGINGFACE_URL']
BEDROCK_AGENT_ID = os.environ.get('BEDROCK_AGENT_ID', '')
OPENSEARCH_ENDPOINT = os.environ.get('OPENSEARCH_ENDPOINT', '')

# DynamoDB tables
analyses_table = dynamodb.Table(ANALYSES_TABLE)
products_table = dynamodb.Table(PRODUCTS_TABLE)


def get_user_id_from_event(event):
    """Extract user ID from Cognito authorizer context"""
    try:
        # Log the event structure for debugging
        print(f"Event keys: {list(event.keys())}")

        # Cognito authorizer adds claims to request context
        request_context = event.get('requestContext', {})
        print(f"Request context keys: {list(request_context.keys())}")

        authorizer = request_context.get('authorizer', {})
        print(f"Authorizer keys: {list(authorizer.keys())}")

        # Get user ID from Cognito claims
        # Cognito provides 'sub' (subject) claim as unique user identifier
        claims = authorizer.get('claims', {})
        print(f"Claims: {claims}")

        cognito_username = claims.get('sub')

        if cognito_username:
            print(f"✓ Found user ID (sub): {cognito_username}")
            return cognito_username

        # Fallback to email if sub not available
        email = claims.get('email')
        if email:
            print(f"✓ Found user ID (email): {email}")
            return email

        print("⚠️ Warning: No user ID found in Cognito claims")
        print(f"   Full authorizer object: {authorizer}")
        return None

    except Exception as e:
        print(f"❌ Error extracting user ID: {str(e)}")
        import traceback
        traceback.print_exc()
        return None


def lambda_handler(event, context):
    """
    Main Lambda handler - routes requests based on source

    Can be triggered by:
    1. S3 upload event (process image)
    2. API Gateway (get presigned URL, query results)
    3. Learning Hub endpoints (articles, chat)
    """
    print(f"Event: {json.dumps(event)}")

    # S3 trigger - process uploaded image
    if 'Records' in event and event['Records'][0]['eventSource'] == 'aws:s3':
        return process_s3_upload(event)

    # API Gateway triggers
    http_method = event.get('httpMethod', '')
    path = event.get('path', '')

    if http_method == 'POST' and '/upload-image' in path:
        return handle_upload_request(event)

    elif http_method == 'GET' and '/analysis/' in path:
        return handle_get_analysis(event)

    elif http_method == 'GET' and '/recommendations' in path:
        return handle_get_recommendations(event)

    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Endpoint not found'})
        }


def handle_upload_request(event):
    """Generate presigned URL for image upload"""
    try:
        # Generate analysis ID
        analysis_id = str(uuid.uuid4())

        # Get authenticated user ID from Cognito
        user_id = get_user_id_from_event(event)

        if not user_id:
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Unauthorized - No valid user ID'})
            }
        
        # S3 key for upload
        s3_key = f"uploads/{user_id}/{analysis_id}.jpg"
        
        # Generate presigned URL (valid for 5 minutes)
        presigned_url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': S3_BUCKET,
                'Key': s3_key,
                'ContentType': 'image/jpeg'
            },
            ExpiresIn=300
        )
        
        # Create initial entry in DynamoDB
        timestamp = int(datetime.utcnow().timestamp())
        analyses_table.put_item(
            Item={
                'analysis_id': analysis_id,
                'user_id': user_id,
                's3_key': s3_key,
                'status': 'pending',
                'timestamp': timestamp,
                'ttl': timestamp + (90 * 24 * 60 * 60)  # 90 days TTL
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'analysis_id': analysis_id,
                'upload_url': presigned_url,
                'message': 'Upload image to this URL'
            })
        }
        
    except Exception as e:
        print(f"Error generating upload URL: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def process_s3_upload(event):
    """Process image uploaded to S3"""
    try:
        # Extract S3 object info
        s3_record = event['Records'][0]['s3']
        bucket = s3_record['bucket']['name']
        key = s3_record['object']['key']

        print(f"Processing image: s3://{bucket}/{key}")

        # Extract user_id and analysis_id from key (format: uploads/{user_id}/{analysis_id}.jpg)
        path_parts = key.split('/')
        if len(path_parts) >= 3:
            user_id = path_parts[1]
            analysis_id = path_parts[2].replace('.jpg', '')
        else:
            print(f"Error: Invalid S3 key format: {key}")
            return {'statusCode': 400, 'body': 'Invalid S3 key format'}

        print(f"User ID: {user_id}, Analysis ID: {analysis_id}")
        
        # Get image from S3
        image_obj = s3.get_object(Bucket=bucket, Key=key)
        image_bytes = image_obj['Body'].read()
        
        # Stage 1: Call Hugging Face for prediction
        print("Stage 1: Calling Hugging Face...")
        prediction = call_huggingface(image_bytes)

        # Stage 2: Call Bedrock Agent for enhanced analysis (optional)
        enhanced = None
        if BEDROCK_AGENT_ID:
            print("Stage 2: Calling Bedrock Agent...")
            try:
                enhanced = call_bedrock_agent(prediction, user_id)
            except Exception as e:
                print(f"Bedrock agent failed: {str(e)}")
                # Continue with just initial prediction
        else:
            print("Stage 2: Skipping Bedrock Agent (not configured)")

        # Stage 3: Get product recommendations
        print("Stage 3: Getting product recommendations...")
        products = get_product_recommendations(prediction['condition'])

        # Update DynamoDB with results
        update_analysis_results(
            analysis_id=analysis_id,
            user_id=user_id,
            prediction=prediction,
            enhanced=enhanced,
            products=products
        )
        
        print(f"✅ Analysis complete: {analysis_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'analysis_id': analysis_id})
        }
        
    except Exception as e:
        print(f"❌ Error processing image: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def call_huggingface(image_bytes):
    """Call Hugging Face API for skin condition prediction"""
    try:
        # Prepare multipart form data
        files = {'file': ('image.jpg', image_bytes, 'image/jpeg')}

        response = requests.post(
            HUGGINGFACE_URL,
            files=files,
            timeout=30
        )
        response.raise_for_status()

        data = response.json()

        # Convert floats to Decimal for DynamoDB compatibility
        confidence_val = data.get('confidence', 0.0)
        all_conditions = data.get('all_predictions', {})

        # Convert all float values to Decimal
        all_conditions_decimal = {k: Decimal(str(v)) for k, v in all_conditions.items()}

        prediction = {
            'condition': data.get('top_prediction', 'Unknown'),
            'confidence': Decimal(str(confidence_val)),
            'all_conditions': all_conditions_decimal,
            'timestamp': datetime.utcnow().isoformat()
        }

        print(f"Hugging Face prediction: {prediction['condition']} ({float(prediction['confidence']):.2%})")

        return prediction

    except Exception as e:
        print(f"Hugging Face API error: {str(e)}")
        raise


def call_bedrock_agent(prediction, user_id, session_id=None):
    """Call AWS Bedrock Agent with AgentCore for enhanced analysis using RAG"""
    condition = prediction['condition']
    confidence = float(prediction['confidence'])
    all_conditions = prediction.get('all_conditions', {})

    # Generate session ID if not provided (for memory)
    if not session_id:
        session_id = f"{user_id}_{condition}_{int(datetime.utcnow().timestamp())}"

    print(f"🧠 Calling Bedrock Agent with session: {session_id}")

    # Get user's previous analyses for memory context
    user_history = get_user_analysis_history(user_id, limit=5)

    # Build comprehensive prompt with medical context
    input_text = f"""
SKIN ANALYSIS REQUEST

Patient Profile:
- User ID: {user_id}
- Previous analyses: {len(user_history)} sessions

Current Analysis:
- Primary Condition: {condition}
- Confidence: {confidence:.1%}
- Secondary Conditions: {', '.join([f"{k} ({v:.1%})" for k, v in list(all_conditions.items())[:3]])}

Analysis Context:
{build_analysis_context(prediction, user_history)}

Please provide a comprehensive analysis including:
1. Medical explanation of the condition(s)
2. Evidence-based treatment recommendations
3. Product suggestions from our database
4. When to consult a dermatologist
5. Prevention strategies

Cite your sources from medical literature and provide reasoning for each recommendation.
"""

    if BEDROCK_AGENT_ID:
        try:
            print("🤖 Invoking Bedrock Agent with RAG...")

            response = bedrock.invoke_agent(
                agentId=BEDROCK_AGENT_ID,
                agentAliasId='TSTALIASID',
                sessionId=session_id,  # Enable memory across sessions
                inputText=input_text.strip(),
                enableTrace=True  # Enable tracing for debugging
            )

            # Parse AgentCore response
            agent_response = response.get('completion', '')
            citations = response.get('citations', [])

            # Extract structured information from agent response
            enhanced_analysis = parse_agent_response(agent_response)

            enhanced = {
                'summary': enhanced_analysis.get('summary', generate_condition_summary(condition, confidence, all_conditions)),
                'recommendations': enhanced_analysis.get('recommendations', []),
                'severity': enhanced_analysis.get('severity', determine_severity(confidence)),
                'care_instructions': enhanced_analysis.get('care_instructions', []),
                'citations': citations,
                'session_id': session_id,
                'used_memory': len(user_history) > 0,
                'timestamp': datetime.utcnow().isoformat()
            }

            print(f"✅ Bedrock Agent analysis complete (memory: {len(user_history)} sessions)")
            return enhanced

        except Exception as e:
            print(f"❌ Bedrock agent error: {str(e)}, falling back to template")
            # Fall through to template-based response

    # Fallback to template-based summary
    return {
        'summary': generate_condition_summary(condition, confidence, all_conditions),
        'recommendations': [],
        'severity': determine_severity(confidence),
        'care_instructions': [],
        'citations': [],
        'session_id': session_id,
        'used_memory': False,
        'timestamp': datetime.utcnow().isoformat()
    }


def get_user_analysis_history(user_id, limit=5):
    """Get user's previous analysis history for memory context"""
    try:
        # Scan analyses table for user's history
        response = analyses_table.scan(
            FilterExpression='user_id = :uid',
            ExpressionAttributeValues={':uid': user_id},
            Limit=limit,
            ScanIndexForward=False  # Most recent first
        )

        analyses = response.get('Items', [])

        # Convert Decimal types and format for context
        history = []
        for analysis in analyses:
            if 'prediction' in analysis and 'enhanced_analysis' in analysis:
                history.append({
                    'condition': analysis['prediction'].get('condition', 'Unknown'),
                    'confidence': float(analysis['prediction'].get('confidence', 0)),
                    'date': analysis.get('timestamp', 'Unknown'),
                    'severity': analysis.get('enhanced_analysis', {}).get('severity', 'Unknown')
                })

        return history

    except Exception as e:
        print(f"Error fetching user history: {e}")
        return []


def build_analysis_context(prediction, user_history):
    """Build context string from prediction and user history"""
    context = f"Current analysis shows {prediction['condition']} with {float(prediction['confidence']):.1%} confidence."

    if user_history:
        context += f"\n\nPatient History ({len(user_history)} previous analyses):"
        for i, hist in enumerate(user_history[:3]):  # Show last 3
            context += f"\n{i+1}. {hist['date']}: {hist['condition']} ({hist['severity']})"

    return context


def parse_agent_response(agent_response):
    """Parse structured information from Bedrock Agent response"""
    # This is a simplified parser - in production, use more sophisticated NLP
    analysis = {
        'summary': '',
        'recommendations': [],
        'severity': 'moderate',
        'care_instructions': []
    }

    if not agent_response:
        return analysis

    # Split response into sections (basic parsing)
    sections = agent_response.split('\n\n')

    for section in sections:
        section_lower = section.lower()

        if 'summary' in section_lower or 'explanation' in section_lower:
            analysis['summary'] = section.strip()
        elif 'recommend' in section_lower or 'treat' in section_lower:
            # Extract recommendations
            lines = section.split('\n')
            for line in lines:
                if line.strip().startswith(('1.', '2.', '3.', '4.', '5.', '-', '•')):
                    analysis['recommendations'].append(line.strip().lstrip('123456789.-• '))
        elif 'care' in section_lower or 'instruction' in section_lower:
            analysis['care_instructions'].append(section.strip())
        elif 'severe' in section_lower:
            if 'high' in section_lower or 'severe' in section_lower:
                analysis['severity'] = 'high'
            elif 'low' in section_lower or 'mild' in section_lower:
                analysis['severity'] = 'low'

    # Fallback if parsing failed
    if not analysis['summary']:
        analysis['summary'] = agent_response[:500] + "..." if len(agent_response) > 500 else agent_response

    return analysis


def generate_condition_summary(condition, confidence, all_conditions):
    """Generate a brief summary based on detected condition"""

    # Condition-specific summaries
    summaries = {
        'eye_bags': 'Puffiness and bags detected under the eyes, likely due to fluid retention, lack of sleep, or aging. A gentle eye cream with caffeine can help reduce swelling.',
        'dark_circles': 'Dark circles detected around the eye area, which may be caused by genetics, sleep deprivation, or thinning skin. Vitamin C and retinol treatments can help brighten.',
        'hormonal_acne': 'Hormonal acne detected, typically appearing on the chin and jawline. This condition often requires targeted treatments with salicylic acid or benzoyl peroxide.',
        'acne': 'Active acne breakouts detected on the skin. Consistent use of gentle cleansers and acne treatments with salicylic acid can help clear and prevent future breakouts.',
        'dark_spots': 'Hyperpigmentation and dark spots detected, often caused by sun exposure or post-inflammatory marks. Vitamin C serums and SPF can help fade spots over time.',
        'wrinkles': 'Fine lines and wrinkles detected, a natural sign of aging. Retinol and peptide-based products can help improve skin texture and reduce the appearance of lines.',
        'dry_skin': 'Dry, dehydrated skin detected. Your skin barrier may need strengthening with ceramides and hyaluronic acid for better moisture retention.',
        'oily_skin': 'Excess oil production detected. Gentle, non-comedogenic products and salicylic acid can help balance oil levels without over-drying.',
        'healthy': 'Your skin appears healthy! Maintain this with a consistent routine including cleanser, moisturizer, and daily SPF protection.'
    }

    # Normalize condition name
    normalized_condition = condition.lower().replace(' ', '_').replace('-', '_')

    # Get summary for condition, or create generic one
    if normalized_condition in summaries:
        summary = summaries[normalized_condition]
    else:
        summary = f"Analysis detected {condition.replace('_', ' ')} with {confidence:.0%} confidence. Consult with a dermatologist for personalized treatment recommendations."

    return summary


def determine_severity(confidence):
    """Determine severity level based on confidence"""
    if confidence >= 0.8:
        return 'high'
    elif confidence >= 0.5:
        return 'moderate'
    else:
        return 'low'


def get_product_recommendations(condition, limit=5):
    """Query DynamoDB for product recommendations based on skin condition"""
    try:
        # Map ML model conditions to product target conditions
        condition_mapping = {
            'eye_bags': ['Eye Bags', 'Dark Circles', 'Puffiness'],
            'dark_circles': ['Dark Circles', 'Eye Bags', 'Puffiness'],
            'hormonal_acne': ['Acne', 'Oily Skin', 'Blackheads'],
            'acne': ['Acne', 'Oily Skin', 'Blackheads'],
            'dark_spots': ['Dark Spots', 'Hyperpigmentation', 'Uneven Skin Tone'],
            'wrinkles': ['Wrinkles', 'Fine Lines', 'Aging Skin'],
            'dry_skin': ['Dry Skin', 'Sensitive Skin'],
            'oily_skin': ['Oily Skin', 'Large Pores', 'Acne'],
            'healthy': ['Healthy Skin', 'Sunscreen']
        }

        # Normalize condition name (lowercase, replace spaces with underscores)
        normalized_condition = condition.lower().replace(' ', '_').replace('-', '_')

        # Get target conditions to search for
        target_conditions = condition_mapping.get(normalized_condition, [])

        print(f"Searching for products for condition: {condition}")
        print(f"Target conditions: {target_conditions}")

        # Scan all products (in production, use GSI for better performance)
        response = products_table.scan()
        all_products = response.get('Items', [])

        # Filter products that match the target conditions
        matched_products = []
        for product in all_products:
            product_conditions = product.get('target_conditions', [])

            # Check if any target condition is in the product's target conditions
            if any(tc in product_conditions for tc in target_conditions):
                matched_products.append(product)

        print(f"Found {len(matched_products)} matching products out of {len(all_products)} total")

        # If we have enough matches, use them; otherwise add general products
        if len(matched_products) >= limit:
            result_products = matched_products[:limit]
        else:
            # Add general skincare products (sunscreen, moisturizer, cleanser)
            general_products = [p for p in all_products
                              if 'Healthy Skin' in p.get('target_conditions', [])
                              and p not in matched_products]

            result_products = matched_products + general_products
            result_products = result_products[:limit]

        # Debug: Log recommended products
        for product in result_products:
            print(f"  - {product.get('name', 'N/A')} (targets: {product.get('target_conditions', [])})")

        return result_products

    except Exception as e:
        print(f"Error getting products: {str(e)}")
        import traceback
        traceback.print_exc()
        return []


def update_analysis_results(analysis_id, user_id, prediction, enhanced, products):
    """Update DynamoDB with analysis results"""
    try:
        # Prepare update expression
        # prediction already has Decimal values from call_huggingface(), use directly
        update_data = {
            ':status': 'completed',
            ':prediction': prediction,  # Already has Decimal types
            ':products': products,  # Products from DynamoDB already use Decimal
            ':completed_at': int(datetime.utcnow().timestamp())
        }

        update_expression = "SET #status = :status, prediction = :prediction, products = :products, completed_at = :completed_at"

        if enhanced:
            update_data[':enhanced'] = enhanced
            update_expression += ", enhanced_analysis = :enhanced"

        analyses_table.update_item(
            Key={'analysis_id': analysis_id, 'user_id': user_id},
            UpdateExpression=update_expression,
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues=update_data
        )

        print(f"Updated analysis {analysis_id} in DynamoDB")

        # TRIGGER: Automatically generate personalized insight after analysis is saved
        try:
            trigger_personalized_insight_generation(user_id, analysis_id)
        except Exception as e:
            print(f"Warning: Failed to trigger personalized insight generation: {e}")
            # Don't fail the analysis update if insight generation fails

    except Exception as e:
        print(f"Error updating DynamoDB: {str(e)}")
        raise


def trigger_personalized_insight_generation(user_id, analysis_id):
    """Asynchronously trigger personalized insights generator Lambda"""
    try:
        prefix = os.environ.get('LAMBDA_PREFIX', 'lumen-skincare-dev')
        function_name = f"{prefix}-personalized-insights-generator"

        # Invoke asynchronously (Event type) so it doesn't block analysis response
        lambda_client = boto3.client('lambda')
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='Event',  # Asynchronous invocation
            Payload=json.dumps({
                'user_id': user_id,
                'analysis_id': analysis_id,
                'location': None  # Could be enhanced to get user location
            })
        )

        print(f"✅ Triggered personalized insight generation for analysis {analysis_id}")
        return response

    except Exception as e:
        print(f"❌ Error triggering personalized insight generation: {e}")
        raise


def handle_get_analysis(event):
    """Get analysis results by ID"""
    try:
        # Extract analysis_id from path
        path_params = event.get('pathParameters', {})
        analysis_id = path_params.get('id')

        if not analysis_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Missing analysis_id'})
            }

        # Get authenticated user ID
        user_id = get_user_id_from_event(event)

        if not user_id:
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Unauthorized - No valid user ID'})
            }

        # Query DynamoDB with user_id to ensure ownership
        response = analyses_table.get_item(
            Key={'analysis_id': analysis_id, 'user_id': user_id}
        )
        
        if 'Item' not in response:
            return {
                'statusCode': 403,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Forbidden - Analysis not found or access denied'})
            }
        
        item = response['Item']
        
        # Convert Decimal to float
        item = json.loads(json.dumps(item, default=decimal_default))
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps(item, default=decimal_default)
        }
        
    except Exception as e:
        print(f"Error getting analysis: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def handle_get_recommendations(event):
    """Get product recommendations"""
    try:
        # Get query parameters
        params = event.get('queryStringParameters', {}) or {}
        condition = params.get('condition', 'General')
        limit = int(params.get('limit', 5))
        
        products = get_product_recommendations(condition, limit)
        
        # Convert Decimal types for JSON serialization
        products_json = json.loads(json.dumps(products, default=decimal_default))

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'condition': condition,
                'products': products_json
            })
        }
        
    except Exception as e:
        print(f"Error getting recommendations: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def decimal_default(obj):
    """Convert Decimal to float for JSON serialization"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

