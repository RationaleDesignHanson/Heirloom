#!/bin/bash
# Get access token
ACCESS_TOKEN=$(node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
admin.credential.applicationDefault().getAccessToken().then(token => {
  console.log(token.access_token);
  process.exit(0);
});
")

# Activate the latest ruleset
curl -X PUT \
  "https://firebaserules.googleapis.com/v1/projects/heirloom-ios-prod/releases/cloud.firestore" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"projects/heirloom-ios-prod/releases/cloud.firestore\",
    \"rulesetName\": \"projects/heirloom-ios-prod/rulesets/8a110918-fc63-4404-a51a-7bd1bd4604ff\"
  }"
