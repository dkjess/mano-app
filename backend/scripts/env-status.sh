#!/bin/bash

# Show current environment status
# This script shows what backend services are running and which environment is active

set -e

echo "📊 Environment Status"
echo "===================="

# Source environment detection
source scripts/check-env.sh

# Check Supabase link status
echo "🔗 Supabase Connection:"
if check_production_link >/dev/null; then
    echo "   🔴 PRODUCTION (zfroutbzdkhivnpiezho)"
    echo "   ⚠️  WARNING: Connected to live production data!"
else
    echo "   🟢 LOCAL"
fi

echo ""

# Check if local Supabase is running
echo "💾 Local Supabase:"
if supabase status >/dev/null 2>&1; then
    echo "   ✅ Running"
    echo "   📍 API: http://127.0.0.1:54321"
    echo "   📍 Studio: http://127.0.0.1:54323"
else
    echo "   ❌ Not running"
fi

echo ""

# Check Edge Functions
echo "🔧 Edge Functions:"
if pgrep -f "supabase functions serve" > /dev/null; then
    echo "   ✅ Running locally"
    echo "   📍 URL: http://127.0.0.1:54321/functions/v1/"
else
    echo "   ❌ Not running locally"
fi

echo ""

# Check ngrok
echo "🌐 ngrok Tunnel:"
if pgrep -f "ngrok http 54321" > /dev/null; then
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
    if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
        echo "   ✅ Running"
        echo "   📍 Public URL: $NGROK_URL"
    else
        echo "   ⚠️  Running but URL unavailable"
    fi
else
    echo "   ❌ Not running"
fi

echo ""

# Current iOS BackendEnvironment recommendations
echo "📱 iOS App Environment Recommendations:"
if check_production_link >/dev/null; then
    echo "   🔴 Select 'Production' in iOS app"
    echo "   📍 URL: https://zfroutbzdkhivnpiezho.supabase.co"
else
    if pgrep -f "ngrok http 54321" > /dev/null; then
        if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
            echo "   🟢 Select 'Local (ngrok)' in iOS app"
            echo "   📍 URL: $NGROK_URL"
            echo "   💡 Update BackendEnvironment.local with this URL"
        else
            echo "   ⚠️  ngrok running but URL unavailable"
        fi
    elif supabase status >/dev/null 2>&1; then
        echo "   🖥️  Select 'Local (Simulator)' in iOS app"
        echo "   📍 URL: http://127.0.0.1:54321"
        echo "   💡 This only works in iOS Simulator"
    else
        echo "   ❌ No backend services running"
    fi
fi

echo ""
echo "🔧 Available Commands:"
echo "   ./scripts/env-local.sh      - Start local development"
echo "   ./scripts/env-production.sh - Switch to production"
echo "   ./scripts/env-stop.sh       - Stop local services"
echo "   ./scripts/env-status.sh     - Show this status"