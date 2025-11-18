#!/usr/bin/env python3
"""
Load products from JSON file into DynamoDB

This script loads product data from data/products.json into the DynamoDB products table.
It can be used to:
1. Initially populate the products table
2. Update existing products
3. Add new products

Usage:
    python3 scripts/load-products.py [--clear] [--file data/products.json]

Options:
    --clear     Clear all existing products before loading (DANGEROUS!)
    --file      Path to products JSON file (default: data/products.json)
"""

import json
import sys
import os
import argparse
import boto3
from decimal import Decimal
from pathlib import Path

# AWS Configuration
REGION = 'us-east-1'
TABLE_NAME = 'lumen-skincare-dev-products'


def convert_floats_to_decimal(obj):
    """Convert float values to Decimal for DynamoDB"""
    if isinstance(obj, list):
        return [convert_floats_to_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_floats_to_decimal(value) for key, value in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
    else:
        return obj


def load_products_from_file(file_path):
    """Load products from JSON file"""
    try:
        with open(file_path, 'r') as f:
            products = json.load(f)
        print(f"✓ Loaded {len(products)} products from {file_path}")
        return products
    except FileNotFoundError:
        print(f"✗ Error: File not found: {file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"✗ Error: Invalid JSON in {file_path}: {e}")
        sys.exit(1)


def clear_all_products(table):
    """Delete all products from DynamoDB table"""
    print("\n⚠️  WARNING: This will delete ALL products from the table!")
    confirm = input("Type 'DELETE' to confirm: ")

    if confirm != 'DELETE':
        print("✗ Aborted. No products were deleted.")
        return False

    print("Scanning table for products to delete...")
    response = table.scan()
    items = response.get('Items', [])

    deleted_count = 0
    for item in items:
        table.delete_item(Key={'product_id': item['product_id']})
        deleted_count += 1
        print(f"  Deleted product {item['product_id']}: {item.get('name', 'Unknown')}")

    print(f"\n✓ Deleted {deleted_count} products")
    return True


def upload_products(table, products):
    """Upload products to DynamoDB"""
    print(f"\nUploading {len(products)} products to DynamoDB...")

    success_count = 0
    error_count = 0

    for product in products:
        try:
            # Convert floats to Decimal for DynamoDB
            product_data = convert_floats_to_decimal(product)

            # Put item in DynamoDB
            table.put_item(Item=product_data)

            print(f"  ✓ {product['product_id']}: {product['name']}")
            success_count += 1

        except Exception as e:
            print(f"  ✗ Error uploading {product.get('product_id', 'unknown')}: {e}")
            error_count += 1

    print(f"\n{'='*60}")
    print(f"Upload complete!")
    print(f"  Successful: {success_count}")
    print(f"  Failed: {error_count}")
    print(f"{'='*60}\n")

    return success_count, error_count


def verify_products(table, product_ids):
    """Verify products were uploaded correctly"""
    print("\nVerifying products in DynamoDB...")

    found_count = 0
    missing_count = 0

    for product_id in product_ids:
        try:
            response = table.get_item(Key={'product_id': product_id})
            if 'Item' in response:
                found_count += 1
                print(f"  ✓ Found: {product_id}")
            else:
                missing_count += 1
                print(f"  ✗ Missing: {product_id}")
        except Exception as e:
            missing_count += 1
            print(f"  ✗ Error checking {product_id}: {e}")

    print(f"\nVerification:")
    print(f"  Found: {found_count}/{len(product_ids)}")
    print(f"  Missing: {missing_count}/{len(product_ids)}")

    return found_count == len(product_ids)


def main():
    parser = argparse.ArgumentParser(
        description='Load products from JSON into DynamoDB',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Load products from default file
  python3 scripts/load-products.py

  # Clear all products and load fresh data
  python3 scripts/load-products.py --clear

  # Load from custom file
  python3 scripts/load-products.py --file my-products.json
        """
    )

    parser.add_argument(
        '--clear',
        action='store_true',
        help='Clear all existing products before loading (requires confirmation)'
    )

    parser.add_argument(
        '--file',
        default='data/products.json',
        help='Path to products JSON file (default: data/products.json)'
    )

    args = parser.parse_args()

    # Print header
    print("\n" + "="*60)
    print("  Lumen Product Loader")
    print("="*60 + "\n")

    # Initialize DynamoDB
    print(f"Connecting to DynamoDB table: {TABLE_NAME}")
    try:
        dynamodb = boto3.resource('dynamodb', region_name=REGION)
        table = dynamodb.Table(TABLE_NAME)

        # Verify table exists
        table.load()
        print(f"✓ Connected to table: {table.table_name}")
        print(f"  Status: {table.table_status}")
        print(f"  Item count: {table.item_count}")

    except Exception as e:
        print(f"✗ Error connecting to DynamoDB: {e}")
        print("\nMake sure:")
        print("  1. AWS credentials are configured (aws configure)")
        print("  2. You have permissions to access DynamoDB")
        print("  3. The table exists in us-east-1 region")
        sys.exit(1)

    # Load products from file
    products = load_products_from_file(args.file)

    # Clear existing products if requested
    if args.clear:
        if not clear_all_products(table):
            sys.exit(1)

    # Upload products
    success_count, error_count = upload_products(table, products)

    # Verify uploads
    product_ids = [p['product_id'] for p in products]
    all_verified = verify_products(table, product_ids)

    # Print final status
    if error_count == 0 and all_verified:
        print("\n✓ All products loaded successfully!")
        sys.exit(0)
    else:
        print(f"\n⚠️  Some products failed to load. Check errors above.")
        sys.exit(1)


if __name__ == '__main__':
    main()
