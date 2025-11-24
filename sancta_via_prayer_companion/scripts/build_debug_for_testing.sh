#!/bin/bash

# Quick Debug Build for Testing - Sancta Via Prayer
set -e

echo "🔨 Building debug APK for testing..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Run this script from the app root directory."
    exit 1
fi

# Clean and get dependencies
flutter clean
flutter pub get

# Build debug APK (automatically signed with debug key)
flutter build apk --debug

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"

if [ -f "$APK_PATH" ]; then
    echo "✅ Debug APK built successfully!"
    echo "📁 Location: $APK_PATH"
    echo "📱 Size: $(du -h "$APK_PATH" | cut -f1)"
    echo ""
    echo "🚀 To install on Android device:"
    echo "   1. Enable 'Developer Options' on the device"
    echo "   2. Enable 'USB Debugging' and 'Install unknown apps'"
    echo "   3. Transfer APK to device or install via ADB:"
    echo "      adb install '$APK_PATH'"
    echo ""
    echo "📤 To share with friends:"
    echo "   1. Upload APK to Google Drive, Dropbox, or file sharing service"
    echo "   2. Share download link with testers"
    echo "   3. Testers need to enable 'Install unknown apps' for their browser/file manager"
else
    echo "❌ Build failed - APK not found"
    exit 1
fi