#!/usr/bin/env python3
"""
Heirloom Refined Sticker Generator
Generates 55 EXPRESSIVE stickers focused on emotional connection
Cost: ~$2.20 (55 stickers × $0.04)
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

# Refined sticker library (55 expressive stickers across 10 categories)
ALL_STICKERS = [
    # ========== CATEGORY 1: FOOD WITH PERSONALITY (10) ==========
    {
        "category": "food",
        "name": "Garlic Bulb",
        "filename": "sticker_food_garlic.png",
        "prompt": BASE_STYLE.format(description="a whole garlic bulb with papery white skin and 2-3 separated cloves beside it, cream and brown shadow tones, showing personality and character")
    },
    {
        "category": "food",
        "name": "Butter",
        "filename": "sticker_food_butter.png",
        "prompt": BASE_STYLE.format(description="a stick of butter with wrapper partially peeled back revealing golden yellow butter, looking rich and indulgent")
    },
    {
        "category": "food",
        "name": "Chocolate Bar",
        "filename": "sticker_food_chocolate.png",
        "prompt": BASE_STYLE.format(description="a chocolate bar partially unwrapped showing squares, rich brown chocolate with cream wrapper, looking tempting and delicious")
    },
    {
        "category": "food",
        "name": "Lemon Slice",
        "filename": "sticker_food_lemon.png",
        "prompt": BASE_STYLE.format(description="a cross-section of a lemon showing detailed segments and seeds, bright golden yellow flesh with cream highlights, fresh and zesty")
    },
    {
        "category": "food",
        "name": "Egg",
        "filename": "sticker_food_egg.png",
        "prompt": BASE_STYLE.format(description="a cracked egg with shell broken open showing bright golden yolk and cream egg white, symbol of homemade cooking")
    },
    {
        "category": "food",
        "name": "Chili Pepper",
        "filename": "sticker_food_chili.png",
        "prompt": BASE_STYLE.format(description="a red chili pepper with green stem, bright red color suggesting heat and spice, slightly curved shape")
    },
    {
        "category": "food",
        "name": "Bacon Strips",
        "filename": "sticker_food_bacon.png",
        "prompt": BASE_STYLE.format(description="three strips of cooked bacon with wavy edges, brown and red tones showing crispy texture")
    },
    {
        "category": "food",
        "name": "Fresh Herbs",
        "filename": "sticker_food_herbs.png",
        "prompt": BASE_STYLE.format(description="a small bundle of fresh herbs (rosemary or thyme) tied with twine, sage green leaves with brown stem, garden-fresh feeling")
    },
    {
        "category": "food",
        "name": "Pie Slice",
        "filename": "sticker_food_pie.png",
        "prompt": BASE_STYLE.format(description="a triangular slice of pie with lattice crust and three small steam wisps rising, golden filling and brown crust, comfort food icon")
    },
    {
        "category": "food",
        "name": "Cookie",
        "filename": "sticker_food_cookie.png",
        "prompt": BASE_STYLE.format(description="a round chocolate chip cookie with a small bite taken out, brown cookie with dark chocolate chips, homemade treat")
    },

    # ========== CATEGORY 2: LOVE & WARMTH (6) ==========
    {
        "category": "love",
        "name": "Heart",
        "filename": "sticker_love_heart.png",
        "prompt": BASE_STYLE.format(description="a hand-drawn heart outline, slightly asymmetrical showing human touch, tomato red, expressing love and care")
    },
    {
        "category": "love",
        "name": "Made With Love",
        "filename": "sticker_love_badge.png",
        "prompt": BASE_STYLE.format(description="a heart-shaped badge with text 'MADE WITH LOVE' in script font, tomato red with cream text")
    },
    {
        "category": "love",
        "name": "Lipstick Kiss",
        "filename": "sticker_love_kiss.png",
        "prompt": BASE_STYLE.format(description="a playful red lipstick kiss mark like Grandma's kiss on a recipe card, realistic but charming, tomato red")
    },
    {
        "category": "love",
        "name": "From My Kitchen",
        "filename": "sticker_love_kitchen.png",
        "prompt": BASE_STYLE.format(description="a banner with text 'From My Kitchen to Yours' in warm script font, amber gold with brown text, sharing and caring")
    },
    {
        "category": "love",
        "name": "Hugging Hands",
        "filename": "sticker_love_hug.png",
        "prompt": BASE_STYLE.format(description="two hands in a gentle embrace or hug gesture, simple line drawing, brown linework, expressing warmth and comfort")
    },
    {
        "category": "love",
        "name": "Gift Box",
        "filename": "sticker_love_gift.png",
        "prompt": BASE_STYLE.format(description="a wrapped gift box with bow on top, suggesting recipes as gifts, cream box with amber ribbon")
    },

    # ========== CATEGORY 3: QUALITY RATINGS & ENDORSEMENTS (7) ==========
    {
        "category": "endorsements",
        "name": "Five Stars",
        "filename": "sticker_endorse_fivestars.png",
        "prompt": BASE_STYLE.format(description="a stamp showing five stars in a row with text '5 STARS' below, amber gold stars on cream background")
    },
    {
        "category": "endorsements",
        "name": "Tested & Approved",
        "filename": "sticker_endorse_tested.png",
        "prompt": BASE_STYLE.format(description="a circular seal badge with text 'TESTED & APPROVED' around edge and large checkmark in center, sage green with cream accents")
    },
    {
        "category": "endorsements",
        "name": "Award Winner",
        "filename": "sticker_endorse_award.png",
        "prompt": BASE_STYLE.format(description="a blue ribbon rosette award with circular center medallion, blue and cream colors, prize-winning quality")
    },
    {
        "category": "endorsements",
        "name": "Thumbs Up",
        "filename": "sticker_endorse_thumbsup.png",
        "prompt": BASE_STYLE.format(description="a hand giving enthusiastic thumbs up gesture, brown linework, approval and endorsement")
    },
    {
        "category": "endorsements",
        "name": "Chef's Kiss",
        "filename": "sticker_endorse_chefskiss.png",
        "prompt": BASE_STYLE.format(description="fingers pinched to lips in chef's kiss gesture, brown linework, *chef's kiss* perfection")
    },
    {
        "category": "endorsements",
        "name": "Crowd Pleaser",
        "filename": "sticker_endorse_crowd.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'CROWD PLEASER' and small stars, amber gold, party-ready recipe")
    },
    {
        "category": "endorsements",
        "name": "Worth the Effort",
        "filename": "sticker_endorse_worth.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'WORTH THE EFFORT' in elegant font, sage green, impressive but doable")
    },

    # ========== CATEGORY 4: DIFFICULTY & SKILL (4) ==========
    {
        "category": "difficulty",
        "name": "Quick & Easy",
        "filename": "sticker_difficulty_quick.png",
        "prompt": BASE_STYLE.format(description="a badge with small clock icon and text 'QUICK & EASY', amber gold color, weeknight friendly")
    },
    {
        "category": "difficulty",
        "name": "Beginner Friendly",
        "filename": "sticker_difficulty_beginner.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'BEGINNER FRIENDLY' and small encouraging icon, sage green, confidence-building")
    },
    {
        "category": "difficulty",
        "name": "One Bowl Wonder",
        "filename": "sticker_difficulty_onebowl.png",
        "prompt": BASE_STYLE.format(description="a badge showing single bowl icon with text 'ONE BOWL WONDER', cream and brown, minimal cleanup")
    },
    {
        "category": "difficulty",
        "name": "Show Stopper",
        "filename": "sticker_difficulty_showstopper.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'SHOW STOPPER' and sparkle elements, amber gold, impressive and fancy")
    },

    # ========== CATEGORY 5: OCCASIONS & MEMORIES (7) ==========
    {
        "category": "occasions",
        "name": "Family Recipe",
        "filename": "sticker_occasion_family.png",
        "prompt": BASE_STYLE.format(description="a circular badge with scalloped edges containing text 'FAMILY RECIPE' in serif font, red border with cream background, heritage and tradition")
    },
    {
        "category": "occasions",
        "name": "Grandma's Secret",
        "filename": "sticker_occasion_grandma.png",
        "prompt": BASE_STYLE.format(description="a banner ribbon with text 'GRANDMA'S SECRET' in script font, sage green with cream text, cherished recipe")
    },
    {
        "category": "occasions",
        "name": "Holiday Favorite",
        "filename": "sticker_occasion_holiday.png",
        "prompt": BASE_STYLE.format(description="a festive badge with text 'HOLIDAY FAVORITE', red and green colors, celebration recipe")
    },
    {
        "category": "occasions",
        "name": "Sunday Dinner",
        "filename": "sticker_occasion_sunday.png",
        "prompt": BASE_STYLE.format(description="an oval badge with text 'SUNDAY DINNER' and small fork and knife icons, amber gold with brown text, weekly tradition")
    },
    {
        "category": "occasions",
        "name": "Birthday Tradition",
        "filename": "sticker_occasion_birthday.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'BIRTHDAY TRADITION' and small balloon or cake icon, tomato red, annual celebration")
    },
    {
        "category": "occasions",
        "name": "Summer BBQ",
        "filename": "sticker_occasion_bbq.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'SUMMER BBQ' and small grill icon, amber gold with red accents, outdoor cooking")
    },
    {
        "category": "occasions",
        "name": "Rainy Day Comfort",
        "filename": "sticker_occasion_rainy.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'RAINY DAY COMFORT' and small umbrella or rain cloud icon, sage green, cozy and soothing")
    },

    # ========== CATEGORY 6: PERSONAL PREFERENCES (6) ==========
    {
        "category": "preferences",
        "name": "Heart Eyes",
        "filename": "sticker_pref_hearteyes.png",
        "prompt": BASE_STYLE.format(description="an emoji-style face with heart shapes for eyes, expressing love for food, tomato red hearts with brown linework")
    },
    {
        "category": "preferences",
        "name": "Fire Spicy",
        "filename": "sticker_pref_fire.png",
        "prompt": BASE_STYLE.format(description="a flame icon showing heat and spice level, amber gold and red tones, bold flavors")
    },
    {
        "category": "preferences",
        "name": "Comfort Food",
        "filename": "sticker_pref_comfort.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'COMFORT FOOD' and warm cozy feeling, cream and brown, soul-satisfying")
    },
    {
        "category": "preferences",
        "name": "Guilty Pleasure",
        "filename": "sticker_pref_guilty.png",
        "prompt": BASE_STYLE.format(description="a playful badge with text 'GUILTY PLEASURE' in fun font, tomato red, indulgent treat")
    },
    {
        "category": "preferences",
        "name": "Weeknight Hero",
        "filename": "sticker_pref_weeknight.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'WEEKNIGHT HERO' and small star, amber gold, reliable go-to recipe")
    },
    {
        "category": "preferences",
        "name": "Can't Stop Making",
        "filename": "sticker_pref_cantstop.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'CAN'T STOP MAKING THIS' in enthusiastic font, sage green, addictive recipe")
    },

    # ========== CATEGORY 7: DIETARY & LIFESTYLE (4) ==========
    {
        "category": "dietary",
        "name": "Vegetarian",
        "filename": "sticker_dietary_vegetarian.png",
        "prompt": BASE_STYLE.format(description="a green badge with text 'VEGETARIAN' and small leaf icon, sage green tones, plant-based")
    },
    {
        "category": "dietary",
        "name": "Gluten-Free",
        "filename": "sticker_dietary_glutenfree.png",
        "prompt": BASE_STYLE.format(description="a badge showing wheat icon with slash-through and text 'GLUTEN-FREE', amber gold color, dietary accommodation")
    },
    {
        "category": "dietary",
        "name": "Homemade",
        "filename": "sticker_dietary_homemade.png",
        "prompt": BASE_STYLE.format(description="a circular badge with handwritten-style text 'HOMEMADE', brown ink on cream background, from-scratch cooking")
    },
    {
        "category": "dietary",
        "name": "From Scratch",
        "filename": "sticker_dietary_scratch.png",
        "prompt": BASE_STYLE.format(description="a badge with text 'FROM SCRATCH' and small hand or rolling pin icon, brown and cream, authentic cooking")
    },

    # ========== CATEGORY 8: EMOTIONAL REACTIONS (5) ==========
    {
        "category": "reactions",
        "name": "Star",
        "filename": "sticker_reaction_star.png",
        "prompt": BASE_STYLE.format(description="a five-point star with slight wobble showing hand-drawn character, amber gold, simple approval")
    },
    {
        "category": "reactions",
        "name": "Smiling Face",
        "filename": "sticker_reaction_smile.png",
        "prompt": BASE_STYLE.format(description="a simple emoji-style happy face with curved smile and dots for eyes, brown linework on cream, joy and satisfaction")
    },
    {
        "category": "reactions",
        "name": "Surprised Face",
        "filename": "sticker_reaction_surprised.png",
        "prompt": BASE_STYLE.format(description="an emoji-style face with wide open eyes and O-shaped mouth, brown linework, wow and amazement")
    },
    {
        "category": "reactions",
        "name": "Too Good to Share",
        "filename": "sticker_reaction_toogood.png",
        "prompt": BASE_STYLE.format(description="a playful badge with text 'TOO GOOD TO SHARE' in fun font, tomato red, possessive about deliciousness")
    },
    {
        "category": "reactions",
        "name": "Coffee Stain",
        "filename": "sticker_reaction_coffeestain.png",
        "prompt": BASE_STYLE.format(description="a realistic circular coffee cup stain ring with authentic texture, brown tones, celebrating kitchen authenticity and real use")
    },

    # ========== CATEGORY 9: HANDWRITTEN NOTES (4) ==========
    {
        "category": "notes",
        "name": "Mom's Original",
        "filename": "sticker_note_moms.png",
        "prompt": BASE_STYLE.format(description="handwritten text reading 'Mom's Original' in casual script style, dark blue ink on cream background, feeling like pen-on-paper")
    },
    {
        "category": "notes",
        "name": "Add More Garlic",
        "filename": "sticker_note_garlic.png",
        "prompt": BASE_STYLE.format(description="playful handwritten note 'Add More Garlic!' with small arrow pointing right, brown ink with character variation")
    },
    {
        "category": "notes",
        "name": "Best Ever",
        "filename": "sticker_note_best.png",
        "prompt": BASE_STYLE.format(description="emphatic handwritten text 'Best Ever' with underline, dark brown ink showing enthusiasm and confidence")
    },
    {
        "category": "notes",
        "name": "Trust Me",
        "filename": "sticker_note_trust.png",
        "prompt": BASE_STYLE.format(description="conversational handwritten text 'Trust Me on This' in friendly script, blue ink, personal recommendation")
    },

    # ========== CATEGORY 10: NOSTALGIC ICONS (2) ==========
    {
        "category": "nostalgic",
        "name": "Wooden Spoon",
        "filename": "sticker_nostalgic_spoon.png",
        "prompt": BASE_STYLE.format(description="a well-worn wooden spoon with visible wood grain texture and slightly rounded bowl, brown wood with cream highlights, symbol of grandma's cooking")
    },
    {
        "category": "nostalgic",
        "name": "Rolling Pin",
        "filename": "sticker_nostalgic_rollingpin.png",
        "prompt": BASE_STYLE.format(description="a classic wooden rolling pin with handles on both ends and visible wood grain, brown and cream tones, symbol of home baking")
    },
]


class StickerGenerator:
    """Generate stickers using OpenAI's DALL-E 3 API"""

    def __init__(self, api_key: str, output_dir: str = "heirloom_stickers_refined"):
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
    print("🍳 HEIRLOOM REFINED STICKER GENERATOR")
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
    output_dir = input("\nOutput directory [heirloom_stickers_refined]: ").strip()
    if not output_dir:
        output_dir = "heirloom_stickers_refined"

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

    print("\n✨ All done! Your refined expressive sticker library is ready to use.")
    print(f"📁 Find them at: {Path(output_dir).absolute()}")


if __name__ == "__main__":
    main()
