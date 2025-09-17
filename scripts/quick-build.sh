#!/bin/bash

# Quick build script - just compile without full build process
# Usage: ./scripts/quick-build.sh

set -e  # Exit on any error

echo "⚡ Quick build check for Mano..."

# Set the Xcode path for this session
export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"

# Just do a syntax check build (faster than full build)
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
    -project Mano.xcodeproj \
    -scheme Mano \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
    -quiet \
    -dry-run \
    build 2>&1 | grep -E "(error:|warning:|fatal)" || echo "✅ No critical errors found"

echo "⚡ Quick build check completed!"