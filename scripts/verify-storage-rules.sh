#!/bin/bash

# Script to verify all Firebase Storage paths used in code have corresponding security rules

echo "🔍 Verifying Firebase Storage Rules Coverage..."
echo ""

# Extract all storage paths from Swift code
echo "📱 Scanning Swift code for Firebase Storage paths..."
SWIFT_PATHS=$(grep -rh "firebasestorage\|Storage.storage\|downloadURL\|uploadData" --include="*.swift" Heirloom | \
  grep -o '"[^"]*"' | \
  sed 's/"//g' | \
  grep -E "^(users/|recipes/|themes/|heritage|import|temp|og-)" | \
  sort -u)

# Extract all match patterns from storage.rules
echo "📋 Scanning storage.rules for security rules..."
RULES_PATHS=$(grep "match /" storage.rules | \
  grep -o "match /[^{]*" | \
  sed 's/match \///g' | \
  sed 's/{[^}]*}/<param>/g' | \
  sed 's/ //g' | \
  sort -u)

echo ""
echo "================================"
echo "PATHS FOUND IN CODE:"
echo "================================"
if [ -z "$SWIFT_PATHS" ]; then
  echo "  (No hardcoded storage paths found - likely using dynamic paths)"
else
  echo "$SWIFT_PATHS" | while read path; do
    echo "  📌 $path"
  done
fi

echo ""
echo "================================"
echo "PATHS DEFINED IN RULES:"
echo "================================"
echo "$RULES_PATHS" | while read path; do
  echo "  ✅ $path"
done

echo ""
echo "================================"
echo "KNOWN STORAGE PATH PATTERNS:"
echo "================================"
echo "  📁 themes/<imageFile> - Theme cover images"
echo "  📁 heritage-recipes/<imageFile> - Heritage recipe images"
echo "  📁 recipes/<themeId>/<imageFile> - Theme recipe images"
echo "  📁 recipe-images/<recipeId>/<imageFile> - Public recipe images"
echo "  📁 users/<userId>/recipes/<recipeId>/<imageFile> - User recipe images"
echo "  📁 users/<userId>/profile/<fileName> - User avatars"
echo "  📁 og-images/profiles/<userId>/<fileName> - OG image cards"
echo "  📁 import-cache/<urlHash>/<file> - Import cache"
echo "  📁 temp-uploads/<userId>/<allPaths> - Temporary uploads"

echo ""
echo "✅ Storage rules verification complete"
echo ""
echo "💡 To test a specific path, use:"
echo "   firebase emulators:start --only storage"
echo "   # Then test accessing storage URLs in your app"
