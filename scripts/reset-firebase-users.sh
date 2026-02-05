#!/bin/bash
#
# reset-firebase-users.sh
# Resets all user data in Firebase to day 0 state
# KEEPS: themes collection (theme definitions and recipes)
# DELETES: all user data, shares, lineages, public recipes, etc.
#
# Usage: ./scripts/reset-firebase-users.sh
#

set -e

PROJECT_ID="heirloom-ios-prod"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

echo ""
echo "=========================================="
echo "  Firebase User Data Reset"
echo "  Project: $PROJECT_ID"
echo "=========================================="
echo ""

log_warning "This will DELETE all user data from Firebase!"
echo ""
echo "Collections to be DELETED:"
echo "  - users (all user data, recipes, collections, etc.)"
echo "  - shares (shared recipes between users)"
echo "  - lineages (recipe version tracking)"
echo "  - publicRecipes (published recipes)"
echo "  - publicRecipeReports (reports)"
echo "  - publicProfiles"
echo "  - userProfiles"
echo ""
echo "Collections to be KEPT:"
echo "  - themes (heritage theme definitions and recipes)"
echo ""

read -p "Are you sure you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Aborted."
    exit 0
fi

echo ""
log_info "Checking Firebase CLI..."

if ! command -v firebase &> /dev/null; then
    log_error "Firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    log_warning "Not logged into Firebase. Running firebase login..."
    firebase login
fi

echo ""
log_info "Starting deletion (this may take a while)..."
echo ""

# Collections to delete
COLLECTIONS=(
    "users"
    "shares"
    "lineages"
    "publicRecipes"
    "publicRecipeReports"
    "publicProfiles"
    "userProfiles"
)

for collection in "${COLLECTIONS[@]}"; do
    log_info "Deleting $collection..."
    firebase firestore:delete --project "$PROJECT_ID" -r "$collection" --force 2>/dev/null || {
        log_warning "Collection $collection may not exist or is already empty"
    }
done

echo ""
log_success "Firebase user data reset complete!"
echo ""
log_info "Next steps:"
echo "  1. Uninstall app from simulator: xcrun simctl uninstall booted com.rationaledesign.heirloom"
echo "  2. Rebuild and run from Xcode"
echo "  3. All users will see fresh onboarding"
echo ""
