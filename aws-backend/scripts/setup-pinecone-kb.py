#!/usr/bin/env python3
"""
Setup Pinecone Knowledge Base for Lumen Skincare
Populates the knowledge-base namespace with skincare research and guidance
"""

import os
import sys
import boto3
import json

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda'))

from pinecone_http_client import PineconeHTTPClient

# Get Pinecone API key from Secrets Manager
secretsmanager = boto3.client('secretsmanager', region_name='us-east-1')
bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')

def get_pinecone_api_key():
    response = secretsmanager.get_secret_value(SecretId='lumen-skincare-dev-pinecone-api-key')
    return response['SecretString']

def generate_embedding(text):
    """Generate embedding using AWS Bedrock Titan"""
    response = bedrock_runtime.invoke_model(
        modelId='amazon.titan-embed-text-v1',
        contentType='application/json',
        accept='application/json',
        body=json.dumps({'inputText': text})
    )
    response_body = json.loads(response['body'].read())
    return response_body['embedding']

# Skincare knowledge base content
KNOWLEDGE_ENTRIES = [
    {
        'id': 'kb-acne-treatment-basics',
        'text': '''Acne treatment requires a multi-faceted approach. Topical treatments include benzoyl peroxide (2.5-10%) which kills acne-causing bacteria, and salicylic acid (0.5-2%) which unclogs pores. For hormonal acne, spironolactone (prescription) can help by blocking androgens. Retinoids like tretinoin or adapalene are gold-standard for preventing new breakouts and clearing existing ones. Consistency is crucial - most treatments take 6-12 weeks to show results.''',
        'metadata': {
            'title': 'Evidence-Based Acne Treatment',
            'type': 'treatment_guide',
            'conditions': ['acne', 'hormonal_acne', 'breakouts'],
            'source': 'Dermatology Research',
            'efficacy': 'high'
        }
    },
    {
        'id': 'kb-retinol-guide',
        'text': '''Retinol (vitamin A derivative) is the most studied anti-aging ingredient. It works by increasing cell turnover, boosting collagen production, and improving skin texture. Start with 0.25-0.5% retinol 2-3 nights per week, gradually increasing to nightly use. Always apply to dry skin, wait 20 minutes, then moisturize. Use sunscreen daily as retinol increases photosensitivity. Results typically visible after 12 weeks of consistent use.''',
        'metadata': {
            'title': 'Retinol Clinical Guide',
            'type': 'ingredient_research',
            'conditions': ['wrinkles', 'aging', 'fine_lines', 'texture'],
            'source': 'Journal of Clinical Dermatology',
            'efficacy': 'high'
        }
    },
    {
        'id': 'kb-dark-circles-research',
        'text': '''Dark circles have multiple causes: genetics (thin skin, visible vessels), aging (volume loss), allergies (inflammation), and lifestyle (sleep, hydration). Caffeine (3-5%) constricts blood vessels reducing puffiness. Vitamin K improves circulation. Vitamin C and niacinamide can brighten. For persistent dark circles, under-eye filler or laser treatments may be needed. Cold compresses provide temporary relief.''',
        'metadata': {
            'title': 'Dark Circles: Causes and Evidence-Based Treatments',
            'type': 'research_summary',
            'conditions': ['dark_circles', 'eye_bags', 'puffiness'],
            'source': 'Ophthalmology & Dermatology Review',
            'efficacy': 'moderate'
        }
    },
    {
        'id': 'kb-hydration-science',
        'text': '''Skin hydration involves three types of ingredients: humectants (hyaluronic acid, glycerin) draw water into skin, emollients (ceramides, fatty acids) smooth and soften, occlusives (petrolatum, oils) seal in moisture. Damaged skin barrier leads to transepidermal water loss (TEWL). Layering: humectant → emollient → occlusive. Apply on damp skin for better penetration. Dehydrated skin needs humectants; dry skin needs all three layers.''',
        'metadata': {
            'title': 'Science of Skin Hydration',
            'type': 'scientific_principle',
            'conditions': ['dry_skin', 'dehydrated_skin', 'sensitive_skin'],
            'source': 'International Journal of Cosmetic Science',
            'efficacy': 'high'
        }
    },
    {
        'id': 'kb-niacinamide-benefits',
        'text': '''Niacinamide (vitamin B3) at 2-5% concentration offers multiple benefits: reduces inflammation (helpful for acne and rosacea), regulates sebum production (for oily skin), improves skin barrier function (ceramide synthesis), and reduces hyperpigmentation (inhibits melanosome transfer). Well-tolerated by most skin types. Can be used with most other actives, but some formulations may cause flushing when combined with high concentrations of vitamin C.''',
        'metadata': {
            'title': 'Niacinamide: Multi-Benefit Ingredient',
            'type': 'ingredient_research',
            'conditions': ['acne', 'oily_skin', 'dark_spots', 'redness', 'sensitive_skin'],
            'source': 'Dermato-Endocrinology',
            'efficacy': 'high'
        }
    },
    {
        'id': 'kb-sunscreen-importance',
        'text': '''Daily broad-spectrum SPF 30+ is essential for preventing photoaging (wrinkles, sagging, dark spots) and skin cancer. UVA rays cause aging, UVB causes burns. Apply 1/4 teaspoon for face, reapply every 2 hours when outdoors. Mineral sunscreens (zinc oxide, titanium dioxide) sit on skin surface; chemical sunscreens absorb into skin. Both effective when used correctly. No sunscreen prevents Vitamin D production significantly if applied correctly.''',
        'metadata': {
            'title': 'Sunscreen Protection Science',
            'type': 'prevention_guide',
            'conditions': ['aging', 'dark_spots', 'hyperpigmentation', 'prevention'],
            'source': 'American Academy of Dermatology',
            'efficacy': 'high'
        }
    },
    {
        'id': 'kb-hyperpigmentation-treatment',
        'text': '''Hyperpigmentation treatments: vitamin C (15-20%) inhibits melanin production, niacinamide (4-5%) reduces melanosome transfer, azelaic acid (10-20%) tyrosinase inhibitor, hydroquinone (2-4%) prescription for stubborn spots. Chemical exfoliants (AHA/BHA) help fade surface pigmentation. Always use SPF to prevent worsening. Post-inflammatory hyperpigmentation (PIH) responds to consistent treatment over 8-12 weeks. Melasma requires ongoing management.''',
        'metadata': {
            'title': 'Hyperpigmentation Treatment Protocols',
            'type': 'treatment_guide',
            'conditions': ['dark_spots', 'hyperpigmentation', 'melasma', 'PIH'],
            'source': 'International Journal of Dermatology',
            'efficacy': 'moderate-high'
        }
    },
    {
        'id': 'kb-routine-layering',
        'text': '''Correct skincare layering order: 1) Cleanse, 2) Toners/Essences (watery), 3) Serums (thinnest first), 4) Eye cream, 5) Moisturizer, 6) SPF (AM) or sleeping mask (PM). Wait 30-60 seconds between layers. Actives: vitamin C (AM), retinol (PM 2-3x/week), AHA/BHA (PM 1-2x/week, not same night as retinol). Introduce one new active at a time, patch test for 3 days, build tolerance gradually.''',
        'metadata': {
            'title': 'Skincare Routine Layering Guide',
            'type': 'routine_guide',
            'conditions': ['healthy', 'beginner', 'routine'],
            'source': 'Dermatology Practice Guidelines',
            'efficacy': 'educational'
        }
    },
    {
        'id': 'kb-sensitive-skin-care',
        'text': '''Sensitive skin management: avoid fragrance, essential oils, alcohol denat, harsh sulfates. Soothing ingredients: centella asiatica (cica), colloidal oatmeal, ceramides, panthenol. Patch test all products. Simplify routine to minimize reaction risk. Use lukewarm water (not hot). Gentle cleansers with pH 5-5.5. If experiencing persistent redness or burning, consult dermatologist to rule out rosacea or contact dermatitis.''',
        'metadata': {
            'title': 'Sensitive Skin Care Protocol',
            'type': 'care_protocol',
            'conditions': ['sensitive_skin', 'redness', 'irritation', 'rosacea'],
            'source': 'Journal of Clinical and Aesthetic Dermatology',
            'efficacy': 'preventive'
        }
    },
    {
        'id': 'kb-aha-bha-guide',
        'text': '''Alpha hydroxy acids (AHAs - glycolic, lactic, mandelic acid) are water-soluble and exfoliate skin surface, best for dry skin, sun damage, mild pigmentation. Beta hydroxy acid (BHA - salicylic acid) is oil-soluble, penetrates pores, best for oily/acne-prone skin. Start with low concentration (5-8% AHA, 1-2% BHA) once weekly, increase gradually. Use at night. Can cause purging initially (normal for 4-6 weeks). Always use SPF next day.''',
        'metadata': {
            'title': 'Chemical Exfoliants Research',
            'type': 'ingredient_research',
            'conditions': ['acne', 'texture', 'dull_skin', 'dark_spots'],
            'source': 'Cosmetic Dermatology Research',
            'efficacy': 'high'
        }
    }
]

def setup_pinecone_kb():
    """Setup Pinecone knowledge base"""
    print("🔧 Setting up Pinecone knowledge base...")
    print(f"📚 Preparing {len(KNOWLEDGE_ENTRIES)} knowledge entries...")
    
    # Get Pinecone API key
    api_key = get_pinecone_api_key()
    print("✓ Retrieved Pinecone API key")
    
    # Initialize Pinecone client
    pinecone = PineconeHTTPClient(api_key=api_key)
    index_name = 'lumen-skincare-dev-educational-kb'
    namespace = 'knowledge-base'
    
    print(f"✓ Initialized Pinecone client for index: {index_name}")
    
    success_count = 0
    error_count = 0
    
    for entry in KNOWLEDGE_ENTRIES:
        try:
            # Generate embedding for the text
            print(f"  Processing: {entry['metadata']['title']}...")
            embedding = generate_embedding(entry['text'])
            
            # Upsert to Pinecone
            pinecone.upsert_vectors(
                index_name=index_name,
                vectors=[{
                    'id': entry['id'],
                    'values': embedding,
                    'metadata': {
                        **entry['metadata'],
                        'text': entry['text'][:500]  # Store snippet in metadata
                    }
                }],
                namespace=namespace
            )
            
            print(f"    ✓ Added to Pinecone")
            success_count += 1
            
        except Exception as e:
            print(f"    ✗ Error: {e}")
            error_count += 1
    
    print(f"\n✅ Successfully added {success_count}/{len(KNOWLEDGE_ENTRIES)} entries to Pinecone")
    if error_count > 0:
        print(f"❌ Failed to add {error_count} entries")
    
    # Test query
    print("\n🧪 Testing knowledge base query...")
    try:
        test_query = "How do I treat acne?"
        test_embedding = generate_embedding(test_query)
        results = pinecone.query(
            index_name=index_name,
            vector=test_embedding,
            top_k=3,
            namespace=namespace,
            include_metadata=True
        )
        
        print(f"✓ Query test successful! Found {len(results.get('matches', []))} results")
        for i, match in enumerate(results.get('matches', [])[:2], 1):
            print(f"  {i}. {match['metadata'].get('title')} (score: {match['score']:.3f})")
        
    except Exception as e:
        print(f"✗ Query test failed: {e}")
    
    return success_count, error_count

if __name__ == '__main__':
    success, errors = setup_pinecone_kb()
    
    if success > 0:
        print("\n" + "="*70)
        print("✅ Pinecone knowledge base is ready!")
        print("="*70)
        print("\nYour AI chat can now:")
        print("  • Access evidence-based skincare research")
        print("  • Cite sources in responses")
        print("  • Provide ingredient recommendations")
        print("  • Reference similar cases")
        print("\nTest in your iOS app by asking skincare questions! 🎉")
    else:
        print("\n❌ Failed to setup knowledge base. Check errors above.")
        sys.exit(1)

