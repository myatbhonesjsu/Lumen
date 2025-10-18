# Lumen - AI Skincare Assistant

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2026.0+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-3.0-green.svg" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

## 📱 Overview

**Lumen** is a privacy-first AI skincare assistant that helps users analyze their skin health through photos, track progress over time, and receive personalized skincare recommendations. All data is stored locally on the device with no account required.

## ✨ Features

### Core Functionality
- 📸 **Photo Capture & Analysis** - Take selfies with guided camera interface
- 🧠 **AI Skin Analysis** - Analyze skin metrics (acne, dryness, moisture, pigmentation)
- 📊 **Progress Tracking** - Visual timeline of skin health over time
- 💡 **Smart Recommendations** - Personalized product suggestions based on analysis
- 📚 **Educational Content** - Learn about skincare with evidence-based articles
- 🔒 **Privacy-First** - All data stored locally, no cloud sync

### Key Screens
1. **Onboarding** - Privacy-forward introduction to the app
2. **Home Dashboard** - Quick overview of skin health metrics
3. **Camera** - Capture photos with face positioning guide
4. **Analysis** - Detailed results with annotated images
5. **History** - Timeline of all past scans with trends
6. **Recommendations** - Curated product suggestions
7. **Learning Hub** - Skincare education articles
8. **Settings** - Privacy controls and preferences

## 🎨 Design

### Design Philosophy
- **Clean & Minimal** - Card-based layout with ample whitespace
- **Yellow Accent** - Warm, friendly brand color representing light
- **SF Symbols** - Consistent iconography throughout
- **Accessibility** - High contrast, readable typography

### Color Palette
- Primary: `#FFCC00` (Yellow)
- Background: White / System Grouped Background
- Text: Black / Gray
- Success: Green
- Warning: Orange
- Error: Red

## 🏗️ Architecture

### Technology Stack
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Camera**: AVFoundation
- **Photos**: PhotosUI
- **Minimum iOS**: 26.0

### Project Structure
```
Lumen/
├── Models/              # SwiftData models
│   ├── SkinMetric.swift
│   ├── Recommendation.swift
│   ├── EducationalContent.swift
│   └── UserProfile.swift
├── Views/
│   ├── Onboarding/     # Welcome flow
│   ├── Home/           # Dashboard
│   ├── Camera/         # Photo capture
│   ├── Analysis/       # Results & processing
│   ├── History/        # Timeline
│   ├── Recommendations/# Product suggestions
│   ├── Learning/       # Educational content
│   ├── Settings/       # App settings
│   └── MainTabView.swift
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

## 🚀 Getting Started

### Prerequisites
- Xcode 16.0+
- macOS Sonoma or later
- iOS 26.0+ device or simulator

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
- Select a simulator or connected device
- Press `Cmd + R` to build and run

### Camera Permissions
The app requires camera and photo library access. Privacy descriptions are configured in `Info.plist`:
- Camera: "Lumen needs access to your camera to take photos for skin analysis."
- Photo Library: "Lumen needs access to your photo library to analyze existing photos."

## 📖 Usage Guide

### First Time User Journey

1. **Onboarding** (3 screens)
   - Welcome to Lumen
   - How it works (4 key features)
   - Privacy policy and guarantees

2. **Take First Photo**
   - Tap camera button in center of tab bar
   - Position face within frame
   - Capture or select from gallery

3. **View Analysis**
   - Watch AI processing animation
   - Review detailed results
   - Check skin age and metrics

4. **Get Recommendations**
   - View personalized product suggestions
   - Filter by category
   - Learn about key ingredients

5. **Track Progress**
   - Regular scans to monitor changes
   - View history timeline
   - Analyze trends over time

## 🔐 Privacy & Security

### Privacy-First Design
- ✅ **Local Storage Only** - All data stored on device using SwiftData
- ✅ **No Account Required** - Use immediately without signup
- ✅ **No Cloud Sync** - Photos never leave your device
- ✅ **No Third-Party Sharing** - Zero data sharing
- ✅ **Easy Data Deletion** - Delete all data anytime from Settings

### Data Storage
- Photos: Stored as `Data` in SwiftData (encrypted at rest by iOS)
- Analysis Results: Local SQLite database
- User Preferences: UserDefaults and SwiftData
- No network requests (base implementation)

## 🧪 Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16'

# Run unit tests only
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LumenTests

# Run UI tests only
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LumenUITests
```

### Test Coverage
- [ ] Unit tests for data models
- [ ] UI tests for onboarding flow
- [ ] Camera integration tests
- [ ] Analysis processing tests

## 🎯 Roadmap

### Current Version (1.0.0)
- ✅ Complete UI implementation
- ✅ Mock AI analysis
- ✅ Local data storage
- ✅ Privacy-first design

### Future Enhancements
- [ ] Real AI/ML model integration (Core ML)
- [ ] Advanced skin analysis (wrinkles, texture, pores)
- [ ] Comparison view (before/after)
- [ ] Export reports as PDF
- [ ] Custom skincare routine builder
- [ ] Ingredient scanner
- [ ] Dark mode support
- [ ] Localization (multiple languages)
- [ ] Apple Health integration
- [ ] Widget support
- [ ] Watch app companion

## 📚 Documentation

- **[Design Guide](LUMEN_DESIGN_GUIDE.md)** - Complete UX journey and design system
- **[CLAUDE.md](CLAUDE.md)** - Development setup and architecture notes

## 🤝 Contributing

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

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Authors

**Team 10** - CMPE 272 Project

## 🙏 Acknowledgments

- Design inspiration from modern skincare apps
- SF Symbols for iconography
- SwiftUI community for best practices

## 📞 Support

For questions or issues:
- Create an issue in this repository
- Email: support@lumenapp.example.com
- Documentation: See LUMEN_DESIGN_GUIDE.md

## 🔄 Version History

### 1.0.0 (2025)
- Initial release
- Core features: Camera, Analysis, History, Recommendations, Learning Hub
- Privacy-focused design
- Local-only data storage

---

**Built with ❤️ for healthy skin**

*Note: This is a prototype/educational project. Always consult with a dermatologist for medical advice about skin concerns.*
