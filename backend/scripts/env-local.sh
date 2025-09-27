#!/bin/bash

# Start local development environment
# This script coordinates the backend to run locally when iOS app uses "Local" environment

set -e

echo "🟢 Starting LOCAL development environment"
echo "========================================"

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed. Please install it first:"
    echo "   brew install ngrok"
    exit 1
fi

# Source environment detection
source scripts/check-env.sh

# Warn if linked to production
if warn_if_production; then
    echo "❌ Cannot start local environment while linked to production"
    echo "   Run: supabase unlink"
    exit 1
fi

# Start Supabase if not running
if ! supabase status >/dev/null 2>&1; then
    echo "🚀 Starting local Supabase..."
    supabase start
else
    echo "✅ Supabase already running locally"
fi

# Start Edge Functions in background
echo "🔧 Starting Edge Functions with local environment..."
if pgrep -f "supabase functions serve" > /dev/null; then
    echo "⚠️  Edge Functions already running. Stopping first..."
    pkill -f "supabase functions serve" || true
    sleep 2
fi

# Start functions in background
nohup supabase functions serve --env-file .env.local > functions.log 2>&1 &
echo "✅ Edge Functions started (logs: functions.log)"

# Start ngrok tunnel in background
echo "🌐 Starting ngrok tunnel..."
if pgrep -f "ngrok http 54321" > /dev/null; then
    echo "⚠️  ngrok already running. Stopping first..."
    pkill -f "ngrok http 54321" || true
    sleep 2
fi

nohup ngrok http 54321 > ngrok.log 2>&1 &
echo "✅ ngrok tunnel started (logs: ngrok.log)"

# Wait for ngrok to start and get URL
echo "⏳ Waiting for ngrok tunnel..."
sleep 3

NGROK_URL=$(./scripts/get-ngrok-url.sh)
if [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL"
    exit 1
fi

echo ""
echo "🎉 LOCAL ENVIRONMENT READY!"
echo "=========================="
echo "📱 Update your iOS Config.swift with:"
echo "   Local ngrok URL: $NGROK_URL"
echo ""
echo "🔧 Services running:"
echo "   • Supabase API: http://127.0.0.1:54321"
echo "   • Supabase Studio: http://127.0.0.1:54323"
echo "   • Edge Functions: http://127.0.0.1:54321/functions/v1/"
echo "   • ngrok tunnel: $NGROK_URL"
echo ""
echo "📋 Next steps:"
echo "   1. Update iOS app's BackendEnvironment.local URL to: $NGROK_URL"
echo "   2. Select 'Local (ngrok)' in iOS app environment picker"
echo "   3. Test the full flow"
echo ""
echo "🛑 To stop: ./scripts/env-stop.sh"