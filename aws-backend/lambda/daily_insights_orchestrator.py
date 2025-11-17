"""
Daily Insights Orchestrator
Coordinates multi-agent workflow to generate personalized daily skincare insights
"""

import json
import os
import boto3
from datetime import datetime, timedelta
from decimal import Decimal

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
lambda_client = boto3.client('lambda')
ssm_client = boto3.client('ssm')

# DynamoDB tables
analyses_table = dynamodb.Table(os.environ['ANALYSES_TABLE'])
daily_insights_table = dynamodb.Table(os.environ['DAILY_INSIGHTS_TABLE'])
checkin_responses_table = dynamodb.Table(os.environ['CHECKIN_RESPONSES_TABLE'])
product_applications_table = dynamodb.Table(os.environ.get('PRODUCT_APPLICATIONS_TABLE', f"{os.environ.get('PREFIX', 'lumen-skincare-dev')}-product-applications"))


def lambda_handler(event, context):
    """
    Daily Insights Orchestrator
    Handles both direct Lambda invocation and API Gateway events

    API Gateway event format:
    {
        "httpMethod": "GET|POST",
        "path": "/daily-insights/generate|/daily-insights/latest|/daily-insights/checkin",
        "body": "{\"location\": {...}}",  // JSON string for POST
        "requestContext": {
            "authorizer": {
                "claims": {
                    "sub": "user_id"
                }
            }
        }
    }

    Direct invocation format:
    {
        "action": "generate_daily_insight|submit_checkin_response|get_latest_insight",
        "user_id": "uuid",
        "location": {"latitude": 37.7749, "longitude": -122.4194},
        "response": {...}
    }
    """
    print(f"Event: {json.dumps(event, default=str)}")

    try:
        # Bedrock Agent action group invocation
        if 'actionGroup' in event and 'apiPath' in event:
            print("📡 Detected Bedrock Agent action invocation")
            return handle_bedrock_agent_action(event, context)

        # Check if this is an API Gateway event
        if 'httpMethod' in event or 'requestContext' in event:
            return handle_api_gateway_event(event, context)

        # Otherwise treat as direct invocation
        return handle_direct_invocation(event, context)

    except Exception as e:
        print(f"Error in daily insights orchestrator: {e}")
        import traceback
        traceback.print_exc()
        return error_response(str(e))


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

        # Fallback for Bedrock session IDs (userId-ISO8601)
        session_id = event.get('sessionId')
        fallback_user = extract_user_from_session(session_id)
        if fallback_user:
            print(f"🔄 Using user ID from sessionId: {fallback_user}")
            return fallback_user

        return None
        
    except Exception as e:
        print(f"❌ Error extracting user ID: {str(e)}")
        import traceback
        traceback.print_exc()
        return None


def handle_api_gateway_event(event, context):
    """Handle API Gateway HTTP events"""
    http_method = event.get('httpMethod', 'GET')
    path = event.get('path', '')
    
    # Extract user_id from Cognito authorizer
    user_id = get_user_id_from_event(event)
    
    if not user_id:
        return {
            'statusCode': 401,
            'body': json.dumps({'success': False, 'error': 'Unauthorized'})
        }
    
    # Parse request body if present
    body = {}
    if 'body' in event and event['body']:
        try:
            body = json.loads(event['body'])
        except:
            pass
    
    # Route based on path
    if '/generate' in path and http_method == 'POST':
        try:
            location = body.get('location')
            if not location:
                print("ℹ️ /generate invoked without location; skipping environmental context")
            result = generate_daily_insight(user_id, location)
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': True, 'data': result}, default=str)
            }
        except Exception as e:
            print(f"Error in /generate endpoint: {e}")
            import traceback
            traceback.print_exc()
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': False, 'error': str(e)})
            }
    
    elif '/latest' in path and http_method == 'GET':
        try:
            result = get_latest_insight(user_id)
            if result:
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'success': True, 'data': result}, default=str)
                }
            else:
                return {
                    'statusCode': 404,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'success': False, 'error': 'No insight found'})
                }
        except Exception as e:
            print(f"Error in /latest endpoint: {e}")
            import traceback
            traceback.print_exc()
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': False, 'error': str(e)})
            }
    
    elif '/checkin' in path and http_method == 'POST':
        response_data = body.get('response')
        if not response_data:
            return {
                'statusCode': 400,
                'body': json.dumps({'success': False, 'error': 'Missing response parameter'})
            }
        result = submit_checkin_response(user_id, response_data)
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'success': True, 'data': result}, default=str)
        }
    
    elif '/products/apply' in path or path.endswith('/products/apply') and http_method == 'POST':
        # Store multiple product applications
        product_ids = body.get('product_ids', [])
        insight_id = body.get('insight_id')
        
        if not product_ids or not isinstance(product_ids, list):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': False, 'error': 'Missing or invalid product_ids array'})
            }
        
        result = store_product_applications(user_id, insight_id, product_ids)
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'success': True, 'data': result}, default=str)
        }
    
    elif '/products/' in path and '/complete' in path and http_method == 'POST':
        # Legacy endpoint - kept for backward compatibility
        path_parts = path.split('/')
        product_id_index = path_parts.index('products') + 1 if 'products' in path_parts else -1
        if product_id_index > 0 and product_id_index < len(path_parts):
            product_id = path_parts[product_id_index]
            insight_id = body.get('insight_id')
            is_completed = body.get('is_completed', True)
            
            result = mark_product_completed(user_id, insight_id, product_id, is_completed)
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': True, 'data': result}, default=str)
            }
        else:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': False, 'error': 'Invalid product ID'})
            }
    
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'success': False, 'error': 'Not found'})
        }


def handle_bedrock_agent_action(event, context):
    """
    Handle Bedrock Agent action group invocations
    """
    api_path = event.get('apiPath', '')
    http_method = (event.get('httpMethod') or 'POST').upper()
    action_group = event.get('actionGroup')
    session_id = event.get('sessionId', '')

    print(f"🤖 Bedrock Agent action: {http_method} {api_path} via {action_group}")

    properties = extract_bedrock_properties(event.get('requestBody'))
    print(f"📋 Action parameters: {properties}")

    user_id = properties.get('user_id')
    if user_id == 'current_user' or not user_id:
        user_id = extract_user_from_session(session_id) or user_id

    try:
        if api_path == '/check-adherence-rate':
            result = handle_check_adherence_rate_action(user_id, properties)
        elif api_path == '/get-motivation-strategy':
            result = handle_get_motivation_strategy_action(properties)
        elif api_path == '/adjust-routine-difficulty':
            result = handle_adjust_routine_difficulty_action(user_id, properties)
        else:
            result = {'error': f'Unknown API path: {api_path}'}
            return bedrock_action_response(event, result, status_code=400)

        return bedrock_action_response(event, result)

    except Exception as e:
        print(f"❌ Error handling Bedrock action: {e}")
        import traceback
        traceback.print_exc()
        return bedrock_action_response(event, {'error': str(e)}, status_code=500)


def extract_bedrock_properties(request_body):
    """Flatten Bedrock request body into dictionary"""
    properties = {}
    if not request_body:
        return properties

    content = request_body.get('content', {})
    if 'application/json' in content:
        props = content['application/json'].get('properties', [])
        for prop in props:
            properties[prop.get('name')] = prop.get('value')

    return properties


def extract_user_from_session(session_id):
    """Bedrock session format: userId-ISO8601"""
    if not session_id:
        return None
    if '-' in session_id:
        return session_id.split('-')[0]
    return None


def bedrock_action_response(event, body, status_code=200):
    """Format response payload expected by Bedrock Agents"""
    return {
        'messageVersion': '1.0',
        'response': {
            'actionGroup': event.get('actionGroup'),
            'apiPath': event.get('apiPath'),
            'httpMethod': event.get('httpMethod'),
            'httpStatusCode': status_code,
            'responseBody': {
                'application/json': {
                    'body': json.dumps(body, default=str)
                }
            }
        }
    }


def handle_check_adherence_rate_action(user_id, params):
    """Compute adherence rate summary for Bedrock action"""
    timeframe_days = int(params.get('timeframe_days') or 7)
    adherence = calculate_routine_adherence(user_id)

    timeframe_key = f"last_{min(max(timeframe_days, 7), 30)}_days"
    if timeframe_key not in adherence:
        timeframe_key = 'last_7_days'

    rate = adherence.get(timeframe_key, 0.0)
    streak = adherence.get('current_streak', 0)
    pattern = determine_adherence_pattern(rate, streak)

    missed_days = max(0, timeframe_days - int(rate * timeframe_days))

    return {
        'user_id': user_id,
        'timeframe_days': timeframe_days,
        'adherence_rate': round(rate * 100, 1),
        'pattern': pattern,
        'missed_days': missed_days,
        'streak': streak,
        'morning_completion_rate': round(adherence.get('morning_completion_rate', 0) * 100, 1),
        'evening_completion_rate': round(adherence.get('evening_completion_rate', 0) * 100, 1)
    }


def handle_get_motivation_strategy_action(params):
    """Return motivational strategy text"""
    adherence_rate = float(params.get('adherence_rate', 0))
    pattern = (params.get('pattern') or 'inconsistent').lower()
    barriers = params.get('barriers') or []

    return generate_motivation_strategy(adherence_rate, pattern, barriers)


def handle_adjust_routine_difficulty_action(user_id, params):
    """Suggest routine adjustments based on adherence/complexity"""
    current_adherence = float(params.get('current_adherence', 0))
    routine_complexity = int(params.get('routine_complexity', 3))

    if current_adherence < 50:
        recommendation = 'simplify'
        suggested_changes = [
            "Focus on just cleanser + moisturizer for one week",
            "Place products next to toothbrush as a cue"
        ]
        target = min(65, current_adherence + 15)
    elif current_adherence > 80 and routine_complexity < 5:
        recommendation = 'expand'
        suggested_changes = [
            "Add a treatment serum after cleansing",
            "Introduce a weekly masking ritual"
        ]
        target = min(95, current_adherence + 10)
    else:
        recommendation = 'maintain'
        suggested_changes = [
            "Keep celebrating streak milestones",
            "Batch products together to stay efficient"
        ]
        target = min(85, current_adherence + 5)

    return {
        'user_id': user_id,
        'recommendation': recommendation,
        'suggested_changes': suggested_changes,
        'rationale': generate_routine_adjustment_rationale(recommendation, current_adherence),
        'target_adherence': target
    }


def determine_adherence_pattern(rate, streak):
    """Basic heuristics for adherence pattern classification"""
    if rate >= 0.8:
        return 'consistent'
    if rate >= 0.6:
        return 'improving' if streak >= 3 else 'inconsistent'
    if rate >= 0.4:
        return 'declining'
    return 'needs_support'


def generate_motivation_strategy(adherence_rate, pattern, barriers):
    """Return motivational message tailored to adherence band"""
    if adherence_rate >= 80:
        strategy_type = 'celebratory'
        message = "Your consistency is outstanding—ready to level up with an advanced add-on?"
        tips = [
            "Schedule a weekly check-in to track streaks",
            "Pair your routine with a favorite song or podcast"
        ]
        frequency = 'weekly'
    elif adherence_rate >= 55:
        strategy_type = 'reinforcement'
        message = "You're building great momentum. Let's add one more consistent day this week."
        tips = [
            "Set a reminder tied to brushing teeth or coffee time",
            "Lay products out the night before"
        ]
        frequency = 'twice_per_week'
    else:
        strategy_type = 'supportive'
        message = "Life gets busy—simplify to two essential steps and celebrate each win."
        tips = [
            "Stick to cleanser + moisturizer for 7 days",
            "Keep products in a visible spot to prompt action"
        ]
        if barriers:
            tips.append(f"Barrier noted: {barriers[0]}. Let's adjust around it.")
        frequency = 'every_other_day'

    return {
        'strategy_type': strategy_type,
        'message': message,
        'tips': tips,
        'reinforcement_frequency': frequency,
        'pattern': pattern,
        'adherence_rate': adherence_rate
    }


def generate_routine_adjustment_rationale(recommendation, adherence_rate):
    """Explain why a routine change was suggested"""
    if recommendation == 'simplify':
        return f"Adherence at {adherence_rate:.0f}% suggests overwhelm. Simplifying rebuilds confidence."
    if recommendation == 'expand':
        return f"With adherence near {adherence_rate:.0f}%, you're ready for an advanced addition."
    return f"Adherence around {adherence_rate:.0f}% is steady—maintaining keeps the habit strong."


def handle_direct_invocation(event, context):
    """Handle direct Lambda invocation (for internal calls)"""
    action = event.get('action')
    user_id = event.get('user_id')

    if not user_id:
        return error_response("Missing user_id parameter")

    if action == 'generate_daily_insight':
        location = event.get('location')
        if not location:
            print("ℹ️ No location provided for direct invocation; continuing without environmental context")
        result = generate_daily_insight(user_id, location)
        return success_response(result)

    elif action == 'submit_checkin_response':
        response_data = event.get('response')
        if not response_data:
            return error_response("Missing response parameter")
        result = submit_checkin_response(user_id, response_data)
        return success_response(result)

    elif action == 'get_latest_insight':
        result = get_latest_insight(user_id)
        return success_response(result)

    else:
        return error_response(f"Unknown action: {action}")


def generate_daily_insight(user_id, location=None):
    """
    Generate personalized daily insight using multi-agent workflow
    Falls back to template-based insight if Bedrock agents not configured
    Always generates fresh insights with latest analysis data
    """
    print(f"🔄 Generating FRESH daily insight for user {user_id} at {datetime.utcnow().isoformat()}")

    try:
        # Step 1: Gather user context (includes product application history)
        # Always fetch fresh context to ensure latest analysis data is included
        user_context = gather_user_context(user_id)
        
        # Log context for debugging
        latest_analysis = user_context.get('latest_analysis')
        if latest_analysis:
            condition = latest_analysis.get('condition', 'unknown')
            timestamp = latest_analysis.get('timestamp', 'unknown time')
            acne = latest_analysis.get('acne_level') or latest_analysis.get('acneLevel', 'N/A')
            health = latest_analysis.get('overall_health') or latest_analysis.get('overallHealth', 'N/A')
            print(f"✅ Using latest analysis: condition={condition}, acne={acne}%, health={health}%, timestamp={timestamp}")
        else:
            print("⚠️ No latest analysis found in context")
        
        # Step 2: Fetch environmental data (MCP servers) - always fresh
        environmental_data = fetch_environmental_data(location)
        print(f"🌍 Environmental data: weather={bool(environmental_data.get('weather'))}")

        # Step 3: Prepare context for supervisor agent
        supervisor_input = prepare_supervisor_input(user_context, environmental_data)
        
        # Add timestamp and variation factors to ensure uniqueness and freshness
        now = datetime.utcnow()
        supervisor_input['generation_timestamp'] = now.isoformat()
        supervisor_input['day_of_week'] = now.strftime('%A')
        supervisor_input['hour'] = now.hour
        supervisor_input['minute'] = now.minute  # Add minute for more variation
        supervisor_input['unique_id'] = f"{user_id}-{now.timestamp()}"  # Unique identifier

        # Step 4: Query RAG for relevant knowledge based on analysis condition
        rag_knowledge = None
        if latest_analysis:
            condition = latest_analysis.get('condition', '')
            if condition:
                try:
                    rag_knowledge = query_rag_knowledge(condition, latest_analysis)
                    print(f"📚 Retrieved {len(rag_knowledge.get('results', []))} RAG results for condition: {condition}")
                except Exception as e:
                    print(f"⚠️ RAG query failed: {e}, continuing without RAG knowledge")
        
        # Add RAG knowledge to supervisor input
        if rag_knowledge:
            supervisor_input['rag_knowledge'] = rag_knowledge
        
        # Step 5: Try to generate insight using Bedrock Agent (with MCP and RAG)
        try:
            supervisor_agent_id = get_agent_id('supervisor-agent-id')
            if supervisor_agent_id and supervisor_agent_id != 'PLACEHOLDER':
                print("🤖 Using Bedrock Agent with MCP and RAG for insight generation")
                agent_response = invoke_bedrock_agent(supervisor_agent_id, supervisor_input)
                # Step 6: Parse and structure the response
                daily_insight = parse_agent_response(agent_response)
                print("✅ Successfully generated insight using Bedrock Agent")
            else:
                raise ValueError("Bedrock agent not configured")
        except (ValueError, Exception) as e:
            print(f"⚠️ Bedrock agent not available ({e}), using enhanced fallback with analysis data...")
            # Enhanced fallback that uses analysis summary and condition
            daily_insight = generate_fallback_insight(user_context, environmental_data, rag_knowledge)

        # Step 6: Store insight in DynamoDB with unique timestamp to ensure it's new
        # Use current timestamp in ID to ensure uniqueness even for same day
        insight_id = store_daily_insight(user_id, daily_insight)

        # Ensure all required fields are present for iOS app
        result = {
            'insight_id': insight_id,
            'user_id': user_id,
            'generated_at': datetime.utcnow().isoformat(),
            'daily_tip': daily_insight.get('daily_tip', ''),
            'check_in_question': daily_insight.get('check_in_question'),
            'progress_prediction': daily_insight.get('progress_prediction'),
            'environmental_recommendation': daily_insight.get('environmental_recommendation'),
            'expires_at': (datetime.utcnow() + timedelta(days=7)).isoformat()
        }
        
        # Add recommended products if present
        if daily_insight.get('recommended_products'):
            result['recommended_products'] = daily_insight.get('recommended_products')
        
        # Log insight generation details for debugging
        print(f"✅ Generated fresh insight at {datetime.utcnow().isoformat()}")
        print(f"   Tip preview: {result['daily_tip'][:100]}...")
        print(f"   Has products: {bool(daily_insight.get('recommended_products'))}")
        print(f"Returning insight result: {json.dumps(result, default=str)}")
        return result
        
    except Exception as e:
        print(f"Error generating insight: {e}")
        import traceback
        traceback.print_exc()
        # Return a basic fallback insight even on error
        fallback = generate_fallback_insight({}, {})
        insight_id = store_daily_insight(user_id, fallback)
        
        # Ensure all required fields are present
        result = {
            'insight_id': insight_id,
            'user_id': user_id,
            'generated_at': datetime.utcnow().isoformat(),
            'daily_tip': fallback.get('daily_tip', ''),
            'check_in_question': fallback.get('check_in_question'),
            'progress_prediction': fallback.get('progress_prediction'),
            'environmental_recommendation': fallback.get('environmental_recommendation'),
            'expires_at': (datetime.utcnow() + timedelta(days=7)).isoformat()
        }
        
        print(f"Returning fallback insight: {json.dumps(result, default=str)}")
        return result


def gather_user_context(user_id):
    """
    Gather comprehensive user context from DynamoDB
    Returns empty dict if queries fail - system will use fallback
    """
    try:
        # Get latest analysis
        latest_analysis = get_latest_analysis(user_id)

        # Get historical metrics (last 30 days)
        historical_metrics = get_historical_metrics(user_id, days=30)

        # Calculate routine adherence
        routine_adherence = calculate_routine_adherence(user_id)

        # Get recent check-in responses
        recent_checkins = get_recent_checkins(user_id, days=7)
        
        # Get applied products history (last 30 days)
        applied_products = get_applied_products(user_id, days=30)

        return {
            'user_id': user_id,
            'latest_analysis': latest_analysis,
            'historical_metrics': historical_metrics,
            'routine_adherence': routine_adherence,
            'recent_checkins': recent_checkins,
            'applied_products': applied_products
        }
    except Exception as e:
        print(f"Error gathering user context: {e}")
        import traceback
        traceback.print_exc()
        # Return minimal context - system will use fallback
        return {
            'user_id': user_id,
            'latest_analysis': None,
            'historical_metrics': [],
            'routine_adherence': {},
            'recent_checkins': []
        }


def fetch_environmental_data(location=None):
    """
    Provide environmental context without external weather services.
    Returns an empty weather payload while preserving coordinate hints for future integrations.
    """
    if not location:
        return {'weather': {}}

    latitude = location.get('latitude')
    longitude = location.get('longitude')

    if latitude is None or longitude is None:
        print("ℹ️ Incomplete coordinates provided; skipping weather lookup")
        return {'weather': {}}

    # Previously this function called an external weather MCP server. That integration has been removed.
    # We still surface sanitized coordinates so the agent can reference general regional guidance if needed.
    return {
        'weather': {},
        'coordinates': {
            'latitude': latitude,
            'longitude': longitude
        }
    }


def prepare_supervisor_input(user_context, environmental_data):
    """
    Prepare comprehensive input for supervisor agent
    Includes analysis summary, condition, and all context for MCP/RAG integration
    """
    latest_analysis = user_context.get('latest_analysis') or {}

    # Extract analysis summary and condition for agent
    # Priority: enhanced_analysis.summary > prediction.condition > fallback
    analysis_summary = latest_analysis.get('analysis_summary', '')
    condition = latest_analysis.get('condition', 'general skin health')
    
    # Get summary from enhanced_analysis if available (this is the multi-agent generated summary)
    enhanced_analysis = latest_analysis.get('enhanced_analysis', {}) or latest_analysis.get('enhanced_analysis_data', {})
    if isinstance(enhanced_analysis, dict):
        if not analysis_summary:
            analysis_summary = enhanced_analysis.get('summary', '')
        if not condition or condition == 'general skin health':
            condition = enhanced_analysis.get('condition') or enhanced_analysis.get('primary_concern', condition)
    
    # Get condition from prediction if still not found
    prediction = latest_analysis.get('prediction', {}) or latest_analysis.get('prediction_data', {})
    if isinstance(prediction, dict):
        if not condition or condition == 'general skin health':
            condition = prediction.get('condition', condition)
    
    # Build comprehensive analysis context
    analysis_context = {
        'condition': condition,
        'summary': analysis_summary,
        'acne_level': latest_analysis.get('acne_level') or latest_analysis.get('acneLevel'),
        'dryness_level': latest_analysis.get('dryness_level') or latest_analysis.get('drynessLevel'),
        'overall_health': latest_analysis.get('overall_health') or latest_analysis.get('overallHealth'),
        'skin_age': latest_analysis.get('skin_age') or latest_analysis.get('skinAge'),
        'timestamp': latest_analysis.get('timestamp', ''),
        'recommendations': enhanced_analysis.get('recommendations', []) if isinstance(enhanced_analysis, dict) else []
    }
    
    return {
        'user_id': user_context['user_id'],
        'analysis_context': analysis_context,  # Structured analysis data
        'latest_analysis': latest_analysis,  # Full analysis for reference
        'historical_metrics': user_context['historical_metrics'],
        'routine_adherence': user_context['routine_adherence'],
        'environmental_context': environmental_data,  # MCP data (weather, UV)
        'recent_checkins': user_context['recent_checkins'],
        'applied_products': user_context.get('applied_products', [])
    }


def invoke_bedrock_agent(agent_id, input_data):
    """
    Invoke AWS Bedrock Agent with prepared context
    """
    session_id = f"{input_data['user_id']}-{datetime.utcnow().isoformat()}"

    response = bedrock_agent_runtime.invoke_agent(
        agentId=agent_id,
        agentAliasId='TSTALIASID',  # Test alias
        sessionId=session_id,
        inputText=json.dumps(input_data)
    )

    # Parse agent response
    completion = ""
    for event in response.get('completion', []):
        if 'chunk' in event:
            chunk = event['chunk']
            if 'bytes' in chunk:
                completion += chunk['bytes'].decode('utf-8')

    print(f"Agent response: {completion}")
    return completion


def parse_agent_response(agent_response):
    """
    Parse JSON response from supervisor agent
    """
    try:
        # Agent should return structured JSON
        parsed = json.loads(agent_response)
        return parsed
    except json.JSONDecodeError:
        # Fallback: extract JSON from text
        import re
        json_match = re.search(r'\{.*\}', agent_response, re.DOTALL)
        if json_match:
            return json.loads(json_match.group(0))
        else:
            raise ValueError("Could not parse agent response as JSON")


def query_rag_knowledge(condition, analysis_data):
    """
    Query RAG knowledge base for relevant skincare information
    Uses the condition and analysis data to find similar cases and knowledge
    """
    try:
        # Build query from condition and key metrics
        query_parts = [f"skincare advice for {condition}"]
        
        acne = analysis_data.get('acne_level') or analysis_data.get('acneLevel')
        if acne and isinstance(acne, (int, float)) and acne > 15:
            query_parts.append(f"acne treatment {int(acne)}%")
        
        dryness = analysis_data.get('dryness_level') or analysis_data.get('drynessLevel')
        if dryness and isinstance(dryness, (int, float)) and dryness > 30:
            query_parts.append(f"dry skin hydration")
        
        query = " ".join(query_parts)
        
        # Invoke RAG query handler Lambda
        result = invoke_lambda(
            'rag_query_handler',
            {
                'action': 'search_knowledge',
                'query': query,
                'namespace': 'knowledge-base',
                'top_k': 5,
                'filter': {'condition': condition} if condition else None
            }
        )
        
        return result.get('data', {})
    except Exception as e:
        print(f"Error querying RAG: {e}")
        return {'results': []}


def store_daily_insight(user_id, daily_insight):
    """
    Store generated insight in DynamoDB
    Always creates a new insight with unique timestamp
    Uses microsecond precision to ensure uniqueness even for same second
    """
    # Use full ISO timestamp with microseconds to ensure uniqueness
    now = datetime.utcnow()
    # Add random component to ensure uniqueness even within same microsecond
    import random
    unique_suffix = random.randint(1000, 9999)
    insight_id = f"{user_id}:{now.isoformat()}:{unique_suffix}"
    insight_date = now.strftime('%Y-%m-%d')
    expires_at = int((now + timedelta(days=7)).timestamp())
    
    print(f"💾 Storing NEW insight with unique ID: {insight_id}")

    item = {
        'insight_id': insight_id,
        'user_id': user_id,
        'insight_date': insight_date,
        'generated_at': datetime.utcnow().isoformat(),
        'daily_tip': daily_insight.get('daily_tip'),
        'check_in_question': daily_insight.get('check_in_question'),
        'progress_prediction': daily_insight.get('progress_prediction'),
        'environmental_recommendation': daily_insight.get('environmental_recommendation'),
        'ttl': expires_at
    }
    
    # Add recommended products if present
    if daily_insight.get('recommended_products'):
        item['recommended_products'] = daily_insight.get('recommended_products')
    
    daily_insights_table.put_item(Item=item)

    print(f"Stored daily insight: {insight_id}")
    return insight_id


def submit_checkin_response(user_id, response_data):
    """
    Store user's check-in response
    """
    response_id = f"{user_id}:{datetime.utcnow().isoformat()}"

    checkin_responses_table.put_item(
        Item={
            'response_id': response_id,
            'user_id': user_id,
            'submitted_at': datetime.utcnow().isoformat(),
            'question': response_data.get('question'),
            'response': response_data.get('response'),
            'response_type': response_data.get('response_type', 'text')
        }
    )

    print(f"Stored check-in response: {response_id}")
    return {'response_id': response_id, 'status': 'stored'}


def store_product_applications(user_id, insight_id, product_ids):
    """
    Store multiple product applications for a user
    """
    try:
        timestamp = datetime.utcnow().isoformat()
        date_str = datetime.utcnow().strftime('%Y-%m-%d')
        
        # Store each product application
        stored_applications = []
        for product_id in product_ids:
            application_id = f"{user_id}:{product_id}:{timestamp}"
            
            try:
                product_applications_table.put_item(
                    Item={
                        'application_id': application_id,
                        'user_id': user_id,
                        'product_id': product_id,
                        'insight_id': insight_id,
                        'applied_date': date_str,
                        'applied_at': timestamp,
                        'ttl': int((datetime.utcnow() + timedelta(days=365)).timestamp())  # Keep for 1 year
                    }
                )
                stored_applications.append(product_id)
                print(f"Stored product application: {product_id} for user {user_id}")
            except Exception as e:
                print(f"Error storing product application {product_id}: {e}")
        
        return {
            'user_id': user_id,
            'insight_id': insight_id,
            'applied_products': stored_applications,
            'timestamp': timestamp,
            'count': len(stored_applications)
        }
    except Exception as e:
        print(f"Error storing product applications: {e}")
        import traceback
        traceback.print_exc()
        raise


def get_applied_products(user_id, days=30):
    """
    Get products applied by user in the last N days
    """
    try:
        cutoff_date = (datetime.utcnow() - timedelta(days=days)).strftime('%Y-%m-%d')
        
        # Try to query by user_id and date range
        # If GSI doesn't exist, scan and filter (less efficient but works)
        try:
            response = product_applications_table.query(
                IndexName='UserDateIndex',
                KeyConditionExpression='user_id = :user_id AND applied_date >= :cutoff',
                ExpressionAttributeValues={
                    ':user_id': user_id,
                    ':cutoff': cutoff_date
                }
            )
            items = response.get('Items', [])
        except Exception as e:
            print(f"GSI query failed, using scan: {e}")
            # Fallback: scan and filter
            response = product_applications_table.scan(
                FilterExpression='user_id = :user_id AND applied_date >= :cutoff',
                ExpressionAttributeValues={
                    ':user_id': user_id,
                    ':cutoff': cutoff_date
                }
            )
            items = response.get('Items', [])
        
        # Group by product_id and get most recent application
        product_applications = {}
        for item in items:
            product_id = item.get('product_id')
            applied_at = item.get('applied_at')
            if product_id:
                if product_id not in product_applications or applied_at > product_applications[product_id].get('applied_at', ''):
                    product_applications[product_id] = {
                        'product_id': product_id,
                        'applied_at': applied_at,
                        'applied_date': item.get('applied_date')
                    }
        
        return list(product_applications.values())
    except Exception as e:
        print(f"Error getting applied products: {e}")
        # If table doesn't exist or query fails, return empty list
        return []


def mark_product_completed(user_id, insight_id, product_id, is_completed):
    """
    Mark a product as completed or uncompleted for tracking (legacy method)
    """
    try:
        if is_completed:
            # Store as product application
            store_product_applications(user_id, insight_id, [product_id])
        
        timestamp = datetime.utcnow().isoformat()
        return {
            'product_id': product_id,
            'insight_id': insight_id,
            'is_completed': is_completed,
            'timestamp': timestamp
        }
    except Exception as e:
        print(f"Error marking product completed: {e}")
        raise


def get_latest_insight(user_id):
    """
    Retrieve latest daily insight for user
    """
    try:
        # Query by user_id (hash key) and get most recent by insight_date (range key)
        today = datetime.utcnow().strftime('%Y-%m-%d')
        # Start from today and go backwards
        response = daily_insights_table.query(
            KeyConditionExpression='user_id = :user_id AND insight_date <= :today',
            ExpressionAttributeValues={
                ':user_id': user_id,
                ':today': today
            },
            ScanIndexForward=False,  # Descending order (most recent first)
            Limit=1
        )

        items = response.get('Items', [])
        if items:
            item = items[0]
            # Convert DynamoDB item to dict, handling Decimal types
            result = {}
            for key, value in item.items():
                if hasattr(value, 'value'):  # Decimal type
                    result[key] = str(value)
                else:
                    result[key] = value
            
            # Ensure expires_at is present (calculate if missing)
            if 'expires_at' not in result and 'ttl' in result:
                # Convert TTL (Unix timestamp) to ISO 8601
                try:
                    expires_timestamp = int(result['ttl'])
                    result['expires_at'] = datetime.fromtimestamp(expires_timestamp).isoformat()
                except:
                    result['expires_at'] = (datetime.utcnow() + timedelta(days=7)).isoformat()
            elif 'expires_at' not in result:
                result['expires_at'] = (datetime.utcnow() + timedelta(days=7)).isoformat()
            
            print(f"Retrieved latest insight: {json.dumps(result, default=str)}")
            return result
        else:
            print("No insight found for user")
            return None
    except Exception as e:
        print(f"Error getting latest insight: {e}")
        import traceback
        traceback.print_exc()
        return None


def generate_fallback_insight(user_context, environmental_data, rag_knowledge=None):
    """
    Generate an enhanced fallback insight using analysis summary and RAG knowledge
    Uses the analysis summary from saved scans to provide personalized advice
    """
    now = datetime.utcnow()
    import random
    variation_seed = random.randint(1, 1000)
    print(f"🔄 Generating enhanced fallback insight with analysis summary and RAG knowledge at {now.isoformat()}")
    
    # Extract basic info
    latest_analysis = user_context.get('latest_analysis')
    historical_metrics = user_context.get('historical_metrics', [])
    recent_checkins = user_context.get('recent_checkins', [])
    applied_products = user_context.get('applied_products', [])
    weather = environmental_data.get('weather', {})

    # Get time-based context for variation
    now = datetime.utcnow()
    hour = now.hour
    day_of_week = now.strftime('%A')
    
    # Build daily tip with variation
    tips = []
    
    # Time-based greeting
    if 5 <= hour < 12:
        tips.append("Good morning! ")
    elif 12 <= hour < 17:
        tips.append("Good afternoon! ")
    elif 17 <= hour < 21:
        tips.append("Good evening! ")
    else:
        tips.append("Good night! ")
    
    # Analysis-based tips - use analysis summary from saved scan
    if latest_analysis:
        # Extract analysis summary from enhanced_analysis (multi-agent generated)
        enhanced_analysis = latest_analysis.get('enhanced_analysis', {}) or latest_analysis.get('enhanced_analysis_data', {})
        analysis_summary = latest_analysis.get('analysis_summary', '')
        recommendations = []
        
        if isinstance(enhanced_analysis, dict):
            if not analysis_summary:
                analysis_summary = enhanced_analysis.get('summary', '')
            recommendations = enhanced_analysis.get('recommendations', [])
        
        # Extract all available metrics
        condition = latest_analysis.get('condition', 'skin health')
        confidence = latest_analysis.get('confidence', 0)
        if isinstance(confidence, str):
            try:
                confidence = float(confidence)
            except:
                confidence = 0
        
        # Extract specific metrics with fallbacks
        acne_level = latest_analysis.get('acne_level') or latest_analysis.get('acneLevel')
        dryness_level = latest_analysis.get('dryness_level') or latest_analysis.get('drynessLevel')
        overall_health = latest_analysis.get('overall_health') or latest_analysis.get('overallHealth')
        skin_age = latest_analysis.get('skin_age') or latest_analysis.get('skinAge')
        
        # Convert string numbers to float if needed
        if isinstance(acne_level, str):
            try:
                acne_level = float(acne_level)
            except:
                acne_level = None
        if isinstance(dryness_level, str):
            try:
                dryness_level = float(dryness_level)
            except:
                dryness_level = None
        if isinstance(overall_health, str):
            try:
                overall_health = float(overall_health)
            except:
                overall_health = None
        if isinstance(skin_age, str):
            try:
                skin_age = int(float(skin_age))
            except:
                skin_age = None
        
        analysis_timestamp = latest_analysis.get('timestamp') or latest_analysis.get('analysis_timestamp', '')
        
        # Log extracted data including summary
        print(f"📊 Using analysis data: condition={condition}, summary_length={len(analysis_summary)}, acne={acne_level}, health={overall_health}")
        
        # Use RAG knowledge if available
        rag_advice = ""
        if rag_knowledge and rag_knowledge.get('results'):
            # Extract relevant advice from RAG results
            top_result = rag_knowledge['results'][0] if rag_knowledge['results'] else {}
            rag_advice = top_result.get('metadata', {}).get('content', '')[:200]  # First 200 chars
            print(f"📚 Using RAG knowledge: {len(rag_knowledge['results'])} results found")
        
        # Check if analysis is recent (within last 24 hours)
        is_recent = False
        if analysis_timestamp:
            try:
                # Parse ISO 8601 timestamp
                if 'T' in analysis_timestamp:
                    # ISO format: 2024-01-01T12:00:00 or 2024-01-01T12:00:00.123456
                    timestamp_str = analysis_timestamp.split('.')[0]  # Remove microseconds if present
                    timestamp_str = timestamp_str.split('+')[0].split('-')[0:3]  # Remove timezone
                    if len(timestamp_str) >= 3:
                        # Try parsing with datetime
                        try:
                            analysis_date = datetime.strptime(analysis_timestamp.split('+')[0].split('Z')[0].split('.')[0], '%Y-%m-%dT%H:%M:%S')
                        except:
                            # Fallback to simpler format
                            analysis_date = datetime.strptime(analysis_timestamp.split('T')[0], '%Y-%m-%d')
                        
                        hours_ago = (datetime.utcnow() - analysis_date).total_seconds() / 3600
                        is_recent = hours_ago < 24
                        print(f"Analysis is {hours_ago:.1f} hours old, is_recent={is_recent}")
                    else:
                        is_recent = True
                else:
                    is_recent = True  # Assume recent if format is unexpected
            except Exception as e:
                print(f"Could not parse timestamp {analysis_timestamp}: {e}")
                is_recent = True  # Assume recent if we can't parse
        
        # Build detailed, personalized tip based on actual metrics
        import random
        random.seed(int(now.timestamp() * 1000) % 10000)  # Use timestamp as seed for variation
        
        # Create specific, actionable tips based on actual metrics
        specific_tips = []
        
        # Acne-specific advice
        if acne_level and isinstance(acne_level, (int, float)):
            if acne_level > 50:
                specific_tips.append(f"Your acne level is {int(acne_level)}% - this is high. Focus on gentle, non-comedogenic products and consider consulting a dermatologist for targeted treatment.")
            elif acne_level > 30:
                specific_tips.append(f"Your acne level is {int(acne_level)}% - moderate. Use salicylic acid or benzoyl peroxide products, and avoid picking or over-washing which can worsen inflammation.")
            elif acne_level > 15:
                specific_tips.append(f"Your acne level is {int(acne_level)}% - mild. Maintain a consistent routine with gentle cleansers and non-comedogenic moisturizers to prevent breakouts.")
        
        # Dryness-specific advice
        if dryness_level and isinstance(dryness_level, (int, float)):
            if dryness_level > 50:
                specific_tips.append(f"Your skin dryness is {int(dryness_level)}% - very dry. Use rich, emollient moisturizers with ceramides and hyaluronic acid twice daily, and avoid hot water.")
            elif dryness_level > 35:
                specific_tips.append(f"Your skin shows {int(dryness_level)}% dryness. Increase hydration with hyaluronic acid serums and occlusive moisturizers, especially at night.")
        
        # Overall health advice
        if overall_health and isinstance(overall_health, (int, float)):
            if overall_health < 50:
                specific_tips.append(f"Your overall skin health is {int(overall_health)}% - below optimal. Focus on a consistent routine addressing your primary concerns: {condition}. Consider professional consultation.")
            elif overall_health < 70:
                specific_tips.append(f"Your skin health is {int(overall_health)}% - improving. Continue your routine and address specific concerns like {condition} to reach optimal health.")
            else:
                specific_tips.append(f"Great! Your skin health is {int(overall_health)}%. Maintain your routine and continue protecting your skin barrier.")
        
        # Skin age advice
        if skin_age and isinstance(skin_age, (int, float)):
            specific_tips.append(f"Your skin age is {int(skin_age)}. Protect with daily SPF, use antioxidants like vitamin C, and maintain hydration to preserve youthful skin.")
        
        # Use analysis summary if available (from multi-agent system)
        if analysis_summary and len(analysis_summary) > 50:
            # Incorporate the AI-generated summary from the saved analysis
            tips.append(f"Based on your recent analysis: {analysis_summary[:150]}...")
            print(f"📝 Using analysis summary from saved scan: {analysis_summary[:80]}...")
        elif rag_advice:
            # Use RAG knowledge if summary not available
            tips.append(f"Based on skincare research: {rag_advice}")
            print(f"📝 Using RAG knowledge: {rag_advice[:80]}...")
        elif specific_tips:
            # Use specific tips with some variation
            selected_tip = random.choice(specific_tips)
            tips.append(selected_tip)
            print(f"📝 Using specific metric-based tip: {selected_tip[:80]}...")
        else:
            # Fallback to condition-based tips
            if is_recent:
                tip_variations = [
                    f"Based on your recent analysis showing {condition}, continue your targeted skincare approach.",
                    f"Your latest scan detected {condition} - keep following your personalized routine for best results.",
                    f"With {condition} identified in your recent analysis, maintain consistency in your skincare regimen.",
                    f"Your recent analysis shows {condition} - stay committed to your treatment plan for visible improvements."
                ]
            else:
                tip_variations = [
                    f"Keep up your consistent routine to improve your {condition}.",
                    f"Your {condition} is responding well to your current regimen.",
                    f"Continue following your skincare routine for optimal {condition} results.",
                    f"Your dedication to treating {condition} is showing progress."
                ]
            selected_tip = random.choice(tip_variations)
            tips.append(selected_tip)
            print(f"📝 Using condition-based tip: {selected_tip[:50]}...")
        
        # Add confidence-based tip
        if confidence and isinstance(confidence, (int, float)) and confidence > 0.7:
            tips.append("High confidence in your analysis results - trust the recommendations.")
    else:
        tips.append("Start tracking your skin health with regular analysis scans to get personalized insights.")
    
    # Weather-based tips (humidity, temperature, conditions)
    if weather:
        humidity = weather.get('humidity_percent', 0)
        temp = weather.get('temperature_celsius', 0)
        conditions = weather.get('conditions', '')

        if humidity < 30:
            tips.append(f"Low humidity ({humidity}%) - use extra moisturizer to prevent dryness.")
        elif humidity > 70:
            tips.append(f"High humidity ({humidity}%) - use lightweight, non-comedogenic products.")

        if 'Rain' in conditions or 'Drizzle' in conditions:
            tips.append("Rainy weather - perfect time for a hydrating mask!")
        elif temp > 30:
            tips.append(f"Hot weather ({temp}°C) - stay hydrated and use oil-free products.")
        elif temp < 10:
            tips.append(f"Cold weather ({temp}°C) - protect your skin barrier with rich moisturizers.")

    daily_tip = " ".join(tips) if tips else "Maintain a consistent skincare routine for healthy, glowing skin."
    
    # Progress prediction - use analysis summary and specific metrics
    progress_prediction = None
    if latest_analysis:
        condition = latest_analysis.get('condition', 'skin health')
        
        # Get analysis summary from enhanced_analysis
        enhanced_analysis = latest_analysis.get('enhanced_analysis', {})
        analysis_summary = ""
        if isinstance(enhanced_analysis, dict):
            analysis_summary = enhanced_analysis.get('summary', '')
            recommendations = enhanced_analysis.get('recommendations', [])
        
        # Extract specific metrics for detailed progress prediction
        acne_level = latest_analysis.get('acne_level') or latest_analysis.get('acneLevel')
        dryness_level = latest_analysis.get('dryness_level') or latest_analysis.get('drynessLevel')
        overall_health = latest_analysis.get('overall_health') or latest_analysis.get('overallHealth')
        skin_age = latest_analysis.get('skin_age') or latest_analysis.get('skinAge')
        
        # Build detailed progress prediction based on analysis summary and metrics
        prediction_parts = []
        
        # Use analysis summary recommendations if available
        if analysis_summary and len(analysis_summary) > 100:
            # Extract key insights from summary for progress prediction
            prediction_parts.append(f"Based on your analysis summary: {analysis_summary[:200]}...")
        elif isinstance(enhanced_analysis, dict) and recommendations:
            # Use recommendations from analysis
            if len(recommendations) > 0:
                prediction_parts.append(f"Following the recommendations from your analysis: {recommendations[0] if isinstance(recommendations[0], str) else str(recommendations[0])}")
        
        # Reference specific conditions
        if acne_level and isinstance(acne_level, (int, float)) and acne_level > 30:
            prediction_parts.append(f"Your current acne level is {int(acne_level)}%. With a targeted treatment routine, you should see a 20-30% reduction within 3-4 weeks.")
        elif acne_level and isinstance(acne_level, (int, float)) and acne_level > 15:
            prediction_parts.append(f"Your acne level ({int(acne_level)}%) is moderate. Consistent use of gentle, non-comedogenic products should improve this within 2-3 weeks.")
        
        if dryness_level and isinstance(dryness_level, (int, float)) and dryness_level > 40:
            prediction_parts.append(f"Your skin dryness ({int(dryness_level)}%) can improve with proper hydration. Using a quality moisturizer twice daily should show results in 1-2 weeks.")
        elif dryness_level and isinstance(dryness_level, (int, float)) and dryness_level > 25:
            prediction_parts.append(f"Your skin shows moderate dryness ({int(dryness_level)}%). Regular moisturizing will help restore your skin barrier within 1-2 weeks.")
        
        if overall_health and isinstance(overall_health, (int, float)):
            if overall_health < 50:
                prediction_parts.append(f"Your overall skin health is {int(overall_health)}%. With a consistent routine addressing your specific concerns, you can expect to see improvements to 60-70% within 4-6 weeks.")
            elif overall_health < 70:
                prediction_parts.append(f"Your skin health is at {int(overall_health)}%. Maintaining your routine and addressing specific concerns can help you reach 75-85% within 3-4 weeks.")
            else:
                prediction_parts.append(f"Your skin health is good at {int(overall_health)}%! Continue your routine to maintain and further improve your results.")
        
        if skin_age and isinstance(skin_age, (int, float)):
            prediction_parts.append(f"Your current skin age is {int(skin_age)}. With proper care and protection, you can maintain or improve this over time.")
        
        # Historical comparison if available
        if historical_metrics and len(historical_metrics) > 1:
            # Compare with previous analysis
            try:
                prev_health = historical_metrics[1].get('overall_health') or historical_metrics[1].get('overallHealth')
                if prev_health and overall_health:
                    if isinstance(prev_health, str):
                        prev_health = float(prev_health)
                    if isinstance(overall_health, str):
                        overall_health = float(overall_health)
                    
                    change = overall_health - prev_health
                    if change > 5:
                        prediction_parts.append(f"Great progress! Your skin health improved by {change:.1f}% since your last scan. Keep up the excellent work!")
                    elif change < -5:
                        prediction_parts.append(f"Your skin health decreased by {abs(change):.1f}% since your last scan. Review your routine and consider adjusting your approach.")
            except:
                pass
        
        # Default prediction if no specific metrics available
        if not prediction_parts:
            prediction_parts.append(f"With consistent care targeting your {condition}, you should see improvements within 2-4 weeks. Track your progress with regular scans.")
        
        progress_prediction = " ".join(prediction_parts)
    else:
        # No analysis - prompt for first scan
        progress_prediction = "Take your first skin scan to get a personalized progress outlook based on your unique skin metrics and conditions."
    
    # Environmental recommendation based on weather
    env_rec = None
    if weather:
        humidity = weather.get('humidity_percent', 0)
        temp = weather.get('temperature_celsius', 0)
        conditions = weather.get('conditions', '')

        if humidity < 30:
            env_rec = f"💧 Low humidity ({humidity}%) - your skin may feel drier. Focus on hydration and barrier protection."
        elif temp > 30:
            env_rec = f"🌡️ Hot weather ({temp}°C) - use lightweight, oil-free products and stay hydrated."
        elif 'Rain' in conditions:
            env_rec = "🌧️ Rainy day - great time for indoor skincare treatments like masks and serums!"
        elif temp < 10:
            env_rec = f"❄️ Cold weather ({temp}°C) - protect your skin with richer moisturizers and avoid harsh winds."

    # Get product recommendations from latest analysis
    recommended_products = []
    if latest_analysis:
        # Extract products from analysis
        products = latest_analysis.get('products', [])
        if isinstance(products, list) and len(products) > 0:
            # Take top 2 products
            for product in products[:2]:
                if isinstance(product, dict):
                    recommended_products.append({
                        'product_id': product.get('product_id', f"prod_{len(recommended_products)}"),
                        'name': product.get('name', 'Product'),
                        'brand': product.get('brand', 'Brand'),
                        'description': product.get('description'),
                        'price_range': product.get('price_range', product.get('priceRange')),
                        'amazon_url': product.get('amazon_url', product.get('amazonUrl'))
                    })
    
    # Check-in question
    check_in_question = "How did your skin feel today? Any changes you noticed?"
    
    return {
        'daily_tip': daily_tip,
        'check_in_question': check_in_question,
        'progress_prediction': progress_prediction,
        'environmental_recommendation': env_rec,
        'recommended_products': recommended_products if recommended_products else None
    }


# Helper functions

def get_latest_analysis(user_id):
    """Get most recent skin analysis - always fetches fresh data
    Extracts and normalizes analysis data from DynamoDB structure
    """
    try:
        # Always query fresh - don't cache
        # Get multiple items to find a completed one
        response = analyses_table.query(
            IndexName='UserIndex',
            KeyConditionExpression='user_id = :user_id',
            ExpressionAttributeValues={':user_id': user_id},
            ScanIndexForward=False,  # Get most recent first
            Limit=10  # Get multiple to filter for completed
        )

        items = response.get('Items', [])
        
        # Filter for completed analyses first
        completed_items = []
        for item in items:
            # Handle both DynamoDB format and dict format
            status = item.get('status', {})
            if isinstance(status, dict):
                status = status.get('S') or status.get('status')
            if status == 'completed':
                completed_items.append(item)
        
        # Use completed items if available, otherwise use most recent (even if pending)
        if completed_items:
            items = completed_items[:1]
        elif items:
            items = items[:1]
        
        if items:
            item = items[0]
            # Convert DynamoDB item to dict
            result = {}
            for key, value in item.items():
                if hasattr(value, 'value'):  # Decimal type
                    result[key] = str(value)
                elif isinstance(value, dict):
                    # Handle nested dicts (like prediction, enhanced_analysis)
                    result[key] = {k: str(v) if hasattr(v, 'value') else v for k, v in value.items()}
                else:
                    result[key] = value
            
            # Extract and normalize analysis metrics from nested structures
            # Check prediction field (contains actual metrics and condition)
            prediction = result.get('prediction', {})
            if isinstance(prediction, dict):
                # Extract condition from prediction (this is the primary source)
                if prediction.get('condition'):
                    result['condition'] = prediction.get('condition')
                
                # Extract confidence
                if prediction.get('confidence'):
                    result['confidence'] = prediction.get('confidence')
                
                # Extract all_conditions for additional context
                if prediction.get('all_conditions'):
                    result['all_conditions'] = prediction.get('all_conditions')
                
                # Extract metrics from prediction (if they exist)
                result['acne_level'] = prediction.get('acne_level') or prediction.get('acneLevel')
                result['dryness_level'] = prediction.get('dryness_level') or prediction.get('drynessLevel')
                result['moisture_level'] = prediction.get('moisture_level') or prediction.get('moistureLevel')
                result['overall_health'] = prediction.get('overall_health') or prediction.get('overallHealth')
                result['skin_age'] = prediction.get('skin_age') or prediction.get('skinAge')
                result['pigmentation_level'] = prediction.get('pigmentation_level') or prediction.get('pigmentationLevel')
                result['dark_circle_level'] = prediction.get('dark_circle_level') or prediction.get('darkCircleLevel')
            
            # Check enhanced_analysis field (contains summary from multi-agent system)
            enhanced = result.get('enhanced_analysis', {})
            if isinstance(enhanced, dict):
                # Extract summary (this is the AI-generated analysis summary)
                result['analysis_summary'] = enhanced.get('summary', '')
                result['recommendations'] = enhanced.get('recommendations', [])
                result['care_instructions'] = enhanced.get('care_instructions', [])
                
                # Extract condition and other details (as fallback)
                if not result.get('condition'):
                    result['condition'] = enhanced.get('condition') or enhanced.get('primary_concern') or enhanced.get('skin_condition')
                if not result.get('confidence'):
                    result['confidence'] = enhanced.get('confidence') or enhanced.get('confidence_score')
            
            # Extract condition from various possible fields (final fallback)
            if not result.get('condition'):
                result['condition'] = result.get('primary_concern') or result.get('skin_condition') or 'skin health'
            
            # Store prediction and enhanced_analysis for reference
            result['prediction_data'] = prediction
            result['enhanced_analysis_data'] = enhanced
            
            # Log extracted data for debugging
            analysis_timestamp = result.get('timestamp') or result.get('analysis_timestamp')
            acne = result.get('acne_level') or result.get('acneLevel', 'N/A')
            health = result.get('overall_health') or result.get('overallHealth', 'N/A')
            condition = result.get('condition', 'N/A')
            
            print(f"✅ Retrieved latest analysis:")
            print(f"   Condition: {condition}")
            print(f"   Acne Level: {acne}")
            print(f"   Overall Health: {health}")
            print(f"   Timestamp: {analysis_timestamp}")
            print(f"   Has prediction: {bool(prediction)}")
            print(f"   Has enhanced: {bool(enhanced)}")
            
            return result
        print("⚠️ No analysis found for user")
        return None
    except Exception as e:
        print(f"❌ Error querying latest analysis: {e}")
        import traceback
        traceback.print_exc()
        return None


def get_historical_metrics(user_id, days=30):
    """Get historical skin metrics"""
    try:
        # Calculate cutoff timestamp (Unix timestamp in seconds)
        cutoff_timestamp = int((datetime.utcnow() - timedelta(days=days)).timestamp())

        response = analyses_table.query(
            IndexName='UserIndex',
            KeyConditionExpression='user_id = :user_id AND #ts > :cutoff',
            ExpressionAttributeNames={
                '#ts': 'timestamp'  # timestamp is a reserved word
            },
            ExpressionAttributeValues={
                ':user_id': user_id,
                ':cutoff': cutoff_timestamp
            }
        )

        return response.get('Items', [])
    except Exception as e:
        print(f"Error querying historical metrics: {e}")
        return []


def calculate_routine_adherence(user_id):
    """
    Calculate routine completion rates
    Would integrate with actual routine tracking system
    """
    # Placeholder implementation
    # In production, this would query a routine_completions table
    return {
        'last_7_days': 0.65,
        'last_14_days': 0.58,
        'last_30_days': 0.62,
        'morning_completion_rate': 0.75,
        'evening_completion_rate': 0.50,
        'current_streak': 3
    }


def get_recent_checkins(user_id, days=7):
    """Get recent check-in responses"""
    try:
        # Calculate cutoff date (ISO 8601 string format)
        cutoff_date = (datetime.utcnow() - timedelta(days=days)).isoformat()

        response = checkin_responses_table.query(
            KeyConditionExpression='user_id = :user_id AND #ts > :cutoff',
            ExpressionAttributeNames={
                '#ts': 'timestamp'  # timestamp is a reserved word
            },
            ExpressionAttributeValues={
                ':user_id': user_id,
                ':cutoff': cutoff_date  # String format for ISO 8601
            }
        )

        return response.get('Items', [])
    except Exception as e:
        print(f"Error querying recent checkins: {e}")
        return []


def invoke_lambda(function_name, payload):
    """Invoke another Lambda function"""
    full_function_name = f"{os.environ.get('LAMBDA_PREFIX', 'lumen-skincare-dev')}-{function_name}"

    response = lambda_client.invoke(
        FunctionName=full_function_name,
        InvocationType='RequestResponse',
        Payload=json.dumps(payload)
    )

    response_payload = json.loads(response['Payload'].read())
    if response_payload.get('statusCode') == 200:
        return json.loads(response_payload['body'])
    else:
        print(f"Lambda {function_name} error: {response_payload}")
        return {}


def get_agent_id(param_name):
    """Retrieve Bedrock agent ID from SSM Parameter Store"""
    param_path = f"/{os.environ.get('LAMBDA_PREFIX', 'lumen-skincare-dev')}/bedrock/{param_name}"

    try:
        response = ssm_client.get_parameter(Name=param_path)
        agent_id = response['Parameter']['Value']

        if agent_id == 'PLACEHOLDER' or not agent_id:
            raise ValueError(f"Agent ID not configured: {param_name}")

        return agent_id
    except ssm_client.exceptions.ParameterNotFound:
        print(f"Parameter not found: {param_path}")
        raise ValueError(f"Agent ID not configured: {param_name}")


def success_response(data):
    """Format success response"""
    return {
        'statusCode': 200,
        'body': json.dumps({
            'success': True,
            'data': data
        }, default=str)
    }


def error_response(message):
    """Format error response"""
    return {
        'statusCode': 400,
        'body': json.dumps({
            'success': False,
            'error': message
        })
    }
