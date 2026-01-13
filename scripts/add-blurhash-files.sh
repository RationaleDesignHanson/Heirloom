#!/bin/bash

# Add BlurHashEncoder and AsyncBlurhashImage to Xcode project

PROJECT="/Users/matthanson/Heirloom/Heirloom.xcodeproj"

echo "Adding blurhash files to Xcode project..."

# Use PlistBuddy to add files to project
# Note: This is a simplified approach - for production, use xcodeproj gem or manual addition

# For now, let's just verify the files exist
if [ -f "/Users/matthanson/Heirloom/Heirloom/Core/Utilities/BlurHashEncoder.swift" ]; then
    echo "✓ BlurHashEncoder.swift exists"
else
    echo "✗ BlurHashEncoder.swift not found"
    exit 1
fi

if [ -f "/Users/matthanson/Heirloom/Heirloom/UI/Components/AsyncBlurhashImage.swift" ]; then
    echo "✓ AsyncBlurhashImage.swift exists"
else
    echo "✗ AsyncBlurhashImage.swift not found"
    exit 1
fi

echo ""
echo "Files ready to be added to Xcode:"
echo "  1. Heirloom/Core/Utilities/BlurHashEncoder.swift"
echo "  2. Heirloom/UI/Components/AsyncBlurhashImage.swift"
echo ""
echo "Please drag these files into Xcode, or I'll try adding them programmatically..."

# Try to find existing file references to understand project structure
PBXPROJ="$PROJECT/project.pbxproj"

# Generate unique IDs for the files
ENCODER_FILE_ID="BH$(openssl rand -hex 10 | tr '[:lower:]' '[:upper:]')"
IMAGE_FILE_ID="BH$(openssl rand -hex 10 | tr '[:lower:]' '[:upper:]')"
ENCODER_BUILD_ID="BH$(openssl rand -hex 10 | tr '[:lower:]' '[:upper:]')"
IMAGE_BUILD_ID="BH$(openssl rand -hex 10 | tr '[:lower:]' '[:upper:]')"

echo "Generated file IDs:"
echo "  BlurHashEncoder: $ENCODER_FILE_ID"
echo "  AsyncBlurhashImage: $IMAGE_FILE_ID"

# For complex project file modifications, recommend manual addition via Xcode UI
echo ""
echo "⚠️  Xcode project.pbxproj is complex. Safest approach:"
echo "   1. In Xcode: Right-click 'Core/Utilities' → Add Files"
echo "   2. Select BlurHashEncoder.swift"
echo "   3. Right-click 'UI/Components' → Add Files"
echo "   4. Select AsyncBlurhashImage.swift"
