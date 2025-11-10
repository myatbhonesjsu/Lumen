#!/bin/bash
# Lumen AWS Backend - Complete Deployment Script
# Deploys Skin Analysis API + Learning Hub with AI Chatbot

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

    echo -e "${BLUE}Architecture:${NC}"
    echo "  • Skin Analysis API (Lambda + Rekognition + Bedrock)"
    echo "  • AI Learning Hub (Lambda + Bedrock + Knowledge Base)"
    echo "  • DynamoDB (Analyses + Products + Chat History)"
    echo "  • S3 (Image Storage)"
    echo ""

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
            print_warning "Region is $REGION (recommended: us-east-1 for Bedrock access)"
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

    # Step 2: Build Lambda packages
    print_header "📦 Step 2: Building Lambda Packages"

    if [ ! -d "lambda" ]; then
        print_error "lambda/ directory not found. Are you in the aws-backend/ directory?"
        exit 1
    fi

    # Build Skin Analysis Lambda
    echo "Building Skin Analysis Lambda..."
    chmod +x scripts/build-lambda.sh
    ./scripts/build-lambda.sh

    if [ -f "lambda/lambda_deployment.zip" ]; then
        SIZE=$(du -h lambda/lambda_deployment.zip | cut -f1)
        print_success "Skin Analysis Lambda built ($SIZE)"
    else
        print_error "Skin Analysis Lambda build failed"
        exit 1
    fi

    # Build Learning Hub Lambda
    echo "Building Learning Hub Lambda..."
    chmod +x scripts/build-learning-hub.sh
    ./scripts/build-learning-hub.sh

    if [ -f "lambda/learning_hub.zip" ]; then
        SIZE=$(du -h lambda/learning_hub.zip | cut -f1)
        print_success "Learning Hub Lambda built ($SIZE)"
    else
        print_error "Learning Hub Lambda build failed"
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

    echo -e "\nDeploying infrastructure..."
    echo -e "${BLUE}This will create:${NC}"
    echo "  • 2 Lambda Functions"
    echo "  • 3 DynamoDB Tables"
    echo "  • 2 API Gateway Endpoints"
    echo "  • 1 S3 Bucket"
    echo "  • IAM Roles & Policies"
    echo ""
    echo "⏱️  Estimated time: 3-5 minutes..."

    terraform apply tfplan

    print_success "Infrastructure deployed!"

    # Save outputs
    terraform output -json > ../outputs.json
    API_ENDPOINT=$(terraform output -raw api_endpoint)
    LEARNING_HUB_API=$(terraform output -raw learning_hub_api_endpoint 2>/dev/null || echo "")
    ANALYSES_TABLE=$(terraform output -raw dynamodb_analyses_table)
    PRODUCTS_TABLE=$(terraform output -raw dynamodb_products_table)

    cd ..

    # Step 4: Load product data
    print_header "📊 Step 4: Loading Product Data"

    echo "Installing Node dependencies..."
    cd scripts
    npm install aws-sdk --silent 2>/dev/null || npm install aws-sdk

    echo "Loading products into DynamoDB..."
    export PRODUCTS_TABLE="$PRODUCTS_TABLE"
    node load-products.js

    cd ..

    print_success "Products loaded!"

    # Step 5: Test deployment
    print_header "🧪 Step 5: Testing Deployment"

    echo "Testing Skin Analysis API..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_ENDPOINT}upload-image" || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "200" ]; then
        print_success "Skin Analysis API is responding (HTTP $HTTP_CODE)"
    else
        print_warning "Unexpected API response (HTTP $HTTP_CODE)"
    fi

    if [ ! -z "$LEARNING_HUB_API" ]; then
        echo "Testing Learning Hub API..."
        LH_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${LEARNING_HUB_API}articles" || echo "000")
        LH_HTTP_CODE=$(echo "$LH_RESPONSE" | tail -n1)

        if [ "$LH_HTTP_CODE" = "200" ]; then
            print_success "Learning Hub API is responding"
        else
            print_warning "Learning Hub API response: HTTP $LH_HTTP_CODE"
        fi
    fi

    # Step 6: Display results
    print_header "🎉 Deployment Complete!"

    echo -e "${GREEN}Your AWS backend is now live!${NC}\n"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📍 API ENDPOINTS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo -e "${GREEN}Skin Analysis API:${NC}"
    echo "   $API_ENDPOINT"

    if [ ! -z "$LEARNING_HUB_API" ]; then
        echo -e "\n${GREEN}Learning Hub API:${NC}"
        echo "   $LEARNING_HUB_API"
    fi

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📱 NEXT STEPS FOR iOS APP${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo "1. Update API endpoints in your iOS app:"
    echo -e "   ${GREEN}File:${NC} Lumen/Helpers/AWSBackendService.swift"
    echo -e "   ${GREEN}Set:${NC} apiEndpoint = \"$API_ENDPOINT\""

    if [ ! -z "$LEARNING_HUB_API" ]; then
        echo ""
        echo -e "   ${GREEN}File:${NC} Lumen/Services/LearningHubService.swift"
        echo -e "   ${GREEN}Set:${NC} baseURL = \"$LEARNING_HUB_API\""
    fi

    echo ""
    echo "2. Build and run your iOS app"
    echo "   • Take a skin analysis photo"
    echo "   • Chat with AI assistant"

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🤖 OPTIONAL: KNOWLEDGE BASE SETUP${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo "For enhanced AI responses with RAG:"
    echo "   cd scripts"
    echo "   python3 setup-knowledge-base.py"
    echo "   python3 load-knowledge-base.py"
    echo ""
    echo "This enables:"
    echo "   • Evidence-based skincare advice"
    echo "   • Product recommendations"
    echo "   • Contextual article suggestions"

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 MONITORING & LOGS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo "View Lambda logs:"
    echo "   # Skin Analysis"
    echo "   aws logs tail /aws/lambda/$(cd terraform && terraform output -raw lambda_function) --follow"
    echo ""
    echo "   # Learning Hub"
    echo "   aws logs tail /aws/lambda/lumen-skincare-dev-learning-hub-chatbot --follow"
    echo ""
    echo "CloudWatch Console:"
    echo "   https://console.aws.amazon.com/cloudwatch"

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}💰 ESTIMATED COSTS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo "For 10,000 monthly active users:"
    echo "   • Lambda: ~\$5/month"
    echo "   • DynamoDB: ~\$2/month"
    echo "   • S3: ~\$1/month"
    echo "   • Rekognition: ~\$10/month"
    echo "   • Bedrock (Claude): ~\$90/month"
    echo "   ────────────────────────────"
    echo "   Total: ~\$108/month"
    echo ""
    echo "💡 Tip: Use AWS Free Tier for first 12 months"

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ All deployment outputs saved to: outputs.json${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    print_header "✨ Happy Analyzing!"
}

# Handle errors
trap 'print_error "Deployment failed! Check the error above."' ERR

# Run main
main
