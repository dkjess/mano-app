#!/bin/bash

echo "🚨 PRODUCTION FIX: Apply missing migration"
echo "======================================="
echo ""
echo "This script will apply the started_working_together migration to production."
echo "This fixes the 500 error when creating persons in production."
echo ""

read -p "Are you sure you want to apply migration to PRODUCTION? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "📦 Linking to production..."
cd "$(dirname "$0")/.."

supabase link --project-ref zfroutbzdkhivnpiezho

echo ""
echo "🔍 Checking current migration status..."
supabase db remote list

echo ""
echo "📋 Applying migrations..."
supabase db push

echo ""
echo "✅ Migration applied to production!"
echo ""
echo "🧪 Running smoke tests..."
deno run --allow-net --allow-env scripts/smoke-tests.ts https://zfroutbzdkhivnpiezho.supabase.co

echo ""
echo "✅ Production fix complete!"
echo ""
echo "IMPORTANT: Now follow proper workflow for all future changes:"
echo "1. Always create feature branches"
echo "2. Always include migrations in feature branches"
echo "3. Always merge to staging first"
echo "4. Always validate in staging before production"
echo ""
