#!/bin/bash

# Switch to production environment
# This script coordinates the backend to use production when iOS app uses "Production" environment

set -e

echo "🔴 Switching to PRODUCTION environment"
echo "====================================="

# Source environment detection
source scripts/check-env.sh

# Check if already linked to production
if check_production_link >/dev/null; then
    echo "✅ Already linked to production"
else
    echo "🔗 Linking to production project..."
    supabase link --project-ref zfroutbzdkhivnpiezho
fi

# Stop local services
echo "🛑 Stopping local services..."
if pgrep -f "supabase functions serve" > /dev/null; then
    echo "   Stopping Edge Functions..."
    pkill -f "supabase functions serve" || true
fi

if pgrep -f "ngrok http 54321" > /dev/null; then
    echo "   Stopping ngrok tunnel..."
    pkill -f "ngrok http 54321" || true
fi

echo "✅ Local services stopped"

# Deploy functions to production
echo "🚀 Deploying Edge Functions to production..."
supabase functions deploy

echo ""
echo "🎉 PRODUCTION ENVIRONMENT READY!"
echo "==============================="
echo "🔴 You are now connected to PRODUCTION"
echo "   Project: zfroutbzdkhivnpiezho"
echo "   URL: https://zfroutbzdkhivnpiezho.supabase.co"
echo ""
echo "📋 Next steps:"
echo "   1. Select 'Production' in iOS app environment picker"
echo "   2. Test the full flow with production data"
echo ""
echo "⚠️  IMPORTANT WARNINGS:"
echo "   • You are working with LIVE PRODUCTION DATA"
echo "   • Any changes affect real users"
echo "   • Database operations are permanent"
echo ""
echo "🟢 To switch back to local: ./scripts/env-local.sh"