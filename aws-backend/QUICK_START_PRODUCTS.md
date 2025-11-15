# Quick Start: Managing Product Recommendations

## TL;DR

```bash
# Export current products
python3 scripts/export-products.py

# Edit products
nano data/products.json

# Upload changes
python3 scripts/load-products.py
```

## Current Setup

- **Products File**: `data/products.json` (12 products currently)
- **Database**: DynamoDB table `lumen-skincare-dev-products`
- **Scripts**: `scripts/load-products.py` and `scripts/export-products.py`

## Add a New Product (3 Steps)

### Step 1: Edit JSON File

```bash
nano data/products.json
```

Add at the end of the array (before the closing `]`):

```json
  ,
  {
    "product_id": "13",
    "name": "Your Product Name",
    "brand": "Brand Name",
    "description": "Brief product description",
    "price_range": "$15-20",
    "amazon_url": "https://www.amazon.com/dp/PRODUCTCODE",
    "rating": 4.5,
    "review_count": 1000,
    "category": "Serum",
    "target_conditions": [
      "Acne",
      "Oily Skin"
    ],
    "ingredients": [
      "Niacinamide",
      "Salicylic Acid"
    ]
  }
```

### Step 2: Validate JSON

```bash
cat data/products.json | python3 -m json.tool > /dev/null && echo "✓ Valid JSON" || echo "✗ Invalid JSON"
```

### Step 3: Upload to DynamoDB

```bash
python3 scripts/load-products.py
```

Done! New product is now live and will appear in skin analysis results.

## Edit Existing Product

1. Find product by `product_id` in `data/products.json`
2. Edit the fields you want to change
3. Save file
4. Run: `python3 scripts/load-products.py`

## Delete a Product

1. Remove the product object from `data/products.json`
2. Run: `python3 scripts/load-products.py --clear`
3. Type `DELETE` when prompted

## Target Conditions (Must Use Exact Strings)

When a user has acne detected, products with `"Acne"` in `target_conditions` will be recommended.

**Valid Conditions**:
- `"Acne"` - For acne-prone skin
- `"Oily Skin"` - Excess oil production
- `"Large Pores"` - Visible pores
- `"Dark Circles"` - Under-eye darkness
- `"Eye Bags"` - Under-eye puffiness
- `"Dark Spots"` - Hyperpigmentation
- `"Wrinkles"` - Fine lines and wrinkles
- `"Dry Skin"` - Dehydrated skin
- `"Sensitive Skin"` - Easily irritated skin
- `"Healthy Skin"` - General maintenance
- `"Rosacea"` - Rosacea-prone skin

## Common Issues

### Products not showing in app?

**Check 1**: Verify target_conditions match detected skin condition:
```bash
# If user has "Acne" detected, check which products target it
cat data/products.json | python3 -c "
import json, sys
products = json.load(sys.stdin)
acne = [p['name'] for p in products if 'Acne' in p.get('target_conditions', [])]
print(f'Products for Acne: {len(acne)}')
for name in acne: print(f'  - {name}')
"
```

**Check 2**: Verify products are in DynamoDB:
```bash
python3 scripts/export-products.py
cat data/products-export.json | grep "product_id"
```

**Check 3**: Check Lambda logs:
```bash
aws logs tail /aws/lambda/lumen-skincare-dev-analyze-skin --follow
```

### Script errors?

**Error: "Table not found"**
- Run: `cd terraform && terraform apply` to create table

**Error: "AWS credentials not configured"**
- Run: `aws configure` and enter your credentials

**Error: "Permission denied"**
- Run: `chmod +x scripts/*.py`

## File Locations

```
aws-backend/
├── data/
│   └── products.json              # ← EDIT THIS FILE
├── scripts/
│   ├── load-products.py           # Upload to DynamoDB
│   └── export-products.py         # Download from DynamoDB
├── PRODUCTS_MANAGEMENT.md         # Detailed docs
└── QUICK_START_PRODUCTS.md        # This file
```

## Complete Documentation

For detailed instructions, see:
- **[PRODUCTS_MANAGEMENT.md](PRODUCTS_MANAGEMENT.md)** - Complete guide
- **[PRODUCT_RECOMMENDATIONS_SOURCE.md](../PRODUCT_RECOMMENDATIONS_SOURCE.md)** - Architecture overview

## Need Help?

1. Check if file exists: `ls -la data/products.json`
2. Validate JSON: `cat data/products.json | python3 -m json.tool`
3. Check DynamoDB: `aws dynamodb scan --table-name lumen-skincare-dev-products --limit 5`
4. View logs: `aws logs tail /aws/lambda/lumen-skincare-dev-analyze-skin --follow`
