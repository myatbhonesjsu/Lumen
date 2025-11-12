# Lumen - AI Skincare Assistant

### Team Derma: Myat Bhone San, Ray Zhao, Shefali Saini, Sriyavarma Saripella

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2018.6+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-3.0-green.svg" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](Agentic_AI_Skin_Health_Assistant.ipynb)

Click the button above to open and run the AI Skin Health Assistant notebook directly in Google Colab.



##  Overview

**Lumen** is a privacy-first AI skincare assistant that helps users analyze their skin health through photos, track progress over time, and receive personalized skincare recommendations powered by advanced AI agents with tool calling and RAG (Retrieval Augmented Generation).


-  **Hugging Face**: Fast skin condition detection
-  **Google Gemini / AWS Bedrock**: Enhanced analysis with condition-specific recommendations
-  **AI Agents**: Tool calling for intelligent product recommendations
-  **Vector Database**: RAG-based semantic product search (mock + AWS OpenSearch)
-  **Amazon Integration**: Direct purchase links for recommended products
-  **AWS Backend**: Production infrastructure with S3, Lambda, DynamoDB, Bedrock (NEW!)

##  Features

### Core Functionality
-  **Photo Capture & Analysis** - Take selfies with guided camera interface and face positioning guide
-  **Real AI Skin Analysis** - Two-stage AI pipeline:
  - **Stage 1**: Hugging Face skin condition detection (2-3s)
  - **Stage 2**: Google Gemini enhanced analysis (3-5s)
-  **AI Agent with Tool Calling** - Intelligent product recommendations using:
  - Function calling to search product database
  - RAG (Retrieval Augmented Generation) with vector search
  - Semantic similarity matching for relevant products
-  **Progress Tracking** - Visual timeline of skin health over time
-  **Product Recommendations** - Curated skincare products with:
  - Amazon purchase links
  - Real ratings & reviews
  - Condition-specific targeting
  - Price information
-  **Educational Content** - Learn about skincare with evidence-based articles
-  **Privacy-First** - All data stored locally, no cloud sync
-  **Dark Mode Support** - Adaptive colors for light and dark mode
-  **Haptic Feedback** - Tactile responses for better UX

### Key Screens
1. **Onboarding** - Privacy-forward introduction to the app
2. **Home Dashboard** - Quick overview of skin health metrics
3. **Camera** - Capture photos with face positioning guide
4. **Analysis** - Detailed results with annotated images
5. **History** - Timeline of all past scans with trends
6. **Recommendations** - Curated product suggestions
7. **Learning Hub** - Skincare education articles
8. **Settings** - Privacy controls and preferences

##  Design

### Design Philosophy
- **Clean & Minimal** - Card-based layout with ample whitespace
- **Yellow Accent** - Warm, friendly brand color representing light
- **SF Symbols** - Consistent iconography throughout
- **Accessibility** - High contrast, readable typography
- **Adaptive Colors** - Full dark mode support with system-aware colors

### Color Palette
- Primary: `#FFCC00` (Yellow)
- Background: System adaptive (white/dark)
- Text: System adaptive (label colors)
- Cards: System background colors
- Shadows: Adaptive opacity for light/dark modes
- Success: Green
- Warning: Orange
- Error: Red

##  Architecture

### Technology Stack

**Frontend (iOS)**:
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData (local SQLite database)
- **Camera**: AVFoundation (thread-safe implementation)
- **Photos**: PhotosUI
- **Haptics**: UIFeedbackGenerator
- **Minimum iOS**: 18.6+

**AI Integration (Choose One)**:
- **Option 1 - Client-Side** (Current): Direct API calls to Hugging Face & Gemini
- **Option 2 - AWS Backend** (Recommended): Production infrastructure
  - **IaC**: Terraform
  - **Compute**: AWS Lambda (Python 3.11)
  - **API**: API Gateway (REST)
  - **Storage**: S3 (images), DynamoDB (results)
  - **AI**: AWS Bedrock Agents (managed framework)
  - **Vector DB**: OpenSearch Serverless
  - **Monitoring**: CloudWatch

### Project Structure
```
Lumen/
├── Models/              # SwiftData models
│   ├── SkinMetric.swift           # Analysis results storage
│   ├── Recommendation.swift       # Product recommendations
│   ├── EducationalContent.swift   # Learning articles
│   ├── SkinConcern.swift          # Skin issue tracking
│   └── UserProfile.swift          # User preferences
├── Views/
│   ├── Onboarding/     # Welcome flow
│   ├── Home/           # Dashboard with ImprovedHomeView
│   ├── Camera/         # Photo capture with face guide
│   ├── Analysis/       # Results & processing (mock data)
│   ├── History/        # Timeline
│   ├── Recommendations/# Product suggestions
│   ├── Learning/       # Educational content
│   ├── Settings/       # App settings
│   └── MainTabView.swift
├── Helpers/
│   ├── ColorExtensions.swift   # Dark mode adaptive colors
│   ├── HapticManager.swift     # Haptic feedback
│   ├── ImageExtensions.swift   # Image utilities
│   └── AIAnalysisEngine.swift  # Mock analysis generator
├── LumenApp.swift      # App entry point
└── Assets.xcassets/    # Images & colors
```

### Data Models

#### SkinMetric
Stores skin analysis results:
- `skinAge`: Estimated skin age
- `overallHealth`: 0-100% health score
- `acneLevel`: Acne severity percentage
- `drynessLevel`: Dryness percentage
- `moistureLevel`: Moisture percentage
- `pigmentationLevel`: Pigmentation concerns
- `imageData`: Original photo
- `analysisNotes`: AI-generated insights

#### UserProfile
User preferences and settings:
- `name`: User's name
- `hasCompletedOnboarding`: Onboarding status
- `scanRemindersEnabled`: Notification preferences
- `privacySettingsAccepted`: Privacy consent

##  Getting Started

### Prerequisites
- Xcode 16.0+
- macOS Sonoma or later
- iOS 18.6+ device or simulator

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd Lumen
```

2. **Open in Xcode**
```bash
open Lumen.xcodeproj
```

3. **Build and Run**
- Select a simulator or connected device (iPhone recommended for full haptic experience)
- Press `Cmd + R` to build and run
- Grant camera and photo library permissions when prompted

### AWS Backend Deployment (Optional, Recommended for Production)

**Quick Deploy**:
```bash
cd aws-backend
./deploy.sh
```

**Time**: ~7 minutes | **Cost**: ~$19/month (10K users)

**What it deploys**:
-  S3 bucket for image storage
-  Lambda function for AI processing
-  API Gateway for REST endpoints
-  DynamoDB for results & products
-  CloudWatch for monitoring
-  (Optional) AWS Bedrock Agents for managed AI framework

**After deployment**:
1. Copy API endpoint URL from output
2. Update `aws-backend/ios-client/AWSBackendService.swift`:
   ```swift
   static let apiEndpoint = "YOUR_API_URL_HERE"
   ```
3. Add `AWSBackendService.swift` to Xcode project
4. Replace analysis service call (see integration guide)

**Full documentation**:
-  `aws-backend/README.md` - Complete 500+ line guide
-  `aws-backend/QUICK_DEPLOY.md` - Quick reference
-  `AWS_ARCHITECTURE.md` - Architecture deep dive
-  `ARCHITECTURE_DECISION.md` - Client vs AWS comparison

**Why use AWS backend?**
-  API keys secure on backend (not in app)
-  Scales to millions of users
-  Update AI logic without app release
-  Full analytics & monitoring
-  AWS Bedrock Agents = managed agentic framework
-  Production-grade infrastructure

### Camera Permissions
The app requires camera and photo library access. Privacy descriptions are configured in the project settings:
- **Camera**: "Lumen needs access to your camera to capture photos of your skin for AI-powered analysis and personalized skincare recommendations."
- **Photo Library**: "Lumen needs access to your photo library so you can select existing photos for skin analysis."
- **Photo Library Additions**: "Lumen would like to save your skin analysis photos to your photo library for your records."

**Note**: On first launch, tap the camera button to trigger the permission dialog.

## 📖 Usage Guide

### First Time User Journey

1. **Onboarding** (3 screens)
   - Welcome to Lumen
   - How it works (4 key features)
   - Privacy policy and guarantees

2. **Grant Camera Permission**
   - Tap yellow camera button in center of tab bar
   - System permission dialog appears
   - Grant camera and photo library access

3. **Take First Photo**
   - Position face within the circular guide
   - Tap capture button (you'll feel haptic feedback)
   - Photo is captured instantly

4. **View Analysis**
   - Watch AI processing animation with progress indicator
   - See "Mock Analysis Mode" message
   - Review detailed results with skin age and metrics

5. **Check Results**
   - Overall health score (0-100%)
   - Skin age estimation
   - Individual metrics: acne, dryness, moisture, pigmentation
   - Personalized insights and recommendations

6. **Track Progress**
   - Regular scans to monitor changes
   - View history timeline with all past analyses
   - Compare before/after photos

##  Privacy & Security

### Privacy-First Design
-  **Local Storage Only** - All data stored on device using SwiftData
-  **No Account Required** - Use immediately without signup
-  **No Cloud Sync** - Photos never leave your device
-  **No Third-Party Sharing** - Zero data sharing
-  **Easy Data Deletion** - Delete all data anytime from Settings

### Data Storage
- Photos: Stored as `Data` in SwiftData (encrypted at rest by iOS)
- Analysis Results: Local SQLite database (SwiftData)
- User Preferences: UserDefaults and SwiftData
- No network requests (current implementation uses mock data)
- All processing happens on-device

##  Testing

### Running Tests

```bash
# Build the app
xcodebuild -project Lumen.xcodeproj -scheme Lumen -configuration Debug -sdk iphonesimulator build

# Run all tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 17'

# Run unit tests only
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LumenTests

# Run UI tests only
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LumenUITests
```

### Test Coverage
- [ ] Unit tests for data models
- [ ] UI tests for onboarding flow
- [ ] Camera integration tests
- [ ] Analysis processing tests

##  Roadmap

### Current Version (1.0.0) -  Complete
-  Complete UI implementation with polished design
-  Mock AI analysis with realistic data
-  Local data storage with SwiftData
-  Privacy-first design philosophy
-  Camera capture with thread-safe implementation
-  Face positioning guide for photos
-  Dark mode support with adaptive colors
-  Haptic feedback throughout app
-  Beautiful analysis animations
-  History tracking and progress visualization

### Future Enhancements
- [ ] Real AI/ML model integration (Core ML or third-party SDK)
- [ ] Advanced skin analysis (wrinkles, texture, pores, eye bags)
- [ ] Side-by-side comparison view (before/after)
- [ ] Export reports as PDF
- [ ] Custom skincare routine builder
- [ ] Ingredient scanner with barcode support
- [ ] Localization (multiple languages)
- [ ] Apple Health integration
- [ ] Widget support for quick stats
- [ ] Watch app companion
- [ ] Push notifications for scan reminders

##  Documentation

- **[CLAUDE.md](CLAUDE.md)** - Development setup and architecture notes for AI assistant

##  Contributing

### Development Guidelines
1. Follow SwiftUI best practices
2. Use SwiftData for all persistence
3. Maintain privacy-first principles
4. Write descriptive commit messages
5. Add tests for new features

### Code Style
- Use Swift naming conventions
- Prefer `struct` over `class` for views
- Use `@State` and `@Query` appropriately
- Keep views small and focused
- Extract reusable components

##  License

This project is licensed under the MIT License - see the LICENSE file for details.

##  Authors

**Team 10** - CMPE 272 Project

##  Acknowledgments

- Design inspiration from modern skincare apps
- SF Symbols for iconography
- SwiftUI community for best practices

##  Support

For questions or issues:
- Create an issue in this repository
- Documentation: See CLAUDE.md for development setup

##  Version History

### 1.0.0 (November 2024)
- Initial release with full UI/UX implementation
- Core features: Camera, Mock Analysis, History, Recommendations, Learning Hub
- Privacy-focused design with local-only data storage
- Thread-safe camera implementation
- Dark mode support with adaptive colors
- Haptic feedback system
- Face positioning guide for camera
- Mock AI analysis with realistic data
- Build status:  **BUILD SUCCEEDED**

---

##  Technical Highlights

### Camera Implementation
- **Thread-safe**: All camera operations on dedicated queue
- **Face guide**: Circular overlay for positioning
- **Haptic feedback**: Tactile response on capture
- **Error handling**: Graceful fallbacks for permissions

### Mock Analysis System
- **Realistic data**: Random but plausible skin metrics
- **Instant results**: No API calls or delays
- **Educational insights**: Helpful skincare tips
- **Full persistence**: Results saved to SwiftData

### Dark Mode Support
- **Adaptive colors**: System-aware background and text
- **Dynamic shadows**: Different opacity for light/dark
- **Seamless switching**: Instant theme changes
- **Consistent design**: All screens support both modes

---

**Built with ❤️ for healthy skin**

*Note: This is a prototype/educational project. The current version uses mock AI data for demonstration. Always consult with a dermatologist for medical advice about skin concerns.*
