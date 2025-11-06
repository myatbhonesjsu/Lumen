#!/usr/bin/env node
/**
 * Verify product data in DynamoDB
 * Usage: node verify-products.js
 */

const AWS = require('aws-sdk');

// Configure AWS
AWS.config.update({ region: 'us-east-1' });
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Get table name from environment or use default
const TABLE_NAME = process.env.PRODUCTS_TABLE || 'lumen-skincare-dev-products';

async function verifyProducts() {
  console.log(`🔍 Verifying products in DynamoDB table: ${TABLE_NAME}\n`);

  try {
    const response = await dynamodb.scan({
      TableName: TABLE_NAME
    }).promise();

    const products = response.Items || [];

    console.log(`Found ${products.length} products in table\n`);

    if (products.length === 0) {
      console.log('❌ No products found! Run: node load-products.js');
      return;
    }

    // Check each product for required fields
    let validCount = 0;
    let invalidCount = 0;

    products.forEach((product, index) => {
      const hasName = !!product.name;
      const hasBrand = !!product.brand;
      const hasAmazonUrl = !!product.amazon_url;
      const urlIsValid = product.amazon_url && product.amazon_url.startsWith('https://');

      const isValid = hasName && hasBrand && hasAmazonUrl && urlIsValid;

      if (isValid) {
        validCount++;
        console.log(`✅ ${index + 1}. ${product.name} (${product.brand})`);
        console.log(`   URL: ${product.amazon_url.substring(0, 60)}...`);
      } else {
        invalidCount++;
        console.log(`❌ ${index + 1}. ${product.name || 'MISSING NAME'} (${product.brand || 'MISSING BRAND'})`);
        if (!hasAmazonUrl) {
          console.log(`   ERROR: Missing amazon_url field!`);
        } else if (!urlIsValid) {
          console.log(`   ERROR: Invalid URL: ${product.amazon_url}`);
        }
      }
      console.log('');
    });

    console.log(`\n📊 Summary:`);
    console.log(`   Valid products: ${validCount}`);
    console.log(`   Invalid products: ${invalidCount}`);
    console.log(`   Total: ${products.length}\n`);

    if (invalidCount > 0) {
      console.log('⚠️  Run "node load-products.js" to fix invalid products');
    }

  } catch (error) {
    console.error('❌ Error verifying products:', error.message);

    if (error.code === 'ResourceNotFoundException') {
      console.log('\n💡 Table not found. Did you deploy the infrastructure?');
      console.log('   Run: cd terraform && terraform apply');
    }
  }
}

// Run if called directly
if (require.main === module) {
  verifyProducts()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}

module.exports = { verifyProducts };
