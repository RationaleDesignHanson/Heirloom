#!/bin/bash
#
# feature-tool.sh
# Heirloom Feature Management CLI
#
# Usage:
#   ./scripts/feature-tool.sh list            - List all features
#   ./scripts/feature-tool.sh coverage        - Show coverage report
#   ./scripts/feature-tool.sh gates           - Validate feature gates
#   ./scripts/feature-tool.sh validate        - Validate dependencies
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage
usage() {
    echo "Heirloom Feature Management CLI"
    echo ""
    echo "Usage:"
    echo "  $0 <command>"
    echo ""
    echo "Commands:"
    echo "  list        List all features with their states"
    echo "  coverage    Show test coverage report"
    echo "  gates       Validate feature lifecycle gates"
    echo "  validate    Validate feature dependencies"
    echo "  help        Show this help message"
    echo ""
    exit 1
}

# List features
cmd_list() {
    echo -e "${BLUE}=== Heirloom Features ===${NC}"
    echo ""

    swift "$SCRIPT_DIR/list-features.swift"
}

# Show coverage
cmd_coverage() {
    echo -e "${BLUE}=== Test Coverage Report ===${NC}"
    echo ""

    if [ -f "coverage.json" ]; then
        swift "$SCRIPT_DIR/check-coverage.swift" coverage.json
    elif [ -f ".build/coverage.json" ]; then
        swift "$SCRIPT_DIR/check-coverage.swift" .build/coverage.json
    else
        echo -e "${RED}❌ Coverage file not found${NC}"
        echo "Run tests with coverage first:"
        echo "  xcodebuild test -scheme Heirloom -enableCodeCoverage YES"
        exit 1
    fi
}

# Validate gates
cmd_gates() {
    echo -e "${BLUE}=== Feature Lifecycle Gates ===${NC}"
    echo ""

    swift "$SCRIPT_DIR/check-feature-gates.swift"
}

# Validate dependencies
cmd_validate() {
    echo -e "${BLUE}=== Dependency Validation ===${NC}"
    echo ""

    swift "$SCRIPT_DIR/validate-features.swift"
}

# Main
case "${1:-}" in
    list)
        cmd_list
        ;;
    coverage)
        cmd_coverage
        ;;
    gates)
        cmd_gates
        ;;
    validate)
        cmd_validate
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: ${1:-}${NC}"
        echo ""
        usage
        ;;
esac
