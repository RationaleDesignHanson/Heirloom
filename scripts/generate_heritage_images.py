#!/usr/bin/env python3
"""
Generate period-appropriate AI images for heritage recipes
Usage: python3 generate_heritage_images.py YOUR_OPENAI_API_KEY
"""

import json
import sys
import os
import time
import requests
from pathlib import Path

def generate_image_prompt(recipe):
    """Create a detailed prompt for period-appropriate food photography"""
    title = recipe['title']
    era = recipe['sourceDate']
    hist_context = recipe.get('historicalContext', '')
    tags = recipe.get('tags', [])

    # Determine era style
    if '1700s' in era or '1600s' in era or 'colonial' in hist_context.lower():
        style = "colonial American kitchen, rustic wooden table, pewter dishes, candlelight, 1700s painting style"
    elif '1800s' in era or 'Victorian' in hist_context:
        style = "Victorian era, ornate china, formal table setting, sepia tones, daguerreotype photography style"
    elif '1900s' in era or '1920s' in era or '1930s' in era:
        style = "early 20th century, vintage black and white photography, Art Deco styling"
    elif '1950s' in era or '1960s' in era:
        style = "mid-century modern, Kodachrome color photography, 1950s cookbook aesthetic"
    elif 'ancient' in recipe['heritageCollectionId'] or 'Roman' in title or 'Greek' in title:
        style = "ancient world, archaeological photography, earth tones, classical antiquity"
    elif 'BCE' in era or 'CE' in era:
        style = "ancient civilization, historical recreation, museum quality, archaeological"
    else:
        style = "vintage food photography, historical styling, period-appropriate presentation"

    # Build prompt
    prompt = f"A beautifully styled photograph of {title}, {style}. "
    prompt += f"The dish should look authentic to {era}. "
    prompt += "Professional food photography, top-down view, natural lighting. "
    prompt += "No text, no people, just the food in period-appropriate setting."

    return prompt

def generate_with_dalle(api_key, recipe):
    """Generate image using DALL-E 3"""
    prompt = generate_image_prompt(recipe)

    print(f"\n🎨 Generating: {recipe['title']}")
    print(f"   Era: {recipe['sourceDate']}")
    print(f"   Prompt: {prompt[:100]}...")

    try:
        response = requests.post(
            "https://api.openai.com/v1/images/generations",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": "dall-e-3",
                "prompt": prompt,
                "n": 1,
                "size": "1024x1024",
                "quality": "standard",
                "style": "natural"
            },
            timeout=60
        )

        if response.status_code == 200:
            data = response.json()
            image_url = data['data'][0]['url']
            print(f"   ✅ Generated: {image_url[:50]}...")
            return image_url
        else:
            print(f"   ❌ Error {response.status_code}: {response.text[:100]}")
            return None

    except Exception as e:
        print(f"   ❌ Exception: {str(e)}")
        return None

def download_image(url, save_path):
    """Download image from URL to local path"""
    try:
        response = requests.get(url, timeout=30)
        if response.status_code == 200:
            with open(save_path, 'wb') as f:
                f.write(response.content)
            return True
        return False
    except Exception as e:
        print(f"   ⚠️  Download failed: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_heritage_images.py YOUR_OPENAI_API_KEY")
        print("\nThis will:")
        print("1. Generate period-appropriate images for all 100 heritage recipes")
        print("2. Download images to Heirloom/Resources/HeritageCollections/images/")
        print("3. Update heritage-recipes.json with local image paths")
        print("\nEstimated cost: ~$4 (100 images × $0.040 per image with DALL-E 3)")
        print("Estimated time: ~30-45 minutes")
        sys.exit(1)

    api_key = sys.argv[1]

    # Paths
    project_root = Path("/Users/matthanson/Heirloom")
    json_path = project_root / "Heirloom/Resources/HeritageCollections/heritage-recipes.json"
    images_dir = project_root / "Heirloom/Resources/HeritageCollections/images"

    # Create images directory
    images_dir.mkdir(parents=True, exist_ok=True)

    # Load recipes
    with open(json_path, 'r') as f:
        data = json.load(f)

    print(f"\n🍳 Found {len(data['recipes'])} heritage recipes")
    print(f"📁 Images will be saved to: {images_dir}")

    # Confirm (auto-confirmed for batch processing)
    # response = input("\n⚠️  This will cost ~$4. Continue? (yes/no): ")
    # if response.lower() != 'yes':
    #     print("Cancelled.")
    #     return
    print("\n⚠️  Starting generation (~$4 cost)...")

    # Generate images
    generated = 0
    failed = []

    for i, recipe in enumerate(data['recipes'], 1):
        print(f"\n[{i}/{len(data['recipes'])}] Processing: {recipe['title']}")

        # Generate filename
        recipe_id = recipe['id']
        image_filename = f"{recipe_id}.png"
        image_path = images_dir / image_filename

        # Skip if already exists
        if image_path.exists():
            print(f"   ⏭️  Already exists, skipping")
            recipe['localImagePath'] = f"HeritageCollections/images/{image_filename}"
            continue

        # Generate with DALL-E
        image_url = generate_with_dalle(api_key, recipe)

        if image_url:
            # Download
            if download_image(image_url, image_path):
                recipe['localImagePath'] = f"HeritageCollections/images/{image_filename}"
                generated += 1
                print(f"   💾 Saved to: {image_filename}")
            else:
                failed.append(recipe['title'])
        else:
            failed.append(recipe['title'])

        # Rate limit: DALL-E 3 has rate limits
        if i < len(data['recipes']):
            print("   ⏳ Waiting 3 seconds...")
            time.sleep(3)

    # Save updated JSON
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)

    # Summary
    print(f"\n{'='*60}")
    print(f"✅ Generation complete!")
    print(f"   Generated: {generated}")
    print(f"   Failed: {len(failed)}")
    if failed:
        print(f"\n   Failed recipes:")
        for title in failed:
            print(f"   - {title}")
    print(f"\n📄 Updated: {json_path}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
