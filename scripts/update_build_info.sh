#!/bin/bash

# Update build info for this app

APP_NAME="$1"
BUILD_VERSION="$2"
BUILD_DATE="$3"

if [[ -z "$APP_NAME" || -z "$BUILD_VERSION" || -z "$BUILD_DATE" ]]; then
    echo "Usage: $0 <app_name> <build_version> <build_date>"
    exit 1
fi

RELEASES_DIR="../releases"
BUILD_INFO_FILE="$RELEASES_DIR/build_info.json"

mkdir -p "$RELEASES_DIR"

# Create or update build info
if [[ -f "$BUILD_INFO_FILE" ]]; then
    # If jq is available, update properly
    if command -v jq &> /dev/null; then
        # Create a temporary file for the update
        TEMP_FILE=$(mktemp)
        jq --arg app "$APP_NAME" --arg version "$BUILD_VERSION" --arg date "$BUILD_DATE" \
           '.apps[$app] = {version: $version, build_date: $date, platforms: []}' \
           "$BUILD_INFO_FILE" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$BUILD_INFO_FILE"
    else
        # Simple append without jq
        echo "Build completed for $APP_NAME v$BUILD_VERSION at $BUILD_DATE" >> "$RELEASES_DIR/build_log.txt"
    fi
else
    # Create new build info file
    if command -v jq &> /dev/null; then
        jq -n --arg app "$APP_NAME" --arg version "$BUILD_VERSION" --arg date "$BUILD_DATE" \
           '{last_build: $date, apps: {($app): {version: $version, build_date: $date, platforms: []}}}' \
           > "$BUILD_INFO_FILE"
    else
        # Simple JSON without jq
        cat > "$BUILD_INFO_FILE" << EOF
{
  "last_build": "$BUILD_DATE",
  "apps": {
    "$APP_NAME": {
      "version": "$BUILD_VERSION",
      "build_date": "$BUILD_DATE",
      "platforms": []
    }
  }
}
EOF
    fi
fi

echo "Build info updated for $APP_NAME"
