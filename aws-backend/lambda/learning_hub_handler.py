"""
Learning Hub AI Assistant Handler
- Provides chat, recommendations, and routine endpoints for the iOS Learning Hub
- Uses AWS Bedrock runtime (Claude 3.5 Sonnet) with RAG + DynamoDB context
"""

import json
import os
import uuid
from datetime import datetime, timedelta
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Attr, Key

dynamodb = boto3.resource('dynamodb')
bedrock = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
lambda_client = boto3.client('lambda')

CHAT_HISTORY_TABLE = dynamodb.Table(os.environ['CHAT_HISTORY_TABLE'])
EDU_TABLE = dynamodb.Table(os.environ['EDUCATIONAL_CONTENT_TABLE'])
ANALYSES_TABLE = dynamodb.Table(
    os.environ.get('ANALYSES_TABLE', f"{os.environ.get('PREFIX', 'lumen-skincare-dev')}-analyses")
)
PRODUCTS_TABLE = dynamodb.Table(
    os.environ.get('PRODUCTS_TABLE', f"{os.environ.get('PREFIX', 'lumen-skincare-dev')}-products")
)

BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-5-sonnet-20241022')
LAMBDA_PREFIX = os.environ.get('LAMBDA_PREFIX', os.environ.get('PREFIX', 'lumen-skincare-dev'))
RAG_LAMBDA_NAME = os.environ.get('RAG_LAMBDA_NAME', 'rag-query-handler')

CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Content-Type': 'application/json'
}

AUTOCOMPLETE_FALLBACK = [
    'acne care routine',
    'dark spot treatment',
    'hydrating ingredients',
    'sunscreen tips',
    'retinol beginner guide',
    'sensitive skin routine',
    'hyperpigmentation help'
]

FALLBACK_ARTICLES = [
    {
        'id': 'kb-101',
        'title': 'Morning routines that calm inflammation',
        'category': 'routine',
        'summary': 'Dermatologist-backed steps to reduce inflamed breakouts before noon.',
        'url': 'https://lumen.skin/learning/morning-routine',
        'source': 'Lumen Knowledge Base',
        'keywords': ['acne', 'routine', 'inflammation'],
        'relevance_score': 0.82,
        'match_score': 92
    },
    {
        'id': 'kb-203',
        'title': 'Niacinamide vs. Retinol: when to layer',
        'category': 'ingredients',
        'summary': 'Evidence-backed guidance on pairing barrier-friendly actives with retinoids.',
        'url': 'https://lumen.skin/learning/niacinamide-retinol',
        'source': 'Dermatology Review',
        'keywords': ['niacinamide', 'retinol', 'barrier'],
        'relevance_score': 0.78,
        'match_score': 88
    }
]


def lambda_handler(event, context):
    """Entry point for API Gateway"""
    print(f"Event: {json.dumps(event)}")

    if event.get('httpMethod') == 'OPTIONS':
        return {'statusCode': 200, 'headers': CORS_HEADERS, 'body': json.dumps({'success': True})}

    path = (event.get('path') or '').lower()
    method = event.get('httpMethod', 'GET').upper()
    body = parse_body(event.get('body'))
    params = event.get('queryStringParameters') or {}

    if '/learning-hub/chat' in path and method == 'POST':
        return handle_chat(body)

    if '/learning-hub/chat-history' in path and method == 'GET':
        return handle_chat_history(params)

    if '/learning-hub/recommendations' in path and method == 'GET':
        return handle_recommendations(params)

    if '/learning-hub/articles' in path and method == 'GET':
        return handle_articles(params)

    if '/learning-hub/suggestions' in path and method == 'GET':
        return handle_suggestions(params)

    if '/learning-hub/routines/generate' in path and method == 'POST':
        return handle_routines_generate(body)

    return error_response(f"Unsupported path {path}")


def handle_chat(body):
    user_id = body.get('user_id')
    message = (body.get('message') or '').strip()
    session_id = body.get('session_id') or str(uuid.uuid4())
    local_analyses = body.get('local_analyses') or []

    if not user_id or not message:
        return error_response("user_id and message are required")

    context = build_conversation_context(user_id, local_analyses)

    store_chat_message(user_id, session_id, 'user', message)
    assistant = generate_learning_hub_response(message, context)
    store_chat_message(user_id, session_id, 'assistant', assistant['answer'], assistant.get('sources'))

    # Get related articles based on context
    related_articles = context.get('article_refs', [])[:3]  # Top 3 related articles
    
    payload = {
        'response': assistant['answer'],
        'session_id': session_id,
        'sources': assistant.get('sources', []),
        'related_articles': related_articles,
        'timestamp': int(datetime.utcnow().timestamp()),
        'model': assistant.get('model'),
        'analysis_summary': context.get('analysis_summary'),
        'knowledge_used': len(context.get('knowledge_snippets', []))
    }

    return success_response(payload)


def handle_chat_history(params):
    user_id = params.get('user_id')
    session_id = params.get('session_id')

    if not user_id:
        return error_response("user_id query parameter is required")

    try:
        if session_id:
            response = CHAT_HISTORY_TABLE.query(
                IndexName='SessionIndex',
                KeyConditionExpression=Key('session_id').eq(session_id),
                ScanIndexForward=True,
                Limit=50
            )
        else:
            response = CHAT_HISTORY_TABLE.query(
                KeyConditionExpression=Key('user_id').eq(user_id),
                ScanIndexForward=False,
                Limit=50
            )

        history = [convert_decimals(item) for item in response.get('Items', [])]
        history_sorted = sorted(history, key=lambda h: h.get('timestamp', 0))

        return success_response({'history': history_sorted})

    except Exception as exc:
        print(f"Error fetching chat history: {exc}")
        return error_response("Unable to fetch chat history")


def handle_recommendations(params):
    user_id = params.get('user_id', 'anonymous')
    analyses = fetch_recent_analyses(user_id, limit=5)
    conditions = [a.get('condition') for a in analyses if a.get('condition')]
    
    # Get ONLY articles matching user's conditions
    recommendations = fetch_personalized_articles(conditions, limit=10)
    
    # Get unique conditions
    unique_conditions = list(dict.fromkeys(conditions))[:5]
    
    # Calculate match counts per condition
    condition_matches = {}
    if conditions:
        for condition in unique_conditions:
            # Count articles matching this specific condition
            condition_articles = fetch_personalized_articles([condition], limit=100)
            condition_matches[condition] = len(condition_articles)

    payload = {
        'recommendations': recommendations,
        'based_on_conditions': unique_conditions,
        'total_analyses': len(analyses),
        'count': len(recommendations),
        'condition_matches': condition_matches  # Match count per condition
    }
    return success_response(payload)


def handle_articles(params):
    category = params.get('category')
    query = params.get('query')
    articles = fetch_articles_matching(category, query, limit=10)
    return success_response({
        'articles': articles,
        'count': len(articles)
    })


def handle_suggestions(params):
    prefix = (params.get('q') or params.get('prefix') or '').strip()
    if not prefix:
        return success_response({'suggestions': AUTOCOMPLETE_FALLBACK[:5]})

    suggestions = fetch_autocomplete_suggestions(prefix)
    return success_response({'suggestions': suggestions})


def handle_routines_generate(body):
    user_id = body.get('user_id')
    latest = body.get('latest_analysis') or {}

    if not user_id or not latest:
        return error_response("user_id and latest_analysis are required")

    concerns = infer_concerns_from_metrics(latest)
    routine = build_routine_from_metrics(latest, concerns, body.get('budget', 'moderate'))

    payload = {
        'user_id': user_id,
        'routine': routine,
        'generated_at': int(datetime.utcnow().timestamp()),
        'analysis_summary': {
            'top_concerns': concerns,
            'overall_health': latest.get('overallHealth') or latest.get('overall_health') or 72,
            'skin_age': latest.get('skinAge') or latest.get('skin_age') or 28
        }
    }

    return success_response(payload)


def build_conversation_context(user_id, local_analyses):
    stored_analyses = fetch_recent_analyses(user_id, limit=3)
    combined_analyses = local_analyses + stored_analyses

    latest_condition = None
    if combined_analyses:
        latest_condition = combined_analyses[0].get('condition')

    analysis_summary = [
        {
            'condition': entry.get('condition'),
            'confidence': entry.get('confidence'),
            'captured_at': entry.get('completed_at')
        }
        for entry in combined_analyses
    ]

    knowledge_snippets = fetch_knowledge_snippets(latest_condition, user_id)
    recommended_products = extract_products_from_analyses(combined_analyses)
    article_refs = fetch_personalized_articles([latest_condition] if latest_condition else None, limit=3)

    return {
        'analysis_summary': analysis_summary,
        'knowledge_snippets': knowledge_snippets,
        'products': recommended_products,
        'article_refs': article_refs
    }


def fetch_recent_analyses(user_id, limit=3):
    try:
        response = ANALYSES_TABLE.query(
            IndexName='UserIndex',
            KeyConditionExpression=Key('user_id').eq(user_id),
            ScanIndexForward=False,
            Limit=limit
        )
        return [normalize_analysis_item(item) for item in response.get('Items', [])]
    except Exception as exc:
        print(f"Unable to query analyses for {user_id}: {exc}")
        return []


def normalize_analysis_item(item):
    data = convert_decimals(item)
    prediction = data.get('prediction', {})
    return {
        'analysis_id': data.get('analysis_id'),
        'condition': prediction.get('condition') or data.get('condition'),
        'confidence': prediction.get('confidence'),
        'completed_at': data.get('completed_at') or data.get('timestamp'),
        'products': data.get('products', []),
        'enhanced': data.get('enhanced_analysis')
    }


def extract_products_from_analyses(analyses):
    for analysis in analyses:
        products = analysis.get('products')
        if products:
            return products[:3]
    return []


def fetch_personalized_articles(conditions, limit=5):
    """Fetch articles ONLY matching user's specific skin conditions"""
    if not conditions:
        return []  # Return empty if no conditions - "For You" will be empty until user has scans
    
    # Get all articles from DynamoDB
    try:
        response = EDU_TABLE.scan()
        all_articles = [convert_decimals(item) for item in response.get('Items', [])]
        
        # Transform content_id to id
        for article in all_articles:
            if 'content_id' in article and 'id' not in article:
                article['id'] = article['content_id']
        
    except Exception as exc:
        print(f"Error fetching articles: {exc}")
        return []
    
    # Filter to ONLY articles that match user's conditions
    matched_articles = []
    for article in all_articles:
        target_conditions = article.get('target_conditions', [])
        article_keywords = article.get('keywords', [])
        
        # Check if any user condition matches article's target conditions or keywords
        for condition in conditions:
            condition_normalized = condition.lower().replace(' ', '_')
            
            # Check target_conditions
            if any(condition_normalized in tc.lower() for tc in target_conditions):
                matched_articles.append(article)
                break
            
            # Check keywords
            if any(condition_normalized in kw.lower() for kw in article_keywords):
                matched_articles.append(article)
                break
    
    # Sort by relevance score
    sorted_articles = sorted(matched_articles, key=lambda a: float(a.get('relevance_score', 0)), reverse=True)
    return sorted_articles[:limit]


def fetch_articles_matching(category, query, limit=10):
    filter_expression = None

    if category:
        filter_expression = Attr('category').eq(category)

    if query:
        query_filter = Attr('keywords').contains(query) | Attr('title').contains(query)
        filter_expression = query_filter if filter_expression is None else (filter_expression & query_filter)

    try:
        scan_kwargs = {'Limit': limit}
        if filter_expression is not None:
            scan_kwargs['FilterExpression'] = filter_expression

        response = EDU_TABLE.scan(**scan_kwargs)
        items = [convert_decimals(item) for item in response.get('Items', [])]
        
        # Transform content_id to id for iOS compatibility
        for item in items:
            if 'content_id' in item and 'id' not in item:
                item['id'] = item['content_id']
        
        if not items:
            return FALLBACK_ARTICLES[:limit]
        return items[:limit]
    except Exception as exc:
        print(f"Error fetching articles: {exc}")
        return FALLBACK_ARTICLES[:limit]


def fetch_autocomplete_suggestions(prefix, limit=6):
    prefix_lower = prefix.lower()
    suggestions = []
    seen = set()

    try:
        response = EDU_TABLE.scan(ProjectionExpression="keywords, title")
        for item in response.get('Items', []):
            keywords = item.get('keywords', [])
            for keyword in keywords:
                lowered = keyword.lower()
                if lowered.startswith(prefix_lower) and lowered not in seen:
                    seen.add(lowered)
                    suggestions.append(keyword)
                    if len(suggestions) >= limit:
                        return suggestions
            title = item.get('title', '')
            if title.lower().startswith(prefix_lower) and title.lower() not in seen:
                seen.add(title.lower())
                suggestions.append(title)
                if len(suggestions) >= limit:
                    return suggestions
    except Exception as exc:
        print(f"Autocomplete scan failed: {exc}")

    fallback = [s for s in AUTOCOMPLETE_FALLBACK if s.startswith(prefix_lower)]
    for suggestion in fallback:
        if suggestion not in seen:
            suggestions.append(suggestion)
        if len(suggestions) >= limit:
            break

    return suggestions or AUTOCOMPLETE_FALLBACK[:limit]


def fetch_knowledge_snippets(condition, user_id, limit=3):
    if not RAG_LAMBDA_NAME:
        return []

    queries = []
    if condition:
        queries.append(f"Evidence-based guidance for {condition}")
    queries.append(f"Skincare advice for user journey {user_id}")

    snippets = []
    for query in queries:
        rag_results = query_rag(query, namespace='knowledge-base', top_k=5)
        for match in rag_results:
            metadata = match.get('metadata', {})
            snippet = {
                'id': match.get('id'),
                'title': metadata.get('title') or metadata.get('pattern_description') or 'Knowledge base excerpt',
                'summary': metadata.get('summary') or metadata.get('text') or metadata.get('excerpt'),
                'source': metadata.get('source') or metadata.get('url') or 'Lumen Knowledge Base',
                'score': match.get('score')
            }
            snippets.append(snippet)
        if len(snippets) >= limit:
            break

    return snippets[:limit]


def generate_learning_hub_response(user_message, context):
    system_prompt = (
        "You are Lumen's AI Skin Coach. Respond conversationally, cite relevant knowledge sources "
        "inline using (Source: ...), and reference recent analyses or recommended products when helpful. "
        "Keep answers under 3 short paragraphs."
    )

    context_blocks = []
    analyses = context.get('analysis_summary')
    if analyses:
        lines = [
            f"- {item.get('condition')} (confidence {int((item.get('confidence') or 0) * 100)}%)"
            for item in analyses[:3]
            if item.get('condition')
        ]
        if lines:
            context_blocks.append("Recent analyses:\n" + "\n".join(lines))

    products = context.get('products') or []
    if products:
        product_lines = [
            f"- {prod.get('name')} ({prod.get('category')}) – {prod.get('description', '')}"
            for prod in products[:3]
        ]
        context_blocks.append("Suggested products:\n" + "\n".join(product_lines))

    knowledge_snippets = context.get('knowledge_snippets') or []
    if knowledge_snippets:
        snippet_lines = [
            f"- {snippet.get('title')}: {snippet.get('summary', '')[:180]}"
            for snippet in knowledge_snippets
        ]
        context_blocks.append("Knowledge base excerpts:\n" + "\n".join(snippet_lines))

    article_refs = context.get('article_refs') or []
    if article_refs:
        article_lines = [f"- {a.get('title')} ({a.get('source')})" for a in article_refs[:2]]
        context_blocks.append("Related reading:\n" + "\n".join(article_lines))

    context_text = "\n\n".join(context_blocks) if context_blocks else "No historical analyses were found."
    user_prompt = f"{context_text}\n\nUser question: {user_message}\n\nDeliver a concise, encouraging response."

    # Try Bedrock first
    answer, usage = call_bedrock_chat(system_prompt, user_prompt)
    
    # If Bedrock failed but we have analysis context, use smart fallback
    if answer == "BEDROCK_FAILED" or "trouble reaching" in answer:
        if analyses:
            latest_condition = analyses[0].get('condition', '').replace('_', ' ')
            answer = generate_smart_fallback(user_message, latest_condition)
            print(f"✅ Using smart fallback for condition: {latest_condition}")
        else:
            answer = "I'm here to help with skincare questions! For personalized advice, try taking a skin scan first so I can give you specific recommendations based on your unique skin condition."
        usage = {}

    return {
        'answer': answer,
        'model': BEDROCK_MODEL_ID,
        'usage': usage,
        'sources': knowledge_snippets
    }


def generate_smart_fallback(user_message, condition):
    """Generate intelligent responses based on analysis condition AND user question"""
    message_lower = user_message.lower()
    
    # Determine question type
    is_ingredient_question = any(word in message_lower for word in ['ingredient', 'product', 'what should i use', 'what to use', 'recommend'])
    is_routine_question = any(word in message_lower for word in ['routine', 'regimen', 'steps', 'order', 'how do i'])
    is_timeline_question = any(word in message_lower for word in ['how long', 'when', 'timeline', 'results', 'take to'])
    is_prevention_question = any(word in message_lower for word in ['prevent', 'avoid', 'stop'])
    
    # Condition-specific responses adapted to question type
    if condition.lower().replace(' ', '_') in ['hormonal_acne', 'acne']:
        if is_ingredient_question:
            return f"Based on your analysis showing hormonal acne, the most effective ingredients are: salicylic acid (1-2%) for unclogging pores, benzoyl peroxide (2.5-5%) for killing bacteria, and niacinamide (4-5%) to reduce inflammation. Your analysis detected hormonal acne with high confidence, so look for gentle, non-comedogenic formulations. For stubborn hormonal acne, a dermatologist can prescribe spironolactone or tretinoin for more powerful results."
        elif is_routine_question:
            return f"For your hormonal acne, here's an effective routine: Morning - 1) Gentle cleanser, 2) Niacinamide serum, 3) Oil-free moisturizer, 4) SPF 30+. Evening - 1) Double cleanse if wearing makeup, 2) Salicylic acid treatment, 3) Spot treatment on active breakouts, 4) Lightweight moisturizer. Your analysis shows this appearing around your chin and jawline (typical for hormonal acne). Consistency is key - stick with this for 8-12 weeks."
        elif is_timeline_question:
            return f"Based on your hormonal acne analysis, you can expect to see initial improvement in 4-6 weeks with consistent treatment. Significant clearing typically takes 8-12 weeks. Your analysis detected hormonal acne, which can be cyclical with hormone fluctuations. Track your progress weekly - if no improvement after 8 weeks, consider consulting a dermatologist for prescription options like spironolactone."
        elif is_prevention_question:
            return f"To prevent hormonal acne flare-ups based on your analysis: 1) Maintain consistent gentle cleansing (don't over-wash), 2) Use non-comedogenic products only, 3) Change pillowcases 2x weekly, 4) Avoid touching your face, 5) Manage stress (triggers cortisol), 6) Stay hydrated, 7) Consider tracking flares with your menstrual cycle if applicable. Your analysis shows hormonal acne - prevention is about barrier support and consistent actives."
        else:
            return f"Your analysis detected hormonal acne with high confidence. This typically appears around the chin and jawline due to hormone fluctuations. The best approach combines gentle cleansing, targeted actives (salicylic acid, benzoyl peroxide, or niacinamide), oil-free moisturizer, and daily SPF. Avoid over-washing which can trigger more oil production. Most people see improvement in 8-12 weeks with consistent treatment. For persistent cases, a dermatologist can prescribe spironolactone or tretinoin."
    
    elif 'dark_circle' in condition.lower() or 'eye_bag' in condition.lower():
        if is_ingredient_question:
            return f"For your dark circles, the most effective ingredients are: caffeine (3-5%) to constrict blood vessels and reduce puffiness, vitamin K to improve circulation, vitamin C to brighten, and niacinamide for overall improvement. Your scan detected dark circles - look for gentle eye creams since this area has delicate skin. Retinol can help but use lower concentrations (0.01-0.025%) around eyes."
        elif is_routine_question:
            return f"For dark circles detected in your analysis: Morning - 1) Gently pat (don't rub) caffeine eye cream while skin is damp, 2) Apply vitamin C serum, 3) Lightweight eye moisturizer, 4) SPF. Evening - 1) Remove makeup gently, 2) Apply vitamin K or retinol eye cream, 3) Hydrating eye cream. Use cold compresses for 5-10 minutes in the AM to reduce puffiness. Your scan shows this is a concern - consistency for 6-8 weeks is needed."
        elif is_timeline_question:
            return f"Based on your dark circles analysis, topical treatments typically show results in 6-8 weeks with consistent use. Caffeine provides temporary improvement within hours. Vitamin C and K need 8-12 weeks for visible brightening. Your scan detected dark circles - if genetic (inherited from family), topicals help but won't fully eliminate them. For faster results, consider consulting about under-eye filler or laser treatments."
        else:
            return f"Your scan detected dark circles. These can be caused by genetics, lack of sleep, dehydration, or aging. For treatment, use eye creams with caffeine (reduces puffiness), vitamin K (improves circulation), and vitamin C (brightens). Get 7-8 hours of sleep, stay hydrated, use cold compresses in the morning, and always wear SPF to prevent worsening. Results take 6-8 weeks of consistent use."
    
    elif 'wrinkle' in condition.lower() or 'aging' in condition.lower() or 'fine_line' in condition.lower():
        if is_ingredient_question:
            return f"For the wrinkles detected in your analysis, retinol is the gold standard - it boosts collagen and increases cell turnover. Start with 0.25% retinol 2x weekly, building to nightly. Also effective: peptides (stimulate collagen), vitamin C (antioxidant protection), niacinamide (barrier repair), and hyaluronic acid (hydration). Your analysis shows signs of aging - combine these with daily SPF 30+ which is THE most important anti-aging step."
        elif is_routine_question:
            return f"Anti-aging routine for your wrinkles: Morning - 1) Gentle cleanser, 2) Vitamin C serum (antioxidant), 3) Eye cream with peptides, 4) Moisturizer with hyaluronic acid, 5) SPF 30-50. Evening - 1) Cleanse, 2) Retinol serum (start 2x weekly), 3) Peptide moisturizer, 4) Occlusive (like squalane) to seal. Your analysis detected aging signs - retinol is key but introduce slowly to avoid irritation. Expect visible results in 12 weeks."
        elif is_timeline_question:
            return f"For the wrinkles your analysis detected, retinol shows initial results in 4-6 weeks (smoother texture) and significant improvement in 12-16 weeks (visible line reduction). Peptides work faster (4-8 weeks) but are less dramatic. Vitamin C provides gradual brightening over 8-12 weeks. Your skin detected aging signs - patience is essential. Most anti-aging actives need consistent use for 3-6 months for best results."
        else:
            return f"Your analysis detected fine lines and wrinkles. Retinol is the proven gold standard - start with 0.25-0.5% concentration 2-3 nights weekly, gradually increasing to nightly use. This increases cell turnover and boosts collagen. Pair with peptides for additional support, vitamin C for antioxidant protection, and hyaluronic acid for hydration. Daily SPF 30+ is crucial to prevent further aging. Expect visible improvement in 12-16 weeks with consistent use."
    
    elif 'dry' in condition.lower():
        if is_ingredient_question:
            return f"For your dry skin detected in the analysis, layer these ingredients: 1) Hyaluronic acid (humectant - draws water in), 2) Ceramides (repairs barrier), 3) Glycerin (locks moisture), 4) Niacinamide (strengthens barrier), 5) Squalane or oils (seals everything). Your scan shows dehydration - avoid harsh cleansers and alcohol-based products. Apply on damp skin for better penetration."
        elif is_routine_question:
            return f"For dry skin from your analysis: Morning - 1) Cream cleanser (not foam), 2) Hyaluronic acid serum on damp skin, 3) Niacinamide serum, 4) Rich moisturizer with ceramides, 5) SPF. Evening - 1) Oil cleanser, 2) Hyaluronic acid, 3) Repair serum with peptides, 4) Thick night cream, 5) Facial oil to seal. Your scan detected dehydration - the key is layering hydrators while skin is damp."
        else:
            return f"Your analysis detected dry, dehydrated skin. Focus on hydrating ingredients: hyaluronic acid draws water into skin, ceramides repair your moisture barrier, and glycerin locks in hydration. Apply products on damp skin (within 60 seconds of washing) for better absorption. Use a humidifier if you're in a dry climate. Avoid harsh cleansers and hot water. Results typically visible within 2-4 weeks of consistent hydrating routine."
    
    # Generic fallback
    else:
        if is_ingredient_question:
            return f"Based on your analysis showing {condition}, I recommend consulting with a dermatologist for specific product recommendations tailored to your skin. In the meantime, maintain a gentle routine with: cleanser appropriate for your skin type, a treatment targeting {condition}, moisturizer, and daily SPF 30+."
        elif is_routine_question:
            return f"For {condition} detected in your analysis, a basic routine should include: Morning - gentle cleanser, treatment serum, moisturizer, SPF. Evening - cleanser, treatment for {condition}, night moisturizer. Introduce new products one at a time, waiting 2-4 weeks between additions to identify what works."
        else:
            return f"Your analysis detected {condition}. For the best results, I recommend consulting with a dermatologist who can create a personalized treatment plan. They can assess your specific situation and may prescribe targeted treatments. In the meantime, maintain a gentle skincare routine with daily SPF protection."


def call_bedrock_chat(system_prompt, user_prompt):
    payload = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 700,
        "temperature": 0.4,
        "top_p": 0.9,
        "system": system_prompt,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_prompt}
                ]
            }
        ]
    })

    try:
        print(f"🤖 Calling Bedrock with model: {BEDROCK_MODEL_ID}")
        response = bedrock.invoke_model(modelId=BEDROCK_MODEL_ID, body=payload)
        body = json.loads(response['body'].read())
        content_blocks = body.get('content') or body.get('output', [])
        text_parts = []
        for block in content_blocks:
            if isinstance(block, dict):
                if block.get('type') == 'text':
                    text_parts.append(block.get('text', ''))
                elif 'content' in block:
                    for inner in block['content']:
                        if inner.get('type') == 'text':
                            text_parts.append(inner.get('text', ''))
        answer = "\n".join(part.strip() for part in text_parts if part).strip()
        if not answer:
            answer = "I'm reviewing your history but need a moment—could you share a bit more detail?"
        print(f"✅ Bedrock responded with {len(answer)} characters")
        return answer, body.get('usage', {})
    except Exception as exc:
        print(f"❌ Bedrock call failed: {exc}")
        import traceback
        traceback.print_exc()
        return (
            "BEDROCK_FAILED",  # Signal to use smart fallback
            {}
        )


def query_rag(query, namespace='knowledge-base', top_k=5):
    function_name = f"{LAMBDA_PREFIX}-{RAG_LAMBDA_NAME}" if not RAG_LAMBDA_NAME.startswith(LAMBDA_PREFIX) else RAG_LAMBDA_NAME
    payload = {
        'action': 'search_knowledge',
        'query': query,
        'namespace': namespace,
        'top_k': top_k
    }

    try:
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        raw_payload = response['Payload'].read()
        parsed = json.loads(raw_payload)
        if parsed.get('statusCode') == 200:
            body = json.loads(parsed.get('body') or '{}')
            return body.get('data', {}).get('results', [])
    except Exception as exc:
        print(f"RAG invocation failed: {exc}")

    return []


def store_chat_message(user_id, session_id, role, message, sources=None):
    timestamp = Decimal(str(datetime.utcnow().timestamp()))
    ttl = int((datetime.utcnow() + timedelta(days=30)).timestamp())
    item = {
        'user_id': user_id,
        'timestamp': timestamp,
        'session_id': session_id,
        'role': role,
        'message': message,
        'ttl': ttl
    }
    if sources:
        item['sources'] = sources

    try:
        CHAT_HISTORY_TABLE.put_item(Item=item)
    except Exception as exc:
        print(f"Failed to persist chat message: {exc}")


def infer_concerns_from_metrics(latest_metrics):
    mapping = {
        'acneLevel': 'breakouts',
        'drynessLevel': 'dryness',
        'moistureLevel': 'hydration',
        'pigmentationLevel': 'pigmentation',
        'darkCircleLevel': 'dark circles'
    }
    concerns = []
    for key, label in mapping.items():
        value = latest_metrics.get(key) or latest_metrics.get(key[0].lower() + key[1:])
        if value and value >= 60:
            concerns.append(label)

    return concerns or ['skin balance']


def build_routine_from_metrics(latest_metrics, concerns, budget):
    def step(step_name, product_type, reason, icon):
        return {'step': step_name, 'product_type': product_type, 'reason': reason, 'icon': icon}

    morning_steps = [
        step('Gentle cleanse', 'cleanser', 'Removes overnight oil without stripping barrier.', 'sparkles'),
        step('Treatment serum', 'serum', 'Targets your top concern with actives like niacinamide or azelaic acid.', 'dropper'),
        step('Moisturize + SPF', 'moisturizer', 'Locks hydration and shields from UV.', 'sun.max')
    ]

    evening_steps = [
        step('Double cleanse', 'cleanser', 'Breaks down sunscreen/makeup to prevent clogged pores.', 'moon.stars'),
        step('Targeted treatment', 'treatment', 'Use retinol or exfoliating acids 2-3x weekly based on tolerance.', 'flame'),
        step('Barrier repair cream', 'moisturizer', 'Seals in moisture overnight for recovery.', 'shield')
    ]

    overall_strategy = "Prioritize barrier repair while layering concern-specific actives slowly."
    if 'breakouts' in concerns:
        overall_strategy = "Balance barrier-friendly hydration with consistent acne-fighting actives."
    elif 'dryness' in concerns:
        overall_strategy = "Stack humectants plus occlusives to restore moisture reservoir."

    important_notes = [
        "Patch test new products for 3 nights.",
        "Introduce actives gradually (every other night).",
        f"Stick with the plan for at least 4-6 weeks ({budget} budget)."
    ]

    return {
        'morning_routine': morning_steps,
        'evening_routine': evening_steps,
        'key_concerns': concerns,
        'overall_strategy': overall_strategy,
        'expected_timeline': '4-6 weeks',
        'important_notes': important_notes
    }


def parse_body(raw_body):
    if not raw_body:
        return {}
    if isinstance(raw_body, dict):
        return raw_body
    try:
        return json.loads(raw_body)
    except Exception:
        return {}


def convert_decimals(obj):
    if isinstance(obj, list):
        return [convert_decimals(i) for i in obj]
    if isinstance(obj, dict):
        return {k: convert_decimals(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return float(obj)
    return obj


def success_response(data):
    return {
        'statusCode': 200,
        'headers': CORS_HEADERS,
        'body': json.dumps(data, default=str)
    }


def error_response(message):
    return {
        'statusCode': 400,
        'headers': CORS_HEADERS,
        'body': json.dumps({'error': message})
    }

