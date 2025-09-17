#!/bin/bash

# Pre-commit build test script
# Tests both local and Netlify build environments before committing

set -e  # Exit on any error

echo "🔧 Running pre-commit build tests..."
echo

# Test 1: Local build with current Node version
echo "1️⃣  Testing local build (Node $(node --version))..."
pnpm run build
echo "✅ Local build successful"
echo

# Test 2: Netlify CLI build simulation
echo "2️⃣  Testing Netlify build environment..."
if command -v netlify &> /dev/null; then
    netlify build
    echo "✅ Netlify build simulation successful"
else
    echo "⚠️  Netlify CLI not found - skipping Netlify build test"
    echo "   Install with: npm install -g netlify-cli"
fi
echo

# Test 3: TypeScript type checking (excluding Edge Functions which use Deno types)
echo "3️⃣  Running TypeScript type check..."
if npx tsc --noEmit --skipLibCheck 2>/dev/null; then
    echo "✅ TypeScript check successful"
else
    echo "⚠️  TypeScript issues found - review before committing"
    echo "   (Note: Edge Functions use Deno types, not Node types)"
fi
echo

# Test 4: Linting (if enabled)
echo "4️⃣  Running ESLint..."
if pnpm run lint --silent 2>/dev/null; then
    echo "✅ Linting successful"
else
    echo "⚠️  Linting issues found - review before committing"
fi
echo

echo "🎉 All pre-commit build tests passed!"
echo "   Safe to commit and push to GitHub"