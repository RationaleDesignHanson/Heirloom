#!/bin/bash

# Script to update version numbers for both the main app and share extension
# Usage: ./update-version.sh <version> <build>
# Example: ./update-version.sh 1.7.0 8

set -e

if [ "$#" -ne 2 ]; then
    echo "Error: Requires exactly 2 arguments"
    echo "Usage: $0 <version> <build>"
    echo "Example: $0 1.7.0 8"
    exit 1
fi

VERSION=$1
BUILD=$2

# Validate version format (basic check)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 1.7.0)"
    exit 1
fi

# Validate build number is numeric
if ! [[ "$BUILD" =~ ^[0-9]+$ ]]; then
    echo "Error: Build number must be numeric"
    exit 1
fi

MAIN_APP_PLIST="Heirloom/Resources/Info.plist"
SHARE_EXT_PLIST="HeirloomShareExtension/Info.plist"
PROJECT_FILE="Heirloom.xcodeproj/project.pbxproj"

echo "Updating version to $VERSION (build $BUILD)..."

# Update main app Info.plist
if [ -f "$MAIN_APP_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$MAIN_APP_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$MAIN_APP_PLIST"
    echo "✓ Updated $MAIN_APP_PLIST"
else
    echo "✗ Error: $MAIN_APP_PLIST not found"
    exit 1
fi

# Update share extension Info.plist
if [ -f "$SHARE_EXT_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$SHARE_EXT_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$SHARE_EXT_PLIST"
    echo "✓ Updated $SHARE_EXT_PLIST"
else
    echo "✗ Error: $SHARE_EXT_PLIST not found"
    exit 1
fi

# Update project.pbxproj build settings
# This updates CURRENT_PROJECT_VERSION and MARKETING_VERSION in the Xcode project file
# which override the Info.plist values during build
if [ -f "$PROJECT_FILE" ]; then
    # Get current values for backup
    CURRENT_MARKETING=$(grep -m 1 "MARKETING_VERSION = " "$PROJECT_FILE" | sed 's/.*= \(.*\);/\1/')
    CURRENT_BUILD=$(grep -m 1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | sed 's/.*= \(.*\);/\1/')

    # Create backup
    cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

    # Update all MARKETING_VERSION occurrences
    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" "$PROJECT_FILE"

    # Update all CURRENT_PROJECT_VERSION occurrences
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PROJECT_FILE"

    echo "✓ Updated $PROJECT_FILE (was: v$CURRENT_MARKETING build $CURRENT_BUILD)"
else
    echo "✗ Error: $PROJECT_FILE not found"
    exit 1
fi

echo ""
echo "✓ Version update complete!"
echo "  Version: $VERSION"
echo "  Build:   $BUILD"
echo ""
echo "Files updated:"
echo "  - $MAIN_APP_PLIST"
echo "  - $SHARE_EXT_PLIST"
echo "  - $PROJECT_FILE"
echo ""
echo "Remember to commit these changes:"
echo "  git add $MAIN_APP_PLIST $SHARE_EXT_PLIST $PROJECT_FILE"
echo "  git commit -m \"Bump version to $VERSION ($BUILD)\""
