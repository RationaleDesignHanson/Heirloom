# Firebase Recipe Schema Validation

## Overview

This document validates that the JSON recipe files match the Firebase schema expected by the iOS app.

---

## Theme Document Schema

**Firebase Path:** `/themes/{themeId}`

### Required Fields:
```javascript
{
  name: string,           // "Automat Classics"
  tagline: string,        // "Recipes from restaurants..."
  description: string,    // Full description
  iconName: string,       // SF Symbol name
  category: string,       // "source", "era", "cuisine", "difficulty"
  totalRecipes: number,   // 14
  unlockSchedule: [int],  // [1, 2, 3, 5, 7, 9, 11, 14]
  sortOrder: number,      // 1
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Optional Fields:
```javascript
{
  coverImageURL: string,  // Cloud storage URL
  source: string,         // "Horn & Hardart Archives"
  era: string,            // "1902-1991"
  region: string          // "New York / Philadelphia"
}
```

---

## Recipe Document Schema

**Firebase Path:** `/themes/{themeId}/recipes/{recipeId}`

### Required Fields:
```javascript
{
  title: string,          // "Horn & Hardart Macaroni and Cheese"
  description: string,    // Recipe description
  prepTime: number,       // Minutes (15)
  cookTime: number,       // Minutes (40)
  servings: number,       // 8
  difficulty: string,     // "easy", "medium", "hard"
  unlockDay: number,      // 1-14
  sortOrder: number,      // 1
  tags: [string],         // ["comfort food", "classic"]
  source: string,         // "Horn & Hardart Archives"
  story: string,          // Historical context
  createdAt: timestamp,
  updatedAt: timestamp
}
```

---

## Ingredient Subcollection Schema

**Firebase Path:** `/themes/{themeId}/recipes/{recipeId}/ingredients/{autoId}`

### Fields:
```javascript
{
  text: string,           // "1 pound elbow macaroni"
  name: string,           // "elbow macaroni"
  amount: number | null,  // 1
  unit: string | null,    // "pound"
  group: string | null,   // "For the sauce"
  isOptional: boolean,    // false
  order: number           // 1
}
```

---

## Instruction Subcollection Schema

**Firebase Path:** `/themes/{themeId}/recipes/{recipeId}/instructions/{autoId}`

### Fields:
```javascript
{
  text: string,           // "Preheat oven to 375°F..."
  order: number           // 1
}
```

---

## JSON File to Firebase Mapping

### Your JSON Structure:
```json
{
  "themeId": "automat-classics",
  "themeName": "Automat Classics",
  "recipes": [
    {
      "id": "automat-mac-cheese",
      "title": "...",
      "description": "...",
      "ingredients": [
        {
          "name": "elbow macaroni",
          "amount": 1,
          "unit": "pound",
          "group": "For the sauce",      // Optional
          "notes": "warmed",              // Optional
          "preparation": "shredded",      // Optional
          "isOptional": true              // Optional
        }
      ],
      "instructions": [
        "Step 1 text",
        "Step 2 text"
      ],
      "prepTime": 15,
      "cookTime": 40,
      "servings": 8,
      "source": "...",
      "story": "...",
      "unlockDay": 1,
      "sortOrder": 1,
      "difficulty": "easy",
      "tags": ["comfort food", "classic"]
    }
  ]
}
```

### Seed Script Transformations:

1. **Ingredient Formatting:**
   ```javascript
   "1 pound elbow macaroni"               // Basic
   "1 pound elbow macaroni, shredded"     // With preparation
   "1 pound elbow macaroni (warmed)"      // With notes
   "1 cup butter (For the sauce)"         // With group
   ```

2. **Auto-generated Fields:**
   - `createdAt: serverTimestamp()`
   - `updatedAt: serverTimestamp()`
   - Ingredient `order`: 1, 2, 3...
   - Instruction `order`: 1, 2, 3...

---

## Validation Checklist

### ✅ Theme Files Present:
- [x] theme-01-automat-classics.json → automat-classics
- [x] theme-02-railroad-dining.json → railroad-dining
- [x] theme-03-victory-kitchen.json → victory-kitchen
- [x] theme-04-navy-mess.json → navy-mess
- [x] theme-05-boston-cooking.json → boston-cooking-school
- [x] theme-06-southern-roots.json → southern-roots
- [x] theme-07-scandinavian.json → scandinavian-heritage
- [x] theme-08-german-american.json → german-american
- [x] theme-09-quick-weeknight.json → quick-weeknight
- [x] theme-10-sunday-suppers.json → sunday-suppers

### ✅ Required Fields:
All JSON files have been verified to contain:
- [x] id (unique per recipe)
- [x] title
- [x] description
- [x] ingredients (array with name, optional amount/unit)
- [x] instructions (array of strings)
- [x] prepTime, cookTime, servings
- [x] source, story
- [x] unlockDay (1-14)
- [x] sortOrder (1+)
- [x] difficulty ("easy", "medium", "hard")
- [x] tags (array of strings)

### ✅ Data Types Match:
- [x] Numbers are numbers (not strings)
- [x] Arrays are arrays
- [x] Strings are strings
- [x] Booleans are booleans (for isOptional)

---

## Testing the Schema

### Dry Run (Validate Without Uploading):
```bash
cd /Users/matthanson/Heirloom/firebase
node seed-recipes.js --dry-run
```

This will:
1. Load all JSON files
2. Parse and validate structure
3. Show what would be uploaded
4. Report any errors
5. **NOT** upload to Firebase

### Upload Single Theme (Test):
```bash
node seed-recipes.js automat-classics
```

### Upload All Themes:
```bash
node seed-recipes.js
```

---

## Expected Results

After seeding, Firebase should contain:

```
/themes
  /automat-classics (14 recipes)
  /railroad-dining (12 recipes)
  /victory-kitchen (14 recipes)
  /navy-mess (14 recipes)
  /boston-cooking-school (14 recipes)
  /southern-roots (14 recipes)
  /scandinavian-heritage (12 recipes)
  /german-american (14 recipes)
  /quick-weeknight (14 recipes)
  /sunday-suppers (12 recipes)

Total: 136 recipes across 10 themes
```

Each recipe should have:
- Main document with metadata
- `/ingredients` subcollection (auto-generated IDs)
- `/instructions` subcollection (auto-generated IDs)

---

## Common Issues & Solutions

### Issue: Recipe not unlocking in app
**Cause:** `unlockDay` doesn't match theme's `unlockSchedule`
**Solution:** Ensure recipe `unlockDay` is in theme's `unlockSchedule` array

### Issue: Ingredients showing incorrectly
**Cause:** Missing `amount` or `unit` fields
**Solution:** Ingredients can have null amount/unit for items like "salt to taste"

### Issue: Recipe missing in Firebase Console
**Cause:** Recipe ID contains invalid characters
**Solution:** Use kebab-case IDs (e.g., "automat-mac-cheese")

---

## Schema Matches iOS App ✅

The seed script has been validated against:
- `ThemeLoader.swift` - Expects theme fields
- `FirebaseShareService.swift` - Expects ingredient/instruction subcollections
- `Recipe.swift` model - Matches all required/optional fields

**Status:** Schema is correct and ready for seeding.
