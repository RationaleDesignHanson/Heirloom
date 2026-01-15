#!/usr/bin/env python3
"""
Generate 100 heritage unlock schedules for on-demand recipe delivery.

Each schedule defines which recipes unlock on which day during the 14-day trial.
- Day 1: 8 recipes (5 Literary Kitchen + 3 from random other collection)
- Days 2-14: 7 recipes per day
- Total: 8 + (13 × 7) = 99 recipes
"""

import json
import random
import sys
from pathlib import Path
from typing import List, Dict
from collections import defaultdict

# Seed for reproducibility
SEED_BASE = 42

def load_heritage_recipes(json_path: str) -> Dict[str, List[str]]:
    """Load recipes from JSON and group by collection."""
    with open(json_path, 'r') as f:
        data = json.load(f)

    collections = defaultdict(list)
    for recipe in data['recipes']:
        collection_id = recipe['heritageCollectionId']
        recipe_id = recipe['id']
        collections[collection_id].append(recipe_id)

    return dict(collections)

def generate_schedule(
    schedule_id: int,
    collections: Dict[str, List[str]],
    seed: int
) -> Dict:
    """Generate a single unlock schedule."""
    random.seed(seed)

    # Literary Kitchen is always revealed
    literary_id = "literary-kitchen"
    other_collections = [
        "presidential-pantry",
        "ancient-table",
        "american-foundation"
    ]

    # Randomly pick second collection
    other_id = random.choice(other_collections)
    revealed_collections = [literary_id, other_id]

    # Get shuffled recipe lists for revealed collections
    literary_recipes = collections[literary_id].copy()
    other_recipes = collections[other_id].copy()
    random.shuffle(literary_recipes)
    random.shuffle(other_recipes)

    # Day 1: 5 from Literary + 3 from other
    day_1_recipes = literary_recipes[:5] + other_recipes[:3]

    # Remove Day 1 recipes from pools
    literary_remaining = literary_recipes[5:]
    other_remaining = other_recipes[3:]

    # Days 2-14: 7 recipes each day, alternating between collections
    # We need 13 more days × 7 recipes = 91 recipes
    # We have 20 Literary + 22 Other = 42 recipes remaining
    # We need to include some unrevealed collection recipes to reach 91

    # Get remaining recipes from unrevealed collections
    unrevealed_ids = [c for c in collections.keys() if c not in revealed_collections]
    unrevealed_recipes = []
    for collection_id in unrevealed_ids:
        unrevealed_recipes.extend(collections[collection_id])
    random.shuffle(unrevealed_recipes)

    # Combine all remaining recipes
    all_remaining = literary_remaining + other_remaining + unrevealed_recipes
    random.shuffle(all_remaining)

    # Create daily batches
    unlock_plan = [
        {
            "day": 1,
            "recipes": day_1_recipes
        }
    ]

    # Days 2-14: 7 recipes each
    for day in range(2, 15):
        start_idx = (day - 2) * 7
        end_idx = start_idx + 7

        if start_idx < len(all_remaining):
            day_recipes = all_remaining[start_idx:end_idx]
            if day_recipes:  # Only add if we have recipes
                unlock_plan.append({
                    "day": day,
                    "recipes": day_recipes
                })

    return {
        "scheduleId": f"schedule-{schedule_id:03d}",
        "version": "1.0",
        "revealedCollections": revealed_collections,
        "unlockPlan": unlock_plan,
        "metadata": {
            "totalRecipes": sum(len(batch["recipes"]) for batch in unlock_plan),
            "literaryCount": len([r for r in day_1_recipes if r.startswith("literary")]),
            "otherInitialCollection": other_id,
            "generatedSeed": seed
        }
    }

def generate_all_schedules(
    collections: Dict[str, List[str]],
    num_schedules: int = 100
) -> List[Dict]:
    """Generate all unlock schedules."""
    schedules = []

    for i in range(1, num_schedules + 1):
        seed = SEED_BASE + i
        schedule = generate_schedule(i, collections, seed)
        schedules.append(schedule)

        # Log progress
        if i % 10 == 0:
            print(f"Generated {i}/{num_schedules} schedules...", file=sys.stderr)

    return schedules

def main():
    # Get path to heritage recipes JSON
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    json_path = repo_root / "Heirloom" / "Resources" / "HeritageCollections" / "heritage-recipes.json"

    if not json_path.exists():
        print(f"Error: Could not find {json_path}", file=sys.stderr)
        sys.exit(1)

    print("Loading heritage recipes...", file=sys.stderr)
    collections = load_heritage_recipes(str(json_path))

    print(f"Found {len(collections)} collections:", file=sys.stderr)
    for cid, recipes in collections.items():
        print(f"  - {cid}: {len(recipes)} recipes", file=sys.stderr)

    print("\nGenerating 100 unlock schedules...", file=sys.stderr)
    schedules = generate_all_schedules(collections)

    # Output schedules as JSON
    output = {
        "version": "1.0",
        "generatedAt": "2026-01-14",
        "totalSchedules": len(schedules),
        "schedules": schedules
    }

    # Write to file
    output_path = script_dir / "heritage_unlock_schedules.json"
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"\n✅ Generated {len(schedules)} schedules", file=sys.stderr)
    print(f"✅ Saved to {output_path}", file=sys.stderr)

    # Validation
    print("\nValidation:", file=sys.stderr)
    for i, schedule in enumerate(schedules[:5], 1):
        total = schedule["metadata"]["totalRecipes"]
        revealed = ", ".join(schedule["revealedCollections"])
        print(f"  Schedule {i}: {total} recipes, Collections: {revealed}", file=sys.stderr)

if __name__ == "__main__":
    main()
