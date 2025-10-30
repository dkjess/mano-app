#!/bin/bash

# Pre-commit test hook
# Runs core tests before allowing commit
# To bypass (emergencies only): git commit --no-verify

set -e

echo "🧪 Running pre-commit tests..."
echo ""

# Change to backend directory
cd "$(dirname "$0")/.." || exit 1

# Check if Supabase is running
if ! curl -s http://127.0.0.1:54321/rest/v1/ > /dev/null 2>&1; then
  echo "⚠️  Warning: Supabase doesn't appear to be running"
  echo "   Tests may fail. Start with: supabase start"
  echo ""
fi

# Run core tests
echo "Running core test suite..."
if npm run test:core --silent; then
  echo ""
  echo "✅ All pre-commit tests passed!"
  echo ""
  exit 0
else
  echo ""
  echo "❌ Tests failed! Commit blocked."
  echo ""
  echo "To fix:"
  echo "  1. Review test failures above"
  echo "  2. Fix the issues"
  echo "  3. Run: npm run test:core"
  echo "  4. Try committing again"
  echo ""
  echo "To bypass (emergencies only):"
  echo "  git commit --no-verify"
  echo ""
  exit 1
fi
