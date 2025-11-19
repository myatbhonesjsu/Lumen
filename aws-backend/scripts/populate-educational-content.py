#!/usr/bin/env python3
"""
Populate educational-content DynamoDB table with curated skincare articles
"""

import boto3
import json
from datetime import datetime, UTC
from decimal import Decimal

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('lumen-skincare-dev-educational-content')

ARTICLES = [
    {
        'content_id': 'edu-acne-101',
        'title': 'Understanding Acne: Complete Treatment Guide',
        'category': 'Acne Care',
        'summary': 'Learn about different types of acne, their causes, and evidence-based treatment options. Includes information on topical treatments, lifestyle changes, and when to see a dermatologist.',
        'url': 'https://www.aad.org/public/diseases/acne/really-acne/overview',
        'source': 'American Academy of Dermatology',
        'keywords': ['acne', 'hormonal_acne', 'breakouts', 'treatment', 'salicylic acid', 'benzoyl peroxide'],
        'relevance_score': Decimal('0.95'),
        'match_score': 95,
        'target_conditions': ['acne', 'hormonal_acne'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-retinol-101',
        'title': 'The Science of Retinol: Anti-Aging Powerhouse',
        'category': 'Anti-Aging',
        'summary': 'Comprehensive guide to retinol and retinoids. Learn how they work, how to introduce them into your routine, and what results to expect for wrinkles and skin texture.',
        'url': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2699641/',
        'source': 'Journal of Cosmetic Dermatology',
        'keywords': ['retinol', 'anti-aging', 'wrinkles', 'fine lines', 'tretinoin'],
        'relevance_score': Decimal('0.93'),
        'match_score': 93,
        'target_conditions': ['wrinkles', 'fine_lines', 'aging'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-dark-circles-101',
        'title': 'Dark Circles and Eye Bags: Causes and Solutions',
        'category': 'Eye Care',
        'summary': 'Explore the multiple causes of dark circles including genetics, sleep deprivation, and aging. Evidence-based treatments including caffeine serums, vitamin K, and lifestyle modifications.',
        'url': 'https://www.health.harvard.edu/staying-healthy/how-to-get-rid-of-bags-under-your-eyes',
        'source': 'Harvard Health Publishing',
        'keywords': ['dark_circles', 'eye_bags', 'puffiness', 'under-eye', 'caffeine'],
        'relevance_score': Decimal('0.89'),
        'match_score': 89,
        'target_conditions': ['dark_circles', 'eye_bags'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-hydration-101',
        'title': 'Skin Hydration: The Foundation of Healthy Skin',
        'category': 'Skin Health',
        'summary': 'Understanding the importance of skin hydration and moisture barrier health. Learn about humectants, emollients, and occlusives including hyaluronic acid and ceramides.',
        'url': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6849652/',
        'source': 'Dermatology and Therapy Journal',
        'keywords': ['hydration', 'dry_skin', 'moisturizer', 'ceramides', 'hyaluronic acid'],
        'relevance_score': Decimal('0.91'),
        'match_score': 91,
        'target_conditions': ['dry_skin', 'dehydrated_skin'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-sunscreen-101',
        'title': 'Sunscreen: Your Most Important Anti-Aging Product',
        'category': 'Sun Protection',
        'summary': 'Why daily SPF is crucial for preventing premature aging, hyperpigmentation, and skin cancer. Guide to choosing the right sunscreen formula for your skin type.',
        'url': 'https://www.skincancer.org/skin-cancer-prevention/sun-protection/sunscreen/',
        'source': 'Skin Cancer Foundation',
        'keywords': ['sunscreen', 'SPF', 'sun protection', 'UV protection', 'prevention'],
        'relevance_score': Decimal('0.92'),
        'match_score': 92,
        'target_conditions': ['healthy', 'prevention', 'dark_spots', 'aging'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-hyperpigmentation-101',
        'title': 'Treating Dark Spots and Hyperpigmentation',
        'category': 'Pigmentation',
        'summary': 'Evidence-based treatments for hyperpigmentation including vitamin C, niacinamide, and chemical exfoliants. Understanding PIH (post-inflammatory hyperpigmentation) and melasma.',
        'url': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6826978/',
        'source': 'Indian Dermatology Online Journal',
        'keywords': ['dark_spots', 'hyperpigmentation', 'melasma', 'PIH', 'vitamin C', 'niacinamide'],
        'relevance_score': Decimal('0.90'),
        'match_score': 90,
        'target_conditions': ['dark_spots', 'hyperpigmentation'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-niacinamide-101',
        'title': 'Niacinamide: The Multi-Benefit Ingredient',
        'category': 'Ingredients',
        'summary': 'Niacinamide (vitamin B3) benefits for skin: reduces inflammation, brightens dark spots, regulates oil production, and strengthens the skin barrier. How to incorporate it into your routine.',
        'url': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5964969/',
        'source': 'Dermato-Endocrinology Journal',
        'keywords': ['niacinamide', 'vitamin B3', 'brightening', 'barrier', 'acne'],
        'relevance_score': Decimal('0.88'),
        'match_score': 88,
        'target_conditions': ['acne', 'dark_spots', 'oily_skin', 'redness'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-routine-basics',
        'title': 'Building Your Skincare Routine: A Step-by-Step Guide',
        'category': 'Routine',
        'summary': 'Essential guide to building an effective skincare routine. Learn the correct order to apply products, how to introduce new products safely, and what products are truly essential.',
        'url': 'https://www.paulaschoice.com/expert-advice/skincare-advice/basic-skin-care-tips/the-beginners-guide-to-skincare.html',
        'source': 'Paula\'s Choice Skincare',
        'keywords': ['routine', 'beginner', 'layering', 'skincare basics', 'order'],
        'relevance_score': Decimal('0.87'),
        'match_score': 87,
        'target_conditions': ['healthy', 'beginner'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-sensitive-skin',
        'title': 'Caring for Sensitive Skin: Gentle Approach Guide',
        'category': 'Sensitive Skin',
        'summary': 'How to identify if you have sensitive skin and best practices for gentle skincare. Ingredients to avoid and soothing ingredients like centella asiatica and colloidal oatmeal.',
        'url': 'https://nationaleczema.org/eczema/treatment/skin-care/',
        'source': 'National Eczema Association',
        'keywords': ['sensitive_skin', 'redness', 'irritation', 'gentle', 'soothing'],
        'relevance_score': Decimal('0.86'),
        'match_score': 86,
        'target_conditions': ['sensitive_skin', 'redness', 'irritation'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-chemical-exfoliants',
        'title': 'Chemical Exfoliants: AHAs vs BHAs Explained',
        'category': 'Exfoliation',
        'summary': 'Understanding chemical exfoliants: glycolic acid, lactic acid (AHAs) for surface exfoliation, and salicylic acid (BHA) for deep pore cleansing. How to choose and use safely.',
        'url': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5574737/',
        'source': 'Clinical, Cosmetic and Investigational Dermatology',
        'keywords': ['exfoliation', 'AHA', 'BHA', 'glycolic acid', 'salicylic acid'],
        'relevance_score': Decimal('0.85'),
        'match_score': 85,
        'target_conditions': ['acne', 'dark_spots', 'texture', 'dull_skin'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-hormonal-acne',
        'title': 'Hormonal Acne: Understanding and Managing Breakouts',
        'category': 'Acne Care',
        'summary': 'Specific guide to hormonal acne that appears around the chin and jawline. Hormonal triggers, treatment options including spironolactone, and targeted topical solutions.',
        'url': 'https://www.aad.org/public/diseases/acne/causes/hormonal-factors',
        'source': 'American Academy of Dermatology',
        'keywords': ['hormonal_acne', 'adult acne', 'jawline', 'chin', 'hormones'],
        'relevance_score': Decimal('0.94'),
        'match_score': 94,
        'target_conditions': ['hormonal_acne', 'acne'],
        'created_at': datetime.now(UTC).isoformat()
    },
    {
        'content_id': 'edu-vitamin-c',
        'title': 'Vitamin C Serums: Brightening and Protection',
        'category': 'Ingredients',
        'summary': 'How vitamin C (L-ascorbic acid) brightens skin, fades dark spots, and provides antioxidant protection. Choosing stable formulations and proper application for best results.',
        'url': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5605218/',
        'source': 'Nutrients Journal',
        'keywords': ['vitamin C', 'brightening', 'antioxidant', 'dark spots', 'L-ascorbic acid'],
        'relevance_score': Decimal('0.89'),
        'match_score': 89,
        'target_conditions': ['dark_spots', 'dull_skin', 'aging'],
        'created_at': datetime.now(UTC).isoformat()
    }
]

def populate_table():
    """Populate the educational content table"""
    print(f"📚 Populating educational-content table with {len(ARTICLES)} articles...")
    
    success_count = 0
    error_count = 0
    
    for article in ARTICLES:
        try:
            table.put_item(Item=article)
            print(f"  ✓ Added: {article['title']}")
            success_count += 1
        except Exception as e:
            print(f"  ✗ Error adding {article['content_id']}: {e}")
            error_count += 1
    
    print(f"\n✅ Successfully added {success_count} articles")
    if error_count > 0:
        print(f"❌ Failed to add {error_count} articles")
    
    # Verify
    print("\n🔍 Verifying table contents...")
    response = table.scan()
    items = response.get('Items', [])
    print(f"Total articles in table: {len(items)}")
    
    if items:
        print("\nSample articles:")
        for item in items[:3]:
            print(f"  - {item.get('title')} (Category: {item.get('category')})")
    
    return success_count, error_count

if __name__ == '__main__':
    populate_table()
