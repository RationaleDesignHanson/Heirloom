#!/usr/bin/env python3
"""
Upload heritage recipe images to Firebase Storage
Requires: pip install firebase-admin
Usage: python3 upload_heritage_images_to_firebase.py
"""

import json
import sys
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, storage

def main():
    print("🔥 Firebase Heritage Images Upload")
    print("=" * 60)

    # Paths
    project_root = Path("/Users/matthanson/Heirloom")
    json_path = project_root / "Heirloom/Resources/HeritageCollections/heritage-recipes.json"
    images_dir = project_root / "Heirloom/Resources/HeritageCollections/images"
    firebase_config = project_root / "Heirloom/Resources/GoogleService-Info.plist"

    # Check if images exist
    if not images_dir.exists():
        print("❌ Images directory not found. Generate images first!")
        sys.exit(1)

    image_files = list(images_dir.glob("*.png"))
    print(f"📁 Found {len(image_files)} images to upload")

    if len(image_files) == 0:
        print("❌ No images to upload. Generate images first!")
        sys.exit(1)

    # Initialize Firebase Admin
    print("\n🔐 Initializing Firebase Admin SDK...")

    # Read plist to get project info
    import plistlib
    with open(firebase_config, 'rb') as f:
        plist_data = plistlib.load(f)

    storage_bucket = plist_data.get('STORAGE_BUCKET') or plist_data.get('PROJECT_ID') + '.appspot.com'

    print(f"   Storage Bucket: {storage_bucket}")

    # Initialize with Application Default Credentials (using gcloud auth)
    # Or use service account key if you have one
    try:
        # Try application default credentials first
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {
            'storageBucket': storage_bucket
        })
    except:
        print("\n⚠️  Need to authenticate with Firebase:")
        print("   Run: firebase login")
        print("   Or set GOOGLE_APPLICATION_CREDENTIALS to service account key")
        sys.exit(1)

    # Get storage bucket
    bucket = storage.bucket()
    print(f"✅ Connected to Firebase Storage: {bucket.name}")

    # Load JSON to update URLs
    with open(json_path, 'r') as f:
        data = json.load(f)

    # Create a map of recipe ID to recipe
    recipes_map = {recipe['id']: recipe for recipe in data['recipes']}

    # Upload images
    print(f"\n📤 Uploading {len(image_files)} images...")
    uploaded = 0
    failed = []

    for i, image_path in enumerate(image_files, 1):
        recipe_id = image_path.stem  # filename without extension

        if recipe_id not in recipes_map:
            print(f"[{i}/{len(image_files)}] ⚠️  {image_path.name} - No matching recipe")
            continue

        recipe = recipes_map[recipe_id]

        # Firebase Storage path
        blob_path = f"heritage-recipes/{recipe_id}.png"

        print(f"[{i}/{len(image_files)}] Uploading: {recipe['title']}")
        print(f"   → {blob_path}")

        try:
            # Upload to Firebase Storage
            blob = bucket.blob(blob_path)
            blob.upload_from_filename(str(image_path), content_type='image/png')

            # With uniform bucket-level access, we can't make individual objects public
            # Instead, we use Storage rules for public read access
            # Construct the public URL manually
            bucket_name = bucket.name
            public_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{blob_path.replace('/', '%2F')}?alt=media"

            # Update recipe JSON
            recipe['imageURL'] = public_url
            if 'localImagePath' in recipe:
                del recipe['localImagePath']  # Remove local path

            uploaded += 1
            print(f"   ✅ {public_url[:80]}...")

        except Exception as e:
            print(f"   ❌ Failed: {str(e)}")
            failed.append(recipe['title'])

    # Save updated JSON
    print(f"\n💾 Saving updated JSON...")
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)

    # Summary
    print(f"\n{'='*60}")
    print(f"✅ Upload complete!")
    print(f"   Uploaded: {uploaded}/{len(image_files)}")
    print(f"   Failed: {len(failed)}")
    if failed:
        print(f"\n   Failed recipes:")
        for title in failed:
            print(f"   - {title}")
    print(f"\n📄 Updated: {json_path}")
    print(f"🔥 Images available at: https://console.firebase.google.com/project/{plist_data.get('PROJECT_ID')}/storage")
    print(f"{'='*60}")

    print("\n✨ Next steps:")
    print("1. Set Firebase Storage rules to allow anonymous read:")
    print("   rules_version = '2';")
    print("   service firebase.storage {")
    print("     match /b/{bucket}/o {")
    print("       match /heritage-recipes/{imageId} {")
    print("         allow read: if true;")
    print("       }")
    print("     }")
    print("   }")
    print("\n2. App will now download images from Firebase on first launch")

if __name__ == "__main__":
    main()
