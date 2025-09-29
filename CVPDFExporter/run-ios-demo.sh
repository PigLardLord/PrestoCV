#!/bin/bash

# Run the iOS demo app on simulator
echo "Building and running CVExportDemoApp on iOS Simulator..."

# Build for iOS simulator
xcodebuild -scheme CVExportDemoApp \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    build

# Run the app on simulator
xcrun simctl install booted \
    .build/apple/Products/Debug-iphonesimulator/CVExportDemoApp.app

xcrun simctl launch booted com.example.CVExportDemoApp

echo "Demo app launched on iOS Simulator"
echo "Tap the 'Export PDF' button to generate and preview the CV in QuickLook"