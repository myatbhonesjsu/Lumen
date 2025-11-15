# Lumen - AI Skincare Assistant

**Version**: 1.2.0
**Platform**: iOS 18.6+ | Swift 5.0 | SwiftUI 3.0

## Overview

Lumen is an AI-powered skincare assistant iOS application that analyzes skin conditions through photos, tracks progress over time, and provides personalized skincare routines and recommendations. The application uses Claude 3.5 Sonnet via AWS Bedrock for intelligent analysis and machine learning for skin condition detection.

## Core Features

### Skin Analysis
- Photo capture with guided camera interface
- Machine learning-based skin condition detection
- Claude 3.5 Sonnet for enhanced analysis and recommendations
- Comprehensive metrics tracking: acne, dryness, moisture, pigmentation, dark circles
- Skin age estimation and overall health scoring

### AI-Powered Assistants
1. **Conversational Chatbot** - RAG-enabled assistant with context-aware responses
2. **Routine Builder** - Custom morning/evening skincare routines
3. **Progress Tracking** - Scientific skin metrics analysis over time

### Data Management
- Local-first storage using SwiftData
- Organized analysis history with folder support
- Persistent chat history and personalized routines

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
- **AI Services**: AWS Bedrock (Claude 3.5 Sonnet)
- **Storage**: Amazon S3 (images), DynamoDB (analysis results)
- **Infrastructure**: Terraform-managed
- **Region**: us-east-1

## Project Structure

```
Lumen/
├── Lumen/                          # iOS Application
│   ├── Models/                     # Data models (SwiftData)
│   ├── Views/                      # SwiftUI views
│   ├── Services/                   # API clients & business logic
│   │   ├── CognitoAuthService.swift
│   │   ├── AWSBackendService.swift
│   │   └── SkinAnalysisService.swift
│   ├── Helpers/                    # Utilities
│   └── LumenApp.swift
├── aws-backend/                    # Backend Infrastructure
│   ├── lambda/                     # Lambda functions
│   │   └── handler.py
│   ├── terraform/                  # Infrastructure as Code
│   │   ├── main.tf
│   │   ├── cognito.tf
│   │   ├── lambda.tf
│   │   └── api_gateway.tf
│   └── scripts/                    # Deployment scripts
└── docs/                           # Documentation
```

## Getting Started

### Prerequisites
- Xcode 16.0+ and macOS Sonoma or later
- iOS 18.6+ device or simulator
- AWS CLI configured (for backend deployment only)
- Terraform 1.0+ (for infrastructure deployment only)

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
- Lambda function for skin analysis
- API Gateway with Cognito authorizer
- DynamoDB tables for data persistence
- IAM roles and CloudWatch logs

Deployment time: 5-7 minutes
Estimated cost: $10-30/month

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

**Get Product Recommendations**:
```
GET /dev/products/recommendations?condition=<condition>&limit=<count>
Authorization: <cognito-id-token>
Returns: Array of product recommendations
```

## Architecture

### Data Flow

1. **Skin Analysis**:
   - User captures photo via camera interface
   - App authenticates and requests presigned S3 URL
   - Image uploaded directly to S3
   - Lambda processes image with ML models
   - Claude enhances analysis with recommendations
   - Results stored in DynamoDB and returned to app
   - App persists locally to SwiftData

2. **Authentication Flow**:
   - App launches and auto-authenticates with Cognito
   - Receives JWT tokens (ID token, access token, refresh token)
   - Tokens included in all API requests
   - API Gateway validates tokens before invoking Lambda
   - User ID extracted from JWT claims for data isolation

### Security

- **Authentication**: AWS Cognito with JWT tokens
- **Authorization**: API Gateway Cognito authorizer on all endpoints
- **Data Isolation**: User-specific S3 paths and DynamoDB keys
- **Encryption**: DynamoDB at rest, HTTPS in transit
- **Storage**: Private S3 bucket, iOS-encrypted local data

## Data Models

### SkinMetric (SwiftData)
Analysis results stored locally:
- Skin age estimation and overall health score
- Acne, dryness, moisture, pigmentation, dark circle levels
- Original photo and AI-generated analysis notes
- Folder organization for history management

### PersonalizedRoutine (SwiftData)
AI-generated skincare routines:
- Morning and evening step-by-step routines
- Key concerns and treatment strategy
- Expected timeline and important notes

## Development

### Building and Testing
```bash
# Build
xcodebuild build -project Lumen.xcodeproj -scheme Lumen

# Run tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Backend Updates
```bash
cd aws-backend
./scripts/build-lambda.sh
terraform apply -auto-approve
```

## Cost Estimate

Monthly costs for moderate usage (approximate):
- AWS Lambda: $2-5
- AWS Bedrock (Claude): $15-25
- S3 Storage: $1-2
- DynamoDB: $1-3
- API Gateway: $1-2
- Cognito: Free tier

**Total**: $20-37/month

Free tier covers development and testing.

## Privacy and Data

- Local-first architecture with SwiftData
- Photos uploaded only for analysis, not stored permanently
- User data isolated by Cognito user ID
- No personal information collected
- No third-party analytics or tracking
- Full data deletion available in Settings


## Authors

Team Derma (Team 10)
CMPE 272 - Enterprise Software Platforms
San Jose State University, Fall 2025

## Support

- Review documentation in `/docs` and `CLAUDE.md`
- Create an issue in the repository for technical questions

## Acknowledgments

- AWS Bedrock (Claude 3.5 Sonnet)
- AWS Services (Lambda, Cognito, S3, DynamoDB)
- SwiftUI and SwiftData frameworks
- SF Symbols

---

**Disclaimer**: This application is for educational and informational purposes. For medical advice about skin conditions, consult a licensed dermatologist.
