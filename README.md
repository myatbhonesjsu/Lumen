# Lumen - AI Skincare Assistant

**Version**: 1.1.0
<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2018.6+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-3.0-green.svg" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

**Status**: 75% done

## Overview

Lumen is an AI-powered skincare assistant iOS application that analyzes skin conditions through photos, tracks progress over time, and provides personalized skincare routines and recommendations. The application uses Claude 3.5 Sonnet via AWS Bedrock for intelligent analysis and AWS Rekognition Custom Labels for skin condition detection.

## Core Features

### Skin Analysis
- Photo capture with guided camera interface
- AWS Rekognition Custom Labels for skin condition detection
- Claude 3.5 Sonnet for enhanced analysis and recommendations
- Comprehensive metrics: acne level, dryness, moisture, pigmentation, dark circles
- Skin age estimation and overall health scoring

### Personalized AI Agents
1. **Conversational Chatbot** - RAG-enabled AI assistant with context-aware responses
2. **Personalized Routine Builder** - Custom morning/evening skincare routines based on analysis
3. **Progress Tracking** - Scientific skin metrics over time with trend analysis

### Data Management
- Local-first storage using SwiftData
- Analysis history with folder organization
- Chat history with AI assistant
- Personalized routine persistence

### User Experience
- Dark mode support with adaptive colors
- Haptic feedback throughout interface
- Privacy-focused design (local data storage)
- Clean, minimal card-based UI

## Technology Stack

### iOS Application
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI 3.0
- **Data Persistence**: SwiftData (Core Data wrapper)
- **Camera**: AVFoundation with thread-safe implementation
- **Minimum iOS**: 18.6+

### AWS Backend Infrastructure
- **Compute**: AWS Lambda (Python 3.11)
- **API**: API Gateway (REST)
- **AI Services**:
  - AWS Bedrock Runtime (Claude 3.5 Sonnet)
  - AWS Rekognition Custom Labels
- **Storage**:
  - Amazon S3 (image storage)
  - DynamoDB (analysis results, chat history)
- **Infrastructure as Code**: Terraform
- **Region**: us-east-1

## Project Structure

```
Lumen/
├── Lumen/
│   ├── Models/
│   │   ├── SkinMetric.swift           # Analysis results
│   │   ├── UserProfile.swift          # User preferences
│   │   ├── DailyRoutine.swift         # Routine tracking
│   │   ├── PersonalizedRoutine.swift  # AI-generated routines
│   │   └── SkinConcern.swift          # Concern tracking
│   ├── Views/
│   │   ├── Home/                      # Dashboard
│   │   ├── Analysis/                  # Results & processing
│   │   ├── History/                   # Timeline view
│   │   ├── Learning/                  # AI chatbot
│   │   ├── Camera/                    # Photo capture
│   │   ├── Settings/                  # Preferences
│   │   └── Onboarding/                # First-time flow
│   ├── Services/
│   │   ├── LearningHubService.swift   # Chatbot API
│   │   ├── RoutineService.swift       # Routine generation
│   │   └── SkinAnalysisService.swift  # Analysis API
│   ├── Helpers/
│   │   ├── ColorExtensions.swift      # Adaptive colors
│   │   ├── HapticManager.swift        # Haptic feedback
│   │   └── ImageExtensions.swift      # Image utilities
│   └── LumenApp.swift                 # App entry point
├── aws-backend/
│   ├── lambda/
│   │   ├── handler.py                 # Skin analysis Lambda
│   │   ├── learning_hub_handler.py    # Chatbot Lambda
│   │   └── vector_search.py           # Semantic search
│   ├── terraform/
│   │   ├── main.tf                    # Infrastructure config
│   │   ├── lambda.tf                  # Lambda resources
│   │   ├── api_gateway.tf             # API configuration
│   │   └── dynamodb.tf                # Database tables
│   └── scripts/
│       ├── build-lambda.sh            # Lambda build script
│       └── deploy.sh                  # Full deployment
└── docs/                              # Documentation

```

## Getting Started

### Prerequisites
- Xcode 16.0+
- macOS Sonoma or later
- iOS 18.6+ device or simulator
- AWS CLI configured (for backend deployment)
- Terraform 1.0+ (for infrastructure)

### iOS App Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Lumen
```

2. Open in Xcode:
```bash
open Lumen.xcodeproj
```

3. Build and run:
   - Select target device or simulator
   - Press Cmd+R to build and run
   - Grant camera and photo library permissions

### AWS Backend Deployment

The backend infrastructure is required for production use.

1. Navigate to backend directory:
```bash
cd aws-backend
```

2. Configure AWS credentials:
```bash
aws configure
```

3. Deploy infrastructure:
```bash
./deploy.sh
```

Deployment creates:
- S3 bucket for image storage
- Lambda functions for analysis and chatbot
- API Gateway REST API
- DynamoDB tables for data storage
- IAM roles and policies
- CloudWatch log groups

**Deployment time**: Approximately 5-7 minutes
**Estimated cost**: $10-30/month depending on usage

4. Update iOS app configuration:
   - Copy API endpoint URL from deployment output
   - Update endpoints in `Services/` files if needed

### API Endpoints

After deployment, the following endpoints are available:

**Skin Analysis**:
```
POST /dev/analyze
Content-Type: application/json
Body: { "image": "<base64-encoded-image>" }
```

**AI Chatbot**:
```
POST /dev/learning-hub/chat
Content-Type: application/json
Body: { "user_id": "string", "message": "string", "session_id": "string" }
```

**Personalized Routine Generation**:
```
POST /dev/learning-hub/routines/generate
Content-Type: application/json
Body: { "user_id": "string", "latest_analysis": {...}, "budget": "moderate" }
```

## Architecture

### Data Flow

1. **Skin Analysis**:
   - User captures photo with camera
   - Image sent to AWS S3
   - Lambda triggers Rekognition Custom Labels
   - Claude enhances analysis with recommendations
   - Results stored in DynamoDB and returned to app
   - App persists to SwiftData for offline access

2. **AI Chatbot**:
   - User sends message to chatbot
   - Lambda retrieves user context (analysis history, chat history)
   - RAG system searches relevant articles using vector search
   - Claude generates contextualized response
   - Response saved to chat history in DynamoDB

3. **Personalized Routines**:
   - App sends latest analysis to routine generation endpoint
   - Lambda analyzes skin concerns and priorities
   - Claude creates custom morning/evening routine
   - Routine includes product types, reasoning, and timeline
   - Saved to SwiftData for daily tracking

### Security

- API endpoints use AWS IAM authentication
- Images stored in private S3 bucket
- DynamoDB tables encrypted at rest
- All data transmission over HTTPS
- Local data encrypted by iOS

## Data Models

### SkinMetric
Primary model for analysis results:
- `skinAge`: Int - Estimated biological skin age
- `overallHealth`: Double - Health score (0-100%)
- `acneLevel`: Double - Acne severity (0-100%)
- `drynessLevel`: Double - Dryness level (0-100%)
- `moistureLevel`: Double - Moisture content (0-100%)
- `pigmentationLevel`: Double - Pigmentation concerns (0-100%)
- `darkCircleLevel`: Double - Dark circle severity (0-100%)
- `imageData`: Data - Original photo
- `analysisNotes`: String - AI-generated insights
- `folderName`: String - User-defined organization

### PersonalizedRoutine
AI-generated skincare routines:
- `morningRoutineJSON`: String - Morning steps (JSON-encoded)
- `eveningRoutineJSON`: String - Evening steps (JSON-encoded)
- `keyConcerns`: [String] - Primary skin concerns
- `overallStrategy`: String - Treatment approach
- `expectedTimeline`: String - When to expect results
- `importantNotes`: [String] - Critical information

## Development

### Building
```bash
# Clean build
xcodebuild clean -project Lumen.xcodeproj -scheme Lumen

# Build for simulator
xcodebuild build -project Lumen.xcodeproj -scheme Lumen -sdk iphonesimulator

# Run tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Testing
```bash
# Unit tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -only-testing:LumenTests

# UI tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -only-testing:LumenUITests
```

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Prefer value types (struct) over reference types (class)
- Use @State, @Query, and @Environment property wrappers appropriately
- Keep view files under 300 lines
- Extract reusable components

## Deployment

### iOS App Store
1. Update version in project settings
2. Archive build in Xcode
3. Upload to App Store Connect
4. Submit for review

### Backend Updates
```bash
cd aws-backend
./scripts/build-lambda.sh
aws lambda update-function-code --function-name <function-name> --zip-file fileb://lambda.zip
```

## Cost Estimate

Monthly costs for 1,000 active users (10 analyses/user, 50 chat messages/user):

- AWS Lambda: $2-5
- AWS Bedrock (Claude): $15-25
- AWS Rekognition: $10-15
- S3 Storage: $1-2
- DynamoDB: $1-3
- API Gateway: $1-2

**Total**: $30-52/month

Costs scale linearly with usage. Free tier covers development and testing.

## Privacy

### Data Storage
- All user data stored locally on device using SwiftData
- Photos never leave device unless explicitly uploaded for analysis
- Analysis results synced with AWS only for enhanced processing
- No personal information collected
- No third-party analytics or tracking

### User Rights
- Delete all data anytime from Settings
- Export data in standard formats
- No account or registration required
- Full transparency on data usage


## Authors

Team Derma (Team 10) - CMPE 272 Project
San Jose State University
Fall 2025

## Support

For technical issues or questions:
- Create an issue in the repository
- Review documentation in `/docs`
- Check CLAUDE.md for development setup

## Acknowledgments

- AWS Bedrock for Claude 3.5 Sonnet access
- AWS Rekognition for skin analysis capabilities
- SwiftUI and SwiftData frameworks
- SF Symbols for iconography
- Open-source community contributions

---

**Note**: This is a production-ready application. For medical advice about skin conditions, always consult a licensed dermatologist.
