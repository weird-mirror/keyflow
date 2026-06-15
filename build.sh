#!/bin/bash
# Manual build script — bypasses SPM (broken in CommandLineTools 26.x).
# Once you install Xcode or fix CLT, prefer `swift build`.

set -euo pipefail

cd "$(dirname "$0")"

OUT=".build/manual"
mkdir -p "$OUT"

SRC=(
    Sources/KeyboardSwitcher/KeyTranslator.swift
    Sources/KeyboardSwitcher/BloomDictionary.swift
    Sources/KeyboardSwitcher/ExceptionsStore.swift
    Sources/KeyboardSwitcher/LayoutDetector.swift
    Sources/KeyboardSwitcher/WordBuffer.swift
    Sources/KeyboardSwitcher/AppContext.swift
    Sources/KeyboardSwitcher/LayoutSwitcher.swift
    Sources/KeyboardSwitcher/Replayer.swift
    Sources/KeyboardSwitcher/EventTap.swift
    Sources/KeyboardSwitcher/HotkeyManager.swift
    Sources/KeyboardSwitcher/HotkeySpec.swift
    Sources/KeyboardSwitcher/Settings.swift
    Sources/KeyboardSwitcher/Coordinator.swift
    Sources/KeyboardSwitcher/main.swift
)

CONFIG="${1:-debug}"
case "$CONFIG" in
    debug)   FLAGS="-Onone -g" ;;
    release) FLAGS="-O" ;;
    *) echo "usage: $0 [debug|release]"; exit 2 ;;
esac

echo "Building kbswitcher ($CONFIG)..."
swiftc $FLAGS -o "$OUT/kbswitcher" "${SRC[@]}"

# Ad-hoc sign so macOS can identify the binary for Accessibility/TCC.
# Unsigned CLI binaries can be added to the Accessibility list but the toggle
# doesn't actually apply — the OS can't bind a stable identity.
codesign --force --sign - "$OUT/kbswitcher"

echo "→ $OUT/kbswitcher"
