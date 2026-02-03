#!/bin/bash

# Setup script for Gen 2 Functions Firestore permissions
# This grants the Compute Engine default service account permission to write to Firestore

set -e

PROJECT_ID="heirloom-ios-prod"
PROJECT_NUMBER="7832275522"
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "🔧 Setting up Firestore permissions for Gen 2 Functions..."
echo ""
echo "Project: $PROJECT_ID"
echo "Service Account: $SERVICE_ACCOUNT"
echo ""

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
  echo "❌ Error: gcloud not authenticated"
  echo ""
  echo "Please run: gcloud auth login"
  echo ""
  exit 1
fi

echo "✅ gcloud authenticated"
echo ""

# Check if user wants to proceed
read -p "Grant 'Cloud Datastore User' role to service account? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Aborted"
  exit 1
fi

echo ""
echo "📝 Granting IAM permissions..."
echo ""

# Grant Cloud Datastore User role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/datastore.user" \
  --condition=None

echo ""
echo "✅ Permissions granted successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Uncomment rate limiting code in firebase/functions/ai-gateway.ts"
echo "2. Deploy functions: cd firebase && firebase deploy --only functions"
echo "3. Test rate limiting with the app"
echo ""
echo "🔍 To verify permissions:"
echo "gcloud projects get-iam-policy $PROJECT_ID \\"
echo "  --flatten=\"bindings[].members\" \\"
echo "  --filter=\"bindings.members:serviceAccount:${SERVICE_ACCOUNT}\""
echo ""
