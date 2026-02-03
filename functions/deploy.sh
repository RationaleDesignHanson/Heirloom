#!/bin/bash

# Deploy Heirloom AI Gateway Functions
# Usage: ./deploy.sh [--emulator]

set -e

echo "🚀 Deploying Heirloom AI Gateway..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

# Check for API keys in config
echo "📋 Checking API key configuration..."

ANTHROPIC_KEY=$(firebase functions:config:get anthropic.key 2>/dev/null || echo "")
OPENAI_KEY=$(firebase functions:config:get openai.key 2>/dev/null || echo "")

if [ -z "$ANTHROPIC_KEY" ] && [ -z "$OPENAI_KEY" ]; then
    echo "⚠️  WARNING: No API keys configured!"
    echo ""
    echo "Set API keys with:"
    echo "  firebase functions:config:set anthropic.key=\"sk-ant-...\""
    echo "  firebase functions:config:set openai.key=\"sk-proj-...\""
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

if [ "$1" == "--emulator" ]; then
    echo "🧪 Starting Firebase Emulator..."
    firebase emulators:start
else
    # Deploy to Firebase
    echo "☁️  Deploying to Firebase..."
    firebase deploy --only functions

    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "Next steps:"
    echo "1. Update iOS app to use FirebaseAIGatewayService"
    echo "2. Test with real AI requests"
    echo "3. Monitor logs: firebase functions:log"
    echo "4. Remove API keys from iOS app"
fi
