#!/bin/bash

echo "🧪 End-to-End Person Creation Test"
echo "==================================="
echo ""

# Run backend test
echo "1️⃣ Testing backend API..."
deno run --allow-net --allow-env /Users/jess/code/Mano/backend/scripts/test-person-creation.ts
BACKEND_RESULT=$?

if [ $BACKEND_RESULT -ne 0 ]; then
    echo "❌ Backend test failed"
    exit 1
fi

echo ""
echo "2️⃣ Testing Swift date decoder..."
swift /Users/jess/code/Mano/backend/scripts/test-swift-decode.swift
SWIFT_RESULT=$?

if [ $SWIFT_RESULT -ne 0 ]; then
    echo "❌ Swift decoder test failed"
    exit 1
fi

echo ""
echo "3️⃣ Building iOS app..."
cd /Users/jess/code/Mano && ./scripts/build-test.sh > /dev/null 2>&1
BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    echo "❌ iOS build failed"
    exit 1
else
    echo "✅ iOS build succeeded"
fi

echo ""
echo "🎉 All tests passed!"
echo ""
echo "✅ Backend API works"
echo "✅ Swift decoder handles date-only strings"
echo "✅ iOS app builds successfully"
echo ""
echo "👉 Person creation should now work in the app!"
