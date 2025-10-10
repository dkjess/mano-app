#!/bin/bash

# Build test script for Mano iOS app
# Always uses iPhone 17 with iOS 26.0 for consistency

set -e

echo "🔨 Testing Mano iOS Build"
echo "========================="
echo "Target: iPhone 17 (iOS 26.0)"
echo ""

# Set consistent build parameters
PROJECT="Mano.xcodeproj"
SCHEME="Mano"
CONFIGURATION="Debug"
DESTINATION="platform=iOS Simulator,name=iPhone 17,OS=26.0"

# Run the build and capture output
echo "🚀 Starting build..."
echo ""

# Run the build and capture output
if xcodebuild -project "$PROJECT" \
              -scheme "$SCHEME" \
              -configuration "$CONFIGURATION" \
              -destination "$DESTINATION" \
              build 2>&1 | tee /tmp/mano-build.log; then

    # Check for specific success/failure indicators
    if grep -q "BUILD FAILED" /tmp/mano-build.log; then
        echo ""
        echo "❌ Build FAILED!"
        echo ""
        echo "Full log saved to: /tmp/mano-build.log"
        echo ""
        echo "Errors found:"
        echo "============="
        grep "error:" /tmp/mano-build.log | head -20
        exit 1
    else
        echo ""
        echo "✅ Build SUCCEEDED!"
        echo ""
        # Show any warnings if present
        if grep -q "warning:" /tmp/mano-build.log; then
            echo "Warnings found:"
            echo "==============="
            grep "warning:" /tmp/mano-build.log | head -10
            echo ""
        fi
    fi
else
    echo ""
    echo "❌ Build FAILED!"
    echo ""
    echo "Full log saved to: /tmp/mano-build.log"
    exit 1
fi