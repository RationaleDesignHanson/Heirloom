#!/bin/bash
# Convenience wrapper for theme recipe image generation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "$1" in
    preview)
        echo "Previewing prompts (no API calls)..."
        python3 generate_recipe_images.py --preview-only
        ;;

    test)
        echo "Generating 3 test images..."
        python3 generate_recipe_images.py --limit 3
        ;;

    generate)
        echo "Generating all theme recipe images..."
        echo "Estimated time: ~22 minutes for 186 images (7s delay)"
        python3 generate_recipe_images.py
        ;;

    status)
        # Count generated vs total
        if [ ! -f "image_manifest.json" ]; then
            # Count from theme files if manifest doesn't exist
            total=$(python3 -c "import json, glob; files = glob.glob('../../themerecipes/theme-*.json') + glob.glob('../../themerecipes/newthemes/theme-*.json'); print(sum(len(json.load(open(f)).get('recipes', [])) for f in files))" 2>/dev/null || echo "186")
        else
            # Count from manifest
            total=$(python3 -c "import json; print(json.load(open('image_manifest.json'))['total_recipes'])" 2>/dev/null || echo "186")
        fi

        generated=$(ls -1 images/*.webp 2>/dev/null | wc -l | tr -d ' ')
        remaining=$((total - generated))

        echo "================================"
        echo "Theme Recipe Image Generation"
        echo "================================"
        echo "Generated: $generated / $total"
        echo "Remaining: $remaining"

        if [ $generated -gt 0 ]; then
            cost=$(python3 -c "import sys; print(f'{int(sys.argv[1]) * 0.003:.2f}')" "$generated")
            echo "Cost so far: \$$cost"
        fi

        if [ $remaining -gt 0 ]; then
            remaining_cost=$(python3 -c "import sys; print(f'{int(sys.argv[1]) * 0.003:.2f}')" "$remaining")
            echo "Estimated remaining cost: \$$remaining_cost"
        fi
        echo "================================"
        ;;

    # Theme cover commands
    preview-covers)
        echo "Previewing theme cover prompts (no API calls)..."
        python3 generate_theme_covers.py --preview-only
        ;;

    generate-covers)
        echo "Generating theme collection cover images..."
        echo "Estimated time: ~2 minutes for 14 covers (7s delay)"
        python3 generate_theme_covers.py
        ;;

    status-covers)
        total=14
        generated=$(ls -1 theme-covers/*.webp 2>/dev/null | wc -l | tr -d ' ')
        remaining=$((total - generated))

        echo "================================"
        echo "Theme Cover Generation"
        echo "================================"
        echo "Generated: $generated / $total"
        echo "Remaining: $remaining"

        if [ $generated -gt 0 ]; then
            cost=$(python3 -c "import sys; print(f'{int(sys.argv[1]) * 0.003:.2f}')" "$generated")
            echo "Cost so far: \$$cost"
        fi

        if [ $remaining -gt 0 ]; then
            remaining_cost=$(python3 -c "import sys; print(f'{int(sys.argv[1]) * 0.003:.2f}')" "$remaining")
            echo "Estimated remaining cost: \$$remaining_cost"
        fi
        echo "================================"
        ;;

    rename)
        echo "Renaming existing images to include theme prefix..."
        python3 rename_existing_images.py
        ;;

    clean)
        echo "Removing all generated images..."
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f images/*.webp
            rm -f image_manifest.json
            rm -f theme-covers/*.webp
            rm -f theme-covers/theme_covers_manifest.json
            echo "✓ Cleaned"
        else
            echo "Cancelled"
        fi
        ;;

    *)
        echo "Theme Recipe Image Generator"
        echo ""
        echo "Usage:"
        echo "  Recipe Images (186 total from 14 themes):"
        echo "    ./run_image_gen.sh preview          - Show recipe prompts (no cost)"
        echo "    ./run_image_gen.sh test             - Generate 3 test images (\$0.01)"
        echo "    ./run_image_gen.sh generate         - Generate all 186 recipe images (\$0.56)"
        echo "    ./run_image_gen.sh status           - Show recipe generation progress"
        echo ""
        echo "  Theme Cover Images (14 total):"
        echo "    ./run_image_gen.sh preview-covers   - Show cover prompts (no cost)"
        echo "    ./run_image_gen.sh generate-covers  - Generate all 14 cover images (\$0.04)"
        echo "    ./run_image_gen.sh status-covers    - Show cover generation progress"
        echo ""
        echo "  Maintenance:"
        echo "    ./run_image_gen.sh rename           - Rename old images to include theme prefix"
        echo "    ./run_image_gen.sh clean            - Remove all generated images"
        echo ""
        echo "Environment:"
        echo "  REPLICATE_API_TOKEN - Your Replicate API token (required)"
        echo ""
        echo "Total Cost: \$0.60 (186 recipes + 14 covers)"
        echo ""
        exit 1
        ;;
esac
