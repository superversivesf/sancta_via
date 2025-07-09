#!/bin/bash

# Sancta Via Confession - Release Build Script
set -e

echo "🔨 Building Sancta Via Confession for release..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Run this script from the app root directory."
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build Android AAB (recommended for Google Play)
echo "📱 Building Android App Bundle..."
flutter build appbundle --release

# Build Android APK (for testing/sideloading)
echo "📱 Building Android APK..."
flutter build apk --release

# Build iOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Building iOS..."
    flutter build ios --release --no-codesign
    
    echo "📦 Building iOS IPA archive..."
    cd ios
    xcodebuild -workspace Runner.xcworkspace \
               -scheme Runner \
               -configuration Release \
               -destination generic/platform=iOS \
               -archivePath build/Runner.xcarchive \
               archive
    
    # Note: You'll need to export the IPA manually through Xcode or using xcodebuild -exportArchive
    echo "ℹ️  iOS archive created. Use Xcode to export IPA for distribution."
    cd ..
else
    echo "ℹ️  Skipping iOS build (not on macOS)"
fi

echo "✅ Build complete!"
echo ""
echo "📁 Build outputs:"
echo "   Android AAB: build/app/outputs/bundle/release/app-release.aab"
echo "   Android APK: build/app/outputs/flutter-apk/app-release.apk"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   iOS Archive: ios/build/Runner.xcarchive"
fi

echo ""
echo "🚀 Next steps:"
echo "   1. Test the APK on physical devices"
echo "   2. Upload AAB to Google Play Console"
echo "   3. Export and submit iOS IPA to App Store Connect"