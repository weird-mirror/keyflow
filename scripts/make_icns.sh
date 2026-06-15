#!/bin/bash
# Generate AppIcon.icns from a source PNG.
# Usage: ./make_icns.sh <input.png> <output.icns>

set -euo pipefail

SRC="${1:?missing source PNG}"
OUT="${2:?missing output .icns}"

if [ ! -f "$SRC" ]; then
    echo "Source not found: $SRC"
    exit 1
fi

# Build iconset with all required sizes.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

for spec in \
    "16    16x16" \
    "32    16x16@2x" \
    "32    32x32" \
    "64    32x32@2x" \
    "128   128x128" \
    "256   128x128@2x" \
    "256   256x256" \
    "512   256x256@2x" \
    "512   512x512" \
    "1024  512x512@2x"
do
    size=$(echo "$spec" | awk '{print $1}')
    name=$(echo "$spec" | awk '{print $2}')
    sips -z "$size" "$size" "$SRC" --out "$ICONSET/icon_$name.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT"
echo "→ $OUT"
