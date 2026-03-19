#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
STAGING_DIR="$BUILD_DIR/staging"
APP_NAME="VirtualDesktop"

# Check prerequisites
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Install Xcode and command line tools." >&2
    exit 1
fi

if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg" >&2
    exit 1
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR"

echo "Building $APP_NAME (Release)..."
xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/derived" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | tail -3

# Find the built app
APP_PATH="$BUILD_DIR/derived/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Built app not found at $APP_PATH" >&2
    exit 1
fi

# Read version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "Staging DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"
cp "$PROJECT_DIR/README.rtf" "$STAGING_DIR/"

echo "Creating DMG: $DMG_NAME..."
VOLICON_ARGS=()
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    VOLICON_ARGS=(--volicon "$APP_PATH/Contents/Resources/AppIcon.icns")
fi

create-dmg \
    --volname "$APP_NAME" \
    "${VOLICON_ARGS[@]}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 80 \
    --icon "$APP_NAME.app" 160 190 \
    --app-drop-link 440 190 \
    --icon "README.rtf" 300 340 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$STAGING_DIR"

# Clean up staging
rm -rf "$STAGING_DIR"
rm -rf "$BUILD_DIR/derived"

echo ""
echo "Done! DMG created at: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
