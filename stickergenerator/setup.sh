#!/bin/bash

# Heirloom Sticker Generator - Quick Start Script
# This script sets up everything you need to generate stickers

set -e  # Exit on error

echo "🍳 Heirloom Sticker Generator - Setup"
echo "======================================"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or higher."
    exit 1
fi

echo "✓ Python 3 detected: $(python3 --version)"

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is not installed. Please install pip."
    exit 1
fi

echo "✓ pip3 detected"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install -r requirements.txt --quiet

echo "✓ Dependencies installed"
echo ""

# Check for API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "⚠️  No OPENAI_API_KEY environment variable found."
    echo ""
    echo "To set it permanently, add this to your ~/.bashrc or ~/.zshrc:"
    echo "   export OPENAI_API_KEY='sk-your-key-here'"
    echo ""
    echo "Or set it for this session:"
    echo "   export OPENAI_API_KEY='sk-your-key-here'"
    echo ""
    read -p "Enter your OpenAI API key now (or press Enter to skip): " API_KEY
    
    if [ ! -z "$API_KEY" ]; then
        export OPENAI_API_KEY="$API_KEY"
        echo "✓ API key set for this session"
    fi
else
    echo "✓ OPENAI_API_KEY found"
fi

echo ""
echo "======================================"
echo "✨ Setup complete!"
echo ""
echo "To generate stickers, run:"
echo "   python3 generate_stickers.py"
echo ""
echo "💰 Estimated cost: $0.80 for 20 stickers"
echo "⏱️  Time: ~3-5 minutes"
echo "======================================"
