# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lumen is an iOS application built with SwiftUI and SwiftData. The project uses Xcode 26.0.1 and targets iOS 26.0+.

## Project Structure

- **Lumen/**: Main application source code
  - `LumenApp.swift`: App entry point, sets up SwiftData ModelContainer with schema
  - `ContentView.swift`: Main view with NavigationSplitView displaying items list
  - `Item.swift`: SwiftData model for timestamp-based items
  - `Assets.xcassets/`: App icons and color assets
- **LumenTests/**: Unit tests using Swift Testing framework
- **LumenUITests/**: UI tests for the application
- **Lumen.xcodeproj/**: Xcode project configuration (bundle identifier: com.team10.Lumen)

## Data Architecture

The app uses **SwiftData** for persistence:
- Schema defined in `LumenApp.swift:14-16` includes the `Item` model
- ModelContainer configured with persistent storage (not in-memory)
- Environment injection via `.modelContainer(sharedModelContainer)` in `LumenApp.swift:30`
- Views access data through `@Environment(\.modelContext)` and `@Query` property wrappers

## Common Commands

### Building and Running
```bash
# Build the project
xcodebuild -project Lumen.xcodeproj -scheme Lumen -configuration Debug build

# Run tests
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16'

# Run unit tests only
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LumenTests

# Run UI tests only
xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LumenUITests
```

### Opening in Xcode
```bash
open Lumen.xcodeproj
```

## Testing Framework

This project uses the **Swift Testing** framework (not XCTest). Test files use:
- `import Testing` (not `import XCTest`)
- `@Test` attribute for test methods
- `#expect(...)` for assertions (not `XCTAssert...`)

## Device Compatibility

Targets both iPhone and iPad (TARGETED_DEVICE_FAMILY = "1,2") with support for portrait and landscape orientations.
