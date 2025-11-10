"""
Lightweight Vector Search for Lambda
Uses sentence-transformers for embeddings and cosine similarity for search
"""

import json
import numpy as np
from typing import List, Dict, Tuple
import os

# Try to import sentence-transformers, fallback to basic search if not available
try:
    from sentence_transformers import SentenceTransformer
    EMBEDDINGS_AVAILABLE = True
except ImportError:
    print("Warning: sentence-transformers not available, falling back to keyword search")
    EMBEDDINGS_AVAILABLE = False


class VectorSearch:
    """Lightweight vector search using sentence transformers"""

    def __init__(self, model_name='all-MiniLM-L6-v2'):
        """
        Initialize vector search

        Args:
            model_name: Sentence transformer model to use
                       'all-MiniLM-L6-v2' is fast and only 80MB
        """
        self.model = None
        self.articles = []
        self.embeddings = None

        if EMBEDDINGS_AVAILABLE:
            try:
                print(f"Loading embedding model: {model_name}")
                self.model = SentenceTransformer(model_name)
                print("Embedding model loaded successfully")
            except Exception as e:
                print(f"Error loading embedding model: {e}")
                self.model = None

        # Load articles
        self.load_articles()

    def load_articles(self):
        """Load skincare articles into vector search"""

        self.articles = [
            {
                'id': '1',
                'title': 'Acne: Diagnosis and Treatment',
                'content': '''Acne is a common skin condition that occurs when hair follicles become clogged with oil and dead skin cells. It causes whiteheads, blackheads, and pimples. Acne is most common among teenagers, though it affects people of all ages.

                Treatment options include:
                - Benzoyl peroxide: Kills acne-causing bacteria and reduces inflammation
                - Salicylic acid: Unclogs pores and prevents new breakouts
                - Retinoids: Reduce oil production and help prevent clogged pores
                - Antibiotics: Reduce bacteria and inflammation
                - Niacinamide: Reduces inflammation and regulates oil production

                For best results, use a gentle cleanser, avoid picking at blemishes, and always wear sunscreen.''',
                'url': 'https://www.aad.org/public/diseases/acne-and-rosacea/acne',
                'source': 'American Academy of Dermatology',
                'category': 'Conditions',
                'keywords': ['acne', 'breakout', 'pimple', 'treatment', 'benzoyl peroxide', 'salicylic acid']
            },
            {
                'id': '2',
                'title': 'Retinoids: The Gold Standard for Anti-Aging',
                'content': '''Retinoids are vitamin A derivatives that are considered the gold standard for anti-aging skincare. They work by increasing cell turnover, boosting collagen production, and reducing the appearance of fine lines and wrinkles.

                Benefits include:
                - Reduces fine lines and wrinkles
                - Improves skin texture and tone
                - Fades dark spots and hyperpigmentation
                - Unclogs pores and reduces acne
                - Boosts collagen production

                Start with a low concentration (0.025% or 0.05%) and gradually increase. Apply at night, as retinoids can make skin sun-sensitive. Always use sunscreen during the day.''',
                'url': 'https://www.paulaschoice.com/skin-care-advice/anti-aging-wrinkles/how-retinol-works',
                'source': "Paula's Choice Skincare",
                'category': 'Ingredients',
                'keywords': ['retinol', 'retinoid', 'wrinkles', 'aging', 'anti-aging', 'tretinoin', 'collagen']
            },
            {
                'id': '3',
                'title': 'How to Choose the Best Sunscreen for Your Skin',
                'content': '''Sunscreen is the single most important step in any skincare routine. It protects against UV damage, prevents premature aging, and reduces skin cancer risk.

                Key factors when choosing sunscreen:
                - SPF 30 or higher: Blocks 97% of UVB rays
                - Broad-spectrum: Protects against both UVA and UVB rays
                - Water-resistant: Stays effective for 40-80 minutes while swimming or sweating
                - Mineral vs. chemical: Both are effective, choose based on preference

                Apply generously (about 1/4 teaspoon for face) and reapply every 2 hours or after swimming/sweating.''',
                'url': 'https://www.skincancer.org/blog/how-to-choose-the-best-sunscreen-for-your-skin/',
                'source': 'Skin Cancer Foundation',
                'category': 'Basics',
                'keywords': ['sunscreen', 'spf', 'sun protection', 'aging', 'prevention', 'uva', 'uvb', 'mineral']
            },
            {
                'id': '4',
                'title': 'Understanding Dry Skin',
                'content': '''Dry skin (xerosis) occurs when your skin loses too much water or oil. It can feel tight, rough, flaky, or itchy. Common causes include cold weather, low humidity, hot showers, and harsh soaps.

                Treatment strategies:
                - Use gentle, fragrance-free cleansers
                - Apply moisturizer immediately after bathing
                - Look for ingredients like hyaluronic acid, ceramides, and glycerin
                - Avoid hot water and limit shower time
                - Use a humidifier in dry environments

                For severe dryness, consider seeing a dermatologist to rule out conditions like eczema or psoriasis.''',
                'url': 'https://www.aad.org/public/diseases/a-z/dry-skin-overview',
                'source': 'American Academy of Dermatology',
                'category': 'Conditions',
                'keywords': ['dry', 'dehydrated', 'moisturizer', 'hydration', 'eczema', 'ceramides']
            },
            {
                'id': '5',
                'title': 'Building Your Skincare Routine',
                'content': '''A good skincare routine doesn't need to be complicated. Start with the basics and add products as needed.

                Morning routine:
                1. Cleanser - Remove oil and debris
                2. Toner (optional) - Balance pH
                3. Serum - Target specific concerns
                4. Moisturizer - Hydrate and protect
                5. Sunscreen - Always the last step (SPF 30+)

                Evening routine:
                1. Cleanser - Remove makeup, sunscreen, and dirt
                2. Exfoliant (2-3x per week) - Remove dead skin cells
                3. Serum/Treatment - Active ingredients work overnight
                4. Moisturizer - Repair and hydrate

                Be consistent and patient - it takes 4-6 weeks to see results.''',
                'url': 'https://www.paulaschoice.com/skin-care-advice/skin-care-how-tos/how-to-put-together-a-skin-care-routine',
                'source': "Paula's Choice Skincare",
                'category': 'Routines',
                'keywords': ['routine', 'regimen', 'steps', 'basics', 'cleanser', 'moisturizer', 'order', 'morning', 'evening']
            },
            {
                'id': '6',
                'title': 'Dark Circles Under Eyes',
                'content': '''Dark circles under the eyes can be caused by genetics, aging, lack of sleep, allergies, or hyperpigmentation. The thin skin under the eyes makes blood vessels more visible.

                Treatment options:
                - Caffeine eye creams: Constrict blood vessels
                - Vitamin C serums: Brighten and reduce pigmentation
                - Retinol: Thicken skin and reduce visibility of blood vessels
                - Cold compresses: Reduce swelling
                - Get adequate sleep: 7-9 hours per night
                - Stay hydrated: Drink plenty of water

                For severe or sudden dark circles, consult a dermatologist to rule out underlying conditions.''',
                'url': 'https://dermnetnz.org/topics/dark-circles-under-the-eyes',
                'source': 'DermNet NZ',
                'category': 'Conditions',
                'keywords': ['dark circles', 'eye bags', 'puffiness', 'under eye', 'periorbital', 'caffeine']
            },
            {
                'id': '7',
                'title': 'Hyperpigmentation: Dark Spots and Treatment',
                'content': '''Hyperpigmentation occurs when the skin produces too much melanin, causing dark spots or patches. Common causes include sun damage, acne scarring, hormonal changes, and inflammation.

                Effective treatments:
                - Vitamin C: Brightens and inhibits melanin production
                - Niacinamide: Reduces melanin transfer to skin cells
                - Alpha arbutin: Lightens dark spots
                - Retinoids: Increase cell turnover and fade spots
                - Chemical peels: Remove top layers of pigmented skin
                - Sunscreen: Prevents further darkening (essential!)

                Results take 3-6 months. Always use SPF 30+ daily to prevent worsening.''',
                'url': 'https://www.aad.org/public/everyday-care/skin-care-secrets/routine/fade-dark-spots',
                'source': 'American Academy of Dermatology',
                'category': 'Conditions',
                'keywords': ['hyperpigmentation', 'dark spots', 'melasma', 'pigmentation', 'discoloration', 'brightening']
            },
            {
                'id': '8',
                'title': 'Vitamin C for Skin: Benefits and Usage',
                'content': '''Vitamin C (ascorbic acid) is a powerful antioxidant that brightens skin, reduces hyperpigmentation, and protects against environmental damage.

                Key benefits:
                - Brightens dull skin and evens tone
                - Fades dark spots and hyperpigmentation
                - Boosts collagen production
                - Protects against free radical damage
                - Enhances sunscreen effectiveness

                How to use:
                - Apply in the morning for antioxidant protection
                - Use 10-20% concentration for best results
                - Store in dark, airtight container (vitamin C degrades with light/air)
                - Pair with sunscreen for maximum benefits
                - Start with lower concentration if you have sensitive skin''',
                'url': 'https://www.paulaschoice.com/skin-care-advice/ingredient-spotlight/vitamin-c',
                'source': "Paula's Choice Skincare",
                'category': 'Ingredients',
                'keywords': ['vitamin c', 'antioxidant', 'brightening', 'serum', 'ascorbic acid', 'collagen']
            },
            {
                'id': '9',
                'title': 'Niacinamide: The Multi-Tasking Ingredient',
                'content': '''Niacinamide (vitamin B3) is a gentle, versatile ingredient that works for all skin types. It addresses multiple skin concerns without irritation.

                Benefits:
                - Reduces the appearance of large pores
                - Regulates oil production
                - Minimizes redness and inflammation
                - Brightens skin tone
                - Strengthens skin barrier
                - Works well with other active ingredients

                Use 5-10% concentration for best results. Can be used morning and evening. Safe to combine with vitamin C, retinoids, and AHAs/BHAs.''',
                'url': 'https://www.paulaschoice.com/skin-care-advice/ingredient-spotlight/niacinamide',
                'source': "Paula's Choice Skincare",
                'category': 'Ingredients',
                'keywords': ['niacinamide', 'vitamin b3', 'pores', 'oil control', 'barrier', 'redness']
            },
            {
                'id': '10',
                'title': 'AHA vs BHA: Chemical Exfoliants Explained',
                'content': '''Chemical exfoliants use acids to dissolve dead skin cells, revealing smoother, brighter skin underneath.

                AHAs (Alpha Hydroxy Acids):
                - Glycolic acid, lactic acid, mandelic acid
                - Water-soluble (work on skin surface)
                - Best for: Dry skin, sun damage, fine lines
                - Benefits: Brightens, evens tone, improves texture

                BHAs (Beta Hydroxy Acids):
                - Salicylic acid
                - Oil-soluble (penetrates into pores)
                - Best for: Oily skin, acne, blackheads
                - Benefits: Unclogs pores, reduces inflammation

                Start with 2-3 times per week, increase gradually. Always use sunscreen.''',
                'url': 'https://www.paulaschoice.com/skin-care-advice/exfoliants/difference-between-aha-and-bha-exfoliants',
                'source': "Paula's Choice Skincare",
                'category': 'Ingredients',
                'keywords': ['aha', 'bha', 'glycolic acid', 'salicylic acid', 'exfoliation', 'chemical exfoliant']
            },
            {
                'id': '11',
                'title': 'Rosacea: Signs and Symptoms',
                'content': '''Rosacea is a chronic inflammatory skin condition that causes redness, flushing, and visible blood vessels on the face. It can also cause acne-like bumps.

                Common symptoms:
                - Facial redness (especially nose and cheeks)
                - Visible blood vessels
                - Bumps and pimples
                - Eye irritation
                - Thickened skin (in advanced cases)

                Triggers to avoid:
                - Hot beverages and spicy foods
                - Alcohol
                - Extreme temperatures
                - Sun exposure
                - Harsh skincare products

                Treatment includes gentle skincare, prescription medications, and avoiding triggers. See a dermatologist for proper diagnosis.''',
                'url': 'https://www.aad.org/public/diseases/rosacea/what-is/symptoms',
                'source': 'American Academy of Dermatology',
                'category': 'Conditions',
                'keywords': ['rosacea', 'redness', 'sensitive', 'facial', 'flushing', 'inflammation']
            },
            {
                'id': '12',
                'title': 'Hyaluronic Acid: The Hydration Hero',
                'content': '''Hyaluronic acid (HA) is a humectant that can hold up to 1,000 times its weight in water, making it incredibly effective for hydration.

                Benefits:
                - Deeply hydrates without feeling heavy
                - Plumps fine lines and wrinkles
                - Suitable for all skin types (even oily)
                - Helps other products absorb better
                - Non-irritating and gentle

                How to use:
                - Apply to damp skin for best absorption
                - Layer under moisturizer to seal in hydration
                - Use morning and evening
                - Look for multiple molecular weights for deeper penetration

                Works well with all other ingredients and is safe for sensitive skin.''',
                'url': 'https://www.paulaschoice.com/skin-care-advice/ingredient-spotlight/hyaluronic-acid',
                'source': "Paula's Choice Skincare",
                'category': 'Ingredients',
                'keywords': ['hyaluronic acid', 'hydration', 'moisture', 'plumping', 'humectant', 'water']
            }
        ]

        print(f"Loaded {len(self.articles)} articles")

        # Generate embeddings if model is available
        if self.model:
            self.generate_embeddings()

    def generate_embeddings(self):
        """Generate embeddings for all articles"""
        if not self.model:
            return

        try:
            # Combine title and content for better semantic search
            texts = [f"{article['title']}. {article['content']}" for article in self.articles]
            print(f"Generating embeddings for {len(texts)} articles...")
            self.embeddings = self.model.encode(texts, show_progress_bar=False)
            print("Embeddings generated successfully")
        except Exception as e:
            print(f"Error generating embeddings: {e}")
            self.embeddings = None

    def semantic_search(self, query: str, top_k: int = 3) -> List[Dict]:
        """
        Perform semantic search using embeddings

        Args:
            query: Search query
            top_k: Number of results to return

        Returns:
            List of articles sorted by relevance
        """
        if not self.model or self.embeddings is None:
            # Fallback to keyword search
            return self.keyword_search(query, top_k)

        try:
            # Generate query embedding
            query_embedding = self.model.encode([query])

            # Calculate cosine similarity
            similarities = self._cosine_similarity(query_embedding[0], self.embeddings)

            # Get top-k indices
            top_indices = np.argsort(similarities)[::-1][:top_k]

            # Build results
            results = []
            for idx in top_indices:
                article = self.articles[idx].copy()
                article['relevance_score'] = float(similarities[idx])
                # Trim content for response
                article['content'] = article['content'][:300] + '...'
                results.append(article)

            print(f"Semantic search found {len(results)} results for: '{query}'")
            return results

        except Exception as e:
            print(f"Error in semantic search: {e}")
            return self.keyword_search(query, top_k)

    def keyword_search(self, query: str, top_k: int = 3) -> List[Dict]:
        """
        Fallback keyword-based search

        Args:
            query: Search query
            top_k: Number of results to return

        Returns:
            List of articles sorted by keyword matches
        """
        query_lower = query.lower()
        query_words = set(query_lower.split())

        # Score articles by keyword matches
        scored_articles = []
        for article in self.articles:
            score = 0

            # Check title
            if any(word in article['title'].lower() for word in query_words):
                score += 3

            # Check keywords
            for keyword in article['keywords']:
                if keyword in query_lower:
                    score += 2

            # Check content
            content_lower = article['content'].lower()
            for word in query_words:
                if word in content_lower:
                    score += 1

            if score > 0:
                article_copy = article.copy()
                article_copy['relevance_score'] = score / 10.0  # Normalize
                article_copy['content'] = article_copy['content'][:300] + '...'
                scored_articles.append((score, article_copy))

        # Sort by score and return top-k
        scored_articles.sort(key=lambda x: x[0], reverse=True)
        results = [article for _, article in scored_articles[:top_k]]

        print(f"Keyword search found {len(results)} results for: '{query}'")
        return results

    @staticmethod
    def _cosine_similarity(vec1, vec2):
        """Calculate cosine similarity between vectors"""
        if len(vec2.shape) == 1:
            # Single vector
            dot_product = np.dot(vec1, vec2)
            norm_product = np.linalg.norm(vec1) * np.linalg.norm(vec2)
            return dot_product / norm_product if norm_product > 0 else 0
        else:
            # Multiple vectors (matrix)
            dot_products = np.dot(vec2, vec1)
            norms = np.linalg.norm(vec2, axis=1) * np.linalg.norm(vec1)
            return np.divide(dot_products, norms, where=norms!=0)


# Singleton instance for Lambda
_vector_search = None

def get_vector_search() -> VectorSearch:
    """Get or create vector search instance (singleton for Lambda)"""
    global _vector_search

    if _vector_search is None:
        print("Initializing vector search...")
        _vector_search = VectorSearch()

    return _vector_search


def search_articles(query: str, top_k: int = 3) -> List[Dict]:
    """
    Convenience function to search articles

    Args:
        query: Search query
        top_k: Number of results to return

    Returns:
        List of relevant articles
    """
    vs = get_vector_search()
    return vs.semantic_search(query, top_k)


# For testing
if __name__ == "__main__":
    # Test vector search
    vs = VectorSearch()

    # Test queries
    queries = [
        "How do I treat acne?",
        "What helps with wrinkles?",
        "Best sunscreen recommendations",
        "Moisturizer for dry skin",
        "Dark spots on face"
    ]

    for query in queries:
        print(f"\n{'='*60}")
        print(f"Query: {query}")
        print('='*60)
        results = vs.semantic_search(query, top_k=3)
        for i, result in enumerate(results, 1):
            print(f"\n{i}. {result['title']}")
            print(f"   Relevance: {result['relevance_score']:.2f}")
            print(f"   Source: {result['source']}")
            print(f"   URL: {result['url']}")
