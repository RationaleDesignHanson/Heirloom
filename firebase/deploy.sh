#!/bin/bash

# Firebase Deployment Script for Heirloom Theme Collections
# Run from project root: ./firebase/deploy.sh

set -e  # Exit on error

echo "🔥 Heirloom Firebase Deployment"
echo "================================"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install it with:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Run:"
    echo "   firebase login"
    exit 1
fi

echo "📝 Deploying Firestore Security Rules..."
firebase deploy --only firestore:rules

echo ""
echo "📊 Deploying Firestore Indexes..."
firebase deploy --only firestore:indexes

echo ""
echo "🗂️  Deploying Storage Security Rules..."
firebase deploy --only storage

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "⏳ Note: Firestore indexes may take 5-10 minutes to build."
echo "   Check status at: https://console.firebase.google.com"
echo ""
echo "📋 Next Steps:"
echo "   1. Verify indexes are building in Firebase Console"
echo "   2. Create Storage folder structure (themes/, recipes/)"
echo "   3. Run theme seeding script (Phase 2)"
echo ""
