#!/usr/bin/env python3
"""
Heirloom Complete Sticker Generator
Generates ALL 70 stickers across 8 categories using DALL-E 3
Cost: ~$2.80 (70 stickers × $0.04)
"""

import os
import sys
import json
import time
import requests
from pathlib import Path
from datetime import datetime

try:
    from openai import OpenAI
    from tqdm import tqdm
except ImportError:
    print("❌ Missing required packages. Install with:")
    print("   pip install openai tqdm requests")
    sys.exit(1)


# Base prompt template for consistent style
BASE_STYLE = "A charming hand-drawn sticker illustration in a vintage cookbook style, {description}, warm nostalgic color palette, slightly imperfect organic linework with visible brush strokes, mid-century modern aesthetic, isolated on pure white background for transparency, vector-style flat colors with subtle texture, simple and readable silhouette, cozy grandma's kitchen vibes, centered composition"

# Complete sticker library (70 stickers across 8 categories)
ALL_STICKERS = [
    # ========== CATEGORY 1: FOOD & INGREDIENTS (15) ==========
    {
        "category": "food",
        "name": "Tomato",
        "filename": "sticker_food_tomato.png",
        "prompt": BASE_STYLE.format(description="a plump red heirloom tomato with bright crimson skin and a green leafy stem on top, featuring tomato red and sage green colors")
    },
    {
        "category": "food",
        "name": "Garlic Bulb",
        "filename": "sticker_food_garlic.png",
        "prompt": BASE_STYLE.format(description="a whole garlic bulb with papery white skin and 2-3 separated cloves beside it, cream and brown shadow tones")
    },
    {
        "category": "food",
        "name": "Lemon Slice",
        "filename": "sticker_food_lemon.png",
        "prompt": BASE_STYLE.format(description="a cross-section of a lemon showing detailed segments and seeds in the center, bright golden yellow flesh with cream highlights")
    },
    {
        "category": "food",
        "name": "Carrot",
        "filename": "sticker_food_carrot.png",
        "prompt": BASE_STYLE.format(description="an orange carrot with leafy green tops, showing natural tapering shape and subtle texture lines")
    },
    {
        "category": "food",
        "name": "Mushroom",
        "filename": "sticker_food_mushroom.png",
        "prompt": BASE_STYLE.format(description="a classic button mushroom in side view, showing brown cap and cream stem")
    },
    {
        "category": "food",
        "name": "Egg",
        "filename": "sticker_food_egg.png",
        "prompt": BASE_STYLE.format(description="a cracked egg with shell broken open showing bright golden yolk and cream-colored egg white")
    },
    {
        "category": "food",
        "name": "Butter",
        "filename": "sticker_food_butter.png",
        "prompt": BASE_STYLE.format(description="a stick of butter with wrapper partially peeled back, golden yellow butter visible")
    },
    {
        "category": "food",
        "name": "Cheese Wedge",
        "filename": "sticker_food_cheese.png",
        "prompt": BASE_STYLE.format(description="a triangular wedge of Swiss cheese with characteristic holes, golden yellow color")
    },
    {
        "category": "food",
        "name": "Flour Sack",
        "filename": "sticker_food_flour.png",
        "prompt": BASE_STYLE.format(description="a vintage flour sack with 'FLOUR' label in serif font, cream colored fabric with brown text")
    },
    {
        "category": "food",
        "name": "Sugar Bowl",
        "filename": "sticker_food_sugar.png",
        "prompt": BASE_STYLE.format(description="a ceramic sugar bowl with small spoon inside, white bowl with sugar visible")
    },
    {
        "category": "food",
        "name": "Chocolate Bar",
        "filename": "sticker_food_chocolate.png",
        "prompt": BASE_STYLE.format(description="a chocolate bar partially unwrapped showing squares, brown chocolate with cream wrapper")
    },
    {
        "category": "food",
        "name": "Pie Slice",
        "filename": "sticker_food_pie.png",
        "prompt": BASE_STYLE.format(description="a triangular slice of pie with lattice crust and three small steam wisps rising, golden filling and brown crust")
    },
    {
        "category": "food",
        "name": "Bread Loaf",
        "filename": "sticker_food_bread.png",
        "prompt": BASE_STYLE.format(description="an artisan bread loaf with score marks on top, golden brown crust")
    },
    {
        "category": "food",
        "name": "Cookie",
        "filename": "sticker_food_cookie.png",
        "prompt": BASE_STYLE.format(description="a round chocolate chip cookie with a small bite taken out, brown cookie with dark chocolate chips")
    },
    {
        "category": "food",
        "name": "Herb Sprig",
        "filename": "sticker_food_herbs.png",
        "prompt": BASE_STYLE.format(description="a sprig of rosemary or thyme tied with twine, sage green leaves with brown stem")
    },

    # ========== CATEGORY 2: KITCHEN TOOLS (10) ==========
    {
        "category": "tools",
        "name": "Wooden Spoon",
        "filename": "sticker_tools_woodenspoon.png",
        "prompt": BASE_STYLE.format(description="a well-worn wooden spoon with visible wood grain texture and slightly rounded bowl, brown wood with cream highlights")
    },
    {
        "category": "tools",
        "name": "Whisk",
        "filename": "sticker_tools_whisk.png",
        "prompt": BASE_STYLE.format(description="a wire whisk with 8-10 loops and wooden handle, slightly bent from use, brown handle with silver-grey wires")
    },
    {
        "category": "tools",
        "name": "Rolling Pin",
        "filename": "sticker_tools_rollingpin.png",
        "prompt": BASE_STYLE.format(description="a classic wooden rolling pin with handles on both ends and visible wood grain, brown and cream tones")
    },
    {
        "category": "tools",
        "name": "Chef's Knife",
        "filename": "sticker_tools_knife.png",
        "prompt": BASE_STYLE.format(description="a professional chef's knife with silver blade and dark brown wooden handle with visible bolster and three rivets")
    },
    {
        "category": "tools",
        "name": "Mixing Bowl",
        "filename": "sticker_tools_bowl.png",
        "prompt": BASE_STYLE.format(description="a ceramic mixing bowl in side view, showing depth and rim, cream colored pottery")
    },
    {
        "category": "tools",
        "name": "Measuring Cups",
        "filename": "sticker_tools_measuringcups.png",
        "prompt": BASE_STYLE.format(description="a set of 4 nested measuring cups with handles, graduated sizes, cream or silver colored")
    },
    {
        "category": "tools",
        "name": "Cast Iron Skillet",
        "filename": "sticker_tools_skillet.png",
        "prompt": BASE_STYLE.format(description="a black cast iron skillet pan with long handle, showing traditional shape and weight")
    },
    {
        "category": "tools",
        "name": "Dutch Oven",
        "filename": "sticker_tools_dutchoven.png",
        "prompt": BASE_STYLE.format(description="an enameled Dutch oven pot with lid and handles, tomato red or cream colored enamel")
    },
    {
        "category": "tools",
        "name": "Stand Mixer",
        "filename": "sticker_tools_mixer.png",
        "prompt": BASE_STYLE.format(description="a vintage stand mixer in mid-century style reminiscent of KitchenAid, with tilting head and bowl, cream or red colored")
    },
    {
        "category": "tools",
        "name": "Apron",
        "filename": "sticker_tools_apron.png",
        "prompt": BASE_STYLE.format(description="a folded kitchen apron with pocket and ties visible, cream fabric with simple details")
    },

    # ========== CATEGORY 3: BADGES & LABELS (12) ==========
    {
        "category": "badges",
        "name": "Family Recipe",
        "filename": "sticker_badge_familyrecipe.png",
        "prompt": BASE_STYLE.format(description="a circular badge with scalloped edges containing the text 'FAMILY RECIPE' in serif font, red border with cream background")
    },
    {
        "category": "badges",
        "name": "Grandma's Secret",
        "filename": "sticker_badge_grandma.png",
        "prompt": BASE_STYLE.format(description="a banner ribbon with the text 'GRANDMA'S SECRET' in script font, sage green with cream text")
    },
    {
        "category": "badges",
        "name": "Tested & Approved",
        "filename": "sticker_badge_tested.png",
        "prompt": BASE_STYLE.format(description="a circular seal badge with text 'TESTED & APPROVED' around the edge and a large checkmark in center, sage green with cream accents")
    },
    {
        "category": "badges",
        "name": "Sunday Dinner",
        "filename": "sticker_badge_sunday.png",
        "prompt": BASE_STYLE.format(description="an oval badge with text 'SUNDAY DINNER' and small fork and knife icons, amber gold with brown text")
    },
    {
        "category": "badges",
        "name": "Vegetarian",
        "filename": "sticker_badge_vegetarian.png",
        "prompt": BASE_STYLE.format(description="a green badge with the text 'VEGETARIAN' and a small leaf icon, sage green tones")
    },
    {
        "category": "badges",
        "name": "Gluten-Free",
        "filename": "sticker_badge_glutenfree.png",
        "prompt": BASE_STYLE.format(description="a badge showing wheat icon with slash-through and text 'GLUTEN-FREE', amber gold color")
    },
    {
        "category": "badges",
        "name": "Holiday Favorite",
        "filename": "sticker_badge_holiday.png",
        "prompt": BASE_STYLE.format(description="a festive badge with text 'HOLIDAY FAVORITE', red and green colors")
    },
    {
        "category": "badges",
        "name": "Quick & Easy",
        "filename": "sticker_badge_quick.png",
        "prompt": BASE_STYLE.format(description="a badge with small clock icon and text 'QUICK & EASY', amber gold color")
    },
    {
        "category": "badges",
        "name": "Five Stars",
        "filename": "sticker_badge_fivestars.png",
        "prompt": BASE_STYLE.format(description="a stamp showing five stars in a row with text '5 STARS' below, amber gold stars on cream background")
    },
    {
        "category": "badges",
        "name": "Award Winner",
        "filename": "sticker_badge_award.png",
        "prompt": BASE_STYLE.format(description="a blue ribbon rosette award with circular center medallion, blue and cream colors")
    },
    {
        "category": "badges",
        "name": "Made With Love",
        "filename": "sticker_badge_love.png",
        "prompt": BASE_STYLE.format(description="a heart-shaped badge with text 'MADE WITH LOVE' in script font, tomato red with cream text")
    },
    {
        "category": "badges",
        "name": "Homemade",
        "filename": "sticker_badge_homemade.png",
        "prompt": BASE_STYLE.format(description="a circular badge with handwritten-style text 'HOMEMADE', brown ink on cream background")
    },

    # ========== CATEGORY 4: SEASONAL & HOLIDAY (8) ==========
    {
        "category": "seasonal",
        "name": "Cherry Blossoms",
        "filename": "sticker_seasonal_cherry.png",
        "prompt": BASE_STYLE.format(description="a small branch with delicate pink cherry blossoms, showing petals and brown stem")
    },
    {
        "category": "seasonal",
        "name": "Strawberry",
        "filename": "sticker_seasonal_strawberry.png",
        "prompt": BASE_STYLE.format(description="a red strawberry with seeds visible and green leaves on top, bright red with yellow seeds")
    },
    {
        "category": "seasonal",
        "name": "Sunflower",
        "filename": "sticker_seasonal_sunflower.png",
        "prompt": BASE_STYLE.format(description="a bright sunflower head with yellow petals and brown center showing seeds")
    },
    {
        "category": "seasonal",
        "name": "Pumpkin",
        "filename": "sticker_seasonal_pumpkin.png",
        "prompt": BASE_STYLE.format(description="an orange pumpkin with green stem and curling vines, showing ridges and traditional shape")
    },
    {
        "category": "seasonal",
        "name": "Autumn Leaves",
        "filename": "sticker_seasonal_leaves.png",
        "prompt": BASE_STYLE.format(description="three colorful fall leaves - one red, one orange, one yellow - arranged together")
    },
    {
        "category": "seasonal",
        "name": "Snowflake",
        "filename": "sticker_seasonal_snowflake.png",
        "prompt": BASE_STYLE.format(description="a delicate 6-point snowflake with intricate crystalline pattern, light blue and white")
    },
    {
        "category": "seasonal",
        "name": "Holly Sprig",
        "filename": "sticker_seasonal_holly.png",
        "prompt": BASE_STYLE.format(description="a holly sprig with spiky green leaves and red berries clustered together")
    },
    {
        "category": "seasonal",
        "name": "Pinecone",
        "filename": "sticker_seasonal_pinecone.png",
        "prompt": BASE_STYLE.format(description="a detailed pinecone showing overlapping scales in natural brown tones")
    },

    # ========== CATEGORY 5: HANDWRITTEN ANNOTATIONS (6) ==========
    {
        "category": "annotations",
        "name": "Mom's Original",
        "filename": "sticker_annotation_moms.png",
        "prompt": BASE_STYLE.format(description="handwritten text reading 'Mom's Original' in casual script style, dark blue ink on cream background, feeling like pen-on-paper")
    },
    {
        "category": "annotations",
        "name": "Add More Garlic",
        "filename": "sticker_annotation_garlic.png",
        "prompt": BASE_STYLE.format(description="playful handwritten note 'Add More Garlic!' with a small arrow pointing right, brown ink with character variation")
    },
    {
        "category": "annotations",
        "name": "Best Ever",
        "filename": "sticker_annotation_best.png",
        "prompt": BASE_STYLE.format(description="emphatic handwritten text 'Best Ever' with underline, dark brown ink showing enthusiasm")
    },
    {
        "category": "annotations",
        "name": "Try This",
        "filename": "sticker_annotation_try.png",
        "prompt": BASE_STYLE.format(description="handwritten 'Try This!' with exclamation mark, casual script in blue ink")
    },
    {
        "category": "annotations",
        "name": "Double the Recipe",
        "filename": "sticker_annotation_double.png",
        "prompt": BASE_STYLE.format(description="practical handwritten note 'Double the Recipe' in red ink, clear lettering")
    },
    {
        "category": "annotations",
        "name": "From Italy 1952",
        "filename": "sticker_annotation_italy.png",
        "prompt": BASE_STYLE.format(description="historical provenance note 'From Italy 1952' in elegant script, brown aged-ink appearance")
    },

    # ========== CATEGORY 6: DECORATIVE ELEMENTS (5) ==========
    {
        "category": "decorative",
        "name": "Corner Flourish",
        "filename": "sticker_decorative_flourish.png",
        "prompt": BASE_STYLE.format(description="a vintage scroll design perfect for card corners, ornate curves and swirls, brown linework")
    },
    {
        "category": "decorative",
        "name": "Divider Line",
        "filename": "sticker_decorative_divider.png",
        "prompt": BASE_STYLE.format(description="a decorative horizontal separator line with small icon in center, elegant and simple, brown")
    },
    {
        "category": "decorative",
        "name": "Banner Ribbon",
        "filename": "sticker_decorative_banner.png",
        "prompt": BASE_STYLE.format(description="a blank ribbon banner for custom text, flowing fabric with folds, cream with brown shadows")
    },
    {
        "category": "decorative",
        "name": "Recipe Box Border",
        "filename": "sticker_decorative_border.png",
        "prompt": BASE_STYLE.format(description="an ornate rectangular frame border suitable for recipe cards, vintage design elements, brown linework")
    },
    {
        "category": "decorative",
        "name": "Laurel Wreath",
        "filename": "sticker_decorative_laurel.png",
        "prompt": BASE_STYLE.format(description="a simple laurel branch arc forming partial wreath, sage green leaves on brown stems")
    },

    # ========== CATEGORY 7: EMOTIONS & MEMORIES (6) ==========
    {
        "category": "emotions",
        "name": "Heart",
        "filename": "sticker_emotion_heart.png",
        "prompt": BASE_STYLE.format(description="a hand-drawn heart outline, slightly asymmetrical showing human touch, tomato red")
    },
    {
        "category": "emotions",
        "name": "Star",
        "filename": "sticker_emotion_star.png",
        "prompt": BASE_STYLE.format(description="a five-point star with slight wobble showing hand-drawn character, amber gold")
    },
    {
        "category": "emotions",
        "name": "Smiling Face",
        "filename": "sticker_emotion_smile.png",
        "prompt": BASE_STYLE.format(description="a simple emoji-style happy face with curved smile and dots for eyes, brown linework on cream")
    },
    {
        "category": "emotions",
        "name": "Coffee Stain",
        "filename": "sticker_emotion_coffeestain.png",
        "prompt": BASE_STYLE.format(description="a realistic circular coffee cup stain ring with authentic texture, brown tones celebrating cooking's love marks")
    },
    {
        "category": "emotions",
        "name": "Fingerprint",
        "filename": "sticker_emotion_fingerprint.png",
        "prompt": BASE_STYLE.format(description="a smudged fingerprint as if from floury hands, realistic texture, brown tones showing kitchen authenticity")
    },
    {
        "category": "emotions",
        "name": "Lipstick Kiss",
        "filename": "sticker_emotion_kiss.png",
        "prompt": BASE_STYLE.format(description="a playful red lipstick kiss mark like Grandma's kiss, realistic but not messy, tomato red")
    },

    # ========== CATEGORY 8: NUMBERS & TIME (8) ==========
    {
        "category": "time",
        "name": "Clock 15min",
        "filename": "sticker_time_15min.png",
        "prompt": BASE_STYLE.format(description="a simple clock face showing 15 minutes (quarter hour), clear numbers and hands, brown and cream")
    },
    {
        "category": "time",
        "name": "Clock 30min",
        "filename": "sticker_time_30min.png",
        "prompt": BASE_STYLE.format(description="a clock face showing 30 minutes (half hour), clear dial and hands, brown and cream")
    },
    {
        "category": "time",
        "name": "Clock 1hour",
        "filename": "sticker_time_1hour.png",
        "prompt": BASE_STYLE.format(description="a clock face showing 1 hour (full hour), traditional clock design, brown and cream")
    },
    {
        "category": "time",
        "name": "Timer",
        "filename": "sticker_time_timer.png",
        "prompt": BASE_STYLE.format(description="a kitchen timer or hourglass illustration showing time passage, brown and amber tones")
    },
    {
        "category": "time",
        "name": "Serves 4",
        "filename": "sticker_time_serves4.png",
        "prompt": BASE_STYLE.format(description="a circular badge with '4' number and four small person silhouettes, text 'SERVES 4', brown on cream")
    },
    {
        "category": "time",
        "name": "Serves 8",
        "filename": "sticker_time_serves8.png",
        "prompt": BASE_STYLE.format(description="a badge showing '8' and eight person silhouettes, text 'SERVES 8', brown on cream")
    },
    {
        "category": "time",
        "name": "Feeds a Crowd",
        "filename": "sticker_time_crowd.png",
        "prompt": BASE_STYLE.format(description="a badge with 12+ person silhouettes and text 'FEEDS A CROWD', brown on cream, celebratory feel")
    },
    {
        "category": "time",
        "name": "Portion Sizes",
        "filename": "sticker_time_portions.png",
        "prompt": BASE_STYLE.format(description="a plate illustration with sizing indicators showing portions, simple and clear, brown linework")
    },
]


class StickerGenerator:
    """Generate stickers using OpenAI's DALL-E 3 API"""

    def __init__(self, api_key: str, output_dir: str = "heirloom_stickers_complete"):
        self.client = OpenAI(api_key=api_key)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)

        # Create category subdirectories
        categories = set(sticker["category"] for sticker in ALL_STICKERS)
        for category in categories:
            (self.output_dir / category).mkdir(exist_ok=True)

        self.generated = []
        self.failed = []
        self.total_cost = 0.0

    def generate_sticker(self, sticker_def: dict, delay: float = 1.0) -> bool:
        """Generate a single sticker"""
        try:
            response = self.client.images.generate(
                model="dall-e-3",
                prompt=sticker_def["prompt"],
                size="1024x1024",
                quality="standard",
                n=1,
            )

            # Download the image
            image_url = response.data[0].url
            image_data = requests.get(image_url).content

            # Save to category subfolder
            category = sticker_def["category"]
            filename = sticker_def["filename"]
            filepath = self.output_dir / category / filename

            with open(filepath, 'wb') as f:
                f.write(image_data)

            self.generated.append({
                "name": sticker_def["name"],
                "category": category,
                "filename": filename,
                "filepath": str(filepath),
                "prompt": sticker_def["prompt"],
                "timestamp": datetime.now().isoformat()
            })

            self.total_cost += 0.04  # DALL-E 3 standard quality cost
            time.sleep(delay)  # Rate limiting
            return True

        except Exception as e:
            self.failed.append({
                "name": sticker_def["name"],
                "error": str(e)
            })
            return False

    def generate_all(self, stickers: list, delay: float = 1.0):
        """Generate all stickers with progress bar"""
        print(f"\n🎨 Generating {len(stickers)} stickers...")
        print(f"📁 Output directory: {self.output_dir.absolute()}\n")

        pbar = tqdm(stickers, desc="Generating")

        for sticker in pbar:
            success = self.generate_sticker(sticker, delay=delay)
            pbar.set_description(f"Generating {sticker['name']}")
            pbar.set_postfix_str(f"✓:{len(self.generated)} ✗:{len(self.failed)} ${self.total_cost:.2f}")

        print("\n" + "="*60)
        print(f"✅ Successfully generated: {len(self.generated)}/{len(stickers)} stickers")
        print(f"❌ Failed: {len(self.failed)} stickers")
        print(f"💰 Total cost: ${self.total_cost:.2f}")
        print(f"📁 Saved to: {self.output_dir.absolute()}")
        print("="*60)

        # Save metadata
        self.save_metadata()

        if self.failed:
            print("\n⚠️  Failed stickers:")
            for fail in self.failed:
                print(f"   - {fail['name']}: {fail['error']}")

    def save_metadata(self):
        """Save generation metadata to JSON"""
        metadata = {
            "generated_at": datetime.now().isoformat(),
            "total_stickers": len(ALL_STICKERS),
            "successful": len(self.generated),
            "failed": len(self.failed),
            "total_cost": self.total_cost,
            "stickers": self.generated,
            "failures": self.failed
        }

        metadata_path = self.output_dir / "metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

        print(f"\n📄 Metadata saved to: {metadata_path}")

        # Print directory structure
        print(f"\n📂 Directory structure:")
        categories = {}
        for sticker in self.generated:
            cat = sticker["category"]
            categories[cat] = categories.get(cat, 0) + 1

        for cat, count in sorted(categories.items()):
            print(f"   └── {cat}/ ({count} files)")


def main():
    """Main entry point"""
    print("="*60)
    print("🍳 HEIRLOOM COMPLETE STICKER GENERATOR")
    print("="*60)
    print()

    # Get API key
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        api_key = input("🔑 Enter your OpenAI API key: ").strip()
        if not api_key:
            print("❌ API key required")
            sys.exit(1)
    else:
        print("🔑 OpenAI API Key: [detected from environment]")

    # Get output directory
    output_dir = input("\nOutput directory [heirloom_stickers_complete]: ").strip()
    if not output_dir:
        output_dir = "heirloom_stickers_complete"

    # Confirm cost
    total_stickers = len(ALL_STICKERS)
    estimated_cost = total_stickers * 0.04
    print(f"\n💰 Estimated cost: ${estimated_cost:.2f} ({total_stickers} stickers × $0.04)")
    print(f"⏱️  Estimated time: {total_stickers // 2}-{total_stickers} minutes")

    confirm = input("\nProceed with generation? [Y/n]: ").strip().lower()
    if confirm and confirm != 'y':
        print("❌ Cancelled")
        sys.exit(0)

    # Generate!
    generator = StickerGenerator(api_key, output_dir)
    generator.generate_all(ALL_STICKERS, delay=1.0)

    print("\n✨ All done! Your complete sticker library is ready to use.")
    print(f"📁 Find them at: {Path(output_dir).absolute()}")


if __name__ == "__main__":
    main()
