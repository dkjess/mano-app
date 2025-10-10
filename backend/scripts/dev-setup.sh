#!/bin/bash

# Mano Local Development Setup Script
# This script ensures Supabase runs correctly with all necessary services and environment variables

set -e  # Exit on any error

echo "🚀 Setting up Mano local development environment..."

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "❌ .env.local file not found!"
    echo "   Please create .env.local with the required environment variables."
    echo "   See docs/LOCAL_DEVELOPMENT.md for details."
    exit 1
fi

echo "✅ Found .env.local file"

# Stop any existing Supabase instance
echo "🛑 Stopping any existing Supabase services..."
supabase stop || true

# Start Supabase
echo "🔄 Starting Supabase services..."
supabase start

# Check if Edge Runtime is working
echo "🔍 Checking Edge Runtime status..."
if docker ps | grep -q "supabase_edge_runtime_mano"; then
    echo "✅ Edge Runtime container is running"
else
    echo "⚠️  Edge Runtime container not found, restarting..."
    supabase stop
    supabase start
fi

echo ""
echo "🎯 Local Supabase is ready!"
echo "   API URL: http://127.0.0.1:54321"
echo "   Studio URL: http://127.0.0.1:54323"
echo "   DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres"
echo ""

# Prompt user about Edge Functions
echo "🔧 Do you want to serve Edge Functions with environment variables? (y/n)"
read -r serve_functions

if [[ $serve_functions =~ ^[Yy]$ ]]; then
    echo "🔄 Starting Edge Functions with environment variables..."
    echo "   This will run in the background. Use 'pkill -f \"supabase functions serve\"' to stop."
    echo ""
    
    # Start Edge Functions in background
    nohup supabase functions serve --env-file .env.local > edge-functions.log 2>&1 &
    EDGE_PID=$!
    
    # Wait a moment for startup
    sleep 3
    
    # Check if it's running
    if kill -0 $EDGE_PID 2>/dev/null; then
        echo "✅ Edge Functions are running with environment variables"
        echo "   Chat function: http://127.0.0.1:54321/functions/v1/chat"
        echo "   Logs: tail -f edge-functions.log"
        echo "   PID: $EDGE_PID"
    else
        echo "❌ Failed to start Edge Functions"
        exit 1
    fi
else
    echo "⏭️  Skipping Edge Functions setup"
    echo "   You can start them later with: supabase functions serve --env-file .env.local"
fi

# Prompt user about ngrok for device testing
echo ""
echo "📱 Do you want to start ngrok for device testing? (y/n)"
read -r start_ngrok

if [[ $start_ngrok =~ ^[Yy]$ ]]; then
    # Check if ngrok is installed
    if ! command -v ngrok &> /dev/null; then
        echo "❌ ngrok is not installed"
        echo "   Install ngrok from: https://ngrok.com/download"
        echo "   Or use: brew install ngrok"
    else
        echo "🔄 Starting ngrok tunnel for Supabase with custom domain..."
        echo "   This will run in the background. Use 'pkill ngrok' to stop."
        echo "   Using permanent domain: mano.ngrok.app"

        # Start ngrok in background with custom domain
        nohup ngrok http --url=mano.ngrok.app 54321 > ngrok.log 2>&1 &
        NGROK_PID=$!

        # Wait for ngrok to start
        sleep 3

        # Try to get the tunnel URL
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")

        if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
            echo "✅ ngrok tunnel is running"
            echo "   Public URL: $NGROK_URL (permanent domain)"
            echo "   Local URL: http://127.0.0.1:54321"
            echo "   ngrok Web Interface: http://localhost:4040"
            echo "   PID: $NGROK_PID"
            echo ""
            echo "📋 To test on iOS device:"
            echo "   1. Build and run on device via Xcode"
            echo "   2. Shake device to access developer settings"
            echo "   3. Select 'Local (ngrok)' environment"
            echo "   Note: BackendEnvironment.swift already configured with mano.ngrok.app"
        else
            echo "❌ Failed to get ngrok URL. Check ngrok.log for details."
        fi
    fi
else
    echo "⏭️  Skipping ngrok setup"
    echo "   You can start it later with: ngrok http --url=mano.ngrok.app 54321"
fi

echo ""
echo "🎉 Local development environment is ready!"
echo ""
echo "Next steps:"
echo "   1. Seed test data: npm run seed:dev"
echo "   2. Open iOS project: open ../Mano.xcodeproj"
echo "   3. Run iOS app in Xcode simulator"
echo ""
echo "To stop everything:"
echo "   - Stop Edge Functions: pkill -f \"supabase functions serve\""
echo "   - Stop ngrok: pkill ngrok"
echo "   - Stop Supabase: supabase stop"