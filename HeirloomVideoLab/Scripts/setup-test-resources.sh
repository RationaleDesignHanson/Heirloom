#!/bin/bash
#
# setup-test-resources.sh
# Downloads and organizes test resources for HeirloomVideoLab testing
#
# Usage:
#   ./Scripts/setup-test-resources.sh
#
# Environment variables:
#   TEST_VIDEOS_URL - Base URL for video storage (S3, Dropbox, etc.)
#   SKIP_DOWNLOAD - Set to 1 to skip downloads (use local files)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESOURCES_DIR="$PROJECT_ROOT/TestResources"
VIDEOS_DIR="$TEST_RESOURCES_DIR/Videos"
AUDIO_DIR="$TEST_RESOURCES_DIR/Audio"
GROUND_TRUTH_DIR="$TEST_RESOURCES_DIR/GroundTruth"

echo -e "${GREEN}Setting up HeirloomVideoLab test resources...${NC}\n"

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$VIDEOS_DIR"
mkdir -p "$AUDIO_DIR"
mkdir -p "$GROUND_TRUTH_DIR"

# Function to check if file exists and is valid
check_file() {
    local file=$1
    local min_size=${2:-1000}  # Minimum 1KB by default

    if [ -f "$file" ]; then
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        if [ "$size" -gt "$min_size" ]; then
            return 0  # File exists and is large enough
        fi
    fi
    return 1  # File missing or too small
}

# Download test videos
download_videos() {
    echo -e "\n${YELLOW}Test Video Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check if download should be skipped
    if [ "${SKIP_DOWNLOAD}" = "1" ]; then
        echo "⏭️  Skipping downloads (SKIP_DOWNLOAD=1)"
        return
    fi

    # Check for TEST_VIDEOS_URL environment variable
    if [ -z "${TEST_VIDEOS_URL}" ]; then
        echo -e "${YELLOW}⚠️  TEST_VIDEOS_URL not set${NC}"
        echo ""
        echo "To download test videos automatically, set TEST_VIDEOS_URL:"
        echo "  export TEST_VIDEOS_URL='https://your-storage-url/videos/'"
        echo ""
        echo "Or manually add these videos to TestResources/Videos/:"
        echo "  • sample_recipe.mp4 (30-60s, simple recipe)"
        echo "  • recipe_with_text.mp4 (1-2 min, on-screen text)"
        echo "  • silent_video.mp4 (30s, no audio track)"
        echo "  • noisy_audio.mp4 (1 min, poor audio quality)"
        echo "  • long_recipe.mp4 (10-15 min, full recipe)"
        echo "  • sample_audio.m4a (30s, pre-extracted audio)"
        echo ""
        return
    fi

    # Define test videos
    declare -A videos=(
        ["sample_recipe.mp4"]="Simple 30-60s recipe (scrambled eggs, etc.)"
        ["recipe_with_text.mp4"]="1-2 min recipe with on-screen text overlays"
        ["silent_video.mp4"]="30s video without audio track (error testing)"
        ["noisy_audio.mp4"]="1 min video with background noise"
        ["long_recipe.mp4"]="10-15 min full recipe tutorial"
    )

    declare -A audio=(
        ["sample_audio.m4a"]="30s pre-extracted audio file"
    )

    echo "Downloading test videos..."
    for video in "${!videos[@]}"; do
        if check_file "$VIDEOS_DIR/$video" 100000; then
            echo -e "  ✓ $video ${GREEN}(already exists)${NC}"
        else
            echo -e "  ⬇ Downloading $video..."
            echo -e "    ${videos[$video]}"

            # Try to download
            if curl -f -L -o "$VIDEOS_DIR/$video" "${TEST_VIDEOS_URL}${video}" 2>/dev/null; then
                echo -e "    ${GREEN}✓ Downloaded${NC}"
            else
                echo -e "    ${RED}✗ Download failed${NC}"
                echo -e "    ${YELLOW}Please add manually: $VIDEOS_DIR/$video${NC}"
            fi
        fi
    done

    echo -e "\nDownloading test audio..."
    for audio_file in "${!audio[@]}"; do
        if check_file "$AUDIO_DIR/$audio_file" 10000; then
            echo -e "  ✓ $audio_file ${GREEN}(already exists)${NC}"
        else
            echo -e "  ⬇ Downloading $audio_file..."

            if curl -f -L -o "$AUDIO_DIR/$audio_file" "${TEST_VIDEOS_URL}${audio_file}" 2>/dev/null; then
                echo -e "    ${GREEN}✓ Downloaded${NC}"
            else
                echo -e "    ${RED}✗ Download failed${NC}"
                echo -e "    ${YELLOW}Please add manually: $AUDIO_DIR/$audio_file${NC}"
            fi
        fi
    done
}

# Create ground truth files
create_ground_truth() {
    echo -e "\n${YELLOW}Ground Truth Files${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Sample recipe expected output
    local sample_recipe_expected="$GROUND_TRUTH_DIR/sample_recipe_expected.json"
    if [ ! -f "$sample_recipe_expected" ]; then
        echo "Creating sample_recipe_expected.json..."
        cat > "$sample_recipe_expected" << 'EOF'
{
  "title": "Simple Scrambled Eggs",
  "description": "Quick and easy scrambled eggs for breakfast",
  "servings": "2 servings",
  "prepTime": "2 minutes",
  "cookTime": "5 minutes",
  "ingredients": [
    {
      "item": "eggs",
      "quantity": "4",
      "unit": null,
      "confidence": "explicit"
    },
    {
      "item": "butter",
      "quantity": "1",
      "unit": "tablespoon",
      "confidence": "explicit"
    },
    {
      "item": "salt",
      "quantity": "to taste",
      "unit": null,
      "confidence": "approximate"
    },
    {
      "item": "black pepper",
      "quantity": "to taste",
      "unit": null,
      "confidence": "approximate"
    }
  ],
  "steps": [
    {
      "instruction": "Heat butter in a non-stick pan over medium heat",
      "temperature": "medium heat",
      "confidence": "explicit"
    },
    {
      "instruction": "Crack eggs into a bowl and whisk until combined",
      "confidence": "explicit"
    },
    {
      "instruction": "Pour eggs into the pan and stir gently",
      "confidence": "explicit"
    },
    {
      "instruction": "Cook until just set, about 2-3 minutes",
      "duration": "2-3 minutes",
      "confidence": "explicit"
    },
    {
      "instruction": "Season with salt and pepper to taste",
      "confidence": "explicit"
    }
  ],
  "expectedConfidence": 0.85
}
EOF
        echo -e "  ${GREEN}✓ Created${NC}"
    else
        echo -e "  ✓ sample_recipe_expected.json ${GREEN}(already exists)${NC}"
    fi

    # Recipe with text expected output
    local text_recipe_expected="$GROUND_TRUTH_DIR/recipe_with_text_expected.json"
    if [ ! -f "$text_recipe_expected" ]; then
        echo "Creating recipe_with_text_expected.json..."
        cat > "$text_recipe_expected" << 'EOF'
{
  "title": "Chocolate Chip Cookies",
  "description": "Classic homemade chocolate chip cookies",
  "servings": "24 cookies",
  "prepTime": "15 minutes",
  "cookTime": "12 minutes",
  "ingredients": [
    {
      "item": "all-purpose flour",
      "quantity": "2",
      "unit": "cups",
      "confidence": "visual"
    },
    {
      "item": "butter",
      "quantity": "1",
      "unit": "cup",
      "confidence": "visual"
    },
    {
      "item": "granulated sugar",
      "quantity": "3/4",
      "unit": "cup",
      "confidence": "explicit"
    },
    {
      "item": "brown sugar",
      "quantity": "3/4",
      "unit": "cup",
      "confidence": "explicit"
    },
    {
      "item": "eggs",
      "quantity": "2",
      "unit": null,
      "confidence": "explicit"
    },
    {
      "item": "vanilla extract",
      "quantity": "2",
      "unit": "teaspoons",
      "confidence": "explicit"
    },
    {
      "item": "baking soda",
      "quantity": "1",
      "unit": "teaspoon",
      "confidence": "visual"
    },
    {
      "item": "salt",
      "quantity": "1",
      "unit": "teaspoon",
      "confidence": "visual"
    },
    {
      "item": "chocolate chips",
      "quantity": "2",
      "unit": "cups",
      "confidence": "explicit"
    }
  ],
  "steps": [
    {
      "instruction": "Preheat oven to 375°F",
      "temperature": "375°F",
      "confidence": "visual"
    },
    {
      "instruction": "Cream butter and sugars until fluffy",
      "duration": "2-3 minutes",
      "confidence": "explicit"
    },
    {
      "instruction": "Beat in eggs and vanilla",
      "confidence": "explicit"
    },
    {
      "instruction": "Mix in flour, baking soda, and salt",
      "confidence": "explicit"
    },
    {
      "instruction": "Stir in chocolate chips",
      "confidence": "explicit"
    },
    {
      "instruction": "Drop spoonfuls onto baking sheet",
      "confidence": "explicit"
    },
    {
      "instruction": "Bake for 10-12 minutes until golden brown",
      "duration": "10-12 minutes",
      "temperature": "375°F",
      "confidence": "visual"
    }
  ],
  "expectedConfidence": 0.90,
  "visualElements": ["375°F", "10-12 minutes", "2 cups flour", "1 tsp baking soda"]
}
EOF
        echo -e "  ${GREEN}✓ Created${NC}"
    else
        echo -e "  ✓ recipe_with_text_expected.json ${GREEN}(already exists)${NC}"
    fi

    # Create README for ground truth
    local ground_truth_readme="$GROUND_TRUTH_DIR/README.md"
    if [ ! -f "$ground_truth_readme" ]; then
        cat > "$ground_truth_readme" << 'EOF'
# Ground Truth Files

These JSON files contain the expected extraction results for each test video. They are used to validate extraction accuracy.

## Format

```json
{
  "title": "Recipe Name",
  "description": "Brief description (optional)",
  "servings": "X servings",
  "prepTime": "X minutes",
  "cookTime": "X minutes",
  "ingredients": [
    {
      "item": "ingredient name",
      "quantity": "amount",
      "unit": "cups/tbsp/etc or null",
      "confidence": "explicit|visual|inferred|approximate|unknown"
    }
  ],
  "steps": [
    {
      "instruction": "What to do",
      "duration": "X minutes (optional)",
      "temperature": "X°F (optional)",
      "confidence": "explicit|inferred"
    }
  ],
  "expectedConfidence": 0.85,
  "visualElements": ["list", "of", "on-screen", "text"]
}
```

## Creating New Ground Truth Files

1. Process the video manually
2. Watch the video and transcribe exactly what is said
3. Note any on-screen text (temperatures, times, measurements)
4. Create JSON file with expected extraction
5. Name it `{video_filename}_expected.json`

## Validation

Use the accuracy validation script:

```bash
./Scripts/validate-accuracy.swift sample_recipe.mp4
```
EOF
        echo -e "  ${GREEN}✓ Created ground truth README${NC}"
    fi
}

# Create .gitignore for test resources
create_gitignore() {
    echo -e "\n${YELLOW}Git Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local gitignore="$TEST_RESOURCES_DIR/.gitignore"
    if [ ! -f "$gitignore" ]; then
        echo "Creating .gitignore..."
        cat > "$gitignore" << 'EOF'
# Test videos (too large for git)
Videos/*.mp4
Videos/*.mov
Videos/*.avi

# Test audio (too large for git)
Audio/*.m4a
Audio/*.mp3
Audio/*.wav

# Keep ground truth files (small JSON)
!GroundTruth/*.json

# Download these videos using:
# ./Scripts/setup-test-resources.sh
EOF
        echo -e "  ${GREEN}✓ Created${NC}"
    else
        echo -e "  ✓ .gitignore ${GREEN}(already exists)${NC}"
    fi
}

# Validate setup
validate_setup() {
    echo -e "\n${YELLOW}Validation${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local missing_count=0
    local present_count=0

    # Check videos
    echo "Checking test videos..."
    for video in sample_recipe.mp4 recipe_with_text.mp4 silent_video.mp4 noisy_audio.mp4 long_recipe.mp4; do
        if check_file "$VIDEOS_DIR/$video" 100000; then
            echo -e "  ${GREEN}✓${NC} $video"
            ((present_count++))
        else
            echo -e "  ${RED}✗${NC} $video ${YELLOW}(missing or too small)${NC}"
            ((missing_count++))
        fi
    done

    # Check audio
    echo -e "\nChecking test audio..."
    if check_file "$AUDIO_DIR/sample_audio.m4a" 10000; then
        echo -e "  ${GREEN}✓${NC} sample_audio.m4a"
        ((present_count++))
    else
        echo -e "  ${RED}✗${NC} sample_audio.m4a ${YELLOW}(missing or too small)${NC}"
        ((missing_count++))
    fi

    # Check ground truth
    echo -e "\nChecking ground truth files..."
    for json in sample_recipe_expected.json recipe_with_text_expected.json; do
        if [ -f "$GROUND_TRUTH_DIR/$json" ]; then
            echo -e "  ${GREEN}✓${NC} $json"
            ((present_count++))
        else
            echo -e "  ${RED}✗${NC} $json ${YELLOW}(missing)${NC}"
            ((missing_count++))
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ $missing_count -eq 0 ]; then
        echo -e "${GREEN}✓ All test resources ready!${NC}"
        echo -e "\nYou can now:"
        echo "  1. Create Xcode test target"
        echo "  2. Add TestResources to target"
        echo "  3. Run tests"
    else
        echo -e "${YELLOW}⚠️  $missing_count test resource(s) missing${NC}"
        echo ""
        echo "To add missing videos:"
        echo "  1. Record or download appropriate test videos"
        echo "  2. Place in $VIDEOS_DIR/"
        echo "  3. Run this script again to validate"
        echo ""
        echo "Or set TEST_VIDEOS_URL and re-run:"
        echo "  export TEST_VIDEOS_URL='https://your-storage/videos/'"
        echo "  ./Scripts/setup-test-resources.sh"
    fi
    echo ""
}

# Main execution
main() {
    download_videos
    create_ground_truth
    create_gitignore
    validate_setup
}

main
