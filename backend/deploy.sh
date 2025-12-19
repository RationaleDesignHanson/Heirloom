#!/bin/bash

# Heirloom Backend Deployment Script
# Usage: ./deploy.sh [dev|staging|prod]

set -e  # Exit on error

ENV=${1:-dev}
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Deploying Heirloom Backend to $ENV"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if logged in
echo "🔐 Checking Firebase authentication..."
if ! firebase projects:list > /dev/null 2>&1; then
    echo "❌ Not logged in to Firebase"
    echo "   Run: firebase login"
    exit 1
fi
echo "✅ Authenticated"
echo ""

# Switch to project
echo "📦 Switching to project: $ENV"
cd "$PROJECT_ROOT"
firebase use "$ENV"
echo ""

# Install dependencies
echo "📥 Installing dependencies..."
cd functions
if [ ! -d "node_modules" ]; then
    npm install
else
    echo "   (node_modules exists, skipping)"
fi
echo ""

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi
echo "✅ Build successful"
echo ""

# Deploy
echo "🚀 Deploying to Firebase..."
cd "$PROJECT_ROOT"
firebase deploy --only functions,firestore:rules,firestore:indexes,storage --project "$ENV"

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Deployment Successful!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Test endpoint with curl (see DEPLOY_PROMPT_5.md)"
    echo "  2. Update iOS CloudRecipeImportService baseURL"
    echo "  3. Test from iOS app"
    echo ""
    echo "📊 Monitor at:"
    PROJECT_ID=$(firebase projects:list | grep "$ENV" | awk '{print $1}')
    echo "  https://console.firebase.google.com/project/$PROJECT_ID"
    echo ""
else
    echo ""
    echo "❌ Deployment failed"
    echo "   Check logs: firebase functions:log"
    exit 1
fi
