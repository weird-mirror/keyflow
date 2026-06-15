#!/bin/bash
# Builds KeyFlow.app and a drag-to-install DMG.
# Usage: ./build_app.sh [debug|release]

set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
case "$CONFIG" in
    debug)   FLAGS="-Onone -g" ;;
    release) FLAGS="-O" ;;
    *) echo "usage: $0 [debug|release]"; exit 2 ;;
esac

APP_NAME="KeyFlow"
BUNDLE_ID="com.keyflow.app"
VERSION="0.3.1"

OUT_DIR=".build/app"
APP_PATH="$OUT_DIR/$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"
DMG_DIR=".build/dmg"
DMG_STAGING="$DMG_DIR/staging"
DMG_PATH="$DMG_DIR/$APP_NAME-$VERSION.dmg"

rm -rf "$APP_PATH" "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$DMG_STAGING"

SRC=(
    Sources/KeyboardSwitcher/KeyTranslator.swift
    Sources/KeyboardSwitcher/BloomDictionary.swift
    Sources/KeyboardSwitcher/ExceptionsStore.swift
    Sources/KeyboardSwitcher/LayoutDetector.swift
    Sources/KeyboardSwitcher/WordBuffer.swift
    Sources/KeyboardSwitcher/AppContext.swift
    Sources/KeyboardSwitcher/FocusContext.swift
    Sources/KeyboardSwitcher/LayoutSwitcher.swift
    Sources/KeyboardSwitcher/Replayer.swift
    Sources/KeyboardSwitcher/EventTap.swift
    Sources/KeyboardSwitcher/HotkeyManager.swift
    Sources/KeyboardSwitcher/HotkeySpec.swift
    Sources/KeyboardSwitcher/Settings.swift
    Sources/KeyboardSwitcher/Links.swift
    Sources/KeyboardSwitcher/Coordinator.swift
    Sources/KeyboardSwitcher/LaunchAtLogin.swift
    Sources/KeyboardSwitcher/MenuBarController.swift
    Sources/KeyboardSwitcher/SettingsWindow.swift
    Sources/KeyboardSwitcher/AppDelegate.swift
    Sources/KeyboardSwitcher/main.swift
)

echo "Compiling $APP_NAME ($CONFIG)..."
swiftc $FLAGS -o "$CONTENTS/MacOS/$APP_NAME" "${SRC[@]}"

# Icon: convert icon.png at project root into AppIcon.icns if present.
ICON_KEY=""
if [ -f "icon.png" ]; then
    echo "Generating AppIcon.icns..."
    ./scripts/make_icns.sh icon.png "$CONTENTS/Resources/AppIcon.icns"
    ICON_KEY=$'\n    <key>CFBundleIconFile</key>\n    <string>AppIcon</string>'
else
    echo "(no icon.png at project root — using generic .app icon)"
fi

# Info.plist
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>$ICON_KEY
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>$APP_NAME needs to read keystrokes to detect and correct wrong-layout typing.</string>
</dict>
</plist>
EOF

# Dictionaries
for name in en ru ua; do
    src="Sources/KeyboardSwitcher/Resources/$name.txt"
    if [ -f "$src" ]; then
        cp "$src" "$CONTENTS/Resources/"
    fi
done

# Sign so macOS can identify the bundle for TCC/Accessibility.
# A STABLE signing identity is critical: ad-hoc signatures change their cdhash
# on every build, which makes macOS silently revoke the Accessibility grant
# (the recurring "stopped working after rebuild" bug). Signing with a fixed
# self-signed cert keeps the designated requirement constant, so the grant
# persists across rebuilds and updates. Falls back to ad-hoc if the cert is
# absent (e.g. building on another machine).
SIGN_IDENTITY="KeyFlow Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
    echo "Signing with stable identity: $SIGN_IDENTITY"
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_PATH"
else
    echo "WARNING: '$SIGN_IDENTITY' not found — falling back to ad-hoc (Accessibility will break on rebuild)"
    codesign --force --deep --sign - "$APP_PATH"
fi

# Build DMG with drag-to-Applications layout.
echo "Building $DMG_PATH..."
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" >/dev/null

echo ""
echo "Built:"
echo "  $APP_PATH"
echo "  $DMG_PATH"
echo ""
echo "Install:"
echo "  open '$DMG_PATH'    # then drag $APP_NAME.app onto Applications"
