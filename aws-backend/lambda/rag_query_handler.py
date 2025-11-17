"""
RAG Query Handler
Performs semantic search in Pinecone vector database for skincare knowledge
"""

import json
import os
import boto3
from pinecone_http_client import PineconeHTTPClient

# Initialize AWS clients
secretsmanager = boto3.client('secretsmanager')
bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')

# Initialize Pinecone
def get_pinecone_api_key():
    """Retrieve Pinecone API key from Secrets Manager"""
    secret_name = os.environ['PINECONE_SECRET_ARN']
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    return response['SecretString']

# Lazy initialization
_pinecone_client = None

def get_pinecone_client():
    """Get or create Pinecone HTTP client"""
    global _pinecone_client

    if _pinecone_client is None:
        api_key = get_pinecone_api_key()
        _pinecone_client = PineconeHTTPClient(api_key=api_key)

    return _pinecone_client


def lambda_handler(event, context):
    """
    RAG Query Handler - Performs semantic search in Pinecone

    Handles TWO invocation modes:
    1. Direct Lambda invocation (from personalized-insights-generator)
    2. Bedrock Agent action group invocation (from Skin Analyst/Routine Coach agents)
    """
    print(f"Event: {json.dumps(event)}")

    # Check if this is a Bedrock Agent invocation
    if 'actionGroup' in event and 'apiPath' in event:
        return handle_bedrock_agent_action(event, context)

    # Otherwise, handle as direct invocation
    try:
        action = event.get('action')
        query_text = event.get('query')
        namespace = event.get('namespace', 'knowledge-base')
        top_k = event.get('top_k', 5)
        filter_dict = event.get('filter')

        if not all([action, query_text]):
            return error_response("Missing required parameters: action, query")

        # Generate embedding for query
        query_embedding = generate_embedding(query_text)

        # Search in Pinecone
        results = search_pinecone(
            embedding=query_embedding,
            namespace=namespace,
            top_k=top_k,
            filter_dict=filter_dict
        )

        return success_response({
            'query': query_text,
            'namespace': namespace,
            'results': results,
            'result_count': len(results)
        })

    except Exception as e:
        print(f"Error in RAG query handler: {e}")
        import traceback
        traceback.print_exc()
        return error_response(str(e))


def handle_bedrock_agent_action(event, context):
    """
    Handle Bedrock Agent action group invocations
    Returns response in Bedrock Agent format
    """
    api_path = event.get('apiPath', '')
    http_method = event.get('httpMethod', '')

    print(f"🤖 Bedrock Agent Action: {http_method} {api_path}")

    try:
        # Extract parameters from request body
        request_body = event.get('requestBody', {})
        properties = {}

        if 'content' in request_body:
            content = request_body['content']
            if 'application/json' in content:
                props_list = content['application/json'].get('properties', [])
                for prop in props_list:
                    properties[prop['name']] = prop.get('value', '')

        print(f"📋 Parameters: {properties}")

        # Route to appropriate handler
        if api_path == '/search-similar-cases':
            result = handle_search_similar_cases(properties)
        elif api_path == '/get-ingredient-research':
            result = handle_get_ingredient_research(properties)
        elif api_path == '/get-motivation-strategy':
            result = handle_get_motivation_strategy(properties)
        else:
            result = {'error': f'Unknown API path: {api_path}'}

        # Return in Bedrock Agent format
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': event.get('actionGroup'),
                'apiPath': api_path,
                'httpMethod': http_method,
                'httpStatusCode': 200,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps(result)
                    }
                }
            }
        }

    except Exception as e:
        print(f"❌ Error in Bedrock agent action: {e}")
        import traceback
        traceback.print_exc()

        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': event.get('actionGroup'),
                'apiPath': api_path,
                'httpMethod': http_method,
                'httpStatusCode': 500,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps({'error': str(e)})
                    }
                }
            }
        }


def handle_search_similar_cases(params):
    """Handle /search-similar-cases action"""
    condition = params.get('condition', '')
    skin_type = params.get('skin_type', '')

    user_metrics = {
        'primary_concerns': [condition],
        'acne': 50 if 'acne' in condition.lower() else 0,
        'dryness': 50 if skin_type == 'dry' else 0
    }
    user_patterns = f"{condition} with {skin_type} skin"

    return search_similar_cases(user_metrics, user_patterns)


def handle_get_ingredient_research(params):
    """Handle /get-ingredient-research action"""
    ingredient_name = params.get('ingredient_name', '')
    condition = params.get('condition', '')

    if not ingredient_name:
        return {'error': 'Missing ingredient_name parameter'}

    return get_ingredient_research(ingredient_name)


def handle_get_motivation_strategy(params):
    """Handle /get-motivation-strategy action"""
    adherence_level = params.get('adherence_level', 'medium')
    user_patterns = params.get('user_patterns', '')

    return get_motivation_strategy(adherence_level, user_patterns)


def generate_embedding(text):
    """
    Generate embedding using AWS Bedrock Titan Embeddings
    Returns 1536-dimensional vector
    """
    try:
        response = bedrock_runtime.invoke_model(
            modelId='amazon.titan-embed-text-v1',
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                'inputText': text
            })
        )

        response_body = json.loads(response['body'].read())
        embedding = response_body['embedding']

        print(f"Generated embedding with {len(embedding)} dimensions")
        return embedding

    except Exception as e:
        print(f"Error generating embedding: {e}")
        raise


def search_pinecone(embedding, namespace, top_k=5, filter_dict=None):
    """
    Search Pinecone index for similar vectors
    """
    try:
        client = get_pinecone_client()
        index_name = os.environ['PINECONE_INDEX_NAME']

        response = client.query(
            index_name=index_name,
            vector=embedding,
            top_k=top_k,
            namespace=namespace,
            include_metadata=True,
            filter_dict=filter_dict
        )

        # Format results
        results = []
        for match in response.get('matches', []):
            results.append({
                'id': match['id'],
                'score': float(match['score']),
                'metadata': match.get('metadata', {})
            })

        print(f"Found {len(results)} results in namespace '{namespace}'")
        return results

    except Exception as e:
        print(f"Error searching Pinecone: {e}")
        raise


def search_similar_cases(user_metrics, user_patterns):
    """
    Tool for Skin Analyst Agent: Find similar user journeys
    """
    # Create query from user metrics
    query_text = f"""
    User with skin concerns: {user_metrics.get('primary_concerns', [])}
    Current metrics: acne={user_metrics.get('acne', 0)},
                    dryness={user_metrics.get('dryness', 0)},
                    pigmentation={user_metrics.get('pigmentation', 0)}
    Patterns: {user_patterns}
    """

    query_embedding = generate_embedding(query_text)

    results = search_pinecone(
        embedding=query_embedding,
        namespace='user-patterns',
        top_k=10
    )

    return {
        'similar_cases': results,
        'insights': extract_insights_from_cases(results)
    }


def get_ingredient_research(ingredient_name):
    """
    Tool for Skin Analyst Agent: Get research on ingredient efficacy
    """
    query_text = f"Scientific research and efficacy of {ingredient_name} for skincare"

    query_embedding = generate_embedding(query_text)

    results = search_pinecone(
        embedding=query_embedding,
        namespace='knowledge-base',
        top_k=5,
        filter_dict={'type': 'ingredient_research'}
    )

    return {
        'ingredient': ingredient_name,
        'research': results,
        'summary': summarize_research(results)
    }


def get_motivation_strategy(adherence_level, user_patterns):
    """
    Tool for Routine Coach Agent: Find effective motivation techniques
    """
    query_text = f"""
    Motivation strategies for users with {adherence_level} adherence
    User patterns: {user_patterns}
    """

    query_embedding = generate_embedding(query_text)

    results = search_pinecone(
        embedding=query_embedding,
        namespace='user-patterns',
        top_k=5,
        filter_dict={'category': 'motivation'}
    )

    return {
        'adherence_level': adherence_level,
        'strategies': results,
        'recommended_message': generate_motivation_message(results, adherence_level)
    }


def extract_insights_from_cases(similar_cases):
    """Extract actionable insights from similar user cases"""
    insights = []

    for case in similar_cases[:3]:  # Top 3 most similar
        metadata = case.get('metadata', {})
        if metadata.get('success'):
            insights.append({
                'pattern': metadata.get('pattern_description'),
                'success_rate': metadata.get('success_rate'),
                'timeline': metadata.get('timeline_days'),
                'key_factors': metadata.get('success_factors', [])
            })

    return insights


def summarize_research(research_results):
    """Summarize ingredient research findings"""
    if not research_results:
        return "No research found"

    # Aggregate findings from top results
    summary = {
        'efficacy_rating': 0.0,
        'use_cases': [],
        'evidence_level': 'insufficient'
    }

    for result in research_results:
        metadata = result.get('metadata', {})
        summary['efficacy_rating'] += metadata.get('efficacy', 0.0)
        summary['use_cases'].extend(metadata.get('use_cases', []))

    if research_results:
        summary['efficacy_rating'] /= len(research_results)
        summary['evidence_level'] = 'strong' if len(research_results) >= 3 else 'moderate'

    return summary


def generate_motivation_message(strategies, adherence_level):
    """Generate personalized motivation message"""
    if not strategies:
        return "Keep going! Every step counts."

    # Use top strategy
    top_strategy = strategies[0].get('metadata', {})
    message_template = top_strategy.get('message_template', '')

    # Customize based on adherence level
    if adherence_level == 'high':
        tone = 'celebratory'
    elif adherence_level == 'medium':
        tone = 'supportive'
    else:
        tone = 'compassionate'

    return {
        'message': message_template,
        'tone': tone,
        'strategy_score': strategies[0].get('score')
    }


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
