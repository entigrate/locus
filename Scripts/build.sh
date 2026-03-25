#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Glimpse"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
BUNDLE_ID="com.glimpse.app"
RESET_PERMISSIONS=false

for arg in "$@"; do
    case "$arg" in
        --reset) RESET_PERMISSIONS=true ;;
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

echo "Signing app bundle..."
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

echo "Built successfully: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "First launch will prompt for Screen Recording and Accessibility permissions."
echo "Hotkey: Cmd+Shift+G to capture the window under your cursor."
