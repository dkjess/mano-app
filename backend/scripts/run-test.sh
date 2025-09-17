#!/bin/bash

# Comprehensive Mano Testing Script Runner
# This script sets up the environment and runs comprehensive tests

echo "🚀 Starting Mano Comprehensive Testing"
echo "======================================"

# Check if services are running
echo "🔧 Checking services..."

# Check Next.js
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ Next.js dev server is running"
else
    echo "❌ Next.js dev server is not running. Please start with 'pnpm dev'"
    exit 1
fi

# Check Supabase
if supabase status | grep -q "supabase local development setup is running"; then
    echo "✅ Supabase is running"
else
    echo "❌ Supabase is not running. Please start with 'supabase start'"
    exit 1
fi

echo ""
echo "🧪 Running comprehensive tests..."

# Create test outputs directory
mkdir -p ./test-outputs

# Run the test script
node ./scripts/comprehensive-test.js

echo ""
echo "📋 Test completed. Check ./test-outputs/ for screenshots and detailed logs."
echo "🔍 Browser is left open for manual inspection."