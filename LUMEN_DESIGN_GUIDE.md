# Lumen - AI Skincare Assistant
## Design Guide & UX Journey

---

## 📱 App Overview

**Lumen** is a privacy-focused AI skincare assistant that helps users analyze their skin health through photos, track progress over time, and receive personalized skincare recommendations. The app emphasizes local-first data storage and user privacy.

---

## 🎨 Design Style

### Color Palette
- **Primary**: Yellow (`#FFCC00`) - Represents light, warmth, and positivity
- **Backgrounds**: White and light gray (`systemGroupedBackground`)
- **Text**: Black (primary), Gray (secondary)
- **Accents**: Blue, Green, Red (for metrics and status indicators)

### Typography
- **Headings**: SF Pro Display, Bold (32-36pt)
- **Subheadings**: SF Pro Text, Semibold (18-24pt)
- **Body**: SF Pro Text, Regular (16pt)
- **Captions**: SF Pro Text, Regular (12-14pt)

### Visual Elements
- **Corner Radius**: 12-20px for cards and buttons
- **Shadows**: Subtle, soft shadows (opacity 0.05-0.1, radius 5-10pt)
- **Icons**: SF Symbols throughout for consistency
- **Progress Indicators**: Circular progress rings with yellow accent
- **Cards**: White background with rounded corners and subtle shadows

---

## 🗺️ Core User Journey

### 1. First Launch - Onboarding Flow
```
Welcome Screen → How It Works → Privacy Policy → Get Started
```

**Screens:**

#### **Welcome Page**
- Large sun icon (app logo)
- "Welcome to Lumen" heading
- "Your personal AI skincare assistant" tagline
- Next button (yellow)

#### **How It Works Page**
- 4 key features with icons:
  - 📷 Capture - Take a clear photo
  - ✨ Analyze - AI analyzes skin health
  - 📈 Track - Monitor progress over time
  - 💡 Recommend - Get personalized tips

#### **Privacy Page**
- Lock/shield icon
- Privacy guarantees:
  - ✓ Local storage only
  - ✓ No account required
  - ✓ No third-party sharing
  - ✓ Delete anytime
- "Get Started" button

---

### 2. Main Navigation - Tab Bar
```
Home | History | [Camera] | Learn | Settings
```

**Custom Tab Bar Design:**
- 5 tabs with icons
- Center tab: Elevated camera button (black circle with white camera icon)
- Selected state: Yellow icon + text
- Unselected state: Gray icon + text

---

### 3. Home Dashboard

**Layout Components:**

#### **Header**
- User avatar (profile photo or placeholder)
- Skin health percentage
- Bell icon (notifications)
- Menu icon (settings)

#### **Greeting Card**
- "Hello [Name]"
- "Your skin journey starts here!"

#### **Skin Health Card** (if user has scans)
- Overall health percentage (large, bold)
- Circular progress indicator (yellow)
- "Last scan: X days ago"
- "Read more" link → Analysis Detail

#### **Empty State Card** (if no scans)
- Large camera icon
- "Start Your Journey" heading
- "Take your first skin analysis photo"
- "Take Photo" button (yellow)

#### **Daily Routine Card**
- Sun icon with date
- "Daily Routine" label
- "Read more" → Learning Hub

#### **For You Section**
- Horizontal scroll of product recommendations
- Each card shows product image, title, price

---

### 4. Camera Flow

```
Camera View → Capture Photo → Processing → Analysis Results
```

#### **Camera Interface**
- Full-screen camera preview
- Face frame overlay (rounded rectangle with yellow border)
- Instructions: "Position your face within the frame"
- Controls:
  - Gallery picker (bottom left)
  - Capture button (center, white circle)
  - Flip camera (bottom right)
- Close button (top left)

#### **Processing Screen**
- Photo preview
- Circular progress indicator (animated)
- "Analyzing your skin..." message
- Progress updates (simulated AI processing)
- Cancel button

#### **Analysis Complete**
- Green checkmark
- "Analysis Complete!" message
- "View Results" button

---

### 5. Analysis Detail View

**Layout:**

#### **Header Image**
- Full-width photo with skin age overlay
- Annotation points showing detected features
- Example: "Pigmentation" markers
- Close button (top right)

#### **Metrics Grid**
- 3 circular progress cards:
  - Acne Level
  - Dryness Level
  - Moisture Level
- Color-coded (red for high concern, green for good)

#### **AI Insights Section**
- Card with multiple insight rows:
  - 💧 Hydration recommendation
  - ☀️ Sun protection advice
  - 😊 Overall assessment
- Each insight has icon, color, and text

#### **Action Button**
- "View Recommendation" (yellow button)
- → Recommendations View

---

### 6. History/Timeline View

#### **Overview Card**
- Average health percentage
- Trend indicator (↗ improving, → stable, ↘ declining)
- Circular progress ring
- Statistics:
  - Total scans
  - This month
  - Average skin age

#### **History Timeline**
- Chronological list of past scans
- Each card shows:
  - Thumbnail photo
  - Date
  - Overall health percentage
  - Skin age
  - Mini metrics (Acne, Dry, Moist percentages)
- Tap to view full analysis

#### **Empty State**
- Clock icon
- "No History Yet" message
- Helpful text

---

### 7. Recommendations View

#### **Header Card**
- Light bulb icon
- "Personalized for You" heading
- Explanation text (based on latest analysis)

#### **Category Filter**
- Horizontal scroll of category pills
- Categories: All, Moisturizer, Sunscreen, Acne Treatment, Cleanser
- Selected state: Yellow background
- Unselected: White background

#### **Recommendation Cards**
Each card includes:
- Product icon/image
- Title and category badge
- Price
- "Top Pick" badge (for priority items)
- Description
- Info box: Why recommended
- Key ingredients (horizontal scroll chips)
- "Learn More" button

---

### 8. Learning Hub

#### **Header**
- Book icon
- "Learn About Skincare" heading
- Explanation text

#### **Category Filter**
- Pills: All, Basics, Ingredients, Routines, Conditions

#### **Article Cards**
- Icon with category color
- Category label (color-coded)
- Article title
- Read time estimate
- Arrow indicator

#### **Article Detail View**
- Category label
- Title
- Read time + "Verified" badge
- Full article content with formatting
- Markdown-style formatting (bold, bullets, sections)

**Sample Articles:**
- Understanding Your Skin Type
- The Importance of Sunscreen
- Building Your Skincare Routine
- Understanding Active Ingredients
- Managing Acne-Prone Skin
- Hydration vs. Moisturization

---

### 9. Settings View

#### **Profile Section**
- Profile picture/avatar
- Name field (editable)
- "Lumen User" subtitle

#### **Preferences**
- Toggle: Scan Reminders
- Link: Reminder Schedule
  - Time picker
  - Frequency picker (Daily, Every 3 Days, Weekly, etc.)

#### **Privacy & Data**
- Privacy Policy link
- Data Management
  - Total scans count
  - Storage used
  - Privacy guarantees with icons
- Delete All Data (red, with confirmation)

#### **About**
- Version number
- About Lumen link
- Help & Support link

#### **Privacy Policy Detail**
- Structured sections:
  - Data Collection
  - Photo Storage
  - AI Analysis
  - No Third-Party Sharing
  - Data Deletion

#### **About Detail**
- Lumen logo (sun icon)
- App name and tagline
- Version
- Mission statement
- Copyright

---

## 🎯 Key UX Principles

### 1. **Privacy-First Design**
- All data stored locally
- No login/account required
- Clear privacy messaging throughout
- Easy data deletion

### 2. **Progressive Disclosure**
- Simple onboarding (3 screens)
- Start with empty states
- Guide users to first action (take photo)
- Gradually reveal features

### 3. **Visual Hierarchy**
- Large, bold metrics (health percentage)
- Clear CTAs (yellow buttons)
- Consistent card-based layout
- Ample whitespace

### 4. **Feedback & Guidance**
- Loading states with progress indicators
- Success confirmations
- Helpful empty states
- Clear instructions (camera positioning)

### 5. **Trust & Credibility**
- "Verified" badges on educational content
- Scientific-sounding terminology
- Professional UI design
- Transparent privacy practices

---

## 📐 Layout Patterns

### Card Component
```
Padding: 20px
Background: White
Corner Radius: 16-20px
Shadow: 0px 4px 10px rgba(0,0,0,0.05)
```

### Button Styles
```
Primary (Yellow):
  - Background: Yellow
  - Text: Black/White
  - Padding: 12-16px vertical, 24px horizontal
  - Corner Radius: 12px

Secondary:
  - Background: Gray opacity
  - Text: Primary
  - Border: Optional
```

### Progress Ring
```
Size: 100-120px
Line Width: 10-12px
Background: Gray opacity 0.2
Foreground: Yellow
Line Cap: Round
Animation: Smooth rotation
```

---

## 🔄 Data Flow

### Analysis Pipeline
```
Camera → Image Capture → Local Processing → Mock AI Analysis →
SwiftData Storage → UI Update → Recommendations
```

### Models
- **SkinMetric**: Stores analysis results, images, metrics
- **Recommendation**: Personalized product suggestions
- **UserProfile**: User preferences and settings
- **EducationalContent**: Learning hub articles (static)

---

## ✨ Animations & Interactions

### Transitions
- Screen transitions: Slide/fade
- Modal presentations: Sheet style
- Tab changes: Cross-fade

### Loading States
- Circular progress with rotation
- Smooth percentage increments
- Skeleton screens (optional)

### Gestures
- Tap: Primary interaction
- Swipe: Delete in lists
- Pull to refresh: History view

---

## 🎨 Icon Usage

### Tab Bar Icons
- `house.fill` - Home
- `calendar` - History/Plan
- `camera.fill` - Camera (center)
- `book.fill` - Learn
- `gearshape.fill` - Settings

### Feature Icons
- `sun.max.fill` - Lumen brand, sunscreen
- `face.smiling.fill` - Skin health
- `sparkles` - AI analysis
- `drop.fill` - Hydration/moisture
- `bandage.fill` - Acne treatment
- `chart.line.uptrend.xyaxis` - Progress
- `lightbulb.fill` - Recommendations
- `lock.shield.fill` - Privacy
- `checkmark.seal.fill` - Verified

---

## 📱 Screen Dimensions & Spacing

### Spacing Scale
- **XXS**: 4px
- **XS**: 8px
- **S**: 12px
- **M**: 16px
- **L**: 20px
- **XL**: 24px
- **XXL**: 32px

### Grid System
- Horizontal margins: 20px
- Card spacing: 16-24px
- Section spacing: 32px
- Bottom tab bar height: ~80px (including safe area)

---

## 🚀 Future Enhancements

- Real AI/ML integration for skin analysis
- Cloud sync with end-to-end encryption
- Social features (optional, privacy-conscious)
- Advanced analytics and trends
- Integration with health apps
- Dermatologist consultation booking
- Product purchase integration
- Custom routine builder

---

## 📝 Notes for Developers

### SwiftData Models
- All models use `@Model` macro
- Relationships between SkinMetric and Recommendations
- Query with `@Query` property wrapper
- Environment injection via `modelContext`

### Camera Integration
- Uses `AVCaptureSession` for camera
- `PhotosPicker` for gallery access
- Camera permissions handled in `CameraManager`
- Front camera by default (selfie mode)

### Privacy Compliance
- No analytics/tracking
- No network requests (in base implementation)
- All processing on-device
- SwiftData for local persistence

### Testing Considerations
- Mock data for previews
- In-memory containers for testing
- UI tests for onboarding flow
- Unit tests for analysis logic (when implemented)

---

**Version**: 1.0.0
**Last Updated**: 2025
**Design System**: iOS Human Interface Guidelines
**Minimum iOS**: 26.0
