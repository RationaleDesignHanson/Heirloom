#!/bin/bash

# Script to verify all Firestore paths used in code have corresponding security rules
# Run this before deploying to ensure no collections are missing rules

echo "🔍 Verifying Firestore Rules Coverage..."
echo ""

# Extract all collection/document paths from Swift code
echo "📱 Scanning Swift code for Firestore paths..."
SWIFT_PATHS=$(grep -rh "collection(\|document(" --include="*.swift" Heirloom | \
  grep -o '"[^"]*"' | \
  sed 's/"//g' | \
  grep -v "^$" | \
  sort -u)

# Extract all match patterns from firestore.rules
echo "📋 Scanning firestore.rules for security rules..."
RULES_PATHS=$(grep "match /" firestore.rules | \
  grep -o "match /[^{]*" | \
  sed 's/match \///g' | \
  sed 's/{[^}]*}/<param>/g' | \
  sed 's/ //g' | \
  sort -u)

echo ""
echo "================================"
echo "PATHS FOUND IN SWIFT CODE:"
echo "================================"
echo "$SWIFT_PATHS" | while read path; do
  # Skip variable interpolation patterns
  if [[ "$path" == *"\("* ]]; then
    # Extract the static part before variable
    static_part=$(echo "$path" | sed 's/\\(.*//')
    echo "  📌 $path (static: $static_part)"
  else
    echo "  📌 $path"
  fi
done

echo ""
echo "================================"
echo "PATHS DEFINED IN RULES:"
echo "================================"
echo "$RULES_PATHS" | while read path; do
  echo "  ✅ $path"
done

echo ""
echo "================================"
echo "VERIFICATION RESULTS:"
echo "================================"

# Check each collection from code against rules
missing_rules=0
echo "$SWIFT_PATHS" | while read code_path; do
  # Skip empty lines
  if [ -z "$code_path" ]; then
    continue
  fi

  # Extract collection name (first segment before /)
  if [[ "$code_path" == *"/"* ]]; then
    collection=$(echo "$code_path" | cut -d'/' -f1)
  else
    collection="$code_path"
  fi

  # Check if this collection has a rule
  if echo "$RULES_PATHS" | grep -q "$collection"; then
    echo "  ✅ $code_path → Rule found"
  else
    echo "  ❌ $code_path → MISSING RULE!"
    missing_rules=$((missing_rules + 1))
  fi
done

echo ""
if [ $missing_rules -eq 0 ]; then
  echo "✅ All Firestore paths have security rules!"
  exit 0
else
  echo "❌ Found $missing_rules paths without security rules!"
  echo ""
  echo "⚠️  Add missing rules to firestore.rules before deploying"
  exit 1
fi
