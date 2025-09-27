#!/bin/bash

# Safe database reset script with production protection
# This script prevents accidental production database resets

set -e

echo "🔒 Safe Database Reset Script"
echo "=============================="

# Check if we're linked to production
PROJECT_REF=$(supabase status 2>/dev/null | grep "Project ref:" | awk '{print $3}' || echo "not-linked")

if [ "$PROJECT_REF" = "zfroutbzdkhivnpiezho" ]; then
    echo "⚠️  WARNING: Currently linked to PRODUCTION database!"
    echo "   Project: zfroutbzdkhivnpiezho"
    echo ""
    echo "❌ PRODUCTION RESET BLOCKED FOR SAFETY"
    echo ""
    echo "If you really need to reset production:"
    echo "1. Manually run: supabase db reset --linked --yes"
    echo "2. But think twice - this deletes ALL production data!"
    echo ""
    echo "To reset local database instead:"
    echo "1. supabase unlink"
    echo "2. supabase db reset"
    echo ""
    exit 1
fi

# Check if local Supabase is running
if ! supabase status >/dev/null 2>&1; then
    echo "🚀 Starting local Supabase..."
    supabase start
fi

echo "✅ Safe to reset local database"
echo "   Project: $PROJECT_REF (local)"
echo ""

read -p "Reset LOCAL database? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Resetting local database..."
    supabase db reset
    echo "✅ Local database reset complete!"
else
    echo "❌ Reset cancelled"
fi