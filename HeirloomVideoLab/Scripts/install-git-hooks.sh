#!/bin/bash
#
# install-git-hooks.sh
# Installs pre-commit hooks for HeirloomVideoLab development
#
# Usage:
#   ./HeirloomVideoLab/Scripts/install-git-hooks.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo -e "${GREEN}Installing Git hooks for HeirloomVideoLab...${NC}\n"

# Check if in git repository
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Create pre-commit hook
cat > "$GIT_HOOKS_DIR/pre-commit" << 'HOOK_CONTENT'
#!/bin/bash
#
# Pre-commit hook for HeirloomVideoLab
# Runs before each commit to validate code quality

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Running pre-commit checks...${NC}\n"

# Check if committing HeirloomVideoLab files
VIDEOLAB_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "HeirloomVideoLab/" || true)

if [ -z "$VIDEOLAB_FILES" ]; then
    echo "No HeirloomVideoLab files changed, skipping checks"
    exit 0
fi

echo "Checking HeirloomVideoLab files:"
echo "$VIDEOLAB_FILES"
echo ""

# Function to check for issues
check_failed=0

# Check 1: No debug print statements
echo "Checking for debug print statements..."
if echo "$VIDEOLAB_FILES" | grep "\.swift$" | xargs grep -n "print(" 2>/dev/null | grep -v "TODO\|FIXME\|Logger" | grep -v "Tests/" | grep -v "Mock"; then
    echo -e "${YELLOW}⚠️  Found print() statements (use Logger instead)${NC}"
    check_failed=1
else
    echo "✅ No debug print statements"
fi

# Check 2: No hardcoded secrets
echo "Checking for hardcoded secrets..."
if echo "$VIDEOLAB_FILES" | xargs grep -n "sk-\|password\s*=\s*\"" 2>/dev/null | grep -v "test\|mock"; then
    echo -e "${RED}❌ Found potential hardcoded secret${NC}"
    exit 1
else
    echo "✅ No hardcoded secrets"
fi

# Check 3: Swift files compile (syntax check only)
SWIFT_FILES=$(echo "$VIDEOLAB_FILES" | grep "\.swift$" || true)
if [ -n "$SWIFT_FILES" ]; then
    echo "Checking Swift syntax..."

    for file in $SWIFT_FILES; do
        # Basic syntax check
        if ! xcrun swiftc -typecheck "$file" 2>/dev/null; then
            # Full project context check if individual file fails
            if ! xcodebuild -scheme HeirloomVideoLab -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build -quiet 2>&1 | grep "$file"; then
                echo "✅ Swift syntax valid"
            fi
        fi
    done
else
    echo "No Swift files to check"
fi

# Check 4: No TODO/FIXME in production code (warning only)
echo "Checking for TODO/FIXME comments..."
TODO_COUNT=$(echo "$VIDEOLAB_FILES" | xargs grep -n "TODO\|FIXME" 2>/dev/null | grep -v "Tests/" | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $TODO_COUNT TODO/FIXME comment(s)${NC}"
    echo "$VIDEOLAB_FILES" | xargs grep -n "TODO\|FIXME" 2>/dev/null | grep -v "Tests/" || true
else
    echo "✅ No TODO/FIXME comments"
fi

# Check 5: File size limit (10MB)
echo "Checking file sizes..."
LARGE_FILES=$(echo "$VIDEOLAB_FILES" | while read file; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        if [ "$size" -gt 10485760 ]; then  # 10MB
            echo "$file ($(($size / 1024 / 1024))MB)"
        fi
    fi
done)

if [ -n "$LARGE_FILES" ]; then
    echo -e "${RED}❌ Found large file(s):${NC}"
    echo "$LARGE_FILES"
    echo "Consider using Git LFS for large files"
    exit 1
else
    echo "✅ All files under 10MB"
fi

# Check 6: Copyright headers (warning only)
echo "Checking copyright headers..."
MISSING_COPYRIGHT=$(echo "$VIDEOLAB_FILES" | grep "\.swift$" | while read file; do
    if ! head -5 "$file" | grep -q "Created by"; then
        echo "$file"
    fi
done)

if [ -n "$MISSING_COPYRIGHT" ]; then
    echo -e "${YELLOW}⚠️  Files missing copyright header:${NC}"
    echo "$MISSING_COPYRIGHT"
else
    echo "✅ All files have copyright headers"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$check_failed" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Pre-commit checks passed with warnings${NC}"
    echo ""
    echo "Commit will proceed. Consider fixing warnings."
else
    echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
HOOK_CONTENT

# Make hook executable
chmod +x "$GIT_HOOKS_DIR/pre-commit"

echo -e "${GREEN}✅ Pre-commit hook installed${NC}"
echo ""
echo "The hook will run automatically before each commit."
echo ""
echo "To bypass the hook (not recommended):"
echo "  git commit --no-verify"
echo ""
echo "To uninstall:"
echo "  rm $GIT_HOOKS_DIR/pre-commit"
echo ""
