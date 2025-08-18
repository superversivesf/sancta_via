#!/bin/bash

# Flutter Multi-Project Release Build Script
# Usage: ./build-release.sh [--major] [--minor] [--patch] [--dry-run]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/Users/jason/Repos/SanctaVia"
RELEASES_DIR="$BASE_DIR/releases"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RELEASE_DIR="$RELEASES_DIR/$TIMESTAMP"

# Default version bump type
VERSION_BUMP="patch"
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --major)
            VERSION_BUMP="major"
            shift
            ;;
        --minor)
            VERSION_BUMP="minor"
            shift
            ;;
        --patch)
            VERSION_BUMP="patch"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--major] [--minor] [--patch] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --major    Bump major version (x.0.0)"
            echo "  --minor    Bump minor version (0.x.0)"
            echo "  --patch    Bump patch version (0.0.x) [default]"
            echo "  --dry-run  Show what would be done without executing"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[$timestamp] INFO: $message${NC}" | tee -a "$RELEASE_DIR/build.log"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] SUCCESS: $message${NC}" | tee -a "$RELEASE_DIR/build.log"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] WARNING: $message${NC}" | tee -a "$RELEASE_DIR/build.log"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] ERROR: $message${NC}" | tee -a "$RELEASE_DIR/build.log"
            ;;
    esac
}

# Function to check if directory is a Flutter app project
is_flutter_app() {
    local project_dir=$1
    local project_name=$(basename "$project_dir")
    
    echo -e "${YELLOW}Checking $project_name:${NC}"
    
    # Check if it has pubspec.yaml
    if [[ ! -f "$project_dir/pubspec.yaml" ]]; then
        echo -e "${RED}  ❌ No pubspec.yaml found${NC}"
        return 1
    else
        echo -e "${GREEN}  ✅ pubspec.yaml found${NC}"
    fi
    
    # Check if it has lib/main.dart (main indicator of an app)
    if [[ ! -f "$project_dir/lib/main.dart" ]]; then
        echo -e "${RED}  ❌ No lib/main.dart found${NC}"
        return 1
    else
        echo -e "${GREEN}  ✅ lib/main.dart found${NC}"
    fi
    
    # Additional check: verify it has platform folders (android/ios)
    # This helps distinguish apps from pure Dart packages
    if [[ -d "$project_dir/android" || -d "$project_dir/ios" ]]; then
        echo -e "${GREEN}  ✅ Has platform folders (android/ios)${NC}"
    else
        echo -e "${YELLOW}  ⚠️  No platform folders found (might be a package)${NC}"
        # Still proceed - some apps might not have been set up for all platforms yet
    fi
    
    echo -e "${GREEN}  ✅ $project_name is a Flutter app${NC}"
    return 0
}

# Function to get current version from pubspec.yaml
get_current_version() {
    local project_dir=$1
    grep "^version:" "$project_dir/pubspec.yaml" | sed 's/version: *//' | tr -d ' '
}

# Function to bump version using cider (common Flutter version plugin)
bump_version() {
    local project_dir=$1
    local bump_type=$2
    
    cd "$project_dir" || return 1
    
    # Check if cider is available
    if flutter pub deps | grep -q "cider"; then
        log "INFO" "Using cider to bump $bump_type version in $(basename $project_dir)"
        flutter pub get > /dev/null 2>&1
        flutter pub run cider bump "$bump_type"
        return $?
    fi
    
    # Check if pubspec_version is available
    if flutter pub deps | grep -q "pubspec_version"; then
        log "INFO" "Using pubspec_version to bump $bump_type version in $(basename $project_dir)"
        flutter pub get > /dev/null 2>&1
        case $bump_type in
            "major")
                flutter pub run pubspec_version:bump major
                ;;
            "minor")
                flutter pub run pubspec_version:bump minor
                ;;
            "patch")
                flutter pub run pubspec_version:bump patch
                ;;
        esac
        return $?
    fi
    
    log "WARNING" "No version bumping plugin found in $(basename $project_dir). Skipping version bump."
    return 1
}

# Function to build Flutter app for both platforms
build_flutter_app() {
    local project_dir=$1
    local project_name=$(basename "$project_dir")
    local project_release_dir="$RELEASE_DIR"
    
    cd "$project_dir" || return 1
    
    log "INFO" "Building $project_name..."
    
    # Get dependencies
    log "INFO" "Getting dependencies for $project_name"
    flutter pub get >> "$RELEASE_DIR/build.log" 2>&1
    
    # Build for Android (APK and AAB)
    log "INFO" "Building Android APK for $project_name"
    mkdir -p "$project_release_dir/android"
    
    if flutter build apk --release >> "$RELEASE_DIR/build.log" 2>&1; then
        cp "build/app/outputs/flutter-apk/app-release.apk" "$project_release_dir/android/${project_name}-release.apk"
        log "SUCCESS" "Android APK built successfully for $project_name"
    else
        log "ERROR" "Failed to build Android APK for $project_name"
        return 1
    fi
    
    log "INFO" "Building Android AAB for $project_name"
    if flutter build appbundle --release >> "$RELEASE_DIR/build.log" 2>&1; then
        cp "build/app/outputs/bundle/release/app-release.aab" "$project_release_dir/android/${project_name}-release.aab"
        log "SUCCESS" "Android AAB built successfully for $project_name"
    else
        log "ERROR" "Failed to build Android AAB for $project_name"
        return 1
    fi
    
    # Build for iOS
    log "INFO" "Building iOS IPA for $project_name"
    mkdir -p "$project_release_dir/ios"
    
    if flutter build ios --release >> "$RELEASE_DIR/build.log" 2>&1; then
        # Build archive and export IPA
        if xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release archive -archivePath "$project_release_dir/ios/${project_name}.xcarchive" >> "$RELEASE_DIR/build.log" 2>&1; then
            # Export IPA (this requires an export options plist)
            if [[ -f "ios/ExportOptions.plist" ]]; then
                xcodebuild -exportArchive -archivePath "$project_release_dir/ios/${project_name}.xcarchive" -exportPath "$project_release_dir/ios/" -exportOptionsPlist "ios/ExportOptions.plist" >> "$RELEASE_DIR/build.log" 2>&1
                log "SUCCESS" "iOS IPA built successfully for $project_name"
            else
                log "WARNING" "No ExportOptions.plist found for $project_name. Archive created but IPA not exported."
            fi
        else
            log "ERROR" "Failed to create iOS archive for $project_name"
            return 1
        fi
    else
        log "ERROR" "Failed to build iOS for $project_name"
        return 1
    fi
    
    return 0
}

# Create Android install script
create_android_install_script() {
    local android_dir="$RELEASE_DIR/android"
    local install_script="$android_dir/install-all.sh"
    
    cat > "$install_script" << 'EOF'
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
EOF

    chmod +x "$install_script"
    log "SUCCESS" "Created Android install script at $install_script"
}

# Create iOS TestFlight script (placeholder for now)
create_ios_testflight_script() {
    local ios_dir="$RELEASE_DIR/ios"
    local testflight_script="$ios_dir/upload-testflight.sh"
    
    cat > "$testflight_script" << 'EOF'
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
EOF

    chmod +x "$testflight_script"
    log "SUCCESS" "Created iOS TestFlight script at $testflight_script (requires configuration)"
}

# Main execution
main() {
    echo -e "${BLUE}=== Flutter Multi-Project Release Builder ===${NC}"
    echo -e "${BLUE}Base Directory: $BASE_DIR${NC}"
    echo -e "${BLUE}Release Directory: $RELEASE_DIR${NC}"
    echo -e "${BLUE}Version Bump: $VERSION_BUMP${NC}"
    echo -e "${BLUE}Dry Run: $DRY_RUN${NC}"
    echo ""
    
    if [[ $DRY_RUN == true ]]; then
        echo -e "${YELLOW}DRY RUN MODE - No actual builds will be performed${NC}"
        echo ""
    fi
    
    # Check if base directory exists
    if [[ ! -d "$BASE_DIR" ]]; then
        echo -e "${RED}Error: Base directory $BASE_DIR does not exist${NC}"
        exit 1
    fi
    
    # Create releases directory structure
    if [[ $DRY_RUN == false ]]; then
        mkdir -p "$RELEASE_DIR/android"
        mkdir -p "$RELEASE_DIR/ios"
        
        # Initialize build log
        echo "Flutter Multi-Project Release Build Log" > "$RELEASE_DIR/build.log"
        echo "Started: $(date)" >> "$RELEASE_DIR/build.log"
        echo "Version Bump: $VERSION_BUMP" >> "$RELEASE_DIR/build.log"
        echo "=================================" >> "$RELEASE_DIR/build.log"
    fi
    
    # Discover Flutter app projects
    log "INFO" "Scanning for directories in $BASE_DIR..."
    
    # First, list all directories found
    for item in "$BASE_DIR"/*; do
        if [[ -d "$item" ]]; then
            log "INFO" "Found directory: $(basename "$item")"
        fi
    done
    
    echo ""
    log "INFO" "Checking which directories are Flutter apps..."
    
    flutter_projects=()
    for project_dir in "$BASE_DIR"/*; do
        if [[ -d "$project_dir" ]]; then
            if is_flutter_app "$project_dir"; then
                flutter_projects+=("$project_dir")
                echo ""
            else
                echo ""
            fi
        fi
    done
    
    if [[ ${#flutter_projects[@]} -eq 0 ]]; then
        log "WARNING" "No Flutter app projects found in $BASE_DIR"
        exit 1
    fi
    
    log "INFO" "Found ${#flutter_projects[@]} Flutter app project(s):"
    for project in "${flutter_projects[@]}"; do
        log "INFO" "  - $(basename "$project")"
    done
    echo ""
    
    # Process each project
    success_count=0
    for project_dir in "${flutter_projects[@]}"; do
        project_name=$(basename "$project_dir")
        
        if [[ $DRY_RUN == true ]]; then
            echo -e "${YELLOW}Would process: $project_name${NC}"
            current_version=$(get_current_version "$project_dir")
            echo -e "${YELLOW}  Current version: $current_version${NC}"
            echo -e "${YELLOW}  Would bump: $VERSION_BUMP${NC}"
            echo -e "${YELLOW}  Would build: Android APK, AAB, iOS Archive${NC}"
            continue
        fi
        
        log "INFO" "Processing $project_name..."
        
        # Get current version
        current_version=$(get_current_version "$project_dir")
        log "INFO" "Current version: $current_version"
        
        # Bump version
        if bump_version "$project_dir" "$VERSION_BUMP"; then
            new_version=$(get_current_version "$project_dir")
            log "SUCCESS" "Version bumped from $current_version to $new_version"
        else
            log "WARNING" "Version bump failed or skipped for $project_name"
        fi
        
        # Build the app
        if build_flutter_app "$project_dir"; then
            ((success_count++))
            log "SUCCESS" "Successfully built $project_name"
        else
            log "ERROR" "Failed to build $project_name"
        fi
        
        echo ""
    done
    
    if [[ $DRY_RUN == false ]]; then
        # Create helper scripts
        create_android_install_script
        create_ios_testflight_script
        
        # Final summary
        log "INFO" "Build Summary:"
        log "INFO" "  Total projects: ${#flutter_projects[@]}"
        log "INFO" "  Successful builds: $success_count"
        log "INFO" "  Failed builds: $((${#flutter_projects[@]} - success_count))"
        log "INFO" "Release artifacts saved to: $RELEASE_DIR"
        
        echo ""
        echo -e "${GREEN}🎉 Release build complete!${NC}"
        echo -e "${BLUE}Release directory: $RELEASE_DIR${NC}"
        echo -e "${BLUE}Android installs: $RELEASE_DIR/android/install-all.sh${NC}"
        echo -e "${BLUE}iOS TestFlight: $RELEASE_DIR/ios/upload-testflight.sh${NC}"
    else
        echo -e "${YELLOW}Dry run complete. Use without --dry-run to execute builds.${NC}"
    fi
}

# Run main function
main "$@"
