#!/bin/bash

# Install git hooks for automated testing
# Run this once to set up pre-commit test hooks

set -e

echo "📦 Installing git test hooks..."
echo ""

# Find git root directory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "❌ Error: Not in a git repository"
  exit 1
fi

HOOKS_DIR="$GIT_ROOT/.git/hooks"
BACKEND_DIR="$GIT_ROOT/backend"

# Create pre-commit hook
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

echo "Creating pre-commit hook at: $PRE_COMMIT_HOOK"

cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash

# Pre-commit hook: Run tests before commit
# This ensures code quality and prevents breaking changes

# Check if we're in a merge/rebase
if [ -f .git/MERGE_HEAD ] || [ -f .git/REBASE_HEAD ]; then
  echo "⏭️  Skipping pre-commit tests (merge/rebase in progress)"
  exit 0
fi

# Check if there are any backend changes
BACKEND_CHANGES=$(git diff --cached --name-only | grep "^backend/" || true)

if [ -z "$BACKEND_CHANGES" ]; then
  echo "⏭️  No backend changes detected, skipping tests"
  exit 0
fi

echo "🔍 Backend changes detected, running tests..."

# Run the pre-commit test script
if [ -f "backend/scripts/pre-commit-test.sh" ]; then
  bash backend/scripts/pre-commit-test.sh
else
  echo "⚠️  Warning: pre-commit-test.sh not found, skipping tests"
  exit 0
fi
EOF

chmod +x "$PRE_COMMIT_HOOK"

echo ""
echo "✅ Git hooks installed successfully!"
echo ""
echo "📋 What happens now:"
echo "   • Before each commit, tests will run automatically"
echo "   • If tests fail, commit will be blocked"
echo "   • Only backend changes trigger tests"
echo "   • Merges/rebases skip tests automatically"
echo ""
echo "💡 Tips:"
echo "   • To bypass tests (emergencies): git commit --no-verify"
echo "   • To test manually: npm run test:core"
echo "   • To see what tests run: cat backend/scripts/pre-commit-test.sh"
echo ""
echo "🎉 Happy coding with confidence!"
