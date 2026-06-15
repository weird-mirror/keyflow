#!/bin/bash
# Standalone test runner — bypasses SPM/XCTest.
# Once SPM works again, prefer `swift test`.

set -euo pipefail

cd "$(dirname "$0")"

OUT=".build/manual"
mkdir -p "$OUT"

# Core modules under test (no main.swift, no macOS-only event tap modules).
LIB_SRC=(
    Sources/KeyboardSwitcher/KeyTranslator.swift
    Sources/KeyboardSwitcher/BloomDictionary.swift
    Sources/KeyboardSwitcher/ExceptionsStore.swift
    Sources/KeyboardSwitcher/LayoutDetector.swift
    Sources/KeyboardSwitcher/WordBuffer.swift
)

echo "Building test runner..."
swiftc -Onone -g -o "$OUT/run_tests" \
    "${LIB_SRC[@]}" \
    Tests/standalone_runner.swift

echo "Running tests..."
"$OUT/run_tests"
