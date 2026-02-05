#!/usr/bin/env python3
"""
Generate images for missing theme recipes using Replicate FLUX API.
These are recipes that exist in Firestore but don't have corresponding images.
"""

import os
import sys
import time
import hashlib
import argparse
from pathlib import Path
import replicate
import requests

# Configuration
OUTPUT_DIR = Path(__file__).parent / "missing_images"
FLUX_MODEL = "black-forest-labs/flux-dev"

# Era styling for each theme
ERA_STYLES = {
    'american-foundation': 'Colonial hearth cooking, cast iron skillets, rough-hewn tables, rustic Americana, founding era simplicity, honest farm-to-table, early American heritage',
    'ancient-table': 'Classical antiquity, archaeological recreation photography, earth tones, ancient Roman/Greek styling, museum-quality presentation, historical accuracy, terracotta and olive branches',
    'literary-kitchen': 'Victorian era formality, Mrs. Beeton cookbook aesthetic, ornate china, Edwardian dining, Dickensian literary feast feel, sepia undertones, classic literature inspiration',
    'presidential-pantry': 'Colonial American formal entertaining, 18th-century Mount Vernon style, elegant but not ostentatious, presidential dining aesthetic, pewter and silver, White House state dinner tradition'
}

# Base heritage style (always applied)
BASE_STYLE = (
    "warm golden hour lighting, rustic wooden table, "
    "4:3 landscape aspect ratio, slightly overhead angle 30-45 degrees, "
    "home-cooked heritage aesthetic not restaurant, cream and amber color palette, "
    "soft natural shadows, nostalgic feel, professional food photography"
)

# Negative prompt for consistency
NEGATIVE_PROMPT = (
    "modern plating, restaurant styling, garnishes, microgreens, foam, "
    "molecular gastronomy, neon colors, harsh lighting, people, hands, "
    "text, watermarks, logos, smartphones, modern appliances"
)

# Missing recipes with custom prompts
MISSING_RECIPES = {
    'american-foundation': [
        {
            'title': 'Samp and Beans',
            'filename': 'american-foundation-american-013.webp',
            'prompt': 'A rustic bowl of samp and beans, Native American inspired hominy corn with slow-cooked beans, colonial New England hearth cooking, earthenware bowl, rough wooden table'
        },
        {
            'title': 'Rye and Injun Bread',
            'filename': 'american-foundation-american-014.webp',
            'prompt': 'A dense loaf of rye and injun bread, colonial American cornmeal and rye flour bread, dark crusty exterior, sliced to show dense interior, cast iron baking pan, early American farmhouse'
        },
        {
            'title': 'Pone',
            'filename': 'american-foundation-american-015.webp',
            'prompt': 'A golden cornmeal pone, Southern colonial corn bread, baked in cast iron skillet, crispy edges, rustic frontier cooking, Native American influenced recipe'
        },
        {
            'title': 'Flummery',
            'filename': 'american-foundation-american-016.webp',
            'prompt': 'A molded flummery dessert, colonial American oat or fruit jelly pudding, elegant simple mold shape, cream-colored, vintage pewter serving plate, early American dessert'
        },
        {
            'title': 'Persimmon Pudding',
            'filename': 'american-foundation-american-017.webp',
            'prompt': 'A warm persimmon pudding, American frontier dessert, rich orange-brown color, steaming ceramic dish, wild persimmon fruit, Midwestern heritage recipe, autumn harvest'
        },
        {
            'title': 'Hominy Grits',
            'filename': 'american-foundation-american-018.webp',
            'prompt': 'A steaming bowl of hominy grits, Native American corn preparation, creamy white porridge, pat of butter melting, earthenware bowl, Southern colonial breakfast staple'
        },
        {
            'title': 'Shrub',
            'filename': 'american-foundation-american-019.webp',
            'prompt': 'A glass of colonial shrub drinking vinegar, fruit-infused vinegar beverage, ruby red color, clear glass pitcher, fresh berries, early American refreshment, summer drink'
        },
        {
            'title': 'Indian Pudding (Baked)',
            'filename': 'american-foundation-american-020.webp',
            'prompt': 'A warm baked Indian pudding, New England cornmeal and molasses dessert, golden brown top, ceramic baking dish, dollop of cream, colonial American comfort food'
        },
        {
            'title': 'Corn Oysters',
            'filename': 'american-foundation-american-021.webp',
            'prompt': 'Golden fried corn oysters, colonial corn fritters shaped like oysters, crispy exterior, fresh corn kernels visible, cast iron skillet, early American frontier recipe'
        },
        {
            'title': 'Anadama Bread',
            'filename': 'american-foundation-american-022.webp',
            'prompt': 'A sliced loaf of Anadama bread, New England cornmeal and molasses yeast bread, golden crust, soft interior, rustic bread board, Massachusetts fisherman legend'
        },
        {
            'title': 'Sally Lunn Bread',
            'filename': 'american-foundation-american-023.webp',
            'prompt': 'A golden Sally Lunn bread, rich colonial egg bread, bundt-style ring shape, light and airy texture, Virginia colonial heritage, British-American recipe'
        },
        {
            'title': 'Ash Cakes',
            'filename': 'american-foundation-american-024.webp',
            'prompt': 'Simple ash cakes, frontier cornmeal cakes cooked in hearth ashes, rustic charred exterior, pioneer survival food, campfire cooking, early American trail bread'
        },
        {
            'title': 'Spider Corn Cake',
            'filename': 'american-foundation-american-025.webp',
            'prompt': 'A spider corn cake in cast iron spider skillet, New England cornbread baked with cream, golden top, creamy custard layer, three-legged cast iron pan, colonial hearth'
        }
    ],
    'ancient-table': [
        {
            'title': 'Phoenician Fish Stew',
            'filename': 'ancient-table-ancient-013.webp',
            'prompt': 'A Phoenician fish stew, ancient Mediterranean seafood dish, terracotta cooking pot, fresh fish and herbs, olive oil, coastal Levantine cuisine, archaeological recreation'
        },
        {
            'title': 'Carthaginian Couscous',
            'filename': 'ancient-table-ancient-014.webp',
            'prompt': 'Ancient Carthaginian couscous, North African grain dish, earthen bowl, semolina grains, vegetables and spices, Punic heritage cuisine, terracotta serving'
        },
        {
            'title': 'Etruscan Polenta',
            'filename': 'ancient-table-ancient-015.webp',
            'prompt': 'Etruscan puls or polenta, ancient Italian grain porridge, served in rustic clay bowl, pre-Roman cuisine, simple hearty fare, Tuscany heritage'
        },
        {
            'title': 'Sumerian Date Cake',
            'filename': 'ancient-table-ancient-016.webp',
            'prompt': 'A Sumerian date cake, ancient Mesopotamian dessert, pressed dates with nuts, clay tablet aesthetic, cuneiform inspired presentation, earliest known recipes'
        },
        {
            'title': 'Chinese Jiaozi Dumplings',
            'filename': 'ancient-table-ancient-017.webp',
            'prompt': 'Ancient Chinese jiaozi dumplings, Han dynasty style, delicate pleated wrappers, bamboo steamer, jade-green vegetables inside, silk road aesthetic, museum quality'
        },
        {
            'title': 'Viking Smoked Fish',
            'filename': 'ancient-table-ancient-018.webp',
            'prompt': 'Viking smoked fish, Norse preserved salmon or herring, hanging smoking technique, wooden smoking rack, Scandinavian coastal heritage, amber and earth tones'
        },
        {
            'title': 'Celtic Oat Porridge',
            'filename': 'ancient-table-ancient-019.webp',
            'prompt': 'Celtic oat porridge, ancient Scottish or Irish breakfast, wooden bowl, raw oats and honey, Iron Age simplicity, rustic stone table, morning hearth'
        },
        {
            'title': 'Aztec Chocolate Drink',
            'filename': 'ancient-table-ancient-020.webp',
            'prompt': 'Aztec xocolatl chocolate drink, ancient Mesoamerican cacao beverage, foamy dark liquid, gourd cup, chili peppers and vanilla, Mayan influenced, ceremonial presentation'
        },
        {
            'title': 'Inca Quinoa Soup',
            'filename': 'ancient-table-ancient-021.webp',
            'prompt': 'Inca quinoa soup, ancient Andean grain stew, ceramic pot, colorful vegetables, high altitude cuisine, Peruvian heritage, archaeological aesthetic'
        },
        {
            'title': 'Medieval Pottage',
            'filename': 'ancient-table-ancient-022.webp',
            'prompt': 'Medieval pottage thick soup, European peasant stew, iron cauldron, root vegetables and grains, hearth fire, castle kitchen, rough wooden spoon'
        },
        {
            'title': 'Roman Puls',
            'filename': 'ancient-table-ancient-023.webp',
            'prompt': 'Roman puls grain porridge, ancient Roman staple food, emmer wheat porridge, simple clay bowl, olive oil drizzle, legionary rations, archaeological recreation'
        },
        {
            'title': 'Greek Symposium Wine',
            'filename': 'ancient-table-ancient-024.webp',
            'prompt': 'Greek symposium wine, ancient Athenian drinking vessel, kylix cup, diluted red wine, black-figure pottery style, olive wreath, classical antiquity'
        },
        {
            'title': 'Babylonian Beer',
            'filename': 'ancient-table-ancient-025.webp',
            'prompt': 'Babylonian beer, ancient Mesopotamian brew, clay drinking vessel with straw, barley beer, cuneiform tablet nearby, Hammurabi era, earliest brewing'
        }
    ],
    'literary-kitchen': [
        {
            'title': "Oliver Twist's Gruel",
            'filename': 'literary-kitchen-literary-015.webp',
            'prompt': "Oliver Twist's thin gruel, Dickensian workhouse porridge, sparse watery oatmeal, chipped bowl, Victorian poverty, Please sir I want some more, somber lighting"
        },
        {
            'title': "The Hobbit's Seed-cakes",
            'filename': 'literary-kitchen-literary-016.webp',
            'prompt': "Hobbit seed-cakes from Bag End, Tolkien inspired caraway seed cakes, warm cottage kitchen, round door, cozy Shire aesthetic, second breakfast, rustic comfort"
        },
        {
            'title': "Proust's Madeleines",
            'filename': 'literary-kitchen-literary-017.webp',
            'prompt': "Proust's madeleines, French shell-shaped butter cakes, delicate golden sponge, fine china tea cup, Belle Epoque Paris, Remembrance of Things Past, nostalgic elegance"
        },
        {
            'title': "James Bond's Vesper Martini",
            'filename': 'literary-kitchen-literary-018.webp',
            'prompt': "James Bond's Vesper martini, shaken not stirred, elegant crystal martini glass, lemon twist, sophisticated spy aesthetic, Casino Royale, art deco bar"
        },
        {
            'title': "The Bell Jar's Avocado Pear",
            'filename': 'literary-kitchen-literary-019.webp',
            'prompt': "Avocado pear halves with vinaigrette, 1950s ladies luncheon, Sylvia Plath aesthetic, pristine white plate, elegant simplicity, mid-century New York"
        },
        {
            'title': "Don Quixote's Olla Podrida",
            'filename': 'literary-kitchen-literary-020.webp',
            'prompt': "Don Quixote's olla podrida, Spanish medieval stew, earthenware pot, mixed meats and chickpeas, La Mancha rustic kitchen, Cervantes era, hearty peasant fare"
        },
        {
            'title': "The Old Man and the Sea's Fried Dolphinfish",
            'filename': 'literary-kitchen-literary-021.webp',
            'prompt': "Hemingway's fried dorado fish, Cuban fisherman's meal, simple pan-fried mahi-mahi, rustic wooden boat deck, Old Man and the Sea, Caribbean sun, weathered hands aesthetic"
        },
        {
            'title': "Emma's Wedding Cake",
            'filename': 'literary-kitchen-literary-022.webp',
            'prompt': "Jane Austen's Emma wedding cake, Regency era towering fruit cake, white royal icing, elegant tiered presentation, English countryside manor, romantic period drama"
        },
        {
            'title': "The Grapes of Wrath's Biscuits",
            'filename': 'literary-kitchen-literary-023.webp',
            'prompt': "Grapes of Wrath Depression-era biscuits, simple flour biscuits with gravy, dust bowl aesthetic, humble farm kitchen, Steinbeck Americana, desperate times comfort"
        },
        {
            'title': "Babette's Feast Blinis",
            'filename': 'literary-kitchen-literary-024.webp',
            'prompt': "Babette's Feast blinis, French culinary masterpiece, delicate buckwheat pancakes with caviar, fine Danish table setting, transformative meal, cinematic feast"
        },
        {
            'title': "Catch-22's Milo's Egyptian Cotton",
            'filename': 'literary-kitchen-literary-025.webp',
            'prompt': "Catch-22 absurdist military chocolate, Milo Minderbinder's mess hall, WWII army dining, satirical presentation, Heller's dark humor, cotton candy meets chocolate"
        }
    ],
    'presidential-pantry': [
        {
            'title': "Herbert Hoover's Waldorf Salad",
            'filename': 'presidential-pantry-presidential-015.webp',
            'prompt': "Herbert Hoover's Waldorf salad, elegant 1920s presentation, crisp apples and celery with walnuts, mayonnaise dressing, White House formal dining, Great Depression era elegance"
        },
        {
            'title': "Ulysses S. Grant's Rice Pudding",
            'filename': 'presidential-pantry-presidential-016.webp',
            'prompt': "Ulysses S. Grant's rice pudding, Civil War era comfort dessert, creamy rice with cinnamon, simple military aesthetic, post-war healing, American general's favorite"
        },
        {
            'title': "William Howard Taft's Steak",
            'filename': 'presidential-pantry-presidential-017.webp',
            'prompt': "President Taft's massive beefsteak, hearty presidential appetite, thick-cut prime beef, elegant but generous portion, Gilded Age dining, silver service"
        },
        {
            'title': "Benjamin Harrison's Corn Relish",
            'filename': 'presidential-pantry-presidential-018.webp',
            'prompt': "Benjamin Harrison's corn relish, Indiana farm heritage, colorful preserved corn with peppers, glass canning jar, Midwestern presidential roots, harvest time"
        },
        {
            'title': "Rutherford B. Hayes' Mashed Potatoes",
            'filename': 'presidential-pantry-presidential-019.webp',
            'prompt': "Rutherford B. Hayes' fluffy mashed potatoes, Ohio presidential comfort food, buttery whipped potatoes, elegant silver serving dish, Victorian White House"
        },
        {
            'title': "James Buchanan's Sauerkraut",
            'filename': 'presidential-pantry-presidential-020.webp',
            'prompt': "James Buchanan's Pennsylvania sauerkraut, German-American heritage, fermented cabbage in stoneware crock, Lancaster County roots, pre-Civil War era"
        },
        {
            'title': "Grover Cleveland's Corned Beef Hash",
            'filename': 'presidential-pantry-presidential-021.webp',
            'prompt': "Grover Cleveland's corned beef hash, hearty breakfast dish, crispy cubed potatoes and beef, poached egg on top, New York heritage, cast iron skillet"
        },
        {
            'title': "Chester Arthur's Lobster Newburg",
            'filename': 'presidential-pantry-presidential-022.webp',
            'prompt': "Chester Arthur's Lobster Newburg, Gilded Age extravagance, rich cream sauce with lobster, elegant chafing dish, Delmonico's influence, opulent 1880s"
        },
        {
            'title': "Millard Fillmore's Apple Dumplings",
            'filename': 'presidential-pantry-presidential-023.webp',
            'prompt': "Millard Fillmore's apple dumplings, Upstate New York comfort, whole apples in pastry, cinnamon sauce, Buffalo heritage, mid-19th century dessert"
        },
        {
            'title': "Franklin Pierce's Rum Punch",
            'filename': 'presidential-pantry-presidential-024.webp',
            'prompt': "Franklin Pierce's rum punch, New Hampshire hospitality, crystal punch bowl, citrus and rum, antebellum entertaining, pre-Civil War society"
        },
        {
            'title': "William McKinley's Gingerbread Cookies",
            'filename': 'presidential-pantry-presidential-025.webp',
            'prompt': "William McKinley's gingerbread cookies, Ohio campaign trail treats, molasses spiced cookies, Victorian holiday aesthetic, turn of century Americana"
        }
    ]
}


def generate_seed(title):
    """Generate consistent seed from title for reproducibility"""
    return int(hashlib.md5(title.encode()).hexdigest()[:8], 16)


def generate_full_prompt(recipe, era_style):
    """Combine recipe prompt with era style and base style"""
    return f"{recipe['prompt']}, {era_style}, {BASE_STYLE}"


def generate_image(recipe, era_style, output_path, preview_only=False):
    """Generate image using Replicate FLUX API"""
    full_prompt = generate_full_prompt(recipe, era_style)
    seed = generate_seed(recipe['title'])

    if preview_only:
        print(f"\n{'='*80}")
        print(f"Recipe: {recipe['title']}")
        print(f"Filename: {recipe['filename']}")
        print(f"Seed: {seed}")
        print(f"\nPrompt:\n{full_prompt}")
        print(f"\nNegative Prompt:\n{NEGATIVE_PROMPT}")
        print(f"{'='*80}\n")
        return True

    try:
        print(f"Generating: {recipe['title']}...")

        output = replicate.run(
            FLUX_MODEL,
            input={
                "prompt": full_prompt,
                "aspect_ratio": "4:3",
                "output_format": "webp",
                "output_quality": 90,
                "seed": seed,
                "num_inference_steps": 28,
                "guidance_scale": 3.5,
            }
        )

        # Download image
        image_url = output[0] if isinstance(output, list) else output
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()

        # Save as WebP
        with open(output_path, 'wb') as f:
            f.write(response.content)

        file_size = os.path.getsize(output_path) / 1024  # KB
        print(f"  Saved to {output_path.name} ({file_size:.1f} KB)")
        return True

    except Exception as e:
        print(f"  Error generating {recipe['title']}: {str(e)}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Generate missing theme recipe images with Replicate FLUX')
    parser.add_argument('--preview-only', action='store_true', help='Show prompts without generating images')
    parser.add_argument('--theme', help='Generate only for specific theme (e.g., american-foundation)')
    parser.add_argument('--delay', type=float, default=5.0, help='Delay between API calls (seconds)')
    parser.add_argument('--limit', type=int, help='Limit number of images to generate')

    args = parser.parse_args()

    # Check API token
    if not args.preview_only and not os.getenv('REPLICATE_API_TOKEN'):
        print("Error: REPLICATE_API_TOKEN environment variable not set")
        print("Set it with: export REPLICATE_API_TOKEN='r8_your_key_here'")
        sys.exit(1)

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Collect recipes to process
    recipes_to_process = []

    for theme_id, recipes in MISSING_RECIPES.items():
        if args.theme and theme_id != args.theme:
            continue

        for recipe in recipes:
            recipes_to_process.append({
                **recipe,
                'theme_id': theme_id
            })

    if args.limit:
        recipes_to_process = recipes_to_process[:args.limit]

    # Summary
    print(f"\nMissing Recipe Image Generator")
    print(f"{'='*50}")
    print(f"Total recipes to generate: {len(recipes_to_process)}")
    print(f"Estimated cost: ${len(recipes_to_process) * 0.003:.2f}")
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"{'='*50}\n")

    if args.preview_only:
        print("PREVIEW MODE - No images will be generated\n")

    # Generate images
    success_count = 0
    skip_count = 0
    fail_count = 0

    for i, recipe in enumerate(recipes_to_process, 1):
        output_path = OUTPUT_DIR / recipe['filename']
        era_style = ERA_STYLES.get(recipe['theme_id'], '')

        # Skip if already exists
        if not args.preview_only and output_path.exists():
            print(f"[{i}/{len(recipes_to_process)}] Skipping {recipe['title']} (already exists)")
            skip_count += 1
            continue

        print(f"[{i}/{len(recipes_to_process)}] ", end='')

        if generate_image(recipe, era_style, output_path, args.preview_only):
            success_count += 1
        else:
            fail_count += 1

        # Rate limiting delay
        if not args.preview_only and i < len(recipes_to_process):
            time.sleep(args.delay)

    # Final summary
    print(f"\n{'='*50}")
    print("Generation Complete!")
    print(f"  Total: {len(recipes_to_process)}")
    if not args.preview_only:
        print(f"  Success: {success_count}")
        print(f"  Skipped: {skip_count}")
        print(f"  Failed: {fail_count}")
        print(f"  Actual cost: ${success_count * 0.003:.2f}")
        print(f"\nImages saved to: {OUTPUT_DIR}")
        print(f"\nNext steps:")
        print(f"  1. Review generated images in {OUTPUT_DIR}")
        print(f"  2. Upload to Firebase Storage: recipes/{{theme_id}}/{{filename}}")
        print(f"  3. Run fix-all-theme-image-urls.js to update Firestore URLs")
    print(f"{'='*50}\n")


if __name__ == '__main__':
    main()
