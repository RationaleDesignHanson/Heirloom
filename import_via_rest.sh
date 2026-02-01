#!/bin/bash

# Import test users using Firestore REST API
# Uses Firebase CLI authentication

PROJECT_ID="heirloom-ios-prod"
BASE_URL="https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents"

echo "Getting access token from Firebase..."
ACCESS_TOKEN=$(firebase login:ci --no-localhost 2>&1 | grep -o '1//[^ ]*' | head -1)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Failed to get access token. Trying alternative method..."
    ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null)
fi

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Could not get access token. Please authenticate with: gcloud auth login"
    exit 1
fi

echo "Starting import of test users..."
echo ""

# Function to create a user document via REST API
create_user() {
    local user_id=$1
    local display_name=$2
    local bio=$3
    local location=$4
    shift 4
    local specialties=("$@")

    echo "📝 Importing: $display_name ($user_id)"

    # Build specialties array JSON
    local specialties_json="["
    for ((i=0; i<${#specialties[@]}; i++)); do
        specialties_json+="\"${specialties[i]}\""
        if [ $i -lt $((${#specialties[@]}-1)) ]; then
            specialties_json+=","
        fi
    done
    specialties_json+="]"

    # Create the profile data document
    curl -s -X PATCH \
        "$BASE_URL/users/$user_id/profile/data" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"fields\": {
                \"userId\": {\"stringValue\": \"$user_id\"},
                \"displayName\": {\"stringValue\": \"$display_name\"},
                \"bio\": {\"stringValue\": \"$bio\"},
                \"photoURL\": {\"nullValue\": null},
                \"handle\": {\"nullValue\": null},
                \"location\": {\"stringValue\": \"$location\"},
                \"specialties\": {\"arrayValue\": {\"values\": [
                    $(for spec in "${specialties[@]}"; do echo "{\"stringValue\": \"$spec\"},"; done | sed '$ s/,$//')
                ]}},
                \"websiteURL\": {\"nullValue\": null},
                \"currentKitchenTableId\": {\"nullValue\": null},
                \"kitchenTableIds\": {\"nullValue\": null},
                \"connectionCount\": {\"integerValue\": \"0\"},
                \"followerCount\": {\"integerValue\": \"0\"},
                \"followingCount\": {\"integerValue\": \"0\"},
                \"sharedRecipeCount\": {\"integerValue\": \"0\"},
                \"heritageGenerationCount\": {\"integerValue\": \"0\"},
                \"recipeAcceptanceCount\": {\"integerValue\": \"0\"},
                \"privacySettings\": {\"mapValue\": {\"fields\": {
                    \"profileVisibility\": {\"stringValue\": \"private\"},
                    \"allowMentions\": {\"booleanValue\": true},
                    \"allowSearchIndexing\": {\"booleanValue\": true},
                    \"hideFromSearch\": {\"booleanValue\": false},
                    \"showLocationInSearch\": {\"booleanValue\": true},
                    \"showSpecialtiesInSearch\": {\"booleanValue\": true}
                }}},
                \"hasPublicProfile\": {\"booleanValue\": false},
                \"publicProfileSlug\": {\"nullValue\": null},
                \"locale\": {\"stringValue\": \"en_US\"},
                \"isVerified\": {\"booleanValue\": false},
                \"verificationType\": {\"nullValue\": null}
            }
        }" > /dev/null

    if [ $? -eq 0 ]; then
        echo "✅ Imported: $display_name"
    else
        echo "❌ Failed to import $display_name"
    fi
    echo ""
}

# Import all test users
create_user "test-user-1" "Matt Chef" "Love Italian cooking and fresh pasta" "New York" "Italian" "Pasta" "Baking"
create_user "test-user-2" "Sarah Baker" "Specializing in artisan breads and pastries" "San Francisco" "Baking" "Desserts" "Soups"
create_user "test-user-3" "Maria Garcia" "Mexican cuisine enthusiast and taco expert" "Austin" "Mexican" "Grilling" "Salads"
create_user "test-user-4" "John Smith" "BBQ and grilling expert, competition winner" "Dallas" "Grilling" "BBQ" "Seafood"
create_user "test-user-5" "Emily Chen" "Asian fusion and vegetarian dishes" "Seattle" "Asian" "Vegetarian" "Vegan"
create_user "test-user-6" "Matthew Anderson" "Home cook learning new techniques" "Portland" "Soups" "Salads" "Pasta"

echo "✨ Import complete!"
echo ""
echo "Test search queries:"
echo "- \"Matt\" → should find \"Matt Chef\" and \"Matthew Anderson\""
echo "- \"Sarah\" → should find \"Sarah Baker\""
echo "- \"Maria\" → should find \"Maria Garcia\""
echo "- \"John\" → should find \"John Smith\""
echo "- \"Emily\" → should find \"Emily Chen\""
