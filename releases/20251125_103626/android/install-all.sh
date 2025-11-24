#!/bin/bash

# Android Install Script
# Installs all APK files to connected Android device

echo "🤖 Android App Installer"
echo "========================"

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ Error: adb not found. Please install Android SDK Platform Tools."
    exit 1
fi

# Check for connected devices
devices=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
if [ $devices -eq 0 ]; then
    echo "❌ No Android devices connected. Please connect a device and enable USB debugging."
    exit 1
fi

echo "📱 Found $devices connected device(s)"
echo ""

# Install all APK files
for apk in *.apk; do
    if [ -f "$apk" ]; then
        echo "📦 Installing $apk..."
        if adb install -r "$apk"; then
            echo "✅ Successfully installed $apk"
        else
            echo "❌ Failed to install $apk"
        fi
        echo ""
    fi
done

echo "🎉 Installation complete!"
