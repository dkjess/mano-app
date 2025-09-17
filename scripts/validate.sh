#!/bin/bash

# Syntax validation script for Mano iOS app
# Usage: ./scripts/validate.sh

set -e  # Exit on any error

echo "🔍 Validating Swift syntax..."

# Set the Xcode path for this session
export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"

# Function to validate Swift files
validate_swift_files() {
    local dir="$1"
    local name="$2"

    echo "📂 Checking $name files..."

    if [ -d "$dir" ]; then
        for file in "$dir"/*.swift; do
            if [ -f "$file" ]; then
                echo "  🔸 $(basename "$file")"
                /Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse "$file" 2>&1 | grep -E "(error:|warning:)" || true
            fi
        done
    else
        echo "  ⚠️  Directory $dir not found"
    fi
}

# Validate key directories
validate_swift_files "Mano/Services" "Services"
validate_swift_files "Mano/Models" "Models"
validate_swift_files "Mano/Views/Auth" "Auth Views"
validate_swift_files "Mano/Views/Onboarding" "Onboarding Views"
validate_swift_files "Mano/Views/Profile" "Profile Views"

echo "✅ Syntax validation completed!"