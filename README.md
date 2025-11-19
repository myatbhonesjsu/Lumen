# Lumen - AI Skincare Assistant

[![iOS](https://img.shields.io/badge/iOS-18.6+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20API%20Gateway-orange.svg)](https://aws.amazon.com/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o-green.svg)](https://openai.com/)

**Version**: 2.0.0
**Platform**: iOS 18.6+ | Swift 5.0 | SwiftUI 3.0

## Overview

Lumen is an AI-powered skincare assistant iOS application that analyzes skin conditions through photos, tracks progress over time, and provides personalized skincare insights and recommendations. The application uses OpenAI GPT-4o for intelligent conversational agents and machine learning for skin condition detection.

## Core Features

### Skin Analysis
- Photo capture with guided camera interface
- Machine learning-based skin condition detection
- Comprehensive metrics tracking: acne, dryness, moisture, pigmentation, dark circles, wrinkles
- Skin age estimation and overall health scoring
- Historical analysis with folder organization

### AI-Powered Features
1. **Skin Analysis** - ML-based condition detection with dual-model validation
2. **Learning Hub Chatbot** - RAG-enhanced conversational AI with Bedrock Claude 3.5
3. **Daily Insights** - Multi-agent orchestrator for personalized tips (weather, location, skin condition)
4. **Personalized Routines** - AI-generated morning/evening skincare routines
5. **Agent Chat** - GPT-4o powered Skin Analyst and Routine Coach
6. **Knowledge Base** - Pinecone RAG for evidence-based recommendations

### Data Management
- Local-first storage using SwiftData
- Organized analysis history with folder support
- Persistent agent conversation responses
- Progress tracking over time

## Technology Stack

### iOS Application
- Swift 5.0 with SwiftUI 3.0
- SwiftData for local persistence
- AVFoundation for camera interface
- Minimum iOS 18.6+

### AWS Backend
- **Compute**: AWS Lambda (Python 3.11) - 5 serverless functions
- **API**: 2 API Gateway instances with Cognito authentication
- **Authentication**: AWS Cognito User Pools
- **AI Services**:
  - Hugging Face inference endpoint (skin analysis)
  - AWS Bedrock Claude 3.5 Sonnet v2 (Learning Hub chatbot, daily insights)
  - OpenAI GPT-4o (agent chat, insights generation)
- **RAG**: Pinecone vector database + Bedrock Titan embeddings
- **Storage**: Amazon S3 (images), DynamoDB (9 tables for analytics, chat, insights)
- **Infrastructure**: Terraform-managed
- **Region**: us-east-1

## Project Structure

```
Lumen/
├── Lumen/                          # iOS Application
│   ├── Models/                     # Data models (SwiftData)
│   │   ├── SkinMetric.swift
│   │   ├── ChatMessage.swift
│   │   └── DailyInsight.swift
│   ├── Views/                      # SwiftUI views
│   │   ├── Home/
│   │   │   ├── ImprovedHomeView.swift
│   │   │   └── AgenticInsightsCard.swift
│   │   ├── Analysis/
│   │   │   └── ModernAnalysisDetailView.swift
│   │   ├── History/
│   │   │   └── HistoryView.swift
│   │   └── Learning/
│   │       └── EnhancedLearningHubView.swift
│   ├── Services/                   # API clients & business logic
│   │   ├── CognitoAuthService.swift
│   │   ├── AWSBackendService.swift
│   │   ├── SkinAnalysisService.swift
│   │   └── AgentChatService.swift
│   ├── Helpers/                    # Utilities
│   │   ├── HapticManager.swift
│   │   └── ProgressTrackingService.swift
│   └── LumenApp.swift
├── aws-backend/                    # Backend Infrastructure
│   ├── lambda/                     # Lambda functions (5 total)
│   │   ├── handler.py                              # Skin analysis pipeline
│   │   ├── learning_hub_handler.py                 # Chatbot & Learning Hub
│   │   ├── daily_insights_orchestrator.py          # Multi-agent insights
│   │   ├── personalized_insights_generator.py      # Agent chat (GPT-4o)
│   │   ├── rag_query_handler.py                    # Pinecone RAG queries
│   │   └── pinecone_http_client.py
│   ├── terraform/                  # Infrastructure as Code
│   │   ├── main.tf
│   │   ├── cognito.tf
│   │   ├── lambda.tf
│   │   ├── lambda_additional.tf    # Learning Hub & Daily Insights Lambdas
│   │   ├── api_gateway.tf
│   │   ├── dynamodb.tf
│   │   └── pinecone.tf             # 9 DynamoDB tables
│   └── scripts/                    # Deployment & utilities
│       ├── build-lambda.sh
│       └── populate-*.py           # Data seeding scrips
```

## Getting Started

### Prerequisites
- Xcode 16.0+ and macOS Sonoma or later
- iOS 18.6+ device or simulator
- AWS CLI configured (for backend deployment only)
- Terraform 1.0+ (for infrastructure deployment only)
- OpenAI API key (for AI agents)

### iOS App Installation

1. Clone and open the project:
```bash
git clone <repository-url>
cd Lumen
open Lumen.xcodeproj
```

2. Build and run (Cmd+R)
   - The app automatically authenticates with a demo account
   - Grant camera and photo library permissions when prompted
   - No account creation or login required for demo use

### AWS Backend Deployment

Required for production use. The backend is already deployed and configured for demo purposes.

To deploy your own backend:

```bash
cd aws-backend/terraform
terraform init
terraform apply -auto-approve
```

This creates:
- **Cognito User Pool** for authentication
- **S3 bucket** for image storage (with 90-day lifecycle)
- **5 Lambda functions** for skin analysis, chatbot, insights, and agents
- **2 API Gateway instances** with Cognito authorizer
- **9 DynamoDB tables** (analyses, products, chat-history, educational-content, daily-insights, checkin-responses, product-applications, and more)
- **IAM roles** with Bedrock and DynamoDB permissions
- **CloudWatch logs** with 14-day retention
- **Secrets Manager** for Pinecone and OpenAI API keys

Deployment time: 5-7 minutes


### OpenAI Configuration

Store your OpenAI API key in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name lumen-skincare-openai-api-key \
  --secret-string "your-openai-api-key" \
  --region us-east-1
```

The Lambda function will automatically retrieve the key for API calls.

### Hugging Face Configuration

Provision a Hugging Face Inference Endpoint (or compatible hosted model) for the skin-condition classifier and set the endpoint URL as the `HUGGINGFACE_URL` environment variable in the Lambda configuration. The backend will upload raw image bytes to that endpoint as stage one of the analysis pipeline before enriching the results with AWS Bedrock/OpenAI agents.

### Authentication

The app uses AWS Cognito for API authentication with automatic demo user login:

- **Demo Credentials**: Hardcoded in `CognitoAuthService.swift` for now
- **User Pool ID**: us-east-1_NBBGEaCAW
- **App Client ID**: 6kf024iqqn4hqopqn72hsvlmr7
- **Token Expiry**: 1 hour with automatic refresh

All users share the same demo account for evaluation purposes. Each API request includes a JWT token in the Authorization header.

### API Endpoints

All endpoints require Cognito authentication (except Learning Hub chat).

#### Skin Analysis
```
POST /dev/upload-image                    # Request presigned upload URL
GET  /dev/analysis/{id}                   # Poll for analysis results
GET  /dev/products/recommendations        # Get product recommendations
```

#### Learning Hub (Bedrock Claude 3.5 + RAG)
```
POST /dev/learning-hub/chat               # Send chat message
GET  /dev/learning-hub/chat-history       # Get conversation history
GET  /dev/learning-hub/recommendations    # Personalized articles
GET  /dev/learning-hub/articles           # Browse educational content
GET  /dev/learning-hub/suggestions        # Autocomplete suggestions
POST /dev/learning-hub/routines/generate  # Generate skincare routine
```

#### Daily Insights (Multi-Agent)
```
POST /dev/daily-insights/generate         # Generate daily insight
GET  /dev/daily-insights/latest           # Get today's insight
POST /dev/daily-insights/checkin          # Submit check-in response
POST /dev/daily-insights/products/apply   # Track product usage
```

#### Agent Chat (GPT-4o)
```
POST /dev/agent-chat/skin-analyst         # Skin analysis conversation
POST /dev/agent-chat/routine-coach        # Routine coaching
```

**Total: 16 API endpoints** - See `docs/BACKEND_INFRASTRUCTURE.md` for complete API reference with request/response examples.

## Architecture

### Data Flow

1. **Skin Analysis**:
   - User captures photo via camera interface
   - App authenticates and requests presigned S3 URL
   - Image uploaded directly to S3
   - Lambda processes image with ML models
   - Results stored in DynamoDB and returned to app
   - App persists locally to SwiftData

2. **AI Agent Conversation**:
   - User views analysis in Insights tab
   - App requests AI insights from agents
   - Lambda retrieves user's analysis from DynamoDB
   - OpenAI GPT-4o generates personalized response
   - Agent can call RAG tools to query Pinecone knowledge base
   - Response displayed in app with clean formatting

3. **Authentication Flow**:
   - App launches and auto-authenticates with Cognito
   - Receives JWT tokens (ID token, access token, refresh token)
   - Tokens included in all API requests
   - API Gateway validates tokens before invoking Lambda
   - User ID extracted from JWT claims for data isolation

### AI Agent System

**Skin Analyst**:
- Analyzes skin conditions from photo analysis
- Provides evidence-based ingredient recommendations
- Queries knowledge base for scientific research
- Returns concise, mobile-friendly responses (1-2 paragraphs)

**Routine Coach**:
- Motivates consistent skincare habits
- Provides practical tips and encouragement
- References user's progress trends
- Returns warm, supportive guidance (1-2 paragraphs)

**RAG Integration**:
- Pinecone vector database for knowledge base
- Tools: `search_similar_cases`, `get_ingredient_research`
- OpenAI function calling for tool invocation
- Evidence-based responses grounded in research

**Agentic Flow**:
- Implemented natively in `aws-backend/lambda/personalized_insights_generator.py`
- Uses GPT-4o tool-calling loop to decide when to query RAG tools
- No LangChain or external orchestration framework required

### Security

- **Authentication**: AWS Cognito with JWT tokens
- **Authorization**: API Gateway Cognito authorizer on all endpoints
- **Data Isolation**: User-specific S3 paths and DynamoDB keys
- **Encryption**: DynamoDB at rest, HTTPS in transit
- **Storage**: Private S3 bucket, iOS-encrypted local data
- **API Keys**: OpenAI key stored in AWS Secrets Manager

## Data Models

### SkinMetric (SwiftData)
Analysis results stored locally:
- Skin age estimation and overall health score
- Acne, dryness, moisture, pigmentation, dark circle, wrinkle levels
- Original photo and analysis notes
- Folder organization for history management

### ChatMessage (SwiftData)
Agent conversation history:
- User queries and agent responses
- Timestamps and agent type
- Persistent across app sessions

### DailyInsight (SwiftData)
Daily AI-generated insights:
- Personalized tips based on recent scans
- Check-in questions and motivational content
- Trend analysis and progress tracking

## Development

### Building and Testing
```bash
# Build
xcodebuild build -project Lumen.xcodeproj -scheme Lumen

# Run tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### UI Tests
Lumen includes a comprehensive XCUITest suite that automatically validates all major user flows across the app.
- Onboarding Flow
- Home Screen Navigation
- Camera Flow
- History Tab
- Learn Tab (Chat / For You / Articles)

```bash
# Run UI Tests
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme Lumen \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:LumenUITests
```

### Backend Updates
```bash
cd aws-backend
./scripts/build-lambda.sh
aws lambda update-function-code \
  --function-name lumen-skincare-dev-personalized-insights-generator \
  --zip-file fileb://lambda/lambda_deployment.zip \
  --region us-east-1
```

### Testing AI Agents
```bash
cd aws-backend
python3 -c "
import boto3, json
lambda_client = boto3.client('lambda', region_name='us-east-1')
event = {
    'httpMethod': 'POST',
    'path': '/agent-chat/skin-analyst',
    'body': json.dumps({'message': 'Test query'}),
    'requestContext': {'authorizer': {'claims': {'sub': 'test-user'}}}
}
response = lambda_client.invoke(
    FunctionName='lumen-skincare-dev-personalized-insights-generator',
    InvocationType='RequestResponse',
    Payload=json.dumps(event)
)
print(json.loads(response['Payload'].read()))
"
```

## Privacy and Data

- Local-first architecture with SwiftData
- Photos uploaded only for analysis, not stored permanently
- User data isolated by Cognito user ID
- No personal information collected
- No third-party analytics or tracking
- Full data deletion available in Settings
- OpenAI API calls do not train models (zero data retention)

## Recent Updates

**Version 2.0.0** - Hybrid AI Architecture:
- **Learning Hub**: AWS Bedrock Claude 3.5 Sonnet v2 with RAG
- **Agent Chat**: OpenAI GPT-4o for conversational agents
- **Daily Insights**: Multi-agent orchestration with weather & location context
- **Infrastructure**: 9 DynamoDB tables for comprehensive data tracking
- **Documentation**: Complete API reference in `docs/` folder

**Migration from Bedrock Agents to Hybrid Model**:
- Learning Hub chatbot uses Bedrock Claude 3.5 (cost-effective, RAG-enhanced)
- Agent Chat uses GPT-4o (500 RPM rate limit, superior for insights)
- Smart fallbacks: Chatbot works offline with condition-based responses
- Same Pinecone knowledge base across all AI features

## Future Enhancements
- Implement user accounts and authentication for personalized experiences
- Add user feedback collection (thumbs up/down on recommendations)
- Enhanced analytics dashboard with user engagement metrics
- Multi-language support for global accessibility
- Integration with wearables for holistic skin health tracking

## Authors

Team Derma (Team 9)
CMPE 272 - Enterprise Software Platforms
San Jose State University, Fall 2025

## Support

- **Backend Issues**: Check `docs/BACKEND_INFRASTRUCTURE.md#troubleshooting`
- **AWS Logs**: AWS CloudWatch logs for each Lambda function
- **OpenAI Usage**: https://platform.openai.com/usage
- **Bedrock Usage**: AWS Console → Bedrock → Model invocations
- **Issues**: Create an issue in the repository

## Acknowledgments

- **AWS Bedrock** - Claude 3.5 Sonnet v2 for Learning Hub chatbot
- **OpenAI** - GPT-4o for conversational AI agents
- **AWS Services** - Lambda, Cognito, S3, DynamoDB, API Gateway, Bedrock
- **Pinecone** - Vector database for RAG knowledge base
- **Hugging Face** - Skin condition ML model
- **Apple** - SwiftUI, SwiftData, SF Symbols
- **Terraform** - Infrastructure as Code

---

**Disclaimer**: This application is for educational and informational purposes. For medical advice about skin conditions, consult a licensed dermatologist.
