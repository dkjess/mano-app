#!/bin/bash

# Environment detection utility
# Usage: source scripts/check-env.sh

check_production_link() {
    local project_ref=$(supabase status 2>/dev/null | grep "Project ref:" | awk '{print $3}' || echo "")

    if [ "$project_ref" = "zfroutbzdkhivnpiezho" ]; then
        echo "🔴 PRODUCTION"
        return 0  # true - is production
    else
        echo "🟢 LOCAL"
        return 1  # false - not production
    fi
}

warn_if_production() {
    if check_production_link >/dev/null; then
        echo ""
        echo "⚠️  WARNING: You are linked to PRODUCTION!"
        echo "   Project: zfroutbzdkhivnpiezho"
        echo "   Any database operations will affect LIVE DATA!"
        echo ""
        echo "   To switch to local:"
        echo "   supabase unlink"
        echo ""
        return 0  # is production
    fi
    return 1  # not production
}