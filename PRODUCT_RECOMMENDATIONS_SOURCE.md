# Product Recommendations Source Documentation

This document explains where product recommendations come from in the Lumen project and how to manage them.

## Overview

Product recommendations are stored in **AWS DynamoDB** and retrieved during skin analysis. The system matches products to detected skin conditions.

## Architecture Flow

```
User Takes Photo
    ↓
iOS App (SkinAnalysisService.swift)
    ↓
AWS Lambda (handler.py)
    ↓
1. Hugging Face Model (detects condition: acne, dark_circles, etc.)
2. AWS Bedrock Claude (enhances analysis)
3. DynamoDB Products Table (gets matching products)
    ↓
Returns to iOS App
    ↓
Displayed in AnalysisProcessingView.swift
```

## Product Data Storage

### Location: AWS DynamoDB

**Table Name**: `lumen-skincare-products`

**Schema**:
```
{
  "product_id": "string (Primary Key)",
  "name": "string",
  "brand": "string",
  "description": "string",
  "price_range": "string (e.g., '$15-25')",
  "amazon_url": "string",
  "rating": "number (0-5)",
  "review_count": "number",
  "target_conditions": ["array of conditions"],
  "category": "string"
}
```

**Defined In**: `/aws-backend/terraform/dynamodb.tf` (lines 52-86)

### Target Conditions Mapping

Products are matched to skin conditions using `target_conditions` field.

**Condition Mapping** (`handler.py` lines 436-453):
```python
condition_mapping = {
    'acne': ['Acne', 'Oily Skin', 'Large Pores'],
    'dark_circles': ['Dark Circles', 'Eye Care'],
    'dark_spots': ['Dark Spots', 'Pigmentation', 'Uneven Tone'],
    'wrinkles': ['Anti-Aging', 'Fine Lines', 'Wrinkles'],
    'eye_bags': ['Eye Care', 'Dark Circles', 'Puffiness'],
    'pigmentation': ['Pigmentation', 'Dark Spots', 'Uneven Tone'],
    'dryness': ['Dry Skin', 'Sensitive Skin'],
    'dry_skin': ['Dry Skin', 'Sensitive Skin'],
    'oily_skin': ['Oily Skin', 'Large Pores', 'Acne'],
    'healthy': ['Healthy Skin', 'Sunscreen']
}
```

## How Products Are Retrieved

### 1. During Skin Analysis

**File**: `/aws-backend/lambda/handler.py`
**Function**: `get_product_recommendations()` (lines 428-501)

**Process**:
1. Receives detected condition (e.g., "acne")
2. Maps condition to target conditions array
3. Scans DynamoDB products table
4. Filters products matching target conditions
5. Returns top 5 matching products
6. If not enough matches, adds general skincare products

**Example**:
```python
# User has acne detected
condition = "acne"
# Maps to: ['Acne', 'Oily Skin', 'Large Pores']
# Returns products with any of these in target_conditions
```

### 2. iOS App Receives Products

**File**: `/Lumen/Helpers/SkinAnalysisService.swift`
**Lines**: 152-166

Products are mapped from AWS response to iOS model:
```swift
let products = (awsResponse.products ?? []).map { p in
    AnalysisResult.Product(
        name: p.name,
        brand: p.brand,
        description: p.description,
        priceRange: p.price_range,
        amazonUrl: p.amazon_url,
        rating: p.rating
    )
}
```

### 3. Displayed to User

**File**: `/Lumen/Views/Analysis/AnalysisProcessingView.swift`
**Function**: `productCard()` (lines starting with search result)

Shows:
- Product name and brand
- Star rating
- Price range
- Description
- "View on Amazon" button with URL

## How to Add/Modify Products

### Option 1: Direct DynamoDB Modification (AWS Console)

1. Go to AWS Console → DynamoDB
2. Navigate to `lumen-skincare-products` table
3. Click "Explore table items"
4. Use "Create item" or edit existing items

**Example Item**:
```json
{
  "product_id": "prod_001",
  "name": "CeraVe Hydrating Cleanser",
  "brand": "CeraVe",
  "description": "Gentle cleanser with hyaluronic acid and ceramides",
  "price_range": "$15-20",
  "amazon_url": "https://amazon.com/dp/B01MSSDEPK",
  "rating": 4.5,
  "review_count": 12543,
  "target_conditions": ["Dry Skin", "Sensitive Skin", "Healthy Skin"],
  "category": "Cleanser"
}
```

### Option 2: Bulk Import Script (Recommended)

Create a Python script to load products from JSON/CSV:

```python
import boto3
import json

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('lumen-skincare-products')

# Load products from JSON file
with open('products.json', 'r') as f:
    products = json.load(f)

# Insert each product
for product in products:
    table.put_item(Item=product)
    print(f"Added: {product['name']}")
```

**Sample products.json**:
```json
[
  {
    "product_id": "prod_001",
    "name": "CeraVe Hydrating Cleanser",
    "brand": "CeraVe",
    "description": "Gentle cleanser for dry and sensitive skin",
    "price_range": "$15-20",
    "amazon_url": "https://amazon.com/dp/B01MSSDEPK",
    "rating": 4.5,
    "review_count": 12543,
    "target_conditions": ["Dry Skin", "Sensitive Skin"],
    "category": "Cleanser"
  },
  {
    "product_id": "prod_002",
    "name": "The Ordinary Niacinamide",
    "brand": "The Ordinary",
    "description": "Reduces appearance of blemishes and congestion",
    "price_range": "$6-8",
    "amazon_url": "https://amazon.com/dp/B06XQPW2MY",
    "rating": 4.3,
    "review_count": 8921,
    "target_conditions": ["Acne", "Oily Skin", "Large Pores"],
    "category": "Serum"
  }
]
```

### Option 3: AWS CLI

```bash
# Add single product
aws dynamodb put-item \
  --table-name lumen-skincare-products \
  --item '{
    "product_id": {"S": "prod_003"},
    "name": {"S": "La Roche-Posay SPF 50"},
    "brand": {"S": "La Roche-Posay"},
    "description": {"S": "Broad spectrum sunscreen"},
    "price_range": {"S": "$30-35"},
    "amazon_url": {"S": "https://amazon.com/dp/example"},
    "rating": {"N": "4.7"},
    "review_count": {"N": "5234"},
    "target_conditions": {"L": [
      {"S": "Healthy Skin"},
      {"S": "Sunscreen"}
    ]},
    "category": {"S": "Sunscreen"}
  }'
```

## Important Fields

### Required Fields
- `product_id`: Unique identifier (use UUID or `prod_XXX` format)
- `name`: Product name
- `brand`: Brand name
- `description`: Brief description (1-2 sentences)
- `price_range`: Price range string (e.g., "$15-25")
- `amazon_url`: Full Amazon product URL
- `rating`: Decimal rating 0-5
- `target_conditions`: Array of conditions this product addresses

### Optional Fields
- `review_count`: Number of reviews
- `category`: Product category (Cleanser, Moisturizer, Serum, etc.)

## Product Categories

Common categories to use:
- Cleanser
- Moisturizer
- Serum
- Sunscreen
- Treatment (Retinol, etc.)
- Eye Cream
- Mask
- Toner
- Exfoliant

## Target Conditions Reference

Use these exact strings in `target_conditions`:
- Acne
- Oily Skin
- Large Pores
- Dark Circles
- Eye Care
- Puffiness
- Dark Spots
- Pigmentation
- Uneven Tone
- Anti-Aging
- Fine Lines
- Wrinkles
- Dry Skin
- Sensitive Skin
- Healthy Skin
- Sunscreen

## Testing Product Recommendations

### 1. Check DynamoDB Table
```bash
aws dynamodb scan \
  --table-name lumen-skincare-products \
  --limit 10
```

### 2. Test Lambda Function
```bash
# Trigger analysis with test image
# Products will be returned in response
```

### 3. iOS App Debug
Enable debug logging in `SkinAnalysisService.swift` (lines 153-156):
```swift
#if DEBUG
print("[SkinAnalysis] Product: \(p.name)")
print("[SkinAnalysis] Amazon URL: '\(p.amazon_url)'")
#endif
```

## Current Limitations

1. **No Real-Time Sync**: Products stored in DynamoDB don't update in iOS without new analysis
2. **No Product Search**: Users can't search products directly, only get recommendations
3. **No Favorites**: Can't save favorite products
4. **Amazon Links Only**: Currently only supports Amazon URLs

## Future Enhancements

Consider adding:
1. Product search endpoint in API
2. Favorite products feature in iOS
3. Product reviews integration
4. Multiple retailer links (Sephora, Ulta, etc.)
5. Price tracking
6. User product ratings

## File Locations Summary

### Backend (AWS)
- **DynamoDB Schema**: `/aws-backend/terraform/dynamodb.tf`
- **Product Retrieval Logic**: `/aws-backend/lambda/handler.py` (lines 428-501)
- **Condition Mapping**: `/aws-backend/lambda/handler.py` (lines 436-453)

### iOS App
- **Product Model**: `/Lumen/Helpers/SkinAnalysisService.swift` (lines 21-28)
- **API Integration**: `/Lumen/Helpers/AWSBackendService.swift` (lines 85-94)
- **Display UI**: `/Lumen/Views/Analysis/AnalysisProcessingView.swift`

## Support

For questions about product recommendations:
1. Check DynamoDB table structure
2. Review Lambda function logs in CloudWatch
3. Test with iOS debug logging enabled
4. Verify product `target_conditions` match condition mapping
