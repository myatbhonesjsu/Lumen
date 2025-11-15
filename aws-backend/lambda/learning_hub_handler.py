"""
Learning Hub Lambda Handler
AI-powered chatbot with RAG, vector search, and user context
"""

import json
import os
import time
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Optional, Any
import re

import boto3
from boto3.dynamodb.conditions import Key, Attr

# Try to import vector search (gracefully fallback if not available)
try:
    from vector_search import search_articles, get_vector_search
    VECTOR_SEARCH_AVAILABLE = True
    print("Vector search module loaded successfully")
except ImportError as e:
    print(f"Vector search not available: {e}. Using fallback keyword search.")
    VECTOR_SEARCH_AVAILABLE = False

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
bedrock_runtime = boto3.client('bedrock-runtime')

# Environment variables
CHAT_HISTORY_TABLE = os.environ.get('CHAT_HISTORY_TABLE', '')
EDUCATIONAL_CONTENT_TABLE = os.environ.get('EDUCATIONAL_CONTENT_TABLE', '')
ANALYSES_TABLE = os.environ.get('ANALYSES_TABLE', '')


def should_use_rag(message: str) -> bool:
    """
    Determine if message should use RAG and analysis context.
    Returns True if message contains trigger words/phrases that indicate
    the user is asking about their analysis or needs personalized advice.
    """

    message_lower = message.lower()

    # Trigger patterns for RAG activation
    rag_triggers = [
        # Analysis-related
        'my analysis', 'my skin', 'my condition', 'my results', 'my face',
        'analyze my', 'based on my', 'from my analysis', 'my report',

        # History references
        'last time', 'previous', 'history', 'before', 'past analysis',
        'earlier', 'recent analysis', 'my last', 'my previous',

        # Personalized advice requests
        'what should i', 'recommend for me', 'help me with', 'advice for me',
        'what can i do', 'how can i improve', 'suggestions for me',
        'personalized', 'tailored', 'specific to me',

        # Specific conditions (when asking about own condition)
        'my acne', 'my wrinkles', 'my dryness', 'my dark circles',
        'my pigmentation', 'my moisture', 'my skin age',

        # Comparison and progress
        'improved', 'worse', 'better', 'progress', 'change',
        'compared to', 'difference', 'tracking',

        # General conversational questions (to enable friendly AI personality)
        'your name', 'who are you', 'what are you', 'tell me about',
        'about you', 'about yourself', 'can you', 'do you', 'are you',
        'how are you', 'introduce yourself', 'know you', 'remember',
        'i am', "i'm ", 'my name', 'call me', 'nice to meet'
    ]

    # Check for any trigger pattern
    for trigger in rag_triggers:
        if trigger in message_lower:
            return True

    # Check for question + skin concern pattern (e.g., "How do I treat acne?")
    skin_concerns = ['acne', 'wrinkles', 'dryness', 'dark circles', 'pigmentation',
                     'aging', 'fine lines', 'spots', 'redness', 'sensitivity']

    is_question = any(q in message_lower for q in ['how', 'what', 'why', 'when', 'should', 'can'])
    has_concern = any(concern in message_lower for concern in skin_concerns)

    # If asking a question about a skin concern, use RAG
    if is_question and has_concern:
        return True

    # Simple greetings and general chat should NOT use RAG
    simple_patterns = [
        # Just greetings
        message_lower.strip() in ['hi', 'hello', 'hey', 'hi!', 'hello!', 'hey!'],
        # Just thank you
        message_lower.strip() in ['thanks', 'thank you', 'ty', 'thanks!', 'thank you!'],
        # Just confirmations
        message_lower.strip() in ['ok', 'okay', 'yes', 'no', 'sure', 'ok!', 'okay!'],
    ]

    if any(simple_patterns):
        return False

    return False  # Default to no RAG for general questions


def lambda_handler(event, context):
    """Main Lambda handler for Learning Hub operations"""

    print(f"Event: {json.dumps(event)}")

    # Parse request
    http_method = event.get('httpMethod', '')
    path = event.get('path', '')

    try:
        if http_method == 'POST' and '/chat' in path:
            return handle_chat_message(event)
        elif http_method == 'POST' and '/routines/generate' in path:
            return handle_generate_routine(event)
        elif http_method == 'GET' and '/recommendations' in path:
            return handle_get_recommendations(event)
        elif http_method == 'GET' and '/articles' in path:
            return handle_get_articles(event)
        elif http_method == 'GET' and '/chat-history' in path:
            return handle_get_chat_history(event)
        else:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'Not found'})
            }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': str(e)})
        }


def handle_chat_message(event):
    """Handle chat message from user"""

    body = json.loads(event.get('body', '{}'))
    user_id = body.get('user_id', 'anonymous')
    message = body.get('message', '')
    session_id = body.get('session_id', str(uuid.uuid4()))
    local_analyses = body.get('local_analyses', [])  # Local analysis data from device

    if not message:
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'Message is required'})
        }

    # Check if message contains trigger words/phrases for RAG
    use_rag = should_use_rag(message)

    # Only use analysis context if RAG is triggered
    user_context = local_analyses if use_rag else []

    # Get chat history for context
    chat_history = get_recent_chat_history(user_id, session_id, limit=10)

    # Generate AI response - RAG only if triggered
    ai_response = generate_ai_response(
        message=message,
        user_context=user_context,
        chat_history=chat_history,
        user_id=user_id,
        use_rag=use_rag
    )

    # Save chat messages to history
    timestamp = int(time.time())
    save_chat_message(user_id, session_id, timestamp, 'user', message)
    save_chat_message(user_id, session_id, timestamp + 1, 'assistant', ai_response['response'])

    # Get related articles only if RAG is used
    related_articles = get_related_articles(message, user_context) if use_rag else []

    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps({
            'session_id': session_id,
            'response': ai_response['response'],
            'sources': ai_response.get('sources', []),
            'related_articles': related_articles,
            'timestamp': timestamp,
            'rag_used': use_rag
        }, default=decimal_default)
    }


def handle_generate_routine(event):
    """Generate personalized skincare routine based on user's skin analysis"""

    body = json.loads(event.get('body', '{}'))
    user_id = body.get('user_id', 'anonymous')
    latest_analysis = body.get('latest_analysis', {})
    preferences = body.get('preferences', {})
    budget = body.get('budget', 'moderate')  # 'budget', 'moderate', 'premium'

    if not latest_analysis:
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'latest_analysis is required'})
        }

    # Extract analysis data
    acne_level = latest_analysis.get('acneLevel', 0)
    dryness_level = latest_analysis.get('drynessLevel', 0)
    moisture_level = latest_analysis.get('moistureLevel', 0)
    pigmentation_level = latest_analysis.get('pigmentationLevel', 0)
    dark_circle_level = latest_analysis.get('darkCircleLevel', 0)
    skin_age = latest_analysis.get('skinAge', 25)
    overall_health = latest_analysis.get('overallHealth', 50)

    # Build prompt for Claude
    system_prompt = """You are an expert dermatologist and skincare specialist creating personalized skincare routines.

Your task is to generate a customized morning and evening skincare routine based on the user's skin analysis.

Guidelines:
• Prioritize evidence-based ingredients and steps
• Consider the user's specific concerns (acne, dryness, aging, etc.)
• Recommend specific product types (not brand names unless generic like "CeraVe")
• Explain WHY each step is important for their skin
• Keep routines practical and achievable (5-6 steps max)
• Consider budget constraints
• Focus on treating the most severe concerns first

Return ONLY a valid JSON object (no markdown, no extra text) with this exact structure:
{
  "morning_routine": [
    {"step": "Step name", "product_type": "Specific product", "reason": "Why important", "icon": "SF Symbol name"}
  ],
  "evening_routine": [
    {"step": "Step name", "product_type": "Specific product", "reason": "Why important", "icon": "SF Symbol name"}
  ],
  "key_concerns": ["concern1", "concern2"],
  "overall_strategy": "Brief explanation of the routine strategy",
  "expected_timeline": "When to expect results",
  "important_notes": ["note1", "note2"]
}

Use these SF Symbol icon names: drop.fill, sparkles, eyedropper.full, cloud.fill, sun.max.fill, wand.and.stars, cross.case.fill, moon.fill, leaf.fill, drop.triangle.fill"""

    user_prompt = f"""Create a personalized skincare routine for this user:

SKIN ANALYSIS:
- Acne Level: {acne_level:.0f}% {"(High concern)" if acne_level > 60 else "(Moderate)" if acne_level > 30 else "(Low)"}
- Dryness Level: {dryness_level:.0f}% {"(High concern)" if dryness_level > 60 else "(Moderate)" if dryness_level > 30 else "(Low)"}
- Moisture Level: {moisture_level:.0f}%
- Pigmentation: {pigmentation_level:.0f}% {"(High concern)" if pigmentation_level > 60 else "(Moderate)" if pigmentation_level > 30 else "(Low)"}
- Dark Circles: {dark_circle_level:.0f}% {"(High concern)" if dark_circle_level > 60 else "(Moderate)" if dark_circle_level > 30 else "(Low)"}
- Skin Age: {skin_age} years
- Overall Health Score: {overall_health:.0f}%

BUDGET: {budget}

PREFERENCES:
{json.dumps(preferences, indent=2) if preferences else "None specified"}

Generate a routine that addresses their top concerns while maintaining skin health. Focus on the most critical issues first."""

    try:
        # Call Claude to generate routine
        response = bedrock_runtime.invoke_model(
            modelId='anthropic.claude-3-sonnet-20240229-v1:0',
            body=json.dumps({
                'anthropic_version': 'bedrock-2023-05-31',
                'max_tokens': 2048,
                'temperature': 0.7,
                'system': system_prompt,
                'messages': [
                    {
                        'role': 'user',
                        'content': user_prompt
                    }
                ]
            })
        )

        response_body = json.loads(response['body'].read())
        ai_text = response_body['content'][0]['text']

        # Parse the JSON response from Claude
        # Claude might wrap it in markdown code blocks, so clean it
        ai_text_clean = ai_text.strip()
        if ai_text_clean.startswith('```json'):
            ai_text_clean = ai_text_clean[7:]
        if ai_text_clean.startswith('```'):
            ai_text_clean = ai_text_clean[3:]
        if ai_text_clean.endswith('```'):
            ai_text_clean = ai_text_clean[:-3]
        ai_text_clean = ai_text_clean.strip()

        routine_data = json.loads(ai_text_clean)

        # Return the generated routine
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'user_id': user_id,
                'routine': routine_data,
                'generated_at': int(time.time()),
                'analysis_summary': {
                    'top_concerns': get_top_concerns(latest_analysis),
                    'overall_health': overall_health,
                    'skin_age': skin_age
                }
            }, default=decimal_default)
        }

    except json.JSONDecodeError as e:
        print(f"JSON parsing error: {e}")
        print(f"AI response: {ai_text}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'Failed to parse routine data', 'details': str(e)})
        }
    except Exception as e:
        print(f"Routine generation error: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'Failed to generate routine', 'details': str(e)})
        }


def get_top_concerns(analysis: Dict) -> List[str]:
    """Extract top 3 concerns from analysis"""
    concerns = []

    concern_map = {
        'acneLevel': ('Acne', analysis.get('acneLevel', 0)),
        'drynessLevel': ('Dryness', analysis.get('drynessLevel', 0)),
        'pigmentationLevel': ('Pigmentation', analysis.get('pigmentationLevel', 0)),
        'darkCircleLevel': ('Dark Circles', analysis.get('darkCircleLevel', 0))
    }

    # Sort by severity
    sorted_concerns = sorted(concern_map.values(), key=lambda x: x[1], reverse=True)

    # Return top 3 concerns above threshold
    for name, level in sorted_concerns:
        if level > 30:  # Only include significant concerns
            concerns.append(f"{name} ({int(level)}%)")
        if len(concerns) >= 3:
            break

    return concerns if concerns else ["General maintenance"]


def handle_get_recommendations(event):
    """Get personalized article recommendations based on user's analysis history"""

    query_params = event.get('queryStringParameters', {}) or {}
    user_id = query_params.get('user_id', 'anonymous')
    
    # Get user's analysis history
    user_context = get_user_context(user_id, limit=5)
    
    # Extract conditions from analyses
    conditions = []
    for analysis in user_context:
        if 'prediction' in analysis and 'condition' in analysis['prediction']:
            conditions.append(analysis['prediction']['condition'])
        if 'prediction' in analysis and 'all_conditions' in analysis['prediction']:
            conditions.extend(analysis['prediction']['all_conditions'].keys())
    
    # Get unique conditions
    unique_conditions = list(set(conditions))
    
    # Get recommended articles for these conditions
    recommendations = get_articles_for_conditions(unique_conditions)
    
    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps({
            'recommendations': recommendations,
            'based_on_conditions': unique_conditions[:3],  # Show top 3
            'total_analyses': len(user_context)
        }, default=decimal_default)
    }


def handle_get_articles(event):
    """Get educational articles with optional filtering"""
    
    query_params = event.get('queryStringParameters', {}) or {}
    category = query_params.get('category')
    search_query = query_params.get('query')
    
    # Get articles from DynamoDB
    articles = get_educational_articles(category=category, search_query=search_query)
    
    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps({
            'articles': articles,
            'count': len(articles)
        }, default=decimal_default)
    }


def handle_get_chat_history(event):
    """Get chat history for a user/session"""
    
    query_params = event.get('queryStringParameters', {}) or {}
    user_id = query_params.get('user_id', 'anonymous')
    session_id = query_params.get('session_id')
    
    if not session_id:
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'session_id is required'})
        }
    
    history = get_recent_chat_history(user_id, session_id, limit=50)
    
    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps({
            'history': history,
            'session_id': session_id
        }, default=decimal_default)
    }


def generate_ai_response(message: str, user_context: List[Dict], chat_history: List[Dict], user_id: str, use_rag: bool = False) -> Dict[str, Any]:
    """Generate AI response using Bedrock with optional RAG"""

    # For simple messages without RAG, provide quick conversational responses
    if not use_rag:
        return generate_simple_response(message, chat_history)

    # Build context for the AI (only when RAG is enabled)
    context_parts = []

    # Add user's analysis history
    if user_context:
        context_parts.append("USER'S SKIN ANALYSIS HISTORY:")
        for idx, analysis in enumerate(user_context[:3], 1):
            if 'prediction' in analysis:
                condition = analysis['prediction'].get('condition', 'Unknown')
                confidence = analysis['prediction'].get('confidence', 0)
                timestamp = analysis.get('timestamp', 0)
                # Convert Decimal to int/float for datetime
                timestamp = int(timestamp) if timestamp else 0
                date_str = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d') if timestamp else 'Unknown'

                context_parts.append(
                    f"{idx}. {date_str}: {condition} ({int(confidence*100)}% confidence)"
                )

                if 'enhanced_analysis' in analysis and 'summary' in analysis['enhanced_analysis']:
                    context_parts.append(f"   Summary: {analysis['enhanced_analysis']['summary'][:200]}")

    # Add chat history
    if chat_history:
        context_parts.append("\nRECENT CONVERSATION:")
        for msg in chat_history[-5:]:  # Last 5 messages
            role = msg.get('role', 'user')
            content = msg.get('message', '')
            context_parts.append(f"{role.upper()}: {content}")

    context_text = "\n".join(context_parts)

    # Build the prompt
    system_prompt = """You are Lumen, an intelligent and friendly AI skincare assistant with personality and expertise.

## About You
You're warm, knowledgeable, and genuinely care about helping users achieve their skincare goals. You remember details about users, build relationships with them, and provide personalized guidance. You have a friendly, conversational personality.

## Your Capabilities
• **Skincare Expertise**: Provide evidence-based advice on skin health, products, routines, ingredients, and treatments
• **Personalized Guidance**: Remember user preferences, concerns, and history to give tailored recommendations
• **General Conversation**: Engage in friendly chat, answer questions about yourself, remember names, and be a supportive companion
• **Knowledge**: Discuss skincare science, dermatology, ingredients, product recommendations, and wellness topics

## Conversation Style
• Be warm, friendly, and conversational - like talking to a knowledgeable friend
• Use the user's name when you know it and remember previous conversations
• Ask clarifying questions to better understand their needs
• Share relevant examples and analogies to explain complex concepts
• Be encouraging about their progress and supportive during setbacks
• Use emojis occasionally to be more personable (but not excessively)
• Feel free to engage in brief off-topic friendly conversation, but gently guide back to skincare

## Guidelines
• Always provide evidence-based skincare advice when discussing treatments
• Reference scientific studies or dermatology sources when making specific claims
• Don't diagnose medical conditions - suggest seeing a dermatologist for serious concerns
• Be honest about the limits of your knowledge
• Remember: You're here to help users feel confident and informed about their skincare journey

## Tone Examples
✅ "Hey! I noticed your acne scores improved by 20% - that's awesome progress! The niacinamide is clearly working. How's your skin feeling?"
✅ "Great question! Retinol can be tricky. Think of it like training for a marathon - you wouldn't run 26 miles on day one. Let me walk you through a gentle introduction..."
✅ "I can see you're frustrated. Skincare journeys have ups and downs - totally normal! Remember your progress over the past month. Let's figure out this setback together."

Always prioritize user safety, evidence-based recommendations, and building a supportive relationship."""

    user_prompt = f"""{context_text}

CURRENT QUESTION: {message}

Provide a helpful, personalized response based on the user's history and question. If referencing their past analyses, be specific. Include actionable advice."""

    # Use Claude Sonnet via Bedrock Runtime API
    try:
        response = bedrock_runtime.invoke_model(
            modelId='anthropic.claude-3-sonnet-20240229-v1:0',
            body=json.dumps({
                'anthropic_version': 'bedrock-2023-05-31',
                'max_tokens': 1024,
                'system': system_prompt,
                'messages': [
                    {
                        'role': 'user',
                        'content': user_prompt
                    }
                ]
            })
        )

        response_body = json.loads(response['body'].read())
        ai_text = response_body['content'][0]['text']

        return {
            'response': ai_text,
            'sources': [],
            'method': 'claude_direct'
        }
    except Exception as e:
        print(f"Claude error: {e}")

        # Ultimate fallback: template response
        return {
            'response': generate_template_response(message, user_context),
            'sources': [],
            'method': 'template'
        }


def generate_simple_response(message: str, chat_history: List[Dict]) -> Dict[str, Any]:
    """Generate simple conversational responses without RAG for greetings and basic interactions"""

    message_lower = message.lower().strip()

    # Greetings
    if message_lower in ['hi', 'hello', 'hey', 'hi!', 'hello!', 'hey!', 'yo', 'heya']:
        responses = [
            "Hey there! 👋 I'm Lumen, your AI skincare assistant. I'm here to help you with skincare questions, routines, and personalized advice. What's on your mind?",
            "Hello! 😊 I'm Lumen! I can help you with all things skincare - from routines to ingredients to analyzing your skin health. What would you like to know?",
            "Hi! Great to see you! I'm Lumen, and I'm here to help with your skincare journey. How can I assist you today?"
        ]
        return {
            'response': responses[hash(message_lower) % len(responses)],
            'sources': [],
            'method': 'simple'
        }

    # Thank you
    if message_lower in ['thanks', 'thank you', 'ty', 'thanks!', 'thank you!', 'thx']:
        responses = [
            "You're so welcome! 😊 Feel free to ask anything else about skincare - I'm here to help!",
            "Happy to help! That's what I'm here for. Any other skincare questions?",
            "Anytime! I love helping with skincare. Let me know if you need anything else! ✨"
        ]
        return {
            'response': responses[hash(message_lower) % len(responses)],
            'sources': [],
            'method': 'simple'
        }

    # Confirmations
    if message_lower in ['ok', 'okay', 'yes', 'sure', 'ok!', 'okay!', 'yep', 'yup']:
        return {
            'response': "Great! I'm here if you need anything else. Your skin will thank you! ✨",
            'sources': [],
            'method': 'simple'
        }

    if message_lower in ['no', 'nope', 'no!', 'nah']:
        return {
            'response': "No worries! I'm here whenever you're ready. Take care of that beautiful skin! 💙",
            'sources': [],
            'method': 'simple'
        }

    # For other general messages, provide a helpful prompt
    return {
        'response': "I'm here to help with skincare questions! You can ask me about:\n\n• Skincare routines and best practices\n• Understanding ingredients and products\n• General skin concerns (acne, aging, dryness, etc.)\n• When to see a dermatologist\n\nFor personalized advice based on your skin analysis, try asking questions like 'What should I do for my skin?' or 'Based on my analysis, what do you recommend?'",
        'sources': [],
        'method': 'simple'
    }


def generate_template_response(message: str, user_context: List[Dict]) -> str:
    """Generate a template-based response as fallback"""
    
    message_lower = message.lower()
    
    # Check for common questions
    if any(word in message_lower for word in ['routine', 'regimen', 'steps']):
        return """A good skincare routine typically includes these steps:

**Morning:**
1. Cleanser - Gentle face wash
2. Toner - Balance pH (optional)
3. Serum - Target specific concerns
4. Moisturizer - Hydrate
5. Sunscreen - SPF 30+ (most important!)

**Evening:**
1. Cleanser - Remove makeup/dirt
2. Treatment - Active ingredients
3. Eye cream - For delicate area
4. Moisturizer - Night cream

Start simple and add products gradually. Consistency is more important than having many products!"""
    
    elif any(word in message_lower for word in ['acne', 'breakout', 'pimple']):
        return """For acne-prone skin, here's what typically helps:

**Key Steps:**
- Use a gentle cleanser with salicylic acid (2%)
- Apply benzoyl peroxide or niacinamide for treatment
- Always moisturize (oil-free, non-comedogenic)
- Never skip sunscreen

**Lifestyle Tips:**
- Change pillowcases regularly
- Don't touch your face
- Stay hydrated
- Manage stress

If you have severe or cystic acne, or if over-the-counter products aren't helping after 3 months, consult a dermatologist for prescription options."""
    
    elif any(word in message_lower for word in ['dry', 'flaky', 'dehydrated']):
        return """For dry or dehydrated skin:

**Hydration:**
- Use hyaluronic acid serum on damp skin
- Look for glycerin in products
- Apply to slightly damp skin

**Moisturization:**
- Use cream-based moisturizers with ceramides
- Consider facial oils for extra nourishment
- Use a humidifier at night

**Avoid:**
- Hot water (use lukewarm)
- Harsh cleansers or soaps
- Over-exfoliating

Layer hydrating products under moisturizer for best results!"""
    
    elif any(word in message_lower for word in ['wrinkle', 'aging', 'fine line']):
        return """For anti-aging and wrinkle prevention:

**Key Ingredients:**
- Retinol/Retinoids - Gold standard for anti-aging
- Vitamin C - Antioxidant and brightening
- Peptides - Support collagen production
- Niacinamide - Improves skin texture

**Essential Steps:**
- Daily SPF 30+ (prevents 80% of aging)
- Moisturize consistently
- Use retinol at night (start slow)
- Stay hydrated

**Professional Options:**
- Chemical peels
- Microneedling
- Laser treatments
- Consult a dermatologist

Prevention is easier than reversal - start sun protection early!"""
    
    else:
        # Generic helpful response
        return """I'm here to help with your skincare questions! I can provide advice on:

- Building effective skincare routines
- Understanding ingredients and products
- Managing specific skin concerns (acne, dryness, aging, etc.)
- When to see a dermatologist
- Product recommendations

Based on your previous analyses, I can give personalized advice tailored to your skin's needs. What specific aspect of skincare would you like to learn more about?"""


def get_user_context(user_id: str, limit: int = 5) -> List[Dict]:
    """Get user's recent analysis history for context"""
    
    if not ANALYSES_TABLE:
        return []
    
    try:
        table = dynamodb.Table(ANALYSES_TABLE)
        
        # Scan for user's analyses (in production, use better indexing)
        response = table.scan(
            FilterExpression=Attr('user_id').eq(user_id) & Attr('status').eq('completed'),
            Limit=limit
        )
        
        items = response.get('Items', [])

        # Sort by timestamp descending (convert Decimal to int for sorting)
        items.sort(key=lambda x: int(x.get('timestamp', 0)) if x.get('timestamp') else 0, reverse=True)

        return items[:limit]
    except Exception as e:
        print(f"Error getting user context: {e}")
        return []


def get_recent_chat_history(user_id: str, session_id: str, limit: int = 10) -> List[Dict]:
    """Get recent chat history for a session"""
    
    if not CHAT_HISTORY_TABLE:
        return []
    
    try:
        table = dynamodb.Table(CHAT_HISTORY_TABLE)
        
        response = table.query(
            IndexName='SessionIndex',
            KeyConditionExpression=Key('session_id').eq(session_id),
            Limit=limit,
            ScanIndexForward=False  # Most recent first
        )
        
        items = response.get('Items', [])
        items.reverse()  # Chronological order
        
        return items
    except Exception as e:
        print(f"Error getting chat history: {e}")
        return []


def save_chat_message(user_id: str, session_id: str, timestamp: int, role: str, message: str):
    """Save a chat message to history"""
    
    if not CHAT_HISTORY_TABLE:
        return
    
    try:
        table = dynamodb.Table(CHAT_HISTORY_TABLE)
        
        # TTL: 30 days from now
        ttl = int(time.time()) + (30 * 24 * 60 * 60)
        
        table.put_item(
            Item={
                'user_id': user_id,
                'session_id': session_id,
                'timestamp': timestamp,
                'role': role,
                'message': message,
                'ttl': ttl
            }
        )
    except Exception as e:
        print(f"Error saving chat message: {e}")


def get_related_articles(message: str, user_context: List[Dict]) -> List[Dict]:
    """Get related educational articles based on message and context using vector search"""

    # Build enhanced query from message + user conditions
    query_parts = [message]

    # Add user conditions to query for better relevance
    for analysis in user_context:
        if 'prediction' in analysis and 'condition' in analysis['prediction']:
            condition = analysis['prediction']['condition']
            query_parts.append(condition)

    enhanced_query = " ".join(query_parts)

    # Use vector search if available, fallback to keyword search
    if VECTOR_SEARCH_AVAILABLE:
        try:
            articles = search_articles(enhanced_query, top_k=5)
            print(f"Found {len(articles)} articles using vector search")
            return articles
        except Exception as e:
            print(f"Vector search error: {e}, falling back to keyword search")

    # Fallback: keyword-based search
    keywords = extract_keywords(message)
    conditions = []
    for analysis in user_context:
        if 'prediction' in analysis and 'condition' in analysis['prediction']:
            conditions.append(analysis['prediction']['condition'].lower())

    all_keywords = keywords + conditions
    articles = get_articles_for_keywords(all_keywords)

    print(f"Found {len(articles)} articles using keyword search")
    return articles[:5]  # Top 5


def extract_keywords(text: str) -> List[str]:
    """Extract skincare-related keywords from text"""
    
    skincare_keywords = [
        'acne', 'wrinkles', 'dry', 'oily', 'sensitive', 'rosacea', 'eczema',
        'dark spots', 'dark circles', 'eye bags', 'aging', 'sunscreen',
        'retinol', 'vitamin c', 'niacinamide', 'hyaluronic acid',
        'cleanser', 'moisturizer', 'serum', 'routine', 'exfoliate'
    ]
    
    text_lower = text.lower()
    found_keywords = []
    
    for keyword in skincare_keywords:
        if keyword in text_lower:
            found_keywords.append(keyword)
    
    return found_keywords


def get_articles_for_keywords(keywords: List[str]) -> List[Dict]:
    """Get articles matching keywords"""

    # Predefined article database (verified working URLs from reputable sources)
    articles = [
        {
            'id': '1',
            'title': 'Acne: Diagnosis and Treatment',
            'category': 'Conditions',
            'summary': 'Comprehensive guide to acne causes, types, and treatment options from board-certified dermatologists.',
            'url': 'https://www.aad.org/public/diseases/acne-and-rosacea/acne',
            'source': 'American Academy of Dermatology',
            'keywords': ['acne', 'breakout', 'pimple', 'treatment', 'benzoyl peroxide'],
            'relevance_score': 0.95
        },
        {
            'id': '2',
            'title': 'Retinoids: The Gold Standard for Anti-Aging',
            'category': 'Ingredients',
            'summary': 'How retinol and retinoids work to reduce wrinkles, improve texture, and boost collagen production.',
            'url': 'https://www.paulaschoice.com/skin-care-advice/anti-aging-wrinkles/how-retinol-works',
            'source': 'Paula\'s Choice Skincare',
            'keywords': ['retinol', 'retinoid', 'wrinkles', 'aging', 'anti-aging', 'tretinoin'],
            'relevance_score': 0.92
        },
        {
            'id': '3',
            'title': 'How to Choose the Best Sunscreen for Your Skin',
            'category': 'Basics',
            'summary': 'Everything you need to know about SPF, broad-spectrum protection, and choosing the right sunscreen for your skin type.',
            'url': 'https://www.skincancer.org/blog/how-to-choose-the-best-sunscreen-for-your-skin/',
            'source': 'Skin Cancer Foundation',
            'keywords': ['sunscreen', 'spf', 'sun protection', 'aging', 'prevention', 'uva', 'uvb'],
            'relevance_score': 0.90
        },
        {
            'id': '4',
            'title': 'Dry Skin: Overview',
            'category': 'Conditions',
            'summary': 'Learn about dry skin causes, symptoms, and the best moisturizers and treatments.',
            'url': 'https://www.aad.org/public/diseases/a-z/dry-skin-overview',
            'source': 'American Academy of Dermatology',
            'keywords': ['dry', 'dehydrated', 'moisturizer', 'hydration', 'eczema'],
            'relevance_score': 0.88
        },
        {
            'id': '5',
            'title': 'Building Your Skincare Routine',
            'category': 'Routines',
            'summary': 'Expert guide to creating an effective AM and PM skincare routine with the right order of products.',
            'url': 'https://www.paulaschoice.com/skin-care-advice/skin-care-how-tos/how-to-put-together-a-skin-care-routine',
            'source': 'Paula\'s Choice Skincare',
            'keywords': ['routine', 'regimen', 'steps', 'basics', 'cleanser', 'moisturizer', 'order'],
            'relevance_score': 0.85
        },
        {
            'id': '6',
            'title': 'Dark Circles Under Eyes',
            'category': 'Conditions',
            'summary': 'Understanding the causes of dark circles and effective treatments including eye creams and lifestyle changes.',
            'url': 'https://dermnetnz.org/topics/dark-circles-under-the-eyes',
            'source': 'DermNet NZ',
            'keywords': ['dark circles', 'eye bags', 'puffiness', 'under eye', 'periorbital'],
            'relevance_score': 0.87
        },
        {
            'id': '7',
            'title': 'Hyperpigmentation: Causes and Treatment',
            'category': 'Conditions',
            'summary': 'Learn about dark spots, melasma, and post-inflammatory hyperpigmentation with evidence-based treatments.',
            'url': 'https://www.aad.org/public/everyday-care/skin-care-secrets/routine/fade-dark-spots',
            'source': 'American Academy of Dermatology',
            'keywords': ['hyperpigmentation', 'dark spots', 'melasma', 'pigmentation', 'discoloration'],
            'relevance_score': 0.89
        },
        {
            'id': '8',
            'title': 'Vitamin C for Skin: Benefits and How to Use',
            'category': 'Ingredients',
            'summary': 'The science behind vitamin C serums for brightening, antioxidant protection, and collagen synthesis.',
            'url': 'https://www.paulaschoice.com/skin-care-advice/ingredient-spotlight/vitamin-c',
            'source': 'Paula\'s Choice Skincare',
            'keywords': ['vitamin c', 'antioxidant', 'brightening', 'serum', 'ascorbic acid'],
            'relevance_score': 0.86
        },
        {
            'id': '9',
            'title': 'Niacinamide: The All-Rounder Ingredient',
            'category': 'Ingredients',
            'summary': 'How niacinamide reduces pores, regulates oil, and improves skin barrier function.',
            'url': 'https://www.paulaschoice.com/skin-care-advice/ingredient-spotlight/niacinamide',
            'source': 'Paula\'s Choice Skincare',
            'keywords': ['niacinamide', 'vitamin b3', 'pores', 'oil control', 'barrier'],
            'relevance_score': 0.84
        },
        {
            'id': '10',
            'title': 'Chemical Exfoliation: AHAs and BHAs',
            'category': 'Ingredients',
            'summary': 'Understanding the difference between glycolic acid, lactic acid, and salicylic acid for exfoliation.',
            'url': 'https://www.paulaschoice.com/skin-care-advice/exfoliants/difference-between-aha-and-bha-exfoliants',
            'source': 'Paula\'s Choice Skincare',
            'keywords': ['aha', 'bha', 'glycolic acid', 'salicylic acid', 'exfoliation', 'chemical exfoliant'],
            'relevance_score': 0.91
        },
        {
            'id': '11',
            'title': 'Rosacea: Signs and Symptoms',
            'category': 'Conditions',
            'summary': 'Identifying and managing rosacea with gentle skincare and medical treatments.',
            'url': 'https://www.aad.org/public/diseases/rosacea/what-is/symptoms',
            'source': 'American Academy of Dermatology',
            'keywords': ['rosacea', 'redness', 'sensitive', 'facial', 'flushing'],
            'relevance_score': 0.83
        },
        {
            'id': '12',
            'title': 'Hyaluronic Acid: The Moisture Magnet',
            'category': 'Ingredients',
            'summary': 'How hyaluronic acid attracts and retains moisture for plumper, hydrated skin.',
            'url': 'https://www.paulaschoice.com/skin-care-advice/ingredient-spotlight/hyaluronic-acid',
            'source': 'Paula\'s Choice Skincare',
            'keywords': ['hyaluronic acid', 'hydration', 'moisture', 'plumping', 'humectant'],
            'relevance_score': 0.82
        }
    ]

    # If no keywords provided, return all articles
    if not keywords:
        for article in articles:
            article['match_score'] = 0
        return articles

    # Score articles based on keyword matches
    scored_articles = []
    for article in articles:
        score = 0
        for keyword in keywords:
            if any(kw in keyword or keyword in kw for kw in article['keywords']):
                score += 1

        if score > 0:
            article_copy = article.copy()
            article_copy['match_score'] = score
            scored_articles.append(article_copy)

    # Sort by match score
    scored_articles.sort(key=lambda x: x['match_score'], reverse=True)

    return scored_articles


def get_articles_for_conditions(conditions: List[str]) -> List[Dict]:
    """Get articles relevant to specific skin conditions"""
    
    # Convert conditions to keywords
    keywords = [cond.lower().replace('_', ' ') for cond in conditions]
    
    return get_articles_for_keywords(keywords)


def get_educational_articles(category: Optional[str] = None, search_query: Optional[str] = None) -> List[Dict]:
    """Get educational articles with optional filtering"""
    
    # This would query DynamoDB in production
    # For now, return predefined articles
    all_articles = get_articles_for_keywords([])  # Returns all
    
    if category:
        all_articles = [a for a in all_articles if a.get('category') == category]
    
    if search_query:
        search_lower = search_query.lower()
        all_articles = [
            a for a in all_articles
            if search_lower in a.get('title', '').lower() or
               search_lower in a.get('summary', '').lower()
        ]
    
    return all_articles


def cors_headers():
    """Return CORS headers"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }


def decimal_default(obj):
    """JSON serializer for Decimal objects"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

