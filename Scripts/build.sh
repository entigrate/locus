#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Locus"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
BUNDLE_ID="com.locus.app"
ENTITLEMENTS="$PROJECT_DIR/Resources/Locus.entitlements"
RESET_PERMISSIONS=false
RELEASE=false

DEVELOPER_ID="Developer ID Application: Jin Lee (***REMOVED***)"
TEAM_ID="***REMOVED***"

for arg in "$@"; do
    case "$arg" in
        --reset) RESET_PERMISSIONS=true ;;
        --release) RELEASE=true ;;
    esac
done

if $RESET_PERMISSIONS; then
    echo "Resetting permissions..."
    tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null || true
    tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
    echo "Permissions reset."
fi

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

if $RELEASE; then
    # --- Release build: Developer ID signing + notarization + DMG ---

    if [ -z "${LOCUS_NOTARIZE_PASSWORD:-}" ]; then
        echo "Error: LOCUS_NOTARIZE_PASSWORD not set."
        echo "Generate an app-specific password at https://account.apple.com"
        echo "Then: export LOCUS_NOTARIZE_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
        exit 1
    fi

    APPLE_ID="***REMOVED***"
    VERSION=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleShortVersionString)
    DMG_NAME="Locus-${VERSION}.dmg"
    DMG_PATH="$PROJECT_DIR/$DMG_NAME"

    echo "Signing with Developer ID..."
    codesign --force --options runtime \
        --sign "$DEVELOPER_ID" \
        --entitlements "$ENTITLEMENTS" \
        --identifier "$BUNDLE_ID" \
        "$APP_BUNDLE"

    echo "Verifying signature..."
    codesign --verify --deep --strict "$APP_BUNDLE"
    echo "Signature OK."

    echo "Creating DMG..."
    rm -f "$DMG_PATH"
    create-dmg \
        --volname "$APP_NAME" \
        --background "$PROJECT_DIR/Resources/dmg-background.png" \
        --window-pos 200 120 \
        --window-size 540 300 \
        --icon-size 80 \
        --icon "$APP_NAME.app" 140 150 \
        --app-drop-link 400 150 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_BUNDLE"

    echo "Signing DMG..."
    codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH"

    echo "Notarizing..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$LOCUS_NOTARIZE_PASSWORD" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"

    echo ""
    echo "Release build complete: $DMG_PATH"
    echo "Ready to upload to GitHub Releases."
else
    # --- Dev build: ad-hoc signing ---
    echo "Signing app bundle (ad-hoc)..."
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

    echo "Built successfully: $APP_BUNDLE"
    echo ""
    echo "To run:"
    echo "  open $APP_BUNDLE"
    echo ""
    echo "For a signed + notarized release build:"
    echo "  ./Scripts/build.sh --release"
fi
