#!/bin/bash

# Script to add new onboarding files to Xcode project
# Run from Heirloom directory: ./add-onboarding-files.sh

echo "Adding new onboarding files to Xcode project..."

# Get the project file
PROJECT_FILE="Heirloom.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "Error: project.pbxproj not found. Are you in the Heirloom directory?"
    exit 1
fi

echo "Files to add manually in Xcode:"
echo ""
echo "1. Features/Onboarding/OnboardingWelcomeScreen.swift"
echo "2. Features/Onboarding/OnboardingConceptScreen.swift"
echo "3. Features/Onboarding/OnboardingRecipeSeeder.swift"
echo "4. Features/Collections/BlindBoxCollectionRow.swift"
echo "5. Core/Services/BlindBoxSeeder.swift"
echo ""
echo "Steps:"
echo "1. Open Heirloom.xcodeproj in Xcode"
echo "2. Right-click on appropriate folders in Project Navigator"
echo "3. Choose 'Add Files to Heirloom...'"
echo "4. Select the files listed above"
echo "5. Make sure 'Heirloom' target is checked"
echo "6. Click 'Add'"
echo ""
echo "Or run this command to open Xcode:"
echo "open Heirloom.xcodeproj"
