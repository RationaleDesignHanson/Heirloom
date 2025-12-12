#!/usr/bin/env env python3
"""
Heirloom Sticker Generator
Generates Phase 1 stickers (20 total) using DALL-E 3 API
"""

import os
import sys
import time
import requests
from pathlib import Path
from datetime import datetime

try:
    from openai import OpenAI
    from tqdm import tqdm
except ImportError:
    print("Missing required packages. Install with:")
    print("pip install openai tqdm requests")
    sys.exit(1)


# Sticker definitions with optimized DALL-E 3 prompts
PHASE_1_STICKERS = [
    # Food & Ingredients (6 stickers)
    {
        "filename": "sticker_food_tomato.png",
        "category": "food",
        "name": "Tomato",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a plump red heirloom tomato with bright crimson skin and a green leafy stem on top, warm nostalgic color palette featuring tomato red and sage green, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_food_garlic.png",
        "category": "food",
        "name": "Garlic Bulb",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a whole garlic bulb with papery white skin and 2-3 separated cloves beside it, warm nostalgic color palette featuring cream and brown shadows, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_food_lemon.png",
        "category": "food",
        "name": "Lemon Slice",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a cross-section of a lemon showing detailed segments and seeds in the center, bright golden yellow flesh with cream highlights, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_food_egg.png",
        "category": "food",
        "name": "Egg",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a cracked egg with the shell broken open showing bright golden yolk and cream-colored egg white, warm nostalgic color palette, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_food_pie.png",
        "category": "food",
        "name": "Pie Slice",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a triangular slice of pie with lattice crust on top and three small steam wisps rising from it, warm nostalgic color palette featuring golden filling and brown crust, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_food_cookie.png",
        "category": "food",
        "name": "Cookie",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a round chocolate chip cookie with a small bite taken out of one side showing texture, warm nostalgic color palette featuring brown cookie and dark chocolate chips, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    
    # Kitchen Tools (4 stickers)
    {
        "filename": "sticker_tools_woodenspoon.png",
        "category": "tools",
        "name": "Wooden Spoon",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a well-worn wooden spoon with visible wood grain texture and slightly rounded bowl, warm nostalgic color palette featuring brown wood tones with cream highlights, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_tools_whisk.png",
        "category": "tools",
        "name": "Whisk",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a wire whisk with 8-10 loops and wooden handle, slightly bent from use showing character, warm nostalgic color palette featuring brown handle and silver-grey wires, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_tools_rollingpin.png",
        "category": "tools",
        "name": "Rolling Pin",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a classic wooden rolling pin with handles on both ends and visible wood grain, warm nostalgic color palette featuring brown and cream tones, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_tools_knife.png",
        "category": "tools",
        "name": "Chef's Knife",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a professional chef's knife with silver blade and dark brown wooden handle with visible bolster and three rivets, warm nostalgic color palette, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    
    # Badges & Labels (4 stickers)
    {
        "filename": "sticker_badge_familyrecipe.png",
        "category": "badges",
        "name": "Family Recipe Badge",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a circular badge with scalloped edges containing the text 'FAMILY RECIPE' in serif font, warm nostalgic color palette featuring red border and cream background, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable design, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_badge_tested.png",
        "category": "badges",
        "name": "Tested & Approved",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a circular seal badge with the text 'TESTED & APPROVED' around the edge and a large checkmark in the center, warm nostalgic color palette featuring sage green with cream accents, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable design, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_badge_madewithlove.png",
        "category": "badges",
        "name": "Made With Love",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a heart-shaped badge with the text 'MADE WITH LOVE' in script font inside, warm nostalgic color palette featuring red heart outline with cream fill, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable design, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_badge_fivestars.png",
        "category": "badges",
        "name": "Five Stars",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, five hand-drawn stars in a horizontal row, warm nostalgic color palette featuring golden yellow stars, slightly imperfect organic linework with visible brush strokes showing each star is unique and hand-drawn, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable design, cozy grandma's kitchen vibes, centered composition"
    },
    
    # Emotions & Memories (4 stickers)
    {
        "filename": "sticker_emotion_heart.png",
        "category": "emotions",
        "name": "Heart",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a hand-drawn heart outline that is slightly asymmetrical and imperfect showing authentic character, warm nostalgic color palette featuring red, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_emotion_star.png",
        "category": "emotions",
        "name": "Star",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a five-point star with slightly wobbly lines showing hand-drawn character, warm nostalgic color palette featuring golden yellow, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_emotion_coffeestain.png",
        "category": "emotions",
        "name": "Coffee Stain",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a circular coffee stain ring with irregular edges and realistic brown watercolor texture showing where a coffee mug was placed, warm nostalgic color palette featuring brown tones varying in opacity, slightly imperfect organic edges, mid-century modern aesthetic, isolated on pure white background for transparency, subtle texture showing paper absorption, simple and readable shape, cozy grandma's kitchen vibes, centered composition"
    },
    {
        "filename": "sticker_emotion_fingerprint.png",
        "category": "emotions",
        "name": "Fingerprint",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a smudged fingerprint as if left by floury hands in dough, warm nostalgic color palette featuring cream and light brown tones, realistic fingerprint ridge texture, slightly imperfect organic shape, mid-century modern aesthetic, isolated on pure white background for transparency, subtle dusty flour texture, simple and readable silhouette, cozy grandma's kitchen vibes showing authentic cooking marks, centered composition"
    },
    
    # Decorative Elements (2 stickers)
    {
        "filename": "sticker_decorative_flourish.png",
        "category": "decorative",
        "name": "Corner Flourish",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, an ornate corner flourish with scrolling vine and leaf design meant for card corners, warm nostalgic color palette featuring sage green and brown, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, elegant and decorative, cozy grandma's kitchen vibes, positioned at corner angle, centered composition"
    },
    {
        "filename": "sticker_decorative_banner.png",
        "category": "decorative",
        "name": "Banner Ribbon",
        "prompt": "A charming hand-drawn sticker illustration in a vintage cookbook style, a blank ribbon banner with folded ends for custom text, warm nostalgic color palette featuring red ribbon with cream highlights showing dimension, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable design, cozy grandma's kitchen vibes, horizontal ribbon centered in composition"
    },
]


class StickerGenerator:
    def __init__(self, api_key: str, output_dir: str = "heirloom_stickers"):
        """
        Initialize the sticker generator.
        
        Args:
            api_key: OpenAI API key
            output_dir: Directory to save generated stickers
        """
        self.client = OpenAI(api_key=api_key)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Create category subdirectories
        for category in ["food", "tools", "badges", "emotions", "decorative"]:
            (self.output_dir / category).mkdir(exist_ok=True)
        
        # Track costs
        self.total_cost = 0.0
        self.cost_per_image = 0.04  # DALL-E 3 standard quality (1024x1024)
        
    def generate_sticker(self, sticker_config: dict) -> bool:
        """
        Generate a single sticker using DALL-E 3.
        
        Args:
            sticker_config: Dictionary with filename, category, name, and prompt
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Generate image with DALL-E 3
            response = self.client.images.generate(
                model="dall-e-3",
                prompt=sticker_config["prompt"],
                size="1024x1024",
                quality="standard",
                n=1,
            )
            
            # Get image URL
            image_url = response.data[0].url
            
            # Download image
            img_response = requests.get(image_url)
            img_response.raise_for_status()
            
            # Save to appropriate category folder
            filepath = self.output_dir / sticker_config["category"] / sticker_config["filename"]
            filepath.write_bytes(img_response.content)
            
            # Update cost tracking
            self.total_cost += self.cost_per_image
            
            return True
            
        except Exception as e:
            print(f"\n❌ Error generating {sticker_config['name']}: {str(e)}")
            return False
    
    def generate_all(self, stickers: list, delay: float = 1.0):
        """
        Generate all stickers with progress tracking.
        
        Args:
            stickers: List of sticker configurations
            delay: Delay between API calls in seconds (to avoid rate limits)
        """
        print(f"\n🎨 Heirloom Sticker Generator")
        print(f"📁 Output directory: {self.output_dir.absolute()}")
        print(f"🖼️  Generating {len(stickers)} stickers...\n")
        
        successful = 0
        failed = 0
        
        # Progress bar
        with tqdm(total=len(stickers), desc="Generating stickers", unit="sticker") as pbar:
            for sticker in stickers:
                pbar.set_description(f"Generating {sticker['name']}")
                
                if self.generate_sticker(sticker):
                    successful += 1
                    pbar.set_postfix({"✓": successful, "✗": failed, "cost": f"${self.total_cost:.2f}"})
                else:
                    failed += 1
                    pbar.set_postfix({"✓": successful, "✗": failed, "cost": f"${self.total_cost:.2f}"})
                
                pbar.update(1)
                
                # Small delay to avoid rate limits
                if sticker != stickers[-1]:  # Don't delay after last one
                    time.sleep(delay)
        
        # Summary
        print(f"\n" + "="*60)
        print(f"✅ Successfully generated: {successful}/{len(stickers)} stickers")
        if failed > 0:
            print(f"❌ Failed: {failed}")
        print(f"💰 Total cost: ${self.total_cost:.2f}")
        print(f"📁 Saved to: {self.output_dir.absolute()}")
        print("="*60)
        
        # Show directory structure
        print(f"\n📂 Directory structure:")
        for category in ["food", "tools", "badges", "emotions", "decorative"]:
            category_path = self.output_dir / category
            file_count = len(list(category_path.glob("*.png")))
            print(f"   └── {category}/ ({file_count} files)")
    
    def generate_metadata(self):
        """Generate a metadata JSON file with sticker information."""
        import json
        
        metadata = {
            "generated_at": datetime.now().isoformat(),
            "total_stickers": len(PHASE_1_STICKERS),
            "total_cost": self.total_cost,
            "stickers": [
                {
                    "filename": s["filename"],
                    "category": s["category"],
                    "name": s["name"],
                    "path": f"{s['category']}/{s['filename']}"
                }
                for s in PHASE_1_STICKERS
            ]
        }
        
        metadata_path = self.output_dir / "metadata.json"
        metadata_path.write_text(json.dumps(metadata, indent=2))
        print(f"\n📄 Metadata saved to: {metadata_path}")


def main():
    """Main entry point."""
    print("\n" + "="*60)
    print("🍳 HEIRLOOM STICKER GENERATOR - PHASE 1")
    print("="*60)
    
    # Get API key
    api_key = os.environ.get("OPENAI_API_KEY")
    
    if not api_key:
        print("\n🔑 OpenAI API Key Required")
        print("\nOption 1: Set environment variable")
        print("   export OPENAI_API_KEY='sk-...'")
        print("\nOption 2: Enter it now (will not be saved)")
        api_key = input("\nEnter your OpenAI API key: ").strip()
        
        if not api_key:
            print("❌ No API key provided. Exiting.")
            sys.exit(1)
    
    # Get output directory
    output_dir = input(f"\nOutput directory [heirloom_stickers]: ").strip() or "heirloom_stickers"
    
    # Cost estimate
    estimated_cost = len(PHASE_1_STICKERS) * 0.04
    print(f"\n💰 Estimated cost: ${estimated_cost:.2f} ({len(PHASE_1_STICKERS)} stickers × $0.04)")
    
    confirm = input("\nProceed with generation? [Y/n]: ").strip().lower()
    if confirm and confirm != 'y':
        print("❌ Cancelled.")
        sys.exit(0)
    
    # Generate stickers
    generator = StickerGenerator(api_key=api_key, output_dir=output_dir)
    generator.generate_all(PHASE_1_STICKERS, delay=1.0)
    generator.generate_metadata()
    
    print("\n✨ All done! Your stickers are ready to use.")
    print("\nNext steps:")
    print("1. Review the generated stickers in the output directory")
    print("2. Use remove.bg or Photoshop to clean up backgrounds if needed")
    print("3. Vectorize with Adobe Illustrator for SVG export")
    print("4. Run Phase 2 script for the next 20 stickers")


if __name__ == "__main__":
    main()
