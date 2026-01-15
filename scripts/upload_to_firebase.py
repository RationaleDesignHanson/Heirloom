#!/usr/bin/env python3
"""
Upload heritage unlock schedules and recipes to Firebase.

This script:
1. Uploads 100 unlock schedules to heritage_schedules collection
2. Uploads 100 recipes to heritage_recipes collection
3. Uses Firebase Admin SDK for authenticated access

Prerequisites:
- pip install firebase-admin
- Service account key at backend/firebase-service-account.json
"""

import json
import sys
from pathlib import Path
from typing import Dict, List

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("Error: firebase-admin not installed", file=sys.stderr)
    print("Install with: pip install firebase-admin", file=sys.stderr)
    sys.exit(1)

def init_firebase() -> firestore.Client:
    """Initialize Firebase Admin SDK."""
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    service_account_path = repo_root / "backend" / "firebase-service-account.json"

    if not service_account_path.exists():
        print(f"Error: Service account key not found at {service_account_path}", file=sys.stderr)
        print("Download from Firebase Console > Project Settings > Service Accounts", file=sys.stderr)
        sys.exit(1)

    cred = credentials.Certificate(str(service_account_path))
    firebase_admin.initialize_app(cred)

    return firestore.client()

def upload_schedules(db: firestore.Client, schedules: List[Dict]) -> None:
    """Upload unlock schedules to Firestore."""
    print("\n📤 Uploading unlock schedules...", file=sys.stderr)

    batch = db.batch()
    batch_count = 0

    for schedule in schedules:
        schedule_id = schedule["scheduleId"]
        doc_ref = db.collection("heritage_schedules").document(schedule_id)

        batch.set(doc_ref, schedule)
        batch_count += 1

        # Firestore batch limit is 500 operations
        if batch_count >= 500:
            batch.commit()
            print(f"  ✓ Committed batch of {batch_count} schedules", file=sys.stderr)
            batch = db.batch()
            batch_count = 0

    # Commit remaining
    if batch_count > 0:
        batch.commit()
        print(f"  ✓ Committed final batch of {batch_count} schedules", file=sys.stderr)

    print(f"✅ Uploaded {len(schedules)} unlock schedules", file=sys.stderr)

def upload_recipes(db: firestore.Client, recipes: List[Dict]) -> None:
    """Upload recipes to Firestore."""
    print("\n📤 Uploading heritage recipes...", file=sys.stderr)

    batch = db.batch()
    batch_count = 0

    for recipe in recipes:
        recipe_id = recipe["id"]
        doc_ref = db.collection("heritage_recipes").document(recipe_id)

        # Prepare recipe document
        recipe_doc = {
            "id": recipe_id,
            "title": recipe["title"],
            "heritageCollectionId": recipe["heritageCollectionId"],
            "servings": recipe.get("servings"),
            "prepTime": recipe.get("prepTime"),
            "cookTime": recipe.get("cookTime"),
            "ingredients": recipe["ingredients"],
            "instructions": recipe["instructions"],
            "historicalText": recipe.get("historicalText"),
            "historicalContext": recipe.get("historicalContext"),
            "sourceAttribution": recipe.get("sourceAttribution"),
            "sourceDate": recipe.get("sourceDate"),
            "sourceURL": recipe.get("sourceURL"),
            "imageURL": recipe.get("imageURL"),
            "tags": recipe.get("tags", [])
        }

        batch.set(doc_ref, recipe_doc)
        batch_count += 1

        # Firestore batch limit is 500 operations
        if batch_count >= 500:
            batch.commit()
            print(f"  ✓ Committed batch of {batch_count} recipes", file=sys.stderr)
            batch = db.batch()
            batch_count = 0

    # Commit remaining
    if batch_count > 0:
        batch.commit()
        print(f"  ✓ Committed final batch of {batch_count} recipes", file=sys.stderr)

    print(f"✅ Uploaded {len(recipes)} heritage recipes", file=sys.stderr)

def main():
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent

    # Load schedules
    schedules_path = script_dir / "heritage_unlock_schedules.json"
    if not schedules_path.exists():
        print(f"Error: Schedules file not found at {schedules_path}", file=sys.stderr)
        print("Run generate_unlock_schedules.py first", file=sys.stderr)
        sys.exit(1)

    print("Loading schedules...", file=sys.stderr)
    with open(schedules_path, 'r') as f:
        schedules_data = json.load(f)
    schedules = schedules_data["schedules"]
    print(f"  Loaded {len(schedules)} schedules", file=sys.stderr)

    # Load recipes
    recipes_path = repo_root / "Heirloom" / "Resources" / "HeritageCollections" / "heritage-recipes.json"
    if not recipes_path.exists():
        print(f"Error: Recipes file not found at {recipes_path}", file=sys.stderr)
        sys.exit(1)

    print("Loading recipes...", file=sys.stderr)
    with open(recipes_path, 'r') as f:
        recipes_data = json.load(f)
    recipes = recipes_data["recipes"]
    print(f"  Loaded {len(recipes)} recipes", file=sys.stderr)

    # Initialize Firebase
    print("\n🔥 Initializing Firebase...", file=sys.stderr)
    db = init_firebase()
    print("  ✓ Connected to Firestore", file=sys.stderr)

    # Confirm before uploading
    print(f"\n⚠️  About to upload:", file=sys.stderr)
    print(f"   - {len(schedules)} unlock schedules", file=sys.stderr)
    print(f"   - {len(recipes)} heritage recipes", file=sys.stderr)
    print(f"\n   This will OVERWRITE existing data!", file=sys.stderr)

    response = input("\nProceed? (yes/no): ")
    if response.lower() != "yes":
        print("Aborted.", file=sys.stderr)
        sys.exit(0)

    # Upload
    upload_schedules(db, schedules)
    upload_recipes(db, recipes)

    print("\n✅ Upload complete!", file=sys.stderr)
    print("\nNext steps:", file=sys.stderr)
    print("  1. Update Firestore security rules", file=sys.stderr)
    print("  2. Update iOS app to use on-demand downloads", file=sys.stderr)
    print("  3. Test with a new user account", file=sys.stderr)

if __name__ == "__main__":
    main()
