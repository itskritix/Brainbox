#!/bin/bash
#
# update_appcast.sh — Merges a new <item> into appcast.xml
#
# Usage: ./scripts/update_appcast.sh appcast_item.xml
#
# Reads the existing appcast.xml (from /tmp or creates a new one),
# inserts the new item, and writes the result to /tmp/appcast.xml
# for deployment.

set -euo pipefail

ITEM_FILE="${1:?Usage: update_appcast.sh <appcast_item.xml>}"

APPCAST_PATH="/tmp/appcast.xml"

# Create appcast.xml template if it doesn't exist
if [ ! -f "$APPCAST_PATH" ]; then
    # Try to fetch existing appcast from brainbox.sh
    curl -fsSL "https://brainbox.sh/appcast.xml" -o "$APPCAST_PATH" 2>/dev/null || true
fi

if [ ! -f "$APPCAST_PATH" ]; then
    cat > "$APPCAST_PATH" << 'TEMPLATE'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
    xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
    xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Brainbox Updates</title>
        <link>https://brainbox.sh/appcast.xml</link>
        <description>Updates for Brainbox</description>
        <language>en</language>
    </channel>
</rss>
TEMPLATE
    echo "Created new appcast.xml template"
fi

# Read the new item content
NEW_ITEM=$(cat "$ITEM_FILE")

# Insert the new item before </channel>
sed -i.bak "s|</channel>|${NEW_ITEM}\n    </channel>|" "$APPCAST_PATH"
rm -f "${APPCAST_PATH}.bak"

echo "Updated appcast.xml at $APPCAST_PATH"
echo "---"
cat "$APPCAST_PATH"
