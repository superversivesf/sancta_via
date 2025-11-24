#!/bin/bash

# Build and Upload to TestFlight - Sancta Via Bible
set -e

echo "🍎 Building for TestFlight..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Run this script from the app root directory."
    exit 1
fi

# Check if on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: TestFlight builds require macOS with Xcode"
    exit 1
fi

# Clean and prepare
echo "🧹 Cleaning and preparing..."
flutter clean
flutter pub get

# Build iOS
echo "📱 Building iOS for release..."
flutter build ios --release

# Open Xcode workspace for archiving
echo "🚀 Opening Xcode for archiving..."
echo ""
echo "Next steps in Xcode:"
echo "1. Select 'Any iOS Device' as target"
echo "2. Product → Archive"
echo "3. In Organizer → Distribute App"
echo "4. Choose 'App Store Connect'"
echo "5. Upload to TestFlight"
echo ""
echo "After upload, go to App Store Connect to:"
echo "- Add beta testers"
echo "- Submit for TestFlight review (usually 24-48 hours)"

open ios/Runner.xcworkspace