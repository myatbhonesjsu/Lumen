#!/usr/bin/env python3
"""
Knowledge Base Embedding Script
Embeds skincare knowledge base into Pinecone vector database
"""

import json
import os
import sys
import boto3
from pathlib import Path

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent.parent))

# AWS clients
lambda_client = boto3.client('lambda', region_name='us-east-1')

# Lambda function name
EMBEDDING_LAMBDA = 'lumen-skincare-dev-vector-embedding-processor'


def embed_skincare_articles():
    """Embed skincare education articles"""

    articles = [
        {
            "id": "acne-basics",
            "text": """
            Acne Treatment: Understanding the Basics

            Acne vulgaris is a common skin condition affecting millions worldwide. It occurs when hair follicles
            become clogged with oil and dead skin cells, leading to whiteheads, blackheads, or pimples.

            Common Causes:
            - Excess sebum production
            - Hormonal changes (puberty, menstruation, pregnancy)
            - Bacteria (Cutibacterium acnes)
            - Inflammation
            - Certain medications (corticosteroids, testosterone)

            Treatment Approaches:
            1. Topical Treatments:
               - Benzoyl peroxide (2.5-10%): Kills bacteria, reduces inflammation
               - Salicylic acid (0.5-2%): Unclogs pores, exfoliates
               - Retinoids (tretinoin, adapalene): Prevents clogging, reduces inflammation
               - Antibiotics (clindamycin, erythromycin): Kills bacteria

            2. Oral Medications:
               - Antibiotics (doxycycline, minocycline)
               - Hormonal therapy (birth control pills, spironolactone)
               - Isotretinoin (Accutane) for severe cases

            3. Lifestyle Modifications:
               - Gentle cleansing twice daily
               - Avoid picking or squeezing
               - Use non-comedogenic products
               - Manage stress
               - Balanced diet (limit dairy and high-glycemic foods)

            Timeline: Most treatments take 6-8 weeks to show results. Consistency is key.
            """,
            "metadata": {
                "type": "article",
                "category": "acne",
                "condition": "acne",
                "source": "dermatology-guide",
                "efficacy": 0.85,
                "use_cases": ["acne treatment", "breakout prevention", "skin clearing"]
            },
            "namespace": "knowledge-base"
        }
    ]

    print(f"\n📚 Embedding {len(articles)} skincare articles...")

    # Embed in batch
    response = lambda_client.invoke(
        FunctionName=EMBEDDING_LAMBDA,
        InvocationType='RequestResponse',
        Payload=json.dumps({
            'action': 'embed_batch',
            'batch': articles
        })
    )

    result = json.loads(response['Payload'].read())
    print(f"✅ Articles embedded: {result}")
    return result


def main():
    """Main execution"""
    print("=" * 60)
    print("Lumen Skincare Knowledge Base Embedding")
    print("=" * 60)

    try:
        # Embed all knowledge base content
        embed_skincare_articles()

        print("\n" + "=" * 60)
        print("✅ Knowledge base embedding complete!")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
