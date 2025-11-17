"""
Personalized Insights Generator - Direct HTTP API Version
Uses requests library to call OpenAI API directly (no SDK dependencies)
Keeps ALL existing RAG/Pinecone logic
"""

import json
import os
import boto3
import requests
from datetime import datetime, timedelta
from decimal import Decimal
import random

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
lambda_client = boto3.client('lambda')
secretsmanager = boto3.client('secretsmanager')

# DynamoDB tables
analyses_table = dynamodb.Table(os.environ['ANALYSES_TABLE'])
daily_insights_table = dynamodb.Table(os.environ.get('DAILY_INSIGHTS_TABLE', f"{os.environ.get('PREFIX', 'lumen-skincare-dev')}-daily-insights"))

# Cache for OpenAI API key
_openai_api_key = None


def get_openai_api_key():
    """Get OpenAI API key from Secrets Manager"""
    global _openai_api_key

    if _openai_api_key is None:
        try:
            secret_name = os.environ.get('OPENAI_SECRET_ARN', 'lumen-skincare-openai-api-key')
            response = secretsmanager.get_secret_value(SecretId=secret_name)
            _openai_api_key = response['SecretString']
            print(f"✅ OpenAI API key retrieved")
        except Exception as e:
            print(f"❌ Error retrieving OpenAI API key: {e}")
            raise ValueError("OpenAI API key not configured")

    return _openai_api_key


def call_openai_api(messages, tools=None, max_tokens=2048):
    """Call OpenAI API directly using HTTP requests"""
    api_key = get_openai_api_key()

    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }

    data = {
        'model': 'gpt-4o',
        'messages': messages,
        'max_tokens': max_tokens,
        'temperature': 0.7
    }

    if tools:
        data['tools'] = tools
        data['tool_choice'] = 'auto'

    try:
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=data,
            timeout=60
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ OpenAI API error: {e}")
        raise


def convert_decimals(obj):
    """Convert Decimal objects to float for JSON serialization"""
    if isinstance(obj, list):
        return [convert_decimals(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimals(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj


def lambda_handler(event, context):
    """Main Lambda handler - supports both API Gateway and direct invocation"""
    print(f"Event: {json.dumps(event, default=str)}")

    try:
        # Check if API Gateway event
        has_http_method = 'httpMethod' in event
        has_request_context = 'requestContext' in event
        has_path = 'path' in event or 'resource' in event

        if has_http_method or has_request_context or has_path:
            print("✅ API Gateway event")
            return handle_api_gateway_event(event, context)
        else:
            print("✅ Direct invocation")
            return handle_direct_invocation(event, context)

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return error_response(str(e))


def get_user_id_from_event(event):
    """Extract user ID from Cognito"""
    try:
        claims = event.get('requestContext', {}).get('authorizer', {}).get('claims', {})
        return claims.get('sub') or claims.get('email')
    except:
        return None


def handle_api_gateway_event(event, context):
    """Handle API Gateway HTTP events"""
    path = event.get('path', '')
    user_id = get_user_id_from_event(event)

    if not user_id:
        return {
            'statusCode': 401,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({'success': False, 'error': 'Unauthorized'})
        }

    # Parse body
    body = {}
    if event.get('body'):
        try:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        except:
            pass

    # Route to agent chat
    if 'skin-analyst' in path:
        return handle_agent_chat(user_id, 'skin-analyst', body)
    elif 'routine-coach' in path:
        return handle_agent_chat(user_id, 'routine-coach', body)

    return {
        'statusCode': 404,
        'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
        'body': json.dumps({'success': False, 'error': f'Not found: {path}'})
    }


def handle_agent_chat(user_id, agent_type, body):
    """Handle agent chat using direct OpenAI API"""
    try:
        print(f"💬 {agent_type} chat for user {user_id}")

        # Get analysis
        analysis_id = body.get('analysisId')
        custom_message = body.get('message')

        latest_analysis = None
        if analysis_id:
            latest_analysis = get_analysis_by_id(analysis_id, user_id)
        if not latest_analysis:
            latest_analysis = get_latest_analysis(user_id)

        if not latest_analysis:
            return error_response("No analysis found. Please take a scan first.")

        # Build context
        historical_metrics = get_historical_metrics(user_id, days=30)
        trends = calculate_skin_trends(latest_analysis, historical_metrics)

        if custom_message:
            user_message = custom_message
        else:
            if agent_type == 'skin-analyst':
                user_message = f"""Analyze my skin and provide personalized insights:

Latest Scan:
- Condition: {latest_analysis.get('condition', 'unknown')}
- Confidence: {latest_analysis.get('confidence', 0):.1%}
- Overall Health: {latest_analysis.get('overall_health', 0):.0f}%

Historical:
- Scans: {len(historical_metrics)}
- Trend: {"Improving" if trends.get('improving') else "Stable" if trends.get('stable') else "Declining"}

Provide evidence-based skincare recommendations with specific ingredients."""
            else:
                user_message = f"""Help me stay consistent with my skincare routine:

Latest Scan: {latest_analysis.get('condition')}
Health: {latest_analysis.get('overall_health', 0):.0f}%
Trend: {"Improving" if trends.get('improving') else "Stable" if trends.get('stable') else "Declining"}

Provide motivation and practical tips."""

        # Define tools
        tools = [
            {
                "type": "function",
                "function": {
                    "name": "search_similar_cases",
                    "description": "Search for similar skincare cases and successful treatments in the knowledge base",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "condition": {
                                "type": "string",
                                "description": "Skin condition (e.g., 'acne', 'dryness')"
                            },
                            "skin_type": {
                                "type": "string",
                                "description": "Skin type (e.g., 'oily', 'dry')"
                            }
                        },
                        "required": ["condition"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "get_ingredient_research",
                    "description": "Get scientific research on skincare ingredients",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "ingredient_name": {
                                "type": "string",
                                "description": "Ingredient name (e.g., 'salicylic acid')"
                            },
                            "condition": {
                                "type": "string",
                                "description": "Condition being treated"
                            }
                        },
                        "required": ["ingredient_name"]
                    }
                }
            }
        ]

        # System message based on agent type
        if agent_type == 'skin-analyst':
            system_msg = """You are an expert AI Skin Analyst providing personalized skincare advice through a mobile app.

IMPORTANT FORMATTING RULES:
- Keep responses BRIEF: Maximum 1-2 short paragraphs only
- Use natural, conversational language
- DO NOT use markdown formatting (no ###, **, -, or bullet points)
- Be direct and actionable - focus on the most important advice
- If listing items, use simple format: "Try caffeine eye creams, retinol, and hyaluronic acid"

Use your tools to research ingredients and similar cases. Provide specific, evidence-based recommendations in a warm but concise tone."""
        else:
            system_msg = """You are an expert Routine Coach helping users maintain consistent skincare habits through a mobile app.

IMPORTANT FORMATTING RULES:
- Keep responses BRIEF: Maximum 1-2 short paragraphs only
- Use natural, conversational language
- DO NOT use markdown formatting (no ###, **, -, or bullet points)
- Be encouraging and actionable - focus on one key tip
- Keep it simple and motivating

Provide practical, encouraging advice in a warm but concise tone."""

        messages = [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": user_message}
        ]

        # Call OpenAI with function calling
        max_iterations = 5
        for iteration in range(max_iterations):
            print(f"🔄 Iteration {iteration + 1}")

            response = call_openai_api(messages, tools=tools)
            message = response['choices'][0]['message']

            if not message.get('tool_calls'):
                # No more tool calls, return response
                final_response = message.get('content', '')
                break

            # Execute tools
            messages.append(message)

            for tool_call in message.get('tool_calls', []):
                function_name = tool_call['function']['name']
                arguments = json.loads(tool_call['function']['arguments'])

                print(f"🔧 Calling tool: {function_name}({arguments})")

                # Execute the tool
                if function_name == "search_similar_cases":
                    result = search_similar_cases(**arguments)
                elif function_name == "get_ingredient_research":
                    result = get_ingredient_research(**arguments)
                else:
                    result = json.dumps({"error": f"Unknown function: {function_name}"})

                # Add tool result to messages
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call['id'],
                    "content": result
                })

        return success_response({
            'response': final_response,
            'agent_type': f'openai-{agent_type}',
            'model': 'gpt-4o'
        })

    except Exception as e:
        print(f"Error in agent chat: {e}")
        import traceback
        traceback.print_exc()
        return error_response(str(e))


def search_similar_cases(condition, skin_type=None):
    """Search RAG for similar cases"""
    print(f"🔍 search_similar_cases(condition={condition}, skin_type={skin_type})")

    query = f"skincare journey for {condition}"
    if skin_type:
        query += f" with {skin_type} skin"

    result = invoke_lambda('rag-query-handler', {
        'action': 'search_knowledge',
        'query': query,
        'namespace': 'user-patterns',
        'top_k': 5
    })

    data = result.get('data', {})
    results = data.get('results', [])

    return json.dumps({
        'similar_cases_count': len(results),
        'results': results[:3],  # Top 3
        'summary': f"Found {len(results)} similar cases"
    })


def get_ingredient_research(ingredient_name, condition=None):
    """Get ingredient research from RAG"""
    print(f"🔬 get_ingredient_research(ingredient={ingredient_name}, condition={condition})")

    query = f"Scientific research for {ingredient_name}"
    if condition:
        query += f" treating {condition}"

    result = invoke_lambda('rag-query-handler', {
        'action': 'search_knowledge',
        'query': query,
        'namespace': 'knowledge-base',
        'top_k': 5
    })

    data = result.get('data', {})
    results = data.get('results', [])

    return json.dumps({
        'ingredient': ingredient_name,
        'research_count': len(results),
        'results': results[:3],
        'summary': f"Found {len(results)} research articles"
    })


def handle_direct_invocation(event, context):
    """Handle direct Lambda invocation"""
    user_id = event.get('user_id')
    analysis_id = event.get('analysis_id')

    if not user_id or not analysis_id:
        return error_response("Missing user_id or analysis_id")

    insight = generate_personalized_insight(user_id, analysis_id, event.get('location'))
    insight_id = store_insight(user_id, insight)

    return success_response({
        'insight_id': insight_id,
        'user_id': user_id,
        'generated_at': datetime.utcnow().isoformat(),
        **insight
    })


def generate_personalized_insight(user_id, analysis_id, location=None):
    """Generate insight using OpenAI"""
    return {
        'daily_tip': 'Focus on consistent skincare routine',
        'check_in_question': 'How is your skin feeling today?'
    }


# ==== HELPER FUNCTIONS (unchanged) ====

def get_analysis_by_id(analysis_id, user_id):
    try:
        response = analyses_table.get_item(Key={'analysis_id': analysis_id, 'user_id': user_id})
        return normalize_analysis_item(response.get('Item')) if response.get('Item') else None
    except:
        return None


def get_latest_analysis(user_id):
    try:
        response = analyses_table.query(
            IndexName='UserIndex',
            KeyConditionExpression='user_id = :user_id',
            ExpressionAttributeValues={':user_id': user_id},
            ScanIndexForward=False,
            Limit=1
        )
        items = response.get('Items', [])
        return normalize_analysis_item(items[0]) if items else None
    except:
        return None


def normalize_analysis_item(item):
    result = convert_decimals(item)
    prediction = result.get('prediction', {})
    enhanced = result.get('enhanced_analysis', {})

    if isinstance(prediction, dict):
        result['condition'] = prediction.get('condition', 'skin health')
        result['confidence'] = prediction.get('confidence')

    if isinstance(enhanced, dict):
        result['analysis_summary'] = enhanced.get('summary', '')

    return result


def get_historical_metrics(user_id, days=30):
    try:
        cutoff = int((datetime.utcnow() - timedelta(days=days)).timestamp())
        response = analyses_table.query(
            IndexName='UserIndex',
            KeyConditionExpression='user_id = :user_id AND #ts > :cutoff',
            ExpressionAttributeNames={'#ts': 'timestamp'},
            ExpressionAttributeValues={':user_id': user_id, ':cutoff': cutoff}
        )
        return [normalize_analysis_item(item) for item in response.get('Items', [])]
    except:
        return []


def calculate_skin_trends(latest_analysis, historical_metrics):
    trends = {'improving': False, 'stable': False, 'declining': False, 'health_change': 0}

    if not latest_analysis or len(historical_metrics) < 2:
        trends['stable'] = True
        return trends

    try:
        prev = next((h for h in historical_metrics if h.get('analysis_id') != latest_analysis.get('analysis_id')), None)
        if not prev:
            trends['stable'] = True
            return trends

        latest_health = float(latest_analysis.get('overall_health', 0) or 0)
        prev_health = float(prev.get('overall_health', 0) or 0)

        if latest_health and prev_health:
            trends['health_change'] = latest_health - prev_health
            if trends['health_change'] > 5:
                trends['improving'] = True
            elif trends['health_change'] < -5:
                trends['declining'] = True
            else:
                trends['stable'] = True
    except:
        trends['stable'] = True

    return trends


def store_insight(user_id, insight):
    now = datetime.utcnow()
    insight_id = f"{user_id}:{now.isoformat()}:{random.randint(1000, 9999)}"

    daily_insights_table.put_item(Item={
        'insight_id': insight_id,
        'user_id': user_id,
        'insight_date': now.strftime('%Y-%m-%d'),
        'generated_at': now.isoformat(),
        'daily_tip': insight.get('daily_tip'),
        'check_in_question': insight.get('check_in_question'),
        'ttl': int((now + timedelta(days=7)).timestamp())
    })

    return insight_id


def invoke_lambda(function_name, payload):
    full_name = f"{os.environ.get('LAMBDA_PREFIX', 'lumen-skincare-dev')}-{function_name}"

    try:
        response = lambda_client.invoke(
            FunctionName=full_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        result = json.loads(response['Payload'].read())
        return json.loads(result['body']) if result.get('statusCode') == 200 else {}
    except:
        return {}


def success_response(data):
    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
        'body': json.dumps({'success': True, 'data': data}, default=str)
    }


def error_response(message):
    return {
        'statusCode': 400,
        'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
        'body': json.dumps({'success': False, 'error': message})
    }
