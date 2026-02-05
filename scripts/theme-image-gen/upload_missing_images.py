#!/usr/bin/env python3
"""
Upload generated missing recipe images to Firebase Storage.
Requires google-cloud-storage: pip install google-cloud-storage
"""

import os
import sys
import argparse
from pathlib import Path
from google.cloud import storage

# Configuration
SERVICE_ACCOUNT_PATH = Path(__file__).parent.parent.parent / "firebase" / "serviceAccountKey.json"
BUCKET_NAME = "heirloom-ios-prod.firebasestorage.app"
IMAGES_DIR = Path(__file__).parent / "missing_images"

# Image to theme mapping (derived from filename prefix)
def get_theme_from_filename(filename):
    """Extract theme ID from filename like 'american-foundation-american-013.webp'"""
    parts = filename.replace('.webp', '').split('-')
    # Theme IDs: american-foundation, ancient-table, literary-kitchen, presidential-pantry
    if 'american' in parts and 'foundation' in parts:
        return 'american-foundation'
    elif 'ancient' in parts and 'table' in parts:
        return 'ancient-table'
    elif 'literary' in parts and 'kitchen' in parts:
        return 'literary-kitchen'
    elif 'presidential' in parts and 'pantry' in parts:
        return 'presidential-pantry'
    return None


def upload_to_firebase(image_path, theme_id, dry_run=False):
    """Upload image to Firebase Storage"""
    filename = image_path.name
    storage_path = f"recipes/{theme_id}/{filename}"

    if dry_run:
        print(f"  Would upload: {filename} -> {storage_path}")
        return True

    try:
        client = storage.Client.from_service_account_json(str(SERVICE_ACCOUNT_PATH))
        bucket = client.bucket(BUCKET_NAME)
        blob = bucket.blob(storage_path)

        # Upload with content type and cache control
        blob.upload_from_filename(
            str(image_path),
            content_type='image/webp'
        )

        # Note: Bucket uses uniform access control, so files inherit bucket permissions
        # No need to call make_public() - access is controlled at bucket level

        print(f"  Uploaded: {filename} -> {storage_path}")
        return True

    except Exception as e:
        print(f"  Error uploading {filename}: {str(e)}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Upload missing recipe images to Firebase Storage')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be uploaded without uploading')
    parser.add_argument('--theme', help='Upload only for specific theme')

    args = parser.parse_args()

    # Check service account
    if not SERVICE_ACCOUNT_PATH.exists():
        print(f"Error: Service account key not found at {SERVICE_ACCOUNT_PATH}")
        sys.exit(1)

    # Check images directory
    if not IMAGES_DIR.exists():
        print(f"Error: Images directory not found at {IMAGES_DIR}")
        print("Run generate_missing_images.py first to generate images.")
        sys.exit(1)

    # Find all webp images
    images = list(IMAGES_DIR.glob("*.webp"))

    if not images:
        print(f"No .webp images found in {IMAGES_DIR}")
        sys.exit(1)

    print(f"\nFirebase Storage Uploader")
    print(f"{'='*50}")
    print(f"Images directory: {IMAGES_DIR}")
    print(f"Bucket: {BUCKET_NAME}")
    print(f"Found {len(images)} images to upload")
    print(f"{'='*50}\n")

    if args.dry_run:
        print("DRY RUN - No files will be uploaded\n")

    # Group by theme
    by_theme = {}
    for image_path in images:
        theme_id = get_theme_from_filename(image_path.name)
        if theme_id:
            if args.theme and theme_id != args.theme:
                continue
            if theme_id not in by_theme:
                by_theme[theme_id] = []
            by_theme[theme_id].append(image_path)

    # Upload by theme
    success_count = 0
    fail_count = 0

    for theme_id, theme_images in sorted(by_theme.items()):
        print(f"\n{theme_id} ({len(theme_images)} images):")

        for image_path in sorted(theme_images):
            if upload_to_firebase(image_path, theme_id, args.dry_run):
                success_count += 1
            else:
                fail_count += 1

    # Summary
    print(f"\n{'='*50}")
    print("Upload Complete!")
    print(f"  Success: {success_count}")
    print(f"  Failed: {fail_count}")

    if not args.dry_run and success_count > 0:
        print(f"\nNext steps:")
        print(f"  1. Update MANUAL_OVERRIDES in fix-all-theme-image-urls.js")
        print(f"  2. Run: cd firebase && node fix-all-theme-image-urls.js")
    print(f"{'='*50}\n")


if __name__ == '__main__':
    main()
