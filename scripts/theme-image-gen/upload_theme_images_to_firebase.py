#!/usr/bin/env python3
"""
Upload theme recipe images to Firebase Storage
Generates public URLs for each image and updates manifest
"""

import json
import os
import sys
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, storage

# Configuration
SERVICE_ACCOUNT_PATH = Path(__file__).parent.parent.parent / "backend" / "firebase-service-account.json"
IMAGES_DIR = Path(__file__).parent / "images"
MANIFEST_PATH = Path(__file__).parent / "image_manifest.json"
BUCKET_NAME = "heirloom-ios-prod.appspot.com"
STORAGE_PREFIX = "theme-recipes"


def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    if not SERVICE_ACCOUNT_PATH.exists():
        print(f"Error: Service account file not found at {SERVICE_ACCOUNT_PATH}")
        sys.exit(1)

    try:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT_PATH))
        firebase_admin.initialize_app(cred, {
            'storageBucket': BUCKET_NAME
        })
        print(f"✓ Firebase initialized with bucket: {BUCKET_NAME}")
    except Exception as e:
        print(f"Error initializing Firebase: {str(e)}")
        sys.exit(1)


def upload_image(image_path, filename):
    """Upload single image to Firebase Storage"""
    try:
        bucket = storage.bucket()
        # Keep the full filename including theme prefix
        blob_path = f"{STORAGE_PREFIX}/{filename}"
        blob = bucket.blob(blob_path)

        # Upload with WebP content type
        blob.upload_from_filename(
            str(image_path),
            content_type='image/webp'
        )

        # Make public
        blob.make_public()

        # Get public URL
        public_url = blob.public_url

        return public_url

    except Exception as e:
        print(f"  ✗ Error uploading {filename}: {str(e)}")
        return None


def update_manifest_with_urls(manifest_path, url_mapping):
    """Update manifest with Firebase URLs"""
    if not manifest_path.exists():
        print("Warning: Manifest file not found, skipping update")
        return

    try:
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)

        # Update recipe entries with Firebase URLs
        for recipe in manifest['recipes']:
            recipe_id = recipe['id']
            if recipe_id in url_mapping:
                recipe['firebase_url'] = url_mapping[recipe_id]

        # Save updated manifest
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)

        print(f"\n✓ Manifest updated with Firebase URLs")

    except Exception as e:
        print(f"Error updating manifest: {str(e)}")


def create_url_mapping_file(url_mapping):
    """Create separate JSON file with recipe ID to URL mapping"""
    output_path = Path(__file__).parent / "firebase_urls.json"

    mapping_data = {
        'bucket': BUCKET_NAME,
        'storage_prefix': STORAGE_PREFIX,
        'total_images': len(url_mapping),
        'urls': url_mapping
    }

    with open(output_path, 'w') as f:
        json.dump(mapping_data, f, indent=2)

    print(f"✓ URL mapping saved to {output_path}")


def main():
    print("Theme Recipe Image Upload to Firebase")
    print("="*80)

    # Check images directory
    if not IMAGES_DIR.exists() or not list(IMAGES_DIR.glob("*.webp")):
        print(f"Error: No images found in {IMAGES_DIR}")
        print("Run './run_image_gen.sh generate' first to create images")
        sys.exit(1)

    # Get list of images
    image_files = sorted(IMAGES_DIR.glob("*.webp"))
    print(f"Found {len(image_files)} images to upload\n")

    # Initialize Firebase
    initialize_firebase()

    # Upload images
    url_mapping = {}
    success_count = 0
    fail_count = 0

    for i, image_path in enumerate(image_files, 1):
        filename = image_path.name  # full filename with extension
        recipe_id = image_path.stem  # filename without extension
        print(f"[{i}/{len(image_files)}] Uploading {filename}...")

        url = upload_image(image_path, filename)

        if url:
            url_mapping[recipe_id] = url
            success_count += 1
            print(f"  ✓ {url}")
        else:
            fail_count += 1

    # Update manifest and create mapping file
    if url_mapping:
        update_manifest_with_urls(MANIFEST_PATH, url_mapping)
        create_url_mapping_file(url_mapping)

    # Summary
    print(f"\n{'='*80}")
    print("Upload Summary:")
    print(f"  Total images: {len(image_files)}")
    print(f"  Successful: {success_count}")
    print(f"  Failed: {fail_count}")
    print(f"  Storage path: gs://{BUCKET_NAME}/{STORAGE_PREFIX}/")
    print(f"{'='*80}\n")


if __name__ == '__main__':
    main()
