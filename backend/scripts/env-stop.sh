#!/bin/bash

# Stop all environment services
# This script stops local development services

set -e

echo "🛑 Stopping development environment"
echo "=================================="

# Stop Edge Functions
if pgrep -f "supabase functions serve" > /dev/null; then
    echo "🔧 Stopping Edge Functions..."
    pkill -f "supabase functions serve" || true
    echo "✅ Edge Functions stopped"
else
    echo "✅ Edge Functions not running"
fi

# Stop ngrok
if pgrep -f "ngrok http 54321" > /dev/null; then
    echo "🌐 Stopping ngrok tunnel..."
    pkill -f "ngrok http 54321" || true
    echo "✅ ngrok tunnel stopped"
else
    echo "✅ ngrok tunnel not running"
fi

# Stop Supabase (optional)
read -p "Stop local Supabase too? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Stopping local Supabase..."
    supabase stop
    echo "✅ Local Supabase stopped"
else
    echo "✅ Local Supabase left running"
fi

# Clean up log files
if [ -f "functions.log" ]; then
    rm functions.log
    echo "🧹 Cleaned up functions.log"
fi

if [ -f "ngrok.log" ]; then
    rm ngrok.log
    echo "🧹 Cleaned up ngrok.log"
fi

echo ""
echo "✅ Environment cleanup complete!"