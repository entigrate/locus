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
install_name_tool -add_rpath @executable_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Bundle Sparkle framework
SPARKLE_PATH=$(find .build -path "*/Sparkle.framework" -maxdepth 5 -type d | head -1)
if [ -n "$SPARKLE_PATH" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    cp -R "$SPARKLE_PATH" "$APP_BUNDLE/Contents/Frameworks/"
fi

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
    # Sign Sparkle framework binaries first (deep inside out)
    if [ -d "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" ]; then
        SPARKLE_FW="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
        find "$SPARKLE_FW" -name "*.xpc" -type d | while read -r xpc; do
            codesign --force --options runtime --sign "$DEVELOPER_ID" "$xpc"
        done
        for bin in "$SPARKLE_FW/Versions/B/Autoupdate" \
                   "$SPARKLE_FW/Versions/B/Updater.app"; do
            if [ -e "$bin" ]; then
                codesign --force --options runtime --sign "$DEVELOPER_ID" "$bin"
            fi
        done
        codesign --force --options runtime --sign "$DEVELOPER_ID" "$SPARKLE_FW"
    fi
    # Sign the main app bundle
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

    # --- Sign for Sparkle auto-updates ---
    echo "Signing for Sparkle..."
    SIGN_TOOL="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
    SPARKLE_SIG=$("$SIGN_TOOL" "$DMG_PATH" | grep 'sparkle:edSignature' | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
    FILE_SIZE=$(stat -f%z "$DMG_PATH")
    DOWNLOAD_URL="https://github.com/entigrate/locus/releases/download/v${VERSION}/${DMG_NAME}"
    PUB_DATE=$(date -R)

    echo "Updating appcast..."
    APPCAST="$PROJECT_DIR/docs/appcast.xml"
    cat > "$APPCAST" << XMLEOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Locus</title>
    <link>https://locusapp.dev/appcast.xml</link>
    <description>Locus update feed</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${DOWNLOAD_URL}"
        length="${FILE_SIZE}"
        type="application/octet-stream"
        sparkle:edSignature="${SPARKLE_SIG}"
      />
    </item>
  </channel>
</rss>
XMLEOF

    # --- Update Homebrew cask ---
    echo "Updating Homebrew cask..."
    DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
    TAP_DIR="/tmp/homebrew-tap-release"
    rm -rf "$TAP_DIR"
    git clone git@github.com:entigrate/homebrew-tap.git "$TAP_DIR"
    cat > "$TAP_DIR/Casks/locus.rb" << CASKEOF
cask "locus" do
  version "${VERSION}"
  sha256 "${DMG_SHA256}"

  url "https://github.com/entigrate/locus/releases/download/v#{version}/Locus-#{version}.dmg"
  name "Locus"
  desc "Capture the window under your cursor with one hotkey"
  homepage "https://locusapp.dev"

  depends_on macos: ">= :sonoma"

  app "Locus.app"

  zap trash: [
    "~/Library/Caches/com.locus.app",
    "~/Library/Preferences/com.locus.app.plist",
  ]
end
CASKEOF
    cd "$TAP_DIR"
    git add Casks/locus.rb
    git commit -m "Update Locus to v${VERSION}"
    git push
    cd "$PROJECT_DIR"
    rm -rf "$TAP_DIR"

    # --- Publish ---
    echo "Publishing to GitHub..."
    git add "$APPCAST"
    git commit -m "Update appcast for v${VERSION}"
    git push

    unset GITHUB_TOKEN
    gh release create "v${VERSION}" "$DMG_PATH" \
        --repo entigrate/locus \
        --title "Locus v${VERSION}" \
        --generate-notes

    echo ""
    echo "Release v${VERSION} published!"
    echo "  DMG: $DMG_PATH"
    echo "  Release: https://github.com/entigrate/locus/releases/tag/v${VERSION}"
    echo "  Appcast: https://locusapp.dev/appcast.xml"
    echo "  Homebrew: brew install entigrate/tap/locus"
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
