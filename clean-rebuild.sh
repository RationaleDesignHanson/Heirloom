#!/bin/bash

echo "🧹 Cleaning build folder..."
cd /Users/matthanson/Heirloom

# Clean build folder
xcodebuild -scheme Heirloom clean

# Kill simulator
echo "🛑 Stopping simulator..."
killall Simulator 2>/dev/null

# Remove derived data for this project
echo "🗑️  Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Heirloom-*

echo "🔨 Building fresh..."
xcodebuild -scheme Heirloom -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

echo ""
echo "✅ Clean build complete!"
echo ""
echo "Now run the app from Xcode and you should see:"
echo "1. Empty state if no recipes"
echo "2. 'Add Sample Recipe' button"
echo "3. Recipe cards if recipes exist"
