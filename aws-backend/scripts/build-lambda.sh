#!/bin/bash
# Build Lambda deployment package

set -e

echo "🏗️  Building Lambda deployment package..."

# Create temporary directory
BUILD_DIR="$(pwd)/lambda/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Install dependencies with platform targeting for Lambda (x86_64 Linux)
echo "📦 Installing Python dependencies for Lambda runtime..."
pip3 install -r lambda/requirements.txt -t "$BUILD_DIR" --quiet \
    --platform manylinux2014_x86_64 \
    --implementation cp \
    --python-version 3.11 \
    --only-binary=:all: \
    --upgrade 2>/dev/null || \
    pip3 install -r lambda/requirements.txt -t "$BUILD_DIR" --quiet

# Copy Lambda function code
echo "📄 Copying Lambda function code..."
cp lambda/*.py "$BUILD_DIR/"

# Create ZIP file
echo "🗜️  Creating deployment package..."
cd "$BUILD_DIR"
zip -r ../lambda_deployment.zip . -q
cd ..
rm -rf build

echo "✅ Lambda deployment package created: lambda/lambda_deployment.zip"
echo "📦 Size: $(du -h lambda_deployment.zip | cut -f1)"

