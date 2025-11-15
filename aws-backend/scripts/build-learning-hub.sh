#!/bin/bash

# Build Learning Hub Lambda function

set -e

echo "🏗️  Building Learning Hub Lambda..."

# Navigate to lambda directory
cd "$(dirname "$0")/../lambda"

# Create build directory
rm -rf learning_hub_build
mkdir -p learning_hub_build

# Copy handler
cp learning_hub_handler.py learning_hub_build/

# Install dependencies
echo "📦 Installing dependencies..."
/opt/homebrew/bin/pip3 install --target learning_hub_build boto3 requests -q

# Create zip
echo "📦 Creating deployment package..."
cd learning_hub_build
zip -r ../learning_hub.zip . -q
cd ..

# Cleanup
rm -rf learning_hub_build

echo "✅ Learning Hub Lambda built successfully!"
echo "   Package: lambda/learning_hub.zip"
echo "   Size: $(du -h learning_hub.zip | cut -f1)"

