#!/bin/bash

# ASMR Video Import - Implementation Verification Script
# This script checks that all files are in place and identifies common issues

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
total_checks=0
passed_checks=0
failed_checks=0
warnings=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ASMR Video Import - Implementation Verification          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if file exists
check_file() {
    local file=$1
    local description=$2
    total_checks=$((total_checks + 1))

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo -e "   ${RED}Missing: $file${NC}"
        failed_checks=$((failed_checks + 1))
        return 1
    fi
}

# Function to check directory
check_directory() {
    local dir=$1
    local description=$2
    total_checks=$((total_checks + 1))

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo -e "   ${RED}Missing directory: $dir${NC}"
        failed_checks=$((failed_checks + 1))
        return 1
    fi
}

# Function to check file contains text
check_file_contains() {
    local file=$1
    local text=$2
    local description=$3
    total_checks=$((total_checks + 1))

    if [ -f "$file" ] && grep -q "$text" "$file"; then
        echo -e "${GREEN}✓${NC} $description"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $description"
        echo -e "   ${YELLOW}File exists but doesn't contain expected text${NC}"
        warnings=$((warnings + 1))
        return 1
    fi
}

# Function to count lines in file
count_lines() {
    local file=$1
    if [ -f "$file" ]; then
        wc -l < "$file" | tr -d ' '
    else
        echo "0"
    fi
}

echo -e "${BLUE}[1/8] Checking Core Service Files...${NC}"
check_directory "Heirloom/Core/Services/Video/ASMR" "ASMR service directory"
check_file "Heirloom/Core/Services/Video/ASMR/Protocols/ASMRProcessingProtocols.swift" "ASMRProcessingProtocols.swift"
check_file "Heirloom/Core/Services/Video/ASMR/Analysis/ASMRSoundAnalysisService.swift" "ASMRSoundAnalysisService.swift"
check_file "Heirloom/Core/Services/Video/ASMR/Analysis/ASMRFrameExtractionService.swift" "ASMRFrameExtractionService.swift"
check_file "Heirloom/Core/Services/Video/ASMR/Structuring/ASMRRecipeStructurer.swift" "ASMRRecipeStructurer.swift"
check_file "Heirloom/Core/Services/Video/ASMR/Coordination/ASMRVideoProcessor.swift" "ASMRVideoProcessor.swift"
check_file "Heirloom/Core/Services/Video/ASMR/Usage/ASMRUsageManager.swift" "ASMRUsageManager.swift"
echo ""

echo -e "${BLUE}[2/8] Checking Data Models...${NC}"
check_file "Heirloom/Core/Models/ASMRRecipeExtraction.swift" "ASMRRecipeExtraction.swift"
echo ""

echo -e "${BLUE}[3/8] Checking UI Components...${NC}"
check_directory "Heirloom/Features/Recipes/ASMRVideoImport" "ASMR UI directory"
check_file "Heirloom/Features/Recipes/ASMRVideoImport/Views/ASMRVideoImportView.swift" "ASMRVideoImportView.swift"
check_file "Heirloom/Features/Recipes/ASMRVideoImport/Views/ASMRProcessingView.swift" "ASMRProcessingView.swift"
check_file "Heirloom/Features/Recipes/ASMRVideoImport/Components/ASMRUsageBadge.swift" "ASMRUsageBadge.swift"
check_file "Heirloom/Features/Recipes/ASMRVideoImport/Components/ASMRPassProgressCard.swift" "ASMRPassProgressCard.swift"
echo ""

echo -e "${BLUE}[4/8] Checking Integration Points...${NC}"
check_file_contains "Heirloom/Features/Recipes/RecipeList/Components/Toolbar/RecipeListToolbarActions.swift" "onASMRVideoImport" "RecipeListToolbarActions has ASMR callback"
check_file_contains "Heirloom/Features/Recipes/RecipeList/Components/Toolbar/RecipeListToolbarActions.swift" "From Silent Video" "RecipeListToolbarActions has menu item"
check_file_contains "Heirloom/Features/Recipes/RecipeList/RecipeListView.swift" "showASMRVideoImport" "RecipeListView has ASMR state"
check_file_contains "Heirloom/Features/Recipes/RecipeList/Components/Modifiers/RecipeSheetModifiers.swift" "showASMRVideoImport" "RecipeSheetModifiers has ASMR binding"
check_file_contains "Heirloom/Features/Recipes/RecipeList/Components/Modifiers/RecipeSheetModifiers.swift" "ASMRVideoImportView" "RecipeSheetModifiers presents ASMR view"
echo ""

echo -e "${BLUE}[5/8] Checking Test Files...${NC}"
check_directory "HeirloomTests/Services/ASMR" "ASMR test directory"
check_file "HeirloomTests/Services/ASMR/ASMRUsageManagerTests.swift" "ASMRUsageManagerTests.swift"
check_file "HeirloomTests/Services/ASMR/ASMRVideoProcessorIntegrationTests.swift" "ASMRVideoProcessorIntegrationTests.swift"
echo ""

echo -e "${BLUE}[6/8] Checking Test Videos...${NC}"
total_checks=$((total_checks + 1))
if [ -d "/Users/matthanson/Downloads/asmrsamples" ] && [ "$(ls -A /Users/matthanson/Downloads/asmrsamples)" ]; then
    video_count=$(ls /Users/matthanson/Downloads/asmrsamples/*.MOV 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} Test video directory exists with $video_count video(s)"
    passed_checks=$((passed_checks + 1))
else
    echo -e "${YELLOW}⚠${NC} Test video directory empty or missing"
    echo -e "   ${YELLOW}Expected videos at: /Users/matthanson/Downloads/asmrsamples/${NC}"
    warnings=$((warnings + 1))
fi
echo ""

echo -e "${BLUE}[7/8] Analyzing Implementation...${NC}"
echo ""

# Count total lines of code
total_service_lines=0
total_ui_lines=0
total_test_lines=0

service_files=(
    "Heirloom/Core/Services/Video/ASMR/Protocols/ASMRProcessingProtocols.swift"
    "Heirloom/Core/Services/Video/ASMR/Analysis/ASMRSoundAnalysisService.swift"
    "Heirloom/Core/Services/Video/ASMR/Analysis/ASMRFrameExtractionService.swift"
    "Heirloom/Core/Services/Video/ASMR/Structuring/ASMRRecipeStructurer.swift"
    "Heirloom/Core/Services/Video/ASMR/Coordination/ASMRVideoProcessor.swift"
    "Heirloom/Core/Services/Video/ASMR/Usage/ASMRUsageManager.swift"
    "Heirloom/Core/Models/ASMRRecipeExtraction.swift"
)

ui_files=(
    "Heirloom/Features/Recipes/ASMRVideoImport/Views/ASMRVideoImportView.swift"
    "Heirloom/Features/Recipes/ASMRVideoImport/Views/ASMRProcessingView.swift"
    "Heirloom/Features/Recipes/ASMRVideoImport/Components/ASMRUsageBadge.swift"
    "Heirloom/Features/Recipes/ASMRVideoImport/Components/ASMRPassProgressCard.swift"
)

test_files=(
    "HeirloomTests/Services/ASMR/ASMRUsageManagerTests.swift"
    "HeirloomTests/Services/ASMR/ASMRVideoProcessorIntegrationTests.swift"
)

for file in "${service_files[@]}"; do
    lines=$(count_lines "$file")
    total_service_lines=$((total_service_lines + lines))
done

for file in "${ui_files[@]}"; do
    lines=$(count_lines "$file")
    total_ui_lines=$((total_ui_lines + lines))
done

for file in "${test_files[@]}"; do
    lines=$(count_lines "$file")
    total_test_lines=$((total_test_lines + lines))
done

total_lines=$((total_service_lines + total_ui_lines + total_test_lines))

echo "  📊 Code Statistics:"
echo "     Services & Models: $total_service_lines lines"
echo "     UI Components:     $total_ui_lines lines"
echo "     Tests:             $total_test_lines lines"
echo "     ─────────────────────────────"
echo "     Total:             $total_lines lines"
echo ""

echo -e "${BLUE}[8/8] Checking Build Configuration...${NC}"
total_checks=$((total_checks + 1))
if [ -f "Heirloom.xcodeproj/project.pbxproj" ]; then
    echo -e "${GREEN}✓${NC} Xcode project file exists"
    passed_checks=$((passed_checks + 1))
else
    echo -e "${RED}✗${NC} Xcode project file not found"
    failed_checks=$((failed_checks + 1))
fi

# Check if files are in Xcode project (basic check)
total_checks=$((total_checks + 1))
if grep -q "ASMRProcessingProtocols.swift" "Heirloom.xcodeproj/project.pbxproj" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} ASMR files appear in Xcode project"
    passed_checks=$((passed_checks + 1))
else
    echo -e "${YELLOW}⚠${NC} ASMR files may not be added to Xcode project yet"
    echo -e "   ${YELLOW}Run: open Heirloom.xcodeproj and add files manually${NC}"
    warnings=$((warnings + 1))
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Verification Summary                                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Total Checks:    $total_checks"
echo -e "  ${GREEN}Passed:          $passed_checks${NC}"
if [ $failed_checks -gt 0 ]; then
    echo -e "  ${RED}Failed:          $failed_checks${NC}"
fi
if [ $warnings -gt 0 ]; then
    echo -e "  ${YELLOW}Warnings:        $warnings${NC}"
fi
echo ""

# Overall result
if [ $failed_checks -eq 0 ]; then
    if [ $warnings -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed! Implementation is complete.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Open Xcode: open Heirloom.xcodeproj"
        echo "  2. Build project: Cmd+B"
        echo "  3. Run tests: Cmd+U"
        echo "  4. See ASMR_INTEGRATION_GUIDE.md for detailed testing"
        exit 0
    else
        echo -e "${YELLOW}⚠ Implementation complete with warnings.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Review warnings above"
        echo "  2. Add files to Xcode project if not already added"
        echo "  3. See ASMR_INTEGRATION_GUIDE.md for details"
        exit 0
    fi
else
    echo -e "${RED}✗ Some checks failed. Review errors above.${NC}"
    echo ""
    echo "Common issues:"
    echo "  - Missing files: Ensure all files were created successfully"
    echo "  - Wrong directory: Check you're in /Users/matthanson/Heirloom"
    echo "  - Partial implementation: Re-run the implementation script"
    exit 1
fi
