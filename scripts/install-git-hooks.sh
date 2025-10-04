#!/bin/bash

echo "📦 Installing Git Hooks..."
echo ""

HOOK_DIR=".git/hooks"
HOOK_FILE="$HOOK_DIR/pre-push"

# Create pre-push hook
cat > "$HOOK_FILE" << 'EOF'
#!/bin/bash
# Pre-push hook to prevent direct pushes to main branch

protected_branch='main'
current_branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

if [ "$current_branch" = "$protected_branch" ]; then
    echo ""
    echo "🚨 ERROR: Direct push to main branch is not allowed!"
    echo ""
    echo "Please use the proper workflow:"
    echo "  1. Create a feature branch: git checkout -b feature/your-feature"
    echo "  2. Push your feature branch: git push origin feature/your-feature"
    echo "  3. Create a PR: gh pr create"
    echo ""
    echo "To bypass this check (only if explicitly approved):"
    echo "  git push --no-verify origin main"
    echo ""
    exit 1
fi

exit 0
EOF

# Make hook executable
chmod +x "$HOOK_FILE"

echo "✅ Pre-push hook installed successfully!"
echo ""
echo "The hook will prevent direct pushes to main branch."
echo "Use feature branches and PRs for all changes."
echo ""
