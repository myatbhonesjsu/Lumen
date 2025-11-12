# Product Management Guide

This guide explains how to manage product recommendations in the Lumen skincare app using the JSON file and Python scripts.

## Overview

Product recommendations are stored in:
- **Source File**: `data/products.json` (editable JSON file)
- **Database**: AWS DynamoDB table `lumen-skincare-dev-products`

## Quick Start

### 1. View Current Products
```bash
# Export current products from DynamoDB
cd aws-backend
python3 scripts/export-products.py
```

This creates `data/products-export.json` with all current products.

### 2. Edit Products
```bash
# Edit the JSON file with your favorite editor
nano data/products.json
# or
code data/products.json
```

### 3. Update DynamoDB
```bash
# Upload changes to DynamoDB
python3 scripts/load-products.py
```

## Product JSON Schema

Each product in `data/products.json` must have this structure:

```json
{
  "product_id": "unique_id",          // Required: Unique identifier
  "name": "Product Name",             // Required: Product name
  "brand": "Brand Name",              // Required: Brand name
  "description": "Description",       // Required: Product description
  "price_range": "$10-15",           // Required: Price range string
  "amazon_url": "https://...",       // Required: Amazon product URL
  "rating": 4.5,                     // Required: Rating (0-5)
  "review_count": 12345,             // Required: Number of reviews
  "category": "Serum",               // Required: Product category
  "target_conditions": [             // Required: Array of conditions
    "Acne",
    "Oily Skin"
  ],
  "ingredients": [                   // Optional: Array of ingredients
    "Niacinamide",
    "Zinc PCA"
  ]
}
```

### Valid Categories
- Cleanser
- Moisturizer
- Serum
- Sunscreen
- Eye Cream
- Eye Serum
- Exfoliant
- Treatment
- Toner
- Mask

### Valid Target Conditions
Use these exact strings (case-sensitive):
- Acne
- Oily Skin
- Large Pores
- Dark Circles
- Eye Bags
- Puffiness
- Dark Spots
- Hyperpigmentation
- Uneven Skin Tone
- Wrinkles
- Fine Lines
- Aging Skin
- Dry Skin
- Sensitive Skin
- Healthy Skin
- Rosacea
- Blackheads
- Uneven Texture
- Dull Skin
- Loss of Firmness

## Common Tasks

### Add a New Product

1. Open `data/products.json`
2. Add new product at the end of the array:

```json
{
  "product_id": "13",
  "name": "New Product Name",
  "brand": "Brand",
  "description": "Product description here",
  "price_range": "$15-20",
  "amazon_url": "https://amazon.com/dp/XXXXXXXXX",
  "rating": 4.5,
  "review_count": 1000,
  "category": "Serum",
  "target_conditions": [
    "Acne",
    "Oily Skin"
  ],
  "ingredients": [
    "Active Ingredient 1",
    "Active Ingredient 2"
  ]
}
```

3. Upload to DynamoDB:
```bash
python3 scripts/load-products.py
```

### Update Existing Product

1. Find the product in `data/products.json` by `product_id`
2. Edit the fields you want to change
3. Save the file
4. Upload changes:
```bash
python3 scripts/load-products.py
```

Note: This will overwrite the existing product with the same `product_id`.

### Delete a Product

1. Remove the product from `data/products.json`
2. Upload the updated file:
```bash
python3 scripts/load-products.py --clear
```

**Warning**: `--clear` deletes ALL products and re-uploads from file. Use with caution!

### Backup Products

```bash
# Export current products with timestamp
python3 scripts/export-products.py --output "data/products-backup-$(date +%Y%m%d).json"
```

### Replace All Products

```bash
# Clear all and load fresh
python3 scripts/load-products.py --clear

# This will:
# 1. Ask for confirmation (type 'DELETE')
# 2. Delete all products from DynamoDB
# 3. Upload all products from data/products.json
```

## Script Reference

### load-products.py

Loads products from JSON file into DynamoDB.

**Usage:**
```bash
python3 scripts/load-products.py [OPTIONS]
```

**Options:**
- `--clear` - Delete all existing products before loading (requires confirmation)
- `--file PATH` - Use custom JSON file (default: data/products.json)

**Examples:**
```bash
# Load products from default file
python3 scripts/load-products.py

# Clear all and reload
python3 scripts/load-products.py --clear

# Load from custom file
python3 scripts/load-products.py --file my-products.json
```

**Output:**
- Shows progress for each product
- Reports success/failure counts
- Verifies all products were uploaded

### export-products.py

Exports products from DynamoDB to JSON file.

**Usage:**
```bash
python3 scripts/export-products.py [OPTIONS]
```

**Options:**
- `--output PATH` - Output file path (default: data/products-export.json)

**Examples:**
```bash
# Export to default file
python3 scripts/export-products.py

# Export to custom location
python3 scripts/export-products.py --output backup/products.json

# Export with timestamp
python3 scripts/export-products.py --output "products-$(date +%Y%m%d).json"
```

## Workflow Examples

### Workflow 1: Add New Products

```bash
# Step 1: Backup current products
python3 scripts/export-products.py --output data/products-backup.json

# Step 2: Edit products.json and add new products
nano data/products.json

# Step 3: Upload to DynamoDB
python3 scripts/load-products.py

# Step 4: Verify in app by running a skin analysis
```

### Workflow 2: Update Product Information

```bash
# Step 1: Export current products
python3 scripts/export-products.py

# Step 2: Edit the exported file
nano data/products-export.json

# Step 3: Load the updated file
python3 scripts/load-products.py --file data/products-export.json
```

### Workflow 3: Reorganize All Products

```bash
# Step 1: Export current products
python3 scripts/export-products.py --output data/products-current.json

# Step 2: Edit and reorganize
nano data/products-current.json

# Step 3: Clear and reload everything
python3 scripts/load-products.py --clear --file data/products-current.json
```

## Troubleshooting

### Error: "Table not found"
**Solution**: Make sure you've deployed the Terraform infrastructure:
```bash
cd terraform
terraform apply
```

### Error: "AWS credentials not configured"
**Solution**: Configure AWS CLI:
```bash
aws configure
# Enter your access key, secret key, and region (us-east-1)
```

### Error: "Permission denied"
**Solution**: Make scripts executable:
```bash
chmod +x scripts/load-products.py
chmod +x scripts/export-products.py
```

### Error: "Invalid JSON"
**Solution**: Validate your JSON:
```bash
cat data/products.json | python3 -m json.tool
```

### Products not showing in app
**Possible causes:**
1. Product `target_conditions` don't match detected skin conditions
2. Table name mismatch in Lambda environment variables
3. DynamoDB permissions issue

**Debug steps:**
```bash
# Check if products exist in DynamoDB
aws dynamodb scan --table-name lumen-skincare-dev-products --limit 5

# Check Lambda environment variables
aws lambda get-function-configuration --function-name lumen-skincare-dev-analyze

# Test skin analysis with debug logging enabled
```

## Testing

### Test Product Recommendations

1. Export products to verify they exist:
```bash
python3 scripts/export-products.py
cat data/products-export.json | grep "product_id"
```

2. Check products for specific condition:
```bash
# View products targeting "Acne"
cat data/products.json | python3 -c "
import json, sys
products = json.load(sys.stdin)
acne_products = [p for p in products if 'Acne' in p.get('target_conditions', [])]
print(f'Found {len(acne_products)} products for Acne:')
for p in acne_products:
    print(f'  - {p[\"name\"]} ({p[\"brand\"]})')
"
```

3. Test in iOS app:
   - Take a photo with acne visible
   - Check if relevant products appear in results
   - Enable debug logging in `SkinAnalysisService.swift`

## Best Practices

1. **Always backup before major changes**
   ```bash
   python3 scripts/export-products.py --output "backup-$(date +%Y%m%d).json"
   ```

2. **Use descriptive product IDs**
   - Good: `"cerave-acne-cleanser-001"`
   - Bad: `"1"`, `"prod1"`

3. **Keep target_conditions accurate**
   - Match conditions to product's actual benefits
   - Use multiple conditions for versatile products
   - Don't add conditions just to show product more often

4. **Verify Amazon URLs**
   - Use full Amazon product page URLs
   - Test URLs before uploading
   - Keep URLs updated if Amazon changes them

5. **Maintain consistent pricing format**
   - Always use format: `"$XX-YY"`
   - Example: `"$15-20"` not `"15-20 dollars"`

6. **Include relevant ingredients**
   - List active/key ingredients
   - Helps users understand product effectiveness
   - Optional but recommended

## Integration with App

### How Products Are Retrieved

1. User takes photo
2. Lambda analyzes skin (detects "Acne", "Dark Circles", etc.)
3. Lambda queries DynamoDB for products matching detected condition
4. Lambda returns top 5 products to iOS app
5. Products displayed in `AnalysisProcessingView`

### Condition Mapping

The Lambda function maps detected conditions to product target_conditions:

```python
# In handler.py
condition_mapping = {
    'acne': ['Acne', 'Oily Skin', 'Large Pores'],
    'dark_circles': ['Dark Circles', 'Eye Care'],
    'wrinkles': ['Anti-Aging', 'Fine Lines', 'Wrinkles'],
    # ... etc
}
```

## File Structure

```
aws-backend/
├── data/
│   ├── products.json              # Main product file (edit this)
│   └── products-export.json       # Export output (generated)
├── scripts/
│   ├── load-products.py           # Upload to DynamoDB
│   └── export-products.py         # Download from DynamoDB
└── PRODUCTS_MANAGEMENT.md         # This file
```

## Support

For questions or issues:
1. Check this documentation
2. Review error messages from scripts
3. Verify AWS credentials and permissions
4. Check DynamoDB table exists and has items
5. Review Lambda CloudWatch logs for product retrieval issues

## Related Documentation

- `PRODUCT_RECOMMENDATIONS_SOURCE.md` - Detailed architecture overview
- `lambda/handler.py` - Product retrieval logic
- `terraform/dynamodb.tf` - Database schema
