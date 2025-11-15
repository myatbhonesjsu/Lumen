#!/usr/bin/env python3
"""
Export products from DynamoDB to JSON file

This script exports all products from the DynamoDB table to a JSON file.
Useful for backing up products or making bulk edits.

Usage:
    python3 scripts/export-products.py [--output data/products-backup.json]

Options:
    --output    Output file path (default: data/products-export.json)
"""

import json
import sys
import argparse
import boto3
from decimal import Decimal
from datetime import datetime

# AWS Configuration
REGION = 'us-east-1'
TABLE_NAME = 'lumen-skincare-dev-products'


class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder to handle Decimal types from DynamoDB"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            # Convert Decimal to float for JSON
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def export_products(table, output_file):
    """Export all products from DynamoDB to JSON file"""
    print(f"\nScanning DynamoDB table: {TABLE_NAME}")

    try:
        # Scan the entire table
        response = table.scan()
        products = response.get('Items', [])

        # Handle pagination if there are many products
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            products.extend(response.get('Items', []))

        print(f"✓ Found {len(products)} products")

        # Sort products by product_id for consistency
        products.sort(key=lambda x: x.get('product_id', ''))

        # Write to JSON file with pretty formatting
        with open(output_file, 'w') as f:
            json.dump(products, f, indent=2, cls=DecimalEncoder)

        print(f"✓ Exported to: {output_file}")

        # Print summary
        print("\nProduct Summary:")
        categories = {}
        for product in products:
            category = product.get('category', 'Unknown')
            categories[category] = categories.get(category, 0) + 1

        for category, count in sorted(categories.items()):
            print(f"  {category}: {count}")

        return len(products)

    except Exception as e:
        print(f"✗ Error exporting products: {e}")
        return 0


def main():
    parser = argparse.ArgumentParser(
        description='Export products from DynamoDB to JSON file'
    )

    parser.add_argument(
        '--output',
        default='data/products-export.json',
        help='Output file path (default: data/products-export.json)'
    )

    args = parser.parse_args()

    # Print header
    print("\n" + "="*60)
    print("  Lumen Product Exporter")
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
        sys.exit(1)

    # Export products
    count = export_products(table, args.output)

    if count > 0:
        print(f"\n✓ Successfully exported {count} products!")
        print(f"\nYou can now:")
        print(f"  1. Edit {args.output}")
        print(f"  2. Load it back: python3 scripts/load-products.py --file {args.output}")
        sys.exit(0)
    else:
        print("\n✗ Export failed or no products found")
        sys.exit(1)


if __name__ == '__main__':
    main()
