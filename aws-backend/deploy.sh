#!/bin/bash
# Lumen AWS Backend - One-Click Deployment
# This script automates the entire deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed"
        exit 1
    fi
    print_success "$1 is installed"
}

# Main deployment
main() {
    print_header "🚀 Lumen AWS Backend Deployment"
    
    # Step 1: Check prerequisites
    print_header "📋 Step 1: Checking Prerequisites"
    
    echo "Checking required tools..."
    check_command aws
    check_command terraform
    check_command python3
    check_command node
    
    # Verify AWS credentials
    echo -e "\nVerifying AWS credentials..."
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        REGION=$(aws configure get region)
        print_success "AWS configured - Account: $ACCOUNT_ID, Region: $REGION"
        
        if [ "$REGION" != "us-east-1" ]; then
            print_warning "Region is $REGION (expected us-east-1)"
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_error "AWS credentials not configured"
        echo "Run: aws configure"
        exit 1
    fi
    
    # Step 2: Build Lambda package
    print_header "📦 Step 2: Building Lambda Package"
    
    if [ ! -d "lambda" ]; then
        print_error "lambda/ directory not found. Are you in the aws-backend/ directory?"
        exit 1
    fi
    
    echo "Building Lambda deployment package..."
    chmod +x scripts/build-lambda.sh
    ./scripts/build-lambda.sh
    
    if [ -f "lambda/lambda_deployment.zip" ]; then
        SIZE=$(du -h lambda/lambda_deployment.zip | cut -f1)
        print_success "Lambda package built ($SIZE)"
    else
        print_error "Lambda package build failed"
        exit 1
    fi
    
    # Step 3: Deploy with Terraform
    print_header "🏗️  Step 3: Deploying Infrastructure with Terraform"
    
    cd terraform
    
    echo "Initializing Terraform..."
    terraform init -upgrade
    
    echo -e "\nPlanning deployment..."
    terraform plan -out=tfplan
    
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Review the plan above. Ready to deploy?${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    read -p "Deploy infrastructure? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    echo -e "\nDeploying infrastructure (this takes ~5 minutes)..."
    terraform apply tfplan
    
    print_success "Infrastructure deployed!"
    
    # Save outputs
    terraform output > ../outputs.txt
    API_ENDPOINT=$(terraform output -raw api_endpoint)
    PRODUCTS_TABLE=$(terraform output -raw dynamodb_products_table)
    
    cd ..
    
    # Step 4: Load products
    print_header "📊 Step 4: Loading Product Data"
    
    echo "Installing Node dependencies..."
    cd scripts
    npm install aws-sdk --silent 2>/dev/null || true
    
    echo "Loading products into DynamoDB..."
    export PRODUCTS_TABLE="$PRODUCTS_TABLE"
    node load-products.js
    
    cd ..
    
    print_success "Products loaded!"
    
    # Step 5: Test deployment
    print_header "🧪 Step 5: Testing Deployment"
    
    echo "Testing API endpoint..."
    RESPONSE=$(curl -s -X POST "${API_ENDPOINT}upload-image")
    
    if echo "$RESPONSE" | grep -q "analysis_id"; then
        print_success "API is responding correctly"
    else
        print_warning "API response unexpected: $RESPONSE"
    fi
    
    # Step 6: Display results
    print_header "🎉 Deployment Complete!"
    
    echo -e "${GREEN}Your AWS backend is now live!${NC}\n"
    
    echo -e "${BLUE}📍 API Endpoint:${NC}"
    echo "   $API_ENDPOINT"
    
    echo -e "\n${BLUE}📱 Next Steps for iOS:${NC}"
    echo "   1. Open: ios-client/AWSBackendService.swift"
    echo "   2. Update AWSConfig.apiEndpoint with:"
    echo "      ${GREEN}$API_ENDPOINT${NC}"
    echo "   3. Add AWSBackendService.swift to your Xcode project"
    echo "   4. Replace analysis calls (see README.md)"
    
    echo -e "\n${BLUE}🤖 Optional: AWS Bedrock Agent${NC}"
    echo "   • See README.md section 'AWS Bedrock Agent Setup'"
    echo "   • Enables advanced AI agentic framework"
    echo "   • Requires AWS Bedrock access approval"
    
    echo -e "\n${BLUE}📊 Monitoring:${NC}"
    echo "   • View logs: aws logs tail /aws/lambda/$(terraform -chdir=terraform output -raw lambda_function) --follow"
    echo "   • CloudWatch: https://console.aws.amazon.com/cloudwatch"
    
    echo -e "\n${BLUE}💰 Estimated Cost:${NC}"
    echo "   • Without Bedrock: ~$19/month for 10K users"
    echo "   • With Bedrock: ~$109/month for 10K users"
    
    echo -e "\n${GREEN}All outputs saved to: outputs.txt${NC}"
    
    print_header "✨ Happy Analyzing!"
}

# Handle errors
trap 'print_error "Deployment failed at step: $BASH_COMMAND"' ERR

# Run main
main

