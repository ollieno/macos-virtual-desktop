#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
STAGING_DIR="$BUILD_DIR/staging"
APP_NAME="VirtualDesktop"
PLIST="$PROJECT_DIR/$APP_NAME/Info.plist"

# Optional version bump: ./build-dmg.sh 1.2.0
if [ "${1:-}" != "" ]; then
    NEW_VERSION="$1"

    # Validate semver format
    if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must be in X.Y.Z format (e.g. 1.2.0)" >&2
        exit 1
    fi

    # Read and increment build number
    OLD_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
    NEW_BUILD=$((OLD_BUILD + 1))

    # Update Info.plist
    /usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $NEW_VERSION" "$PLIST"
    /usr/libexec/PlistBuddy -c "Set CFBundleVersion $NEW_BUILD" "$PLIST"

    echo "Version bumped to $NEW_VERSION (Build $NEW_BUILD)"

    # Commit the version bump
    git -C "$PROJECT_DIR" add "$PLIST"
    git -C "$PROJECT_DIR" commit -m "release: bump version to $NEW_VERSION (build $NEW_BUILD)"
fi

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
    --window-size 500 340 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 130 150 \
    --app-drop-link 370 150 \
    --icon "README.rtf" 250 290 \
    --icon ".VolumeIcon.icns" 900 900 \
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
