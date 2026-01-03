#!/bin/bash
# Script to add Phase 3 component files to Xcode project

echo "🔧 Adding Phase 3 components to Xcode project..."

PROJECT_FILE="Heirloom.xcodeproj/project.pbxproj"
COMPONENTS=(
    "RecipeDetailHeader.swift"
    "RecipeMetadataSection.swift"
    "RecipeIngredientsSection.swift"
    "RecipeInstructionsSection.swift"
)

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Cannot find $PROJECT_FILE"
    exit 1
fi

echo "📁 Project file found: $PROJECT_FILE"

# For each component, check if it's already in the project
for component in "${COMPONENTS[@]}"; do
    if grep -q "$component" "$PROJECT_FILE"; then
        echo "✅ $component already in project"
    else
        echo "⚠️  $component needs to be added manually"
    fi
done

echo ""
echo "🎯 Manual Steps Required:"
echo "1. Open Heirloom.xcodeproj in Xcode"
echo "2. Right-click 'RecipeDetail' folder → 'Add Files to Heirloom'"
echo "3. Select the 4 component .swift files"
echo "4. Ensure 'Add to targets: Heirloom' is checked"
echo "5. Click 'Add'"
echo ""
echo "Or run this command to open Xcode:"
echo "  open Heirloom.xcodeproj"
