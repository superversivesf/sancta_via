#!/bin/bash

# iOS TestFlight Upload Script
# Uploads IPA files to TestFlight using altool

echo "🍎 iOS TestFlight Uploader"
echo "=========================="

# Check if altool is available
if ! command -v xcrun altool &> /dev/null; then
    echo "❌ Error: altool not found. Please install Xcode Command Line Tools."
    exit 1
fi

# TODO: Add your Apple ID and app-specific password
APPLE_ID=""
APP_PASSWORD=""

if [ -z "$APPLE_ID" ] || [ -z "$APP_PASSWORD" ]; then
    echo "❌ Error: Please set APPLE_ID and APP_PASSWORD in this script"
    echo "You can generate an app-specific password at: https://appleid.apple.com"
    exit 1
fi

# Upload all IPA files
for ipa in *.ipa; do
    if [ -f "$ipa" ]; then
        echo "📦 Uploading $ipa to TestFlight..."
        xcrun altool --upload-app -f "$ipa" -t ios -u "$APPLE_ID" -p "$APP_PASSWORD"
        echo ""
    fi
done

echo "🎉 Upload complete!"
