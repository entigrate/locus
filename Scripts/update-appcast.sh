#!/bin/bash
set -euo pipefail

# Updates docs/appcast.xml with a new release entry.
# Usage: ./Scripts/update-appcast.sh Locus-0.2.0.dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APPCAST="$PROJECT_DIR/docs/appcast.xml"

DMG_PATH="$1"
DMG_NAME="$(basename "$DMG_PATH")"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found: $DMG_PATH"
    exit 1
fi

# Extract version from DMG filename (e.g., Locus-0.2.0.dmg -> 0.2.0)
VERSION=$(echo "$DMG_NAME" | sed 's/Locus-\(.*\)\.dmg/\1/')
echo "Version: $VERSION"

# Get file size
FILE_SIZE=$(stat -f%z "$DMG_PATH")
echo "File size: $FILE_SIZE"

# Generate EdDSA signature using Sparkle's sign_update tool
SIGN_TOOL="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
if [ ! -f "$SIGN_TOOL" ]; then
    echo "Error: sign_update not found. Run 'swift package resolve' first."
    exit 1
fi

SIGNATURE=$("$SIGN_TOOL" "$DMG_PATH" 2>&1 | grep 'sparkle:edSignature' | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
if [ -z "$SIGNATURE" ]; then
    # Try alternate output format
    SIGNATURE=$("$SIGN_TOOL" "$DMG_PATH" 2>&1)
fi
echo "Signature: ${SIGNATURE:0:20}..."

DOWNLOAD_URL="https://github.com/entigrate/locus/releases/download/v${VERSION}/${DMG_NAME}"
PUB_DATE=$(date -R)

# Build the new appcast
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
        sparkle:edSignature="${SIGNATURE}"
      />
    </item>
  </channel>
</rss>
XMLEOF

echo ""
echo "Updated $APPCAST"
echo "Download URL: $DOWNLOAD_URL"
echo ""
echo "Next steps:"
echo "  1. git add docs/appcast.xml && git commit -m 'Update appcast for v${VERSION}' && git push"
echo "  2. gh release create v${VERSION} ${DMG_PATH} --repo entigrate/locus --title 'Locus v${VERSION}'"
