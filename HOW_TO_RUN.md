# How to Run Lumen App

## 🚀 Quick Start (Easiest Method)

### Option 1: Using Xcode (Recommended)

1. **Open the project**
   ```bash
   cd /Users/myatbhonesan/Desktop/CMPE272/Lumen
   open Lumen.xcodeproj
   ```

2. **Select a simulator**
   - At the top of Xcode, click the device dropdown (next to the Run button)
   - Choose: **iPhone 17** or any iPhone simulator

3. **Run the app**
   - Press `Cmd + R` or click the ▶️ Play button
   - Wait for build to complete (~30 seconds)
   - App will launch automatically in simulator

---

## 📱 Option 2: Command Line

### Step 1: List Available Simulators
```bash
xcrun simctl list devices available | grep iPhone
```

### Step 2: Boot a Simulator
```bash
# Boot iPhone 17
xcrun simctl boot "iPhone 17"

# Or boot by ID if needed
xcrun simctl boot C8ED8519-FC67-4C5E-A78E-6E584E5479B8
```

### Step 3: Open Simulator App
```bash
open -a Simulator
```

### Step 4: Build the App
```bash
cd /Users/myatbhonesan/Desktop/CMPE272/Lumen

xcodebuild -project Lumen.xcodeproj \
  -scheme Lumen \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath ./build \
  build
```

### Step 5: Install on Simulator
```bash
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/Lumen.app
```

### Step 6: Launch the App
```bash
xcrun simctl launch booted com.team10.Lumen
```

---

## 🔧 Troubleshooting

### Problem: "No simulators available"
**Solution:**
```bash
# Download iOS simulators
xcode-select --install

# Or download from Xcode:
# Xcode → Settings → Platforms → iOS → Download
```

### Problem: "Simulator won't boot"
**Solution:**
```bash
# Kill all simulators
killall Simulator

# Erase the simulator
xcrun simctl erase all

# Try booting again
open -a Simulator
```

### Problem: "Build failed"
**Solution:**
```bash
# Clean build folder
cd /Users/myatbhonesan/Desktop/CMPE272/Lumen
rm -rf build/

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Lumen-*

# Rebuild
xcodebuild -project Lumen.xcodeproj \
  -scheme Lumen \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  clean build
```

### Problem: "App crashes on launch"
**Solution:**
The CoreData warnings on first launch are normal. The app creates the database on first run.

If it actually crashes:
```bash
# View crash logs
xcrun simctl spawn booted log stream --level debug | grep Lumen

# Or check Console app on Mac
open /Applications/Utilities/Console.app
```

### Problem: "Camera doesn't work"
**Note:** Camera requires a physical device. In simulator:
- Camera UI will show
- You can select from photo library
- But live camera won't work (simulator limitation)

---

## 🎯 Quick Commands Cheat Sheet

```bash
# List all simulators
xcrun simctl list devices

# Boot a simulator
xcrun simctl boot "iPhone 17"

# Open Simulator app
open -a Simulator

# Build project
xcodebuild -project Lumen.xcodeproj -scheme Lumen build

# Install app
xcrun simctl install booted /path/to/Lumen.app

# Launch app
xcrun simctl launch booted com.team10.Lumen

# Uninstall app
xcrun simctl uninstall booted com.team10.Lumen

# Take screenshot
xcrun simctl io booted screenshot screenshot.png

# Record video
xcrun simctl io booted recordVideo video.mp4
# Press Ctrl+C to stop recording

# Shutdown simulator
xcrun simctl shutdown all
```

---

## 📸 Testing Camera Features

### In Simulator (Limited)
1. Click Camera button in app
2. Click "Gallery" to select existing photos
3. Live camera preview won't work (simulator limitation)

### On Physical Device (Full Features)
1. Connect iPhone via USB
2. In Xcode, select your iPhone from device list
3. Press `Cmd + R` to build and run
4. Accept camera permissions when prompted
5. Camera will work fully!

---

## 🔍 Viewing App in Simulator

Once the app launches, you should see:

### First Launch:
1. **Onboarding Screen** (4 steps)
   - Welcome screen
   - Enter your name
   - Select skin concerns
   - Choose your goal
   - Click "Get Started"

### After Onboarding:
2. **Home Dashboard**
   - Greeting at top
   - Today's Focus card
   - Daily checklist
   - Quick actions
   - Floating camera button (bottom-right)

### Taking First Scan:
3. **Tap floating camera button**
   - Camera view opens
   - Tap "Gallery" (since simulator camera doesn't work)
   - Select a photo
   - View analysis results

---

## 🎨 Testing Both UI Versions

The app includes both:
- **Original UI** (HomeView, OnboardingView, AnalysisDetailView)
- **Improved UI** (ImprovedHomeView, ImprovedOnboardingView, ImprovedAnalysisDetailView)

To switch between them:
1. Open `LumenApp.swift`
2. Change the views used in the body

Current setup uses original views. To use improved views, see `UX_IMPLEMENTATION_SUMMARY.md`

---

## 📱 Simulator Shortcuts

- `Cmd + 1` - Scale to 100%
- `Cmd + 2` - Scale to 75%
- `Cmd + 3` - Scale to 50%
- `Cmd + Shift + H` - Home button
- `Cmd + L` - Lock screen
- `Cmd + Shift + H + H` - App switcher
- `Cmd + K` - Toggle keyboard

---

## ✅ Verification Checklist

After launching, verify:
- [ ] App launches without crashing
- [ ] Onboarding screens appear
- [ ] Can enter name
- [ ] Can select skin concerns
- [ ] Can choose goal
- [ ] Home dashboard loads
- [ ] Floating camera button visible
- [ ] Can access settings
- [ ] Tabs work (Home, History, Learn, Settings)

---

## 🆘 Still Having Issues?

### Check Xcode Version
```bash
xcodebuild -version
# Should be: Xcode 16.0 or later
```

### Check iOS SDK
```bash
xcodebuild -showsdks | grep iOS
# Should show: iOS 26.0 or later
```

### Reset Everything
```bash
# 1. Close Xcode and Simulator
killall Xcode
killall Simulator

# 2. Clean everything
cd /Users/myatbhonesan/Desktop/CMPE272/Lumen
rm -rf build/
rm -rf ~/Library/Developer/Xcode/DerivedData/

# 3. Erase simulators
xcrun simctl erase all

# 4. Reboot simulator
xcrun simctl shutdown all
open -a Simulator

# 5. Open project fresh
open Lumen.xcodeproj

# 6. Press Cmd+R to run
```

---

## 📞 Additional Help

Check these files for more info:
- `BUILD_STATUS.md` - Build information
- `BUILD_FIXES.md` - Common errors and fixes
- `README.md` - Project overview
- `IMPLEMENTATION_NOTES.md` - Technical details

---

## 🎉 Success!

If you see the onboarding screen, you're all set!

The app is running successfully in the simulator.

**Note:** The CoreData warnings on first launch are expected - the app is creating its database. These will not appear on subsequent launches.
