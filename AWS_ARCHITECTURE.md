# AWS Production Architecture

## Overview

This document outlines a production-grade AWS architecture for the Lumen AI Skincare Assistant, replacing client-side AI processing with a scalable backend.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          iOS App                                │
│  • Camera capture                                               │
│  • UI/UX                                                        │
│  • Local data caching                                           │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ HTTPS Upload (presigned URL)
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Amazon S3                                  │
│  • Stores uploaded images                                       │
│  • Lifecycle policies (auto-delete after 30 days)              │
│  • Encryption at rest                                           │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ S3 Event Notification
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Lambda (Orchestrator)                    │
│                                                                 │
│  Function: analyze-skin-image                                  │
│  • Validates image                                              │
│  • Calls Hugging Face API (Stage 1)                            │
│  • Invokes Bedrock Agent (Stage 2)                             │
│  • Stores results in DynamoDB                                   │
│  • Sends notification to app                                    │
└────────────┬────────────────────────────────────────────────────┘
             │
             ├─────────────┬──────────────┬────────────────┐
             ▼             ▼              ▼                ▼
    ┌──────────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────────┐
    │ Hugging Face │ │  Bedrock │ │  OpenSearch  │ │  DynamoDB    │
    │     API      │ │   Agent  │ │  Serverless  │ │              │
    └──────────────┘ └──────────┘ └──────────────┘ └──────────────┘
         Stage 1         Stage 2      Vector DB      Results Store
         Fast            Enhanced     Product        Analysis
         Prediction      Analysis     Search         History
                                                              │
                                                              │
                                                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    API Gateway (REST API)                       │
│  Endpoints:                                                     │
│  • POST /upload-image                                           │
│  • GET  /analysis/{id}                                          │
│  • GET  /products/recommendations?condition=acne                │
│  • GET  /history                                                │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ HTTPS Response
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                          iOS App                                │
│  • Displays results                                             │
│  • Shows product recommendations                                │
│  • Caches for offline viewing                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## AWS Services Used

### 1. **Amazon S3** - Image Storage
**Purpose**: Store uploaded skin images securely

**Configuration**:
```yaml
Bucket: lumen-skin-images-prod
Region: us-west-2
Encryption: AES-256 (server-side)
Lifecycle: Delete after 30 days
Versioning: Disabled (save costs)
Public Access: Blocked
CORS: Enabled for iOS app
```

**Why S3**:
- ✅ Highly durable (99.999999999%)
- ✅ Scalable (unlimited storage)
- ✅ Cost-effective ($0.023 per GB/month)
- ✅ Integrated with other AWS services

**Cost Estimate**:
- 1,000 users × 10 photos/month = 10,000 photos
- ~2 MB per photo = 20 GB
- Cost: ~$0.50/month

---

### 2. **AWS Lambda** - Serverless Compute
**Purpose**: Process images and orchestrate AI pipeline

**Functions**:

#### Function 1: `analyze-skin-image`
```python
# Runtime: Python 3.11
# Memory: 1024 MB
# Timeout: 60 seconds
# Trigger: S3 upload event

def lambda_handler(event, context):
    # 1. Get image from S3
    image_key = event['Records'][0]['s3']['object']['key']
    image = s3.get_object(Bucket='lumen-skin-images', Key=image_key)
    
    # 2. Stage 1: Call Hugging Face
    prediction = call_huggingface(image)
    
    # 3. Stage 2: Call Bedrock Agent
    enhanced = invoke_bedrock_agent(prediction)
    
    # 4. Stage 3: Get product recommendations
    products = search_products(prediction['condition'])
    
    # 5. Store results in DynamoDB
    analysis_id = store_results(prediction, enhanced, products)
    
    # 6. Return analysis ID
    return {
        'statusCode': 200,
        'body': json.dumps({'analysis_id': analysis_id})
    }
```

**Why Lambda**:
- ✅ No servers to manage
- ✅ Auto-scaling
- ✅ Pay only for compute time
- ✅ Integrates with all AWS services

**Cost Estimate**:
- 10,000 invocations/month
- 5 seconds average duration
- 1024 MB memory
- Cost: ~$1.50/month

---

### 3. **Amazon Bedrock** - Managed AI Service
**Purpose**: Replace direct Gemini API calls with AWS-managed AI

**Features**:
- ✅ **Agents**: Built-in agentic framework (like LangChain!)
- ✅ **Tool Calling**: Native function calling support
- ✅ **RAG**: Integrated with Knowledge Bases
- ✅ **Multiple Models**: Claude, Llama, Titan, etc.
- ✅ **No API Key Management**: AWS handles authentication

**Agent Configuration**:
```yaml
Agent: LumenSkinAnalysisAgent
Foundation Model: Anthropic Claude 3 Sonnet
Temperature: 0.7
Tools:
  - search_products
  - get_products_by_condition
  - analyze_skin_condition
Knowledge Base: Products Vector DB (OpenSearch)
```

**Example Usage**:
```python
import boto3

bedrock_agent = boto3.client('bedrock-agent-runtime')

response = bedrock_agent.invoke_agent(
    agentId='AGENT_ID',
    agentAliasId='ALIAS_ID',
    sessionId='session-123',
    inputText=f"Analyze skin condition: {condition}. Recommend products."
)

# Bedrock handles:
# - Tool selection
# - Function calling
# - RAG queries
# - Response generation
```

**Why Bedrock**:
- ✅ **No Framework Needed**: Built-in agents (better than LangChain!)
- ✅ **Managed Service**: AWS handles infrastructure
- ✅ **Multiple Models**: Switch models easily
- ✅ **Security**: No API keys in code
- ✅ **Compliance**: Enterprise-grade

**Cost Estimate**:
- Claude 3 Sonnet: $0.003 per 1K input tokens, $0.015 per 1K output tokens
- Average: 500 input + 500 output tokens per request
- 10,000 requests/month
- Cost: ~$90/month

---

### 4. **Amazon OpenSearch Serverless** - Vector Database
**Purpose**: Production RAG with real vector embeddings

**Replaces**: Our mock `ProductVectorDatabase.swift`

**Configuration**:
```yaml
Collection: lumen-products
Engine: k-NN (k-nearest neighbors)
Dimensions: 1536 (OpenAI ada-002 embeddings)
Index Mapping:
  - product_id (keyword)
  - name (text)
  - embedding (knn_vector)
  - conditions (keyword array)
  - rating (float)
  - price (float)
```

**Why OpenSearch**:
- ✅ **Real Vector Search**: Production-grade, not mock
- ✅ **Serverless**: No cluster management
- ✅ **Scalable**: Millions of vectors
- ✅ **Fast**: <100ms queries
- ✅ **Integrated**: Native AWS service

**Cost Estimate**:
- Serverless: $0.24 per OCU-hour
- Small collection: ~2 OCUs
- Cost: ~$35/month

---

### 5. **Amazon DynamoDB** - NoSQL Database
**Purpose**: Store analysis results and user history

**Tables**:

#### Table 1: `SkinAnalyses`
```json
{
  "analysis_id": "uuid",
  "user_id": "user-123",
  "image_s3_key": "images/user-123/photo.jpg",
  "timestamp": "2024-01-15T10:30:00Z",
  "prediction": {
    "condition": "Acne",
    "confidence": 0.85,
    "all_conditions": {"Acne": 0.85, "Oily": 0.12}
  },
  "enhanced_analysis": {
    "summary": "...",
    "recommendations": [...],
    "severity": "moderate"
  },
  "products": [
    {"id": "1", "name": "CeraVe Cleanser", ...}
  ],
  "ttl": 2592000  // 30 days
}
```

#### Table 2: `Products`
```json
{
  "product_id": "1",
  "name": "CeraVe Acne Foaming Cream Cleanser",
  "brand": "CeraVe",
  "conditions": ["Acne", "Oily Skin"],
  "rating": 4.5,
  "price_range": "$8-12",
  "amazon_url": "https://..."
}
```

**Why DynamoDB**:
- ✅ **Serverless**: No provisioning
- ✅ **Fast**: Single-digit millisecond latency
- ✅ **Scalable**: Auto-scales
- ✅ **Cost-effective**: Pay per request

**Cost Estimate**:
- On-demand pricing
- 10,000 writes/month
- 50,000 reads/month
- Cost: ~$1.50/month

---

### 6. **Amazon API Gateway** - REST API
**Purpose**: Provide HTTP endpoints for iOS app

**Endpoints**:

#### POST `/upload-image`
```http
POST /upload-image
Authorization: Bearer {token}
Content-Type: multipart/form-data

Body: {image file}

Response:
{
  "upload_url": "https://s3.amazonaws.com/presigned-url",
  "analysis_id": "uuid"
}
```

#### GET `/analysis/{id}`
```http
GET /analysis/abc-123-def
Authorization: Bearer {token}

Response:
{
  "analysis_id": "abc-123-def",
  "status": "completed",
  "prediction": {...},
  "enhanced_analysis": {...},
  "products": [...]
}
```

#### GET `/products/recommendations`
```http
GET /products/recommendations?condition=Acne&limit=5
Authorization: Bearer {token}

Response:
{
  "products": [...],
  "explanation": "Based on your condition..."
}
```

**Why API Gateway**:
- ✅ **RESTful**: Standard HTTP
- ✅ **Authentication**: Built-in Cognito integration
- ✅ **Throttling**: Rate limiting
- ✅ **Monitoring**: CloudWatch logs

**Cost Estimate**:
- $3.50 per million requests
- 60,000 requests/month (10K users × 6 API calls)
- Cost: ~$0.25/month

---

### 7. **Amazon Cognito** - User Authentication
**Purpose**: Secure user management and API authentication

**Features**:
- User sign-up/sign-in
- JWT tokens for API auth
- Social login (Apple, Google)
- MFA support
- Password policies

**Cost**: Free tier covers most use cases

---

## Complete Flow

### User Takes Photo

1. **iOS App**:
   ```swift
   // 1. Request upload URL
   let response = await apiClient.post("/upload-image")
   
   // 2. Upload to S3 using presigned URL
   await S3.upload(image, to: response.upload_url)
   
   // 3. Poll for results
   var analysis: Analysis?
   repeat {
       analysis = await apiClient.get("/analysis/\(response.analysis_id)")
       await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
   } while analysis.status != "completed"
   
   // 4. Display results
   displayResults(analysis)
   ```

2. **S3** receives image, triggers Lambda

3. **Lambda** processes:
   ```python
   def lambda_handler(event, context):
       # Stage 1: Hugging Face (2-3s)
       prediction = huggingface_client.predict(image)
       
       # Stage 2: Bedrock Agent (3-5s)
       enhanced = bedrock_agent.invoke_agent(
           inputText=f"Analyze: {prediction['condition']}"
       )
       
       # Stage 3: OpenSearch vector search (0.1s)
       products = opensearch.search(
           index='products',
           body={
               "query": {
                   "knn": {
                       "embedding": {
                           "vector": get_embedding(prediction['condition']),
                           "k": 5
                       }
                   }
               }
           }
       )
       
       # Store in DynamoDB
       dynamodb.put_item(
           TableName='SkinAnalyses',
           Item={
               'analysis_id': analysis_id,
               'prediction': prediction,
               'enhanced': enhanced,
               'products': products,
               'status': 'completed'
           }
       )
       
       return analysis_id
   ```

4. **iOS App** retrieves and displays results

---

## AWS Bedrock Agents - The Game Changer

### Why Bedrock is Perfect for This

**Built-in Agentic Framework**:
```python
# No LangChain needed!
# AWS Bedrock has built-in agents

agent = bedrock.create_agent(
    agentName='LumenSkinAgent',
    foundationModel='anthropic.claude-3-sonnet',
    instruction='''
        You are a skincare analysis assistant.
        Use tools to search products and provide recommendations.
        Always tailor advice to the specific skin condition.
    ''',
    actionGroups=[
        {
            'actionGroupName': 'ProductTools',
            'actionGroupExecutor': {
                'lambda': 'arn:aws:lambda:us-west-2:123456789012:function:product-tools'
            },
            'apiSchema': {
                'payload': json.dumps({
                    'openapi': '3.0.0',
                    'paths': {
                        '/search-products': {...},
                        '/get-by-condition': {...}
                    }
                })
            }
        }
    ],
    knowledgeBases=[
        {
            'knowledgeBaseId': 'KNOWLEDGE_BASE_ID',
            'description': 'Product database with embeddings'
        }
    ]
)
```

**What Bedrock Provides**:
- ✅ **Agent Orchestration**: Like LangChain but managed
- ✅ **Tool Calling**: Native function calling
- ✅ **RAG**: Knowledge Bases (automatic chunking, embeddings)
- ✅ **Memory**: Conversation history
- ✅ **Guardrails**: Content filtering
- ✅ **Monitoring**: CloudWatch integration

**No More Manual Implementation!**

Compare our manual Swift code vs Bedrock:

**Manual (300 lines)**:
```swift
class ProductRecommendationAgent {
    func getToolDeclarations() {...}
    func buildToolCallingRequest() {...}
    func parseAndExecuteTools() {...}
    func executeTool() {...}
}
```

**Bedrock (10 lines)**:
```python
response = bedrock_agent.invoke_agent(
    agentId='AGENT_ID',
    inputText=f"Recommend products for {condition}"
)
# Done! Bedrock handles everything
```

---

## Cost Breakdown

### Monthly Costs (Estimated for 10,000 Users)

| Service | Usage | Cost/Month |
|---------|-------|------------|
| **S3** | 20 GB storage | $0.50 |
| **Lambda** | 10K invocations @ 5s | $1.50 |
| **Bedrock** | 10K agent calls | $90.00 |
| **OpenSearch** | Serverless 2 OCUs | $35.00 |
| **DynamoDB** | 10K writes, 50K reads | $1.50 |
| **API Gateway** | 60K requests | $0.25 |
| **Cognito** | Free tier | $0.00 |
| **CloudWatch** | Logs & metrics | $5.00 |
| **Data Transfer** | Outbound data | $10.00 |
| **Total** | | **~$143.50/month** |

**Per User**: $0.014/month ($0.17/year)

**With AWS Free Tier** (first year):
- Lambda: 1M free requests/month
- DynamoDB: 25 GB storage free
- S3: 5 GB storage free
- **First year cost**: ~$90/month (mostly Bedrock)

---

## Implementation Steps

### Phase 1: Setup AWS Infrastructure (1-2 days)

1. **Create S3 Bucket**:
   ```bash
   aws s3 mb s3://lumen-skin-images-prod
   aws s3api put-bucket-encryption \
       --bucket lumen-skin-images-prod \
       --server-side-encryption-configuration '{...}'
   ```

2. **Deploy Lambda Function**:
   ```bash
   # Package dependencies
   pip install -r requirements.txt -t package/
   cd package && zip -r ../lambda.zip .
   cd .. && zip -g lambda.zip lambda_function.py
   
   # Deploy
   aws lambda create-function \
       --function-name analyze-skin-image \
       --runtime python3.11 \
       --handler lambda_function.lambda_handler \
       --zip-file fileb://lambda.zip
   ```

3. **Create Bedrock Agent**:
   ```bash
   # Via AWS Console or Infrastructure as Code (Terraform/CloudFormation)
   ```

4. **Setup OpenSearch**:
   ```bash
   aws opensearchserverless create-collection \
       --name lumen-products \
       --type VECTORSEARCH
   ```

5. **Create DynamoDB Tables**:
   ```bash
   aws dynamodb create-table \
       --table-name SkinAnalyses \
       --attribute-definitions ... \
       --key-schema ...
   ```

6. **Deploy API Gateway**:
   ```bash
   # Via AWS Console or API Gateway CLI
   ```

### Phase 2: Update iOS App (1 day)

Replace direct API calls with AWS endpoints:

```swift
// Old (Direct):
let prediction = try await HuggingFaceAPI.predict(image)
let analysis = try await GeminiAPI.enhance(prediction)

// New (AWS):
let uploadURL = try await AWSAPI.getUploadURL()
try await S3.upload(image, to: uploadURL)
let analysis = try await AWSAPI.pollForResults(analysisId)
```

### Phase 3: Migrate Data (1 day)

- Load products into DynamoDB
- Generate embeddings and index in OpenSearch
- Test end-to-end flow

### Phase 4: Monitor & Optimize (Ongoing)

- CloudWatch dashboards
- Error tracking
- Cost optimization
- Performance tuning

---

## Security Best Practices

### 1. **API Authentication**
- Use AWS Cognito JWT tokens
- Rotate credentials regularly
- Implement API throttling

### 2. **Data Encryption**
- S3: Server-side encryption (SSE-S3)
- DynamoDB: Encryption at rest
- In-transit: HTTPS only

### 3. **IAM Policies**
- Least privilege access
- Service-specific roles
- No hardcoded credentials

### 4. **Network Security**
- VPC for Lambda (optional)
- Private subnets for databases
- Security groups

---

## Monitoring & Analytics

### CloudWatch Dashboards

**Metrics to Track**:
- API latency (p50, p95, p99)
- Lambda invocations & errors
- Bedrock agent performance
- S3 upload success rate
- DynamoDB read/write capacity
- Cost per analysis

### Alerts
- Lambda errors > 1%
- API latency > 5s
- Bedrock failures
- Unusual cost spikes

---

## Advantages Summary

### vs Current Client-Side Approach

| Aspect | Client-Side | AWS Backend |
|--------|-------------|-------------|
| **Security** | ⚠️ API keys exposed | ✅ Keys on backend |
| **Scalability** | ❌ Limited | ✅ Unlimited |
| **Cost Control** | ❌ Hard to track | ✅ Pay-per-use |
| **Updates** | ❌ Requires app update | ✅ Update anytime |
| **Analytics** | ❌ None | ✅ Full visibility |
| **Reliability** | ⚠️ Depends on device | ✅ 99.99% SLA |
| **Agentic Framework** | ❌ Manual | ✅ Bedrock Agents |
| **Vector DB** | ❌ Mock | ✅ OpenSearch |
| **Professional** | ⚠️ Demo-grade | ✅ Production-grade |

---

## Conclusion

**AWS architecture is the right choice for production**:

✅ **Security**: No API keys in app
✅ **Scalability**: Handle millions of users
✅ **Agentic Framework**: Bedrock Agents (better than manual!)
✅ **Real Vector DB**: OpenSearch with actual embeddings
✅ **Professional**: Enterprise-grade infrastructure
✅ **Cost-Effective**: ~$0.014 per user per month
✅ **Updateable**: Change AI logic without app updates

**For your academic project**:
- Current implementation shows understanding of fundamentals
- AWS architecture shows production thinking
- Both demonstrate comprehensive knowledge

**Recommendation**: 
- Keep current implementation for demo/portfolio
- Document AWS architecture as "production plan"
- Implement AWS if deploying to real users

---

## Next Steps

1. **Learn AWS**: Take AWS Solutions Architect course
2. **Try Bedrock**: Free tier for experimentation
3. **Prototype**: Build MVP with Lambda + Bedrock
4. **Compare**: Client-side vs Backend approach
5. **Document**: Add to your project portfolio

This architecture will impress interviewers and demonstrate production-ready thinking!

