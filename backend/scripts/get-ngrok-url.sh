#!/bin/bash

# Get ngrok URL for device testing
# This script shows the current ngrok tunnel URL

echo "🔍 Checking for ngrok tunnel..."

# Check if ngrok is running
if ! pgrep -f "ngrok" > /dev/null; then
    echo "❌ ngrok is not running"
    echo "   Start ngrok with: ngrok http 54321"
    exit 1
fi

# Try to get the tunnel URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null)

if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
    echo "✅ ngrok tunnel is running"
    echo ""
    echo "📋 Device Testing URLs:"
    echo "   Public URL: $NGROK_URL"
    echo "   Local URL:  http://127.0.0.1:54321"
    echo "   Web UI:     http://localhost:4040"
    echo ""
    echo "📱 To test on iOS device:"
    echo "   1. Update Mano/Config.swift supabaseURL to:"
    echo "      $NGROK_URL"
    echo "   2. Build and run on device via Xcode"
    echo "   3. Remember to revert to localhost for simulator"
else
    echo "❌ Could not get ngrok URL"
    echo "   Check if ngrok is properly running with: ngrok http 54321"
    echo "   Web interface: http://localhost:4040"
fi