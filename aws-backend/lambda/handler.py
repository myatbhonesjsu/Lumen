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

# AWS clients
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
bedrock = boto3.client('bedrock-agent-runtime', region_name='us-east-1')

# Environment variables
ANALYSES_TABLE = os.environ['ANALYSES_TABLE']
PRODUCTS_TABLE = os.environ['PRODUCTS_TABLE']
S3_BUCKET = os.environ['S3_BUCKET']
HUGGINGFACE_URL = os.environ['HUGGINGFACE_URL']
BEDROCK_AGENT_ID = os.environ.get('BEDROCK_AGENT_ID', '')

# DynamoDB tables
analyses_table = dynamodb.Table(ANALYSES_TABLE)
products_table = dynamodb.Table(PRODUCTS_TABLE)


def lambda_handler(event, context):
    """
    Main Lambda handler - routes requests based on source
    
    Can be triggered by:
    1. S3 upload event (process image)
    2. API Gateway (get presigned URL, query results)
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
        
        # Get user ID from headers or generate
        headers = event.get('headers', {})
        user_id = headers.get('x-user-id', 'anonymous')
        
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
        
        # Extract analysis_id from key
        analysis_id = key.split('/')[-1].replace('.jpg', '')
        
        # Get image from S3
        image_obj = s3.get_object(Bucket=bucket, Key=key)
        image_bytes = image_obj['Body'].read()
        
        # Stage 1: Call Hugging Face for initial prediction
        print("Stage 1: Calling Hugging Face...")
        prediction = call_huggingface(image_bytes)
        
        # Stage 2: Call Bedrock Agent for enhanced analysis (optional)
        enhanced = None
        if BEDROCK_AGENT_ID:
            print("Stage 2: Calling Bedrock Agent...")
            try:
                enhanced = call_bedrock_agent(prediction)
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


def call_bedrock_agent(prediction):
    """Call AWS Bedrock Agent for enhanced analysis - fallback to template-based summary"""
    condition = prediction['condition']
    confidence = float(prediction['confidence'])
    all_conditions = prediction.get('all_conditions', {})

    # Generate summary based on condition (template-based fallback if Bedrock unavailable)
    summary = generate_condition_summary(condition, confidence, all_conditions)

    # If Bedrock Agent is configured, try to use it
    if BEDROCK_AGENT_ID:
        try:
            print("Attempting Bedrock Agent call...")
            input_text = f"""
            Analyze this skin condition for personalized recommendations:

            Detected Condition: {condition}
            Confidence: {confidence:.1%}
            All Detections: {json.dumps(all_conditions)}

            Provide a brief 1-2 sentence summary of this condition.
            """

            response = bedrock.invoke_agent(
                agentId=BEDROCK_AGENT_ID,
                agentAliasId='TSTALIASID',
                sessionId=str(uuid.uuid4()),
                inputText=input_text.strip()
            )

            # Parse Bedrock response
            enhanced = {
                'summary': summary,  # Use template summary as fallback
                'recommendations': [],
                'severity': 'moderate',
                'care_instructions': [],
                'timestamp': datetime.utcnow().isoformat()
            }

            print(f"Bedrock agent analysis complete")
            return enhanced

        except Exception as e:
            print(f"Bedrock agent error: {str(e)}, using template summary")

    # Return template-based summary
    return {
        'summary': summary,
        'recommendations': [],
        'severity': determine_severity(confidence),
        'care_instructions': [],
        'timestamp': datetime.utcnow().isoformat()
    }


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


def update_analysis_results(analysis_id, prediction, enhanced, products):
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
            Key={'analysis_id': analysis_id, 'user_id': 'anonymous'},  # Need proper user_id
            UpdateExpression=update_expression,
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues=update_data
        )
        
        print(f"Updated analysis {analysis_id} in DynamoDB")
        
    except Exception as e:
        print(f"Error updating DynamoDB: {str(e)}")
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
                'body': json.dumps({'error': 'Missing analysis_id'})
            }
        
        # Query DynamoDB
        response = analyses_table.get_item(
            Key={'analysis_id': analysis_id, 'user_id': 'anonymous'}  # Need proper user_id
        )
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Analysis not found'})
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

