#!/bin/bash

# Import test users using Firebase CLI
# This uses your existing firebase login credentials

PROJECT_ID="heirloom-ios-prod"

echo "Starting import of test users..."
echo ""

# Function to create a user document
create_user() {
    local user_id=$1
    local display_name=$2
    local bio=$3
    local location=$4
    local specialties=$5

    echo "📝 Importing: $display_name ($user_id)"

    # Create the profile data document
    firebase firestore:write "users/$user_id/profile/data" - <<EOF
{
  "userId": "$user_id",
  "displayName": "$display_name",
  "bio": "$bio",
  "photoURL": null,
  "handle": null,
  "location": "$location",
  "specialties": $specialties,
  "websiteURL": null,
  "currentKitchenTableId": null,
  "kitchenTableIds": null,
  "connectionCount": 0,
  "followerCount": 0,
  "followingCount": 0,
  "sharedRecipeCount": 0,
  "heritageGenerationCount": 0,
  "recipeAcceptanceCount": 0,
  "privacySettings": {
    "profileVisibility": "private",
    "allowMentions": true,
    "allowSearchIndexing": true,
    "hideFromSearch": false,
    "showLocationInSearch": true,
    "showSpecialtiesInSearch": true
  },
  "hasPublicProfile": false,
  "publicProfileSlug": null,
  "locale": "en_US",
  "isVerified": false,
  "verificationType": null
}
EOF

    if [ $? -eq 0 ]; then
        echo "✅ Imported: $display_name"
    else
        echo "❌ Failed to import $display_name"
    fi
    echo ""
}

# Import all test users
create_user "test-user-1" "Matt Chef" "Love Italian cooking and fresh pasta" "New York" '["Italian", "Pasta", "Baking"]'
create_user "test-user-2" "Sarah Baker" "Specializing in artisan breads and pastries" "San Francisco" '["Baking", "Desserts", "Soups"]'
create_user "test-user-3" "Maria Garcia" "Mexican cuisine enthusiast and taco expert" "Austin" '["Mexican", "Grilling", "Salads"]'
create_user "test-user-4" "John Smith" "BBQ and grilling expert, competition winner" "Dallas" '["Grilling", "BBQ", "Seafood"]'
create_user "test-user-5" "Emily Chen" "Asian fusion and vegetarian dishes" "Seattle" '["Asian", "Vegetarian", "Vegan"]'
create_user "test-user-6" "Matthew Anderson" "Home cook learning new techniques" "Portland" '["Soups", "Salads", "Pasta"]'

echo "✨ Import complete!"
echo ""
echo "Test search queries:"
echo "- \"Matt\" → should find \"Matt Chef\" and \"Matthew Anderson\""
echo "- \"Sarah\" → should find \"Sarah Baker\""
echo "- \"Maria\" → should find \"Maria Garcia\""
echo "- \"John\" → should find \"John Smith\""
echo "- \"Emily\" → should find \"Emily Chen\""
