# Lumen AWS Backend - Deployment Guide

Complete AWS backend implementation for production-grade skin analysis with AI agents.

## 🏗️ Architecture Overview

```
iOS App → API Gateway → Lambda → {
    S3 (images)
    Bedrock (AI agent)
    DynamoDB (results)
    HuggingFace (initial prediction)
}
```

## 📋 Prerequisites

### Required
- AWS account with admin access
- AWS CLI installed and configured
- Terraform >= 1.0 installed
- Python 3.11
- Node.js >= 16 (for product loader)

### Optional
- AWS Bedrock access (requires account approval)

## 🚀 Quick Start

### Step 1: Verify AWS Configuration

```bash
# Check AWS CLI is configured
aws sts get-caller-identity

# Should output:
# {
#     "UserId": "...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-user"
# }

# Verify region is us-east-1
aws configure get region
# Should output: us-east-1
```

### Step 2: Build Lambda Package

```bash
cd aws-backend

# Make build script executable
chmod +x scripts/build-lambda.sh

# Build Lambda deployment package
./scripts/build-lambda.sh

# Output: lambda/lambda_deployment.zip created
```

### Step 3: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (takes ~5 minutes)
terraform apply

# Type 'yes' to confirm

# Save outputs
terraform output > ../outputs.txt
```

**Expected output:**
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

api_endpoint = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev/"
lambda_function = "lumen-skincare-dev-analyze-skin"
s3_bucket_images = "lumen-skincare-dev-images"
dynamodb_analyses_table = "lumen-skincare-dev-analyses"
dynamodb_products_table = "lumen-skincare-dev-products"
```

### Step 4: Load Product Data

```bash
cd ..

# Load products from JSON file
python3 scripts/load-products.py

# Expected output:
# ============================================================
#   Lumen Product Loader
# ============================================================
#
# Connecting to DynamoDB table: lumen-skincare-dev-products
# ✓ Connected to table: lumen-skincare-dev-products
#   Status: ACTIVE
#   Item count: 0
# ✓ Loaded 12 products from data/products.json
#
# Uploading 12 products to DynamoDB...
#   ✓ 1: CeraVe Acne Foaming Cream Cleanser
#   ✓ 2: The Ordinary Niacinamide 10% + Zinc 1%
#   ...
# ✓ All products loaded successfully!
```

See [PRODUCTS_MANAGEMENT.md](PRODUCTS_MANAGEMENT.md) for detailed product management instructions.

### Step 5: Test Backend

```bash
# Get API endpoint
API_URL=$(cd terraform && terraform output -raw api_endpoint)

# Test upload endpoint
curl -X POST "${API_URL}upload-image"

# Expected response:
# {
#   "analysis_id": "abc-123-def",
#   "upload_url": "https://s3.amazonaws.com/...",
#   "message": "Upload image to this URL"
# }
```

### Step 6: Update iOS App

```bash
# Get your API endpoint
cd terraform
terraform output api_endpoint

# Copy output, e.g.:
# https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev
```

Then in Xcode:

1. Add `AWSBackendService.swift` to your project
2. Update `AWSConfig.apiEndpoint` with your API URL
3. Replace analysis calls (see integration example below)

---

## 📱 iOS Integration

### Option 1: Quick Integration (Recommended)

Replace your current analysis in `CameraView.swift`:

```swift
// OLD CODE (remove):
SkinAnalysisService.shared.analyzeSkin(
    image: image,
    onInitialResult: { result in
        // ...
    },
    onEnhancedResult: { result in
        // ...
    }
)

// NEW CODE (add):
AWSBackendService.shared.analyzeSkin(
    image: image,
    onProgress: { message in
        DispatchQueue.main.async {
            // Update loading message
            print("Progress: \(message)")
        }
    },
    completion: { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let analysis):
                // Map AWS response to your models
                if let pred = analysis.prediction {
                    self.initialPrediction = InitialPrediction(
                        condition: pred.condition,
                        confidence: pred.confidence,
                        allConditions: pred.all_conditions ?? [:]
                    )
                }
                
                if let enhanced = analysis.enhanced_analysis {
                    self.enhancedAnalysis = ComprehensiveAnalysis(
                        summary: enhanced.summary,
                        recommendations: enhanced.recommendations,
                        severity: enhanced.severity,
                        careInstructions: enhanced.care_instructions
                    )
                }
                
            case .failure(let error):
                print("Analysis failed: \(error)")
                self.analysisError = error
            }
        }
    }
)
```

### Option 2: Full Migration

Create a new service that wraps AWS backend:

```swift
// Lumen/Services/BackendAnalysisService.swift

import Foundation
import UIKit

class BackendAnalysisService {
    static let shared = BackendAnalysisService()
    
    func analyzeSkin(
        image: UIImage,
        onInitialResult: @escaping (Result<InitialPrediction, Error>) -> Void,
        onEnhancedResult: @escaping (Result<ComprehensiveAnalysis, Error>) -> Void
    ) {
        AWSBackendService.shared.analyzeSkin(
            image: image,
            onProgress: { message in
                print("AWS: \(message)")
            },
            completion: { result in
                switch result {
                case .success(let analysis):
                    // Initial prediction
                    if let pred = analysis.prediction {
                        let initial = InitialPrediction(
                            condition: pred.condition,
                            confidence: pred.confidence,
                            allConditions: pred.all_conditions ?? [:]
                        )
                        onInitialResult(.success(initial))
                    }
                    
                    // Enhanced analysis
                    if let enhanced = analysis.enhanced_analysis {
                        let comprehensive = ComprehensiveAnalysis(
                            summary: enhanced.summary,
                            recommendations: enhanced.recommendations,
                            severity: enhanced.severity,
                            careInstructions: enhanced.care_instructions
                        )
                        onEnhancedResult(.success(comprehensive))
                    }
                    
                case .failure(let error):
                    onInitialResult(.failure(error))
                    onEnhancedResult(.failure(error))
                }
            }
        )
    }
}
```

Then just replace:
```swift
// Change from:
SkinAnalysisService.shared.analyzeSkin(...)

// To:
BackendAnalysisService.shared.analyzeSkin(...)
```

---

## 🤖 AWS Bedrock Agent Setup (Optional)

AWS Bedrock Agents provide managed agentic framework. Setup is manual via console.

### Step 1: Request Bedrock Access

1. Go to AWS Console → Bedrock
2. If you see "Request model access", click it
3. Select models:
   - ✅ Claude 3 Sonnet
   - ✅ Claude 3 Haiku (cheaper)
   - ✅ Amazon Titan Embeddings
4. Submit request (usually instant approval)

### Step 2: Create Bedrock Agent

**Via AWS Console**:

1. Bedrock → Agents → Create Agent
2. **Agent name**: `lumen-skin-analysis-agent`
3. **Foundation model**: Anthropic Claude 3 Sonnet
4. **Agent instruction**:
   ```
   You are a skincare analysis assistant. When given a skin condition,
   provide detailed analysis including:
   - Summary of the condition
   - Product recommendations
   - Severity assessment
   - Care instructions
   
   Use the available tools to search for products and gather information.
   Always tailor your advice to the specific condition detected.
   ```

5. **Action Groups** → Add Action Group:
   - Name: `ProductTools`
   - Lambda function: Select your Lambda function
   - API Schema: Upload `bedrock-agent-schema.json` (see below)

6. **Test Agent** → Type: "Recommend products for acne"
7. **Deploy** → Create Alias → Name: `prod`

### Step 3: Update Lambda with Agent ID

```bash
# Get agent ID from console (e.g., AGENT12345XYZ)
AGENT_ID="YOUR_AGENT_ID_HERE"

# Update Lambda environment variable
aws lambda update-function-configuration \
  --function-name lumen-skincare-dev-analyze-skin \
  --environment Variables="{
    BEDROCK_AGENT_ID=${AGENT_ID},
    ANALYSES_TABLE=lumen-skincare-dev-analyses,
    PRODUCTS_TABLE=lumen-skincare-dev-products,
    S3_BUCKET=lumen-skincare-dev-images,
    HUGGINGFACE_URL=https://Musubi23-skin-analyzer.hf.space/predict
  }"
```

### Bedrock Agent API Schema

Create `bedrock-agent-schema.json`:

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "Product Recommendation Tools",
    "version": "1.0.0"
  },
  "paths": {
    "/search-products": {
      "post": {
        "summary": "Search for skincare products",
        "operationId": "searchProducts",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "query": {
                    "type": "string",
                    "description": "Search query for products"
                  },
                  "condition": {
                    "type": "string",
                    "description": "Skin condition to filter by"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "List of matching products"
          }
        }
      }
    }
  }
}
```

---

## 🛍️ Product Management

Product recommendations are managed via JSON files and Python scripts. All products are stored in DynamoDB.

### View Current Products

```bash
# Export current products from DynamoDB
python3 scripts/export-products.py

# View the exported file
cat data/products-export.json
```

### Add/Edit Products

```bash
# 1. Edit the products JSON file
nano data/products.json

# 2. Upload changes to DynamoDB
python3 scripts/load-products.py
```

### Product JSON Structure

```json
{
  "product_id": "13",
  "name": "Product Name",
  "brand": "Brand Name",
  "description": "Product description",
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
    "Active Ingredient"
  ]
}
```

### Target Conditions Reference

Products are matched to skin conditions. Use these exact strings in `target_conditions`:
- Acne
- Oily Skin
- Large Pores
- Dark Circles
- Eye Bags
- Dark Spots
- Hyperpigmentation
- Wrinkles
- Fine Lines
- Dry Skin
- Sensitive Skin
- Healthy Skin
- Rosacea

### Common Product Operations

```bash
# Backup products before changes
python3 scripts/export-products.py --output "backup-$(date +%Y%m%d).json"

# Clear all products and reload
python3 scripts/load-products.py --clear

# Load from custom file
python3 scripts/load-products.py --file custom-products.json

# View product count by category
python3 scripts/export-products.py && \
  cat data/products-export.json | python3 -c "
import json, sys
products = json.load(sys.stdin)
categories = {}
for p in products:
    cat = p.get('category', 'Unknown')
    categories[cat] = categories.get(cat, 0) + 1
for cat, count in sorted(categories.items()):
    print(f'{cat}: {count}')
"
```

**Detailed Documentation**: See [PRODUCTS_MANAGEMENT.md](PRODUCTS_MANAGEMENT.md) for complete guide on managing products.

---

## 📊 Monitoring & Debugging

### View Logs

```bash
# Stream Lambda logs in real-time
aws logs tail /aws/lambda/lumen-skincare-dev-analyze-skin --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/lumen-skincare-dev-analyze-skin \
  --filter-pattern "ERROR"
```

### Check DynamoDB

```bash
# Scan analyses table
aws dynamodb scan \
  --table-name lumen-skincare-dev-analyses \
  --limit 5

# Get specific analysis
aws dynamodb get-item \
  --table-name lumen-skincare-dev-analyses \
  --key '{"analysis_id":{"S":"abc-123-def"},"user_id":{"S":"anonymous"}}'
```

### Test Lambda Directly

```bash
# Create test event
cat > test-event.json <<EOF
{
  "httpMethod": "POST",
  "path": "/upload-image",
  "headers": {
    "x-user-id": "test-user"
  }
}
EOF

# Invoke Lambda
aws lambda invoke \
  --function-name lumen-skincare-dev-analyze-skin \
  --payload file://test-event.json \
  response.json

cat response.json
```

---

## 💰 Cost Estimation

Based on 10,000 users, 1 analysis per month:

| Service | Usage | Cost/Month |
|---------|-------|------------|
| **S3** | 20 GB storage | $0.50 |
| **Lambda** | 10K invocations @ 5s | $1.50 |
| **API Gateway** | 60K requests | $0.25 |
| **DynamoDB** | 10K writes, 50K reads | $1.50 |
| **CloudWatch** | Logs & metrics | $5.00 |
| **Data Transfer** | Outbound | $10.00 |
| **Bedrock** (optional) | 10K agent calls | $90.00 |
| **Total without Bedrock** | | **~$19/month** |
| **Total with Bedrock** | | **~$109/month** |

**Per user**: $0.011/month ($0.13/year)

### Cost Optimization Tips

1. **Use Bedrock conditionally**: Only for complex cases
2. **Implement caching**: Store common recommendations
3. **Optimize Lambda**: Reduce memory, increase concurrency
4. **S3 lifecycle**: Delete old images automatically (already configured)
5. **Use DynamoDB on-demand**: Pay only for what you use (already configured)

---

## 🔧 Troubleshooting

### Issue: Terraform apply fails

**Error**: `Error creating S3 bucket: BucketAlreadyExists`

**Fix**:
```bash
# Change bucket name in main.tf
variable "project_name" {
  default = "lumen-skincare-yourname"  # Make it unique
}
```

### Issue: Lambda timeout

**Error**: `Task timed out after 60.00 seconds`

**Fix**:
```bash
# Increase timeout in lambda.tf
resource "aws_lambda_function" "analyze_skin" {
  timeout = 120  # Increase to 2 minutes
}

# Re-deploy
terraform apply
```

### Issue: Bedrock access denied

**Error**: `AccessDeniedException: User is not authorized to use Bedrock`

**Fix**:
1. AWS Console → Bedrock → Model access
2. Request access to models
3. Wait for approval (usually instant)

### Issue: CORS errors in iOS app

**Error**: `Cross-Origin Request Blocked`

**Fix**: Already configured in `api_gateway.tf`, but verify:
```bash
curl -X OPTIONS \
  -H "Origin: http://localhost" \
  "${API_URL}upload-image"

# Should return Access-Control-Allow-Origin header
```

---

## 🔐 Security Best Practices

### Production Checklist

- [ ] Enable AWS Cognito for authentication
- [ ] Restrict CORS to your app domain
- [ ] Enable API Gateway API keys
- [ ] Add rate limiting (already configured: 50 req/s)
- [ ] Enable CloudWatch alarms for errors
- [ ] Set up AWS WAF for API protection
- [ ] Rotate credentials regularly
- [ ] Enable MFA on AWS account
- [ ] Use AWS Secrets Manager for sensitive data

### Enable Cognito (Recommended)

```bash
# Create Cognito user pool
aws cognito-idp create-user-pool \
  --pool-name lumen-users \
  --auto-verified-attributes email

# Update API Gateway to require Cognito auth
# (Edit api_gateway.tf, change authorization = "COGNITO_USER_POOLS")
```

---

## 🚀 Next Steps

### Phase 1: Basic Deployment ✅
- [x] Deploy infrastructure
- [x] Test API endpoints
- [x] Integrate iOS app

### Phase 2: Bedrock Agent
- [ ] Request Bedrock access
- [ ] Create agent
- [ ] Update Lambda with agent ID
- [ ] Test enhanced analysis

### Phase 3: Production Hardening
- [ ] Enable Cognito authentication
- [ ] Add CloudWatch alarms
- [ ] Set up CI/CD pipeline
- [ ] Load test with 1,000+ requests
- [ ] Configure custom domain

### Phase 4: Optimization
- [ ] Add caching layer (ElastiCache)
- [ ] Implement image optimization
- [ ] Add analytics dashboard
- [ ] A/B test recommendations

---

## 📚 Additional Resources

- [AWS Bedrock Agents Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [API Gateway CORS Configuration](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html)

---

## 🆘 Support

**Issues?**
- Check `terraform/terraform.tfstate` for deployed resources
- View logs: `aws logs tail /aws/lambda/lumen-skincare-dev-analyze-skin --follow`
- Test locally: `python lambda/handler.py` (requires env vars)

**Questions?**
- AWS Documentation: https://docs.aws.amazon.com
- Terraform Docs: https://www.terraform.io/docs
- Create GitHub issue (if this is a repo)

---

## 🎯 Success Criteria

Your deployment is successful when:

✅ Terraform apply completes without errors
✅ API endpoints respond to curl tests
✅ Products are loaded in DynamoDB
✅ iOS app can upload images
✅ Lambda processes images successfully
✅ Results appear in DynamoDB

**Congratulations! Your production-grade AWS backend is live! 🎉**

