#!/bin/bash
# Heirloom Development Environment Setup
# Run this script to set up your development environment
# Usage: ./setup-dev-environment.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}===================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Start setup
print_header "Heirloom Development Environment Setup"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script must be run on macOS"
    exit 1
fi

print_success "Running on macOS"

#===============================================================================
# 1. CHECK XCODE
#===============================================================================
print_header "1. Checking Xcode Installation"

if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode is not installed"
    echo "Please install Xcode from the App Store"
    echo "URL: https://apps.apple.com/us/app/xcode/id497799835"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
print_success "Xcode is installed: $XCODE_VERSION"

# Check for Xcode 15.2+
XCODE_MAJOR=$(echo $XCODE_VERSION | sed 's/Xcode //' | cut -d'.' -f1)
if [ "$XCODE_MAJOR" -lt 15 ]; then
    print_warning "Xcode 15.2+ is recommended (you have version $XCODE_VERSION)"
fi

# Check command line tools
if ! xcode-select -p &> /dev/null; then
    print_warning "Xcode Command Line Tools not set"
    echo "Running: xcode-select --install"
    xcode-select --install
else
    print_success "Xcode Command Line Tools configured"
fi

#===============================================================================
# 2. CHECK HOMEBREW
#===============================================================================
print_header "2. Checking Homebrew"

if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not installed"
    echo "Would you like to install Homebrew? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        print_success "Homebrew installed"
    else
        print_warning "Skipping Homebrew installation"
    fi
else
    print_success "Homebrew is installed: $(brew --version | head -1)"
fi

#===============================================================================
# 3. CHECK/INSTALL DEPENDENCIES
#===============================================================================
print_header "3. Checking Development Dependencies"

# Firebase CLI
if command -v firebase &> /dev/null; then
    print_success "Firebase CLI is installed: $(firebase --version)"
else
    print_warning "Firebase CLI not installed"
    if command -v brew &> /dev/null; then
        echo "Install Firebase CLI via Homebrew? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            brew install firebase-cli
            print_success "Firebase CLI installed"
        fi
    else
        echo "Install Firebase CLI: npm install -g firebase-tools"
    fi
fi

# SwiftLint (optional)
if command -v swiftlint &> /dev/null; then
    print_success "SwiftLint is installed: $(swiftlint version)"
else
    print_info "SwiftLint not installed (optional code quality tool)"
    if command -v brew &> /dev/null; then
        echo "Install SwiftLint? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            brew install swiftlint
            print_success "SwiftLint installed"
        fi
    fi
fi

# Git
if ! command -v git &> /dev/null; then
    print_error "Git is not installed"
    exit 1
fi
print_success "Git is installed: $(git --version)"

#===============================================================================
# 4. SETUP CONFIG FILE
#===============================================================================
print_header "4. Setting Up Configuration File"

if [ ! -f "Config.xcconfig" ]; then
    print_warning "Config.xcconfig not found"

    if [ -f "Config.xcconfig.template" ]; then
        print_info "Copying from template..."
        cp Config.xcconfig.template Config.xcconfig
        print_success "Config.xcconfig created from template"
    else
        print_info "Creating Config.xcconfig..."
        cat > Config.xcconfig << 'EOF'
// Heirloom Configuration
// This file contains sensitive API keys and is excluded from version control
// DO NOT commit this file to git

// Default Anthropic API Key
// Get your key from: https://console.anthropic.com/settings/keys
DEFAULT_ANTHROPIC_KEY = YOUR_ANTHROPIC_API_KEY_HERE

// Google Sign-In Configuration
// Get from: Firebase Console -> Project Settings -> GoogleService-Info.plist
REVERSED_CLIENT_ID = YOUR_REVERSED_CLIENT_ID_HERE

// Mixpanel Analytics Configuration (Optional)
// Get from: https://mixpanel.com/settings/project
MIXPANEL_PRODUCTION_TOKEN = YOUR_PRODUCTION_TOKEN_HERE
MIXPANEL_DEVELOPMENT_TOKEN = YOUR_DEV_TOKEN_HERE
EOF
        print_success "Config.xcconfig created"
    fi

    print_warning "IMPORTANT: Edit Config.xcconfig and add your API keys"
    echo "  1. Anthropic API key (required for AI features)"
    echo "  2. Google Reversed Client ID (from Firebase)"
    echo "  3. Mixpanel tokens (optional, for analytics)"
else
    print_success "Config.xcconfig already exists"
fi

# Verify it's in .gitignore
if grep -q "Config.xcconfig" .gitignore 2>/dev/null; then
    print_success "Config.xcconfig is in .gitignore"
else
    print_warning "Adding Config.xcconfig to .gitignore"
    echo "Config.xcconfig" >> .gitignore
fi

#===============================================================================
# 5. CHECK FIREBASE SETUP
#===============================================================================
print_header "5. Checking Firebase Configuration"

if [ -f "Heirloom/Resources/GoogleService-Info.plist" ]; then
    print_success "GoogleService-Info.plist found"
else
    print_error "GoogleService-Info.plist not found"
    echo "Download from: Firebase Console -> Project Settings -> iOS App"
    echo "Place in: Heirloom/Resources/GoogleService-Info.plist"
fi

if [ -f "firebase.json" ]; then
    print_success "firebase.json configured"
else
    print_warning "firebase.json not found (optional for emulators)"
fi

#===============================================================================
# 6. CHECK SPM DEPENDENCIES
#===============================================================================
print_header "6. Checking Swift Package Dependencies"

if [ -f "Heirloom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    print_success "Swift Package dependencies resolved"
    PACKAGE_COUNT=$(grep -c "\"identity\"" Heirloom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
    print_info "Found $PACKAGE_COUNT packages"
else
    print_warning "Package dependencies not resolved"
    echo "Open Heirloom.xcodeproj in Xcode to resolve dependencies"
fi

#===============================================================================
# 7. VERIFY PROJECT STRUCTURE
#===============================================================================
print_header "7. Verifying Project Structure"

# Check critical directories
DIRS=("Heirloom" "HeirloomTestsV2" "docs" "scripts")
for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_success "$dir/ directory exists"
    else
        print_warning "$dir/ directory not found"
    fi
done

# Check critical files
if [ -f "Heirloom.xcodeproj/project.pbxproj" ]; then
    print_success "Xcode project file exists"
else
    print_error "Xcode project file not found!"
    exit 1
fi

#===============================================================================
# 8. CHECK GIT CONFIGURATION
#===============================================================================
print_header "8. Checking Git Configuration"

if [ -d ".git" ]; then
    print_success "Git repository initialized"

    # Check for remote
    if git remote -v | grep -q origin; then
        REMOTE=$(git remote get-url origin)
        print_success "Git remote configured: $REMOTE"
    else
        print_warning "No git remote configured"
    fi

    # Check current branch
    BRANCH=$(git branch --show-current)
    print_info "Current branch: $BRANCH"
else
    print_error "Not a git repository"
    exit 1
fi

#===============================================================================
# 9. RUN OPTIONAL CHECKS
#===============================================================================
print_header "9. Optional Checks"

# Check iOS Simulator availability
if xcrun simctl list devices available | grep -q "iPhone"; then
    print_success "iOS Simulators available"
else
    print_warning "No iOS Simulators found"
    echo "Open Xcode -> Preferences -> Components to download simulators"
fi

# Check for SwiftLint configuration
if [ -f ".swiftlint.yml" ]; then
    print_success "SwiftLint configuration exists"
else
    print_info "SwiftLint not configured (optional)"
fi

#===============================================================================
# 10. SETUP SUMMARY
#===============================================================================
print_header "Setup Summary"

echo "Your development environment is set up!"
echo ""
echo "Next steps:"
echo "  1. Edit Config.xcconfig with your API keys"
echo "  2. Open Heirloom.xcodeproj in Xcode"
echo "  3. Wait for Swift Package dependencies to resolve"
echo "  4. Select a simulator and build (⌘B)"
echo "  5. Run the app (⌘R)"
echo ""
echo "Documentation:"
echo "  • README.md - Project overview"
echo "  • CONTRIBUTING.md - Contribution guidelines"
echo "  • docs/PRE_LAUNCH_CHECKLIST.md - Launch preparation"
echo "  • docs/DEPLOYMENT_READY.md - Deployment guide"
echo ""
echo "Useful commands:"
echo "  • ./scripts/test-firestore-rules.sh - Test Firebase rules"
echo "  • swiftlint lint - Run code quality checks"
echo "  • firebase emulators:start - Start local Firebase"
echo ""

print_success "Setup complete! Happy coding! 🚀"
