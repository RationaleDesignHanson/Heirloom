#!/bin/bash
# Reset rate limits for a user (development only)

USER_ID="$1"

if [ -z "$USER_ID" ]; then
    echo "Usage: ./reset-rate-limit.sh <user_id>"
    echo ""
    echo "Get your user ID from Firebase Auth or from the app logs"
    exit 1
fi

echo "Resetting rate limits for user: $USER_ID"
echo ""

# Delete rate limit documents
firebase firestore:delete "rateLimits/${USER_ID}:ai_complete" --project heirloom-ios-prod -y
firebase firestore:delete "rateLimits/${USER_ID}:ai_vision" --project heirloom-ios-prod -y
firebase firestore:delete "rateLimits/${USER_ID}:google_vision" --project heirloom-ios-prod -y
firebase firestore:delete "rateLimits/${USER_ID}:brave_search" --project heirloom-ios-prod -y

echo ""
echo "✅ Rate limits reset! You now have:"
echo "   - 200 vision AI requests (recipe extraction)"
echo "   - 500 text AI requests"
echo "   - 500 OCR requests"
echo "   - 500 web searches"
echo ""
echo "These limits will reset at midnight UTC."
