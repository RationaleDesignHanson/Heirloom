#!/bin/bash

# Script to add DI files to Xcode project
# This script needs to be run AFTER manually adding the files in Xcode GUI
# OR we can open Xcode and add them interactively

PROJECT_DIR="/Users/matthanson/Heirloom"
DI_FILES=(
    "Heirloom/Core/DI/ServiceContainer.swift"
    "Heirloom/Core/DI/ServiceRegistration.swift"
    "Heirloom/Core/DI/ServiceProtocols.swift"
    "Heirloom/Core/DI/ServiceEnvironment.swift"
)

echo "🔧 DI Files that need to be added to Xcode project:"
echo ""
for file in "${DI_FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        echo "  ✅ $file (exists)"
    else
        echo "  ❌ $file (missing!)"
    fi
done

echo ""
echo "📝 To add these files to Xcode:"
echo "  1. Open Heirloom.xcodeproj in Xcode"
echo "  2. Right-click on 'Core/DI' folder in Project Navigator"
echo "  3. Select 'Add Files to Heirloom...'"
echo "  4. Navigate to Heirloom/Core/DI/"
echo "  5. Select all 4 .swift files"
echo "  6. Make sure 'Copy items if needed' is UNCHECKED"
echo "  7. Make sure 'Create groups' is selected"
echo "  8. Make sure 'Heirloom' target is checked"
echo "  9. Click 'Add'"
echo ""
echo "Or simply drag and drop the DI folder from Finder into the Project Navigator"
