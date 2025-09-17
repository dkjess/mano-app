#!/bin/bash

# Focus on just the MainActor and critical errors
# Usage: ./scripts/focus-errors.sh

set -e  # Exit on any error

echo "🎯 Focusing on critical errors..."

# Build and filter for just the critical errors we care about
xcodebuild \
    -project Mano.xcodeproj \
    -scheme Mano \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
    build 2>&1 | \
    grep -E "(MainActor|Sendable|Decodable|error:)" | \
    head -20

echo "🎯 Critical errors summary completed!"