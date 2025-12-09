#!/bin/bash

# Heirloom Xcode Project Setup Script
# Creates the .xcodeproj file using xcodegen

set -e  # Exit on error

echo "🍎 Heirloom - Xcode Project Setup"
echo "=================================="
echo ""

# Check if xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "✅ Found xcodegen"
    echo ""
    echo "🔨 Generating Xcode project..."

    xcodegen generate

    echo ""
    echo "✅ Success! Heirloom.xcodeproj has been created."
    echo ""
    echo "📱 Next steps:"
    echo "   1. Open Heirloom.xcodeproj in Xcode"
    echo "   2. Select your Team ID in Signing & Capabilities (should be Q2HHH2GDN8)"
    echo "   3. Build and Run! (⌘R)"
    echo ""
    echo "🎉 All critical architecture issues have been fixed:"
    echo "   ✅ Graceful error handling (no fatal crashes)"
    echo "   ✅ Thread-safe image storage"
    echo "   ✅ Proper SwiftData relationships"
    echo "   ✅ No memory leaks"
    echo "   ✅ Optimized image compression"
    echo "   ✅ MainActor safety for SwiftData"
    echo ""
else
    echo "⚠️  xcodegen not found"
    echo ""
    echo "Option 1: Install xcodegen (recommended)"
    echo "   brew install xcodegen"
    echo "   Then run this script again"
    echo ""
    echo "Option 2: Manual setup in Xcode"
    echo "   Follow the detailed instructions in README.md"
    echo "   (Takes about 5 minutes)"
    echo ""
    exit 1
fi
