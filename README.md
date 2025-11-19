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

### AI-Powered Agents
1. **Skin Analyst** - Personalized skincare recommendations based on analysis results
2. **Routine Coach** - Motivational guidance for maintaining consistent skincare habits
3. **RAG Integration** - Knowledge base queries for evidence-based ingredient research

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
- **Compute**: AWS Lambda (Python 3.11)
- **API**: API Gateway with Cognito authentication
- **Authentication**: AWS Cognito User Pools
- **AI Services**: Hugging Face inference endpoint (skin analysis), OpenAI GPT-4o (agents)
- **Orchestration**: Native OpenAI tool-calling loop (agentic flow, no agentic framework)
- **Vector Database**: Pinecone (knowledge base)
- **Storage**: Amazon S3 (images), DynamoDB (analysis results)
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
│   ├── lambda/                     # Lambda functions
│   │   ├── handler.py
│   │   ├── personalized_insights_generator.py
│   │   ├── rag_query_handler.py
│   │   └── pinecone_http_client.py
│   ├── terraform/                  # Infrastructure as Code
│   │   ├── main.tf
│   │   ├── cognito.tf
│   │   ├── lambda.tf
│   │   └── api_gateway.tf
│   └── scripts/                    # Deployment scripts
│       └── build-lambda.sh
└── docs/                           # Documentation
    └── CLAUDE.md
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
- Cognito User Pool for authentication
- S3 bucket for image storage
- Lambda functions for skin analysis and AI agents
- API Gateway with Cognito authorizer
- DynamoDB tables for data persistence
- IAM roles and CloudWatch logs
- OpenAI API key stored in Secrets Manager

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

- **Demo Credentials**: Hardcoded in `CognitoAuthService.swift`
- **User Pool ID**: us-east-1_NBBGEaCAW
- **App Client ID**: 6kf024iqqn4hqopqn72hsvlmr7
- **Token Expiry**: 1 hour with automatic refresh

All users share the same demo account for evaluation purposes. Each API request includes a JWT token in the Authorization header.

### API Endpoints

All endpoints require Cognito authentication:

**Upload Image**:
```
POST /dev/upload-image
Authorization: <cognito-id-token>
Returns: { "analysis_id": "...", "upload_url": "..." }
```

**Get Analysis Results**:
```
GET /dev/analysis/{analysis_id}
Authorization: <cognito-id-token>
Returns: Analysis results with metrics and recommendations
```

**Skin Analyst Agent**:
```
POST /dev/agent-chat/skin-analyst
Authorization: <cognito-id-token>
Body: { "analysisId": "...", "message": "..." }
Returns: { "success": true, "data": { "response": "...", "model": "gpt-4o" } }
```

**Routine Coach Agent**:
```
POST /dev/agent-chat/routine-coach
Authorization: <cognito-id-token>
Body: { "analysisId": "...", "message": "..." }
Returns: { "success": true, "data": { "response": "...", "model": "gpt-4o" } }
```

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

## Migration Notes

Version 2.0.0 migrates from AWS Bedrock Agents to OpenAI GPT-4o:
- 500x rate limit improvement (1 RPM to 500 RPM)
- Direct HTTP API integration (no SDK dependencies)
- Same RAG/Pinecone knowledge base preserved
- No iOS app code changes required

## Future enhancement 
- Implement user login functionality to provide a personalized experience.
- Collect and incorporate user feedback to continuously improve app features and usability.
- Enhance observability for developers by integrating CloudWatch metrics, enabling monitoring of app performance and usage patterns. This includes tracking analysis metrics, user feedback, and visualizing thumbs‑up/thumbs-down interactions as time-series data.

## Authors

Team Derma (Team 10)
CMPE 272 - Enterprise Software Platforms
San Jose State University, Fall 2025

## Support

- Check AWS CloudWatch logs for backend debugging
- Monitor OpenAI usage at https://platform.openai.com/usage
- Create an issue in the repository for technical questions

## Acknowledgments

- OpenAI GPT-4o for conversational AI agents
- AWS Services (Lambda, Cognito, S3, DynamoDB, API Gateway)
- Pinecone for vector database
- SwiftUI and SwiftData frameworks
- SF Symbols

---

**Disclaimer**: This application is for educational and informational purposes. For medical advice about skin conditions, consult a licensed dermatologist.
