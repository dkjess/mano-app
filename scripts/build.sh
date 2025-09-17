#!/bin/bash

# Build script for Mano iOS app
# Usage: ./scripts/build.sh

set -e  # Exit on any error

echo "🏗️  Building Mano iOS App..."

# Build the project for iOS 26
xcodebuild \
    -project Mano.xcodeproj \
    -scheme Mano \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
    build \
    | tee build.log

echo "✅ Build completed!"