#!/bin/bash

# Script to add HeirloomTestsV2 test target to Xcode project
# Usage: ./scripts/add-test-target.sh

set -e

PROJECT_DIR="/Users/matthanson/Heirloom"
PROJECT_FILE="$PROJECT_DIR/Heirloom.xcodeproj/project.pbxproj"
TEST_DIR="$PROJECT_DIR/HeirloomTestsV2"

echo "🚀 Adding HeirloomTestsV2 to Xcode project..."
echo ""

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Xcode project not found at $PROJECT_FILE"
    exit 1
fi

# Check if test directory exists
if [ ! -d "$TEST_DIR" ]; then
    echo "❌ Error: HeirloomTestsV2 directory not found at $TEST_DIR"
    exit 1
fi

echo "✅ Found project file"
echo "✅ Found test directory"
echo ""

echo "📝 Manual Steps Required (Xcode GUI):"
echo ""
echo "1. Open Xcode:"
echo "   open $PROJECT_DIR/Heirloom.xcodeproj"
echo ""
echo "2. Create new test target:"
echo "   • File → New → Target"
echo "   • Choose: iOS → Unit Testing Bundle"
echo "   • Product Name: HeirloomTestsV2"
echo "   • Language: Swift"
echo "   • Click 'Finish'"
echo ""
echo "3. Delete auto-generated HeirloomTestsV2.swift file"
echo "   (Xcode creates a default test file - we don't need it)"
echo ""
echo "4. Add existing test files:"
echo "   • Right-click 'HeirloomTestsV2' in project navigator"
echo "   • Choose 'Add Files to \"HeirloomTestsV2\"...'"
echo "   • Navigate to: $TEST_DIR"
echo "   • Select 'HeirloomTestsV2' folder"
echo "   • ⚠️  IMPORTANT: Uncheck 'Copy items if needed'"
echo "   • ⚠️  IMPORTANT: Select 'Create folder references'"
echo "   • ⚠️  IMPORTANT: Check 'HeirloomTestsV2' target"
echo "   • Click 'Add'"
echo ""
echo "5. Configure test scheme:"
echo "   • Product → Scheme → Edit Scheme..."
echo "   • Click 'Test' in sidebar"
echo "   • Click '+' button"
echo "   • Select 'HeirloomTestsV2'"
echo "   • Enable 'Run' checkbox"
echo "   • Click 'Close'"
echo ""
echo "6. Build to verify:"
echo "   • Product → Build (⌘B)"
echo "   • Should complete without errors"
echo ""
echo "7. Run a test to verify setup:"
echo "   • Product → Test (⌘U)"
echo "   • Or: xcodebuild test -scheme Heirloom -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232' -only-testing:HeirloomTestsV2"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Once complete, you'll have:"
echo "  ✅ HeirloomTests (old) - Deprecated, don't touch"
echo "  ✅ HeirloomTestsV2 (new) - Modern, comprehensive"
echo ""
echo "All new tests go in HeirloomTestsV2!"
echo ""
