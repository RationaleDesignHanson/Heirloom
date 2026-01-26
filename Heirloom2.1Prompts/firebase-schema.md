# Heirloom Firebase Schema
## Recipe Themes and Curated Content

**Document Version:** 1.0
**Date:** January 26, 2026

---

## Overview

This document defines the Firebase Firestore schema for the theme-based recipe discovery system. It includes collection structures, document schemas, security rules, and seeding scripts.

---

## Firestore Collections

### Collection: `themes`

Top-level collection containing all available recipe themes.

**Path:** `/themes/{themeId}`

```typescript
interface Theme {
  // Identity
  id: string;                    // Auto-generated document ID
  
  // Display
  name: string;                  // "Automat Classics"
  tagline: string;               // "Recipes from restaurants that no longer exist"
  description: string;           // Full description for detail view
  iconName: string;              // SF Symbol name: "building.columns"
  coverImageURL?: string;        // AI-generated or curated image URL
  
  // Classification
  category: ThemeCategory;       // "source" | "era" | "cuisine" | "difficulty" | "dietary"
  source?: string;               // "Horn & Hardart Archives"
  era?: string;                  // "1902-1991"
  region?: string;               // "New York / Philadelphia"
  
  // Content metadata
  totalRecipes: number;          // 14
  unlockSchedule: number[];      // [1, 2, 3, 5, 7, 9, 11, 14]
  
  // Display order
  sortOrder: number;             // 0, 1, 2, ...
  
  // AI image generation
  coverImagePrompt?: string;     // Prompt used to generate cover image
  
  // Timestamps
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

type ThemeCategory = "source" | "era" | "cuisine" | "difficulty" | "dietary";
```

**Example Document:**

```json
{
  "name": "Automat Classics",
  "tagline": "Recipes from restaurants that no longer exist",
  "description": "Horn & Hardart's legendary cafeteria served NYC and Philadelphia from 1902-1991. Their mac and cheese, baked beans, and rice pudding became comfort food icons. These recipes have been adapted from original sources and family archives.",
  "iconName": "building.columns",
  "coverImageURL": "https://storage.googleapis.com/heirloom-assets/themes/automat-classics.jpg",
  "category": "source",
  "source": "Horn & Hardart Archives",
  "era": "1902-1991",
  "region": "New York / Philadelphia",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 1,
  "coverImagePrompt": "Warm art deco cafeteria interior with chrome coffee dispensers and glass pie cases, soft lighting, 1950s nostalgia, watercolor illustration style",
  "createdAt": "2026-01-15T00:00:00Z",
  "updatedAt": "2026-01-15T00:00:00Z"
}
```

---

### Subcollection: `themes/{themeId}/recipes`

Recipes belonging to a specific theme.

**Path:** `/themes/{themeId}/recipes/{recipeId}`

```typescript
interface ThemeRecipe {
  // Identity
  id: string;                    // Auto-generated document ID
  
  // Core recipe data
  title: string;                 // "Horn & Hardart Mac and Cheese"
  description?: string;          // Brief intro
  
  // Ingredients (structured)
  ingredients: Ingredient[];
  
  // Instructions (ordered steps)
  instructions: string[];
  
  // Timing
  prepTime?: number;             // Minutes
  cookTime?: number;             // Minutes
  totalTime?: number;            // Minutes (computed or explicit)
  
  // Servings
  servings?: number;
  servingsUnit?: string;         // "servings", "portions", "cookies"
  
  // Media
  imageURL?: string;
  videoURL?: string;
  
  // Attribution
  source: string;                // "Horn & Hardart Archives, 1952"
  sourceURL?: string;            // Link to original if available
  
  // Story/context
  story?: string;                // Historical context, why this recipe matters
  
  // Unlock timing
  unlockDay: number;             // 1-14
  sortOrder: number;             // Order within the day
  
  // Metadata
  difficulty?: "easy" | "medium" | "hard";
  tags?: string[];               // ["comfort food", "vegetarian", "quick"]
  
  // Nutrition (optional)
  nutrition?: NutritionInfo;
  
  // Timestamps
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

interface Ingredient {
  name: string;                  // "sharp cheddar cheese"
  amount?: number;               // 2
  unit?: string;                 // "cups"
  preparation?: string;          // "shredded"
  notes?: string;                // "or substitute gruyère"
  isOptional?: boolean;
  group?: string;                // "For the sauce", "For the topping"
}

interface NutritionInfo {
  calories?: number;
  protein?: number;              // grams
  carbohydrates?: number;        // grams
  fat?: number;                  // grams
  fiber?: number;                // grams
  sodium?: number;               // mg
}
```

**Example Document:**

```json
{
  "title": "Horn & Hardart Mac and Cheese",
  "description": "The legendary cafeteria's most requested recipe, finally revealed. Rich, creamy, and deeply comforting.",
  "ingredients": [
    {
      "name": "elbow macaroni",
      "amount": 1,
      "unit": "pound"
    },
    {
      "name": "butter",
      "amount": 4,
      "unit": "tablespoons",
      "group": "For the sauce"
    },
    {
      "name": "all-purpose flour",
      "amount": 0.25,
      "unit": "cup",
      "group": "For the sauce"
    },
    {
      "name": "whole milk",
      "amount": 4,
      "unit": "cups",
      "notes": "warmed",
      "group": "For the sauce"
    },
    {
      "name": "sharp cheddar cheese",
      "amount": 4,
      "unit": "cups",
      "preparation": "shredded",
      "group": "For the sauce"
    },
    {
      "name": "dry mustard",
      "amount": 1,
      "unit": "teaspoon",
      "group": "For the sauce"
    },
    {
      "name": "salt",
      "amount": 1,
      "unit": "teaspoon"
    },
    {
      "name": "white pepper",
      "amount": 0.5,
      "unit": "teaspoon"
    },
    {
      "name": "buttered breadcrumbs",
      "amount": 1,
      "unit": "cup",
      "group": "For the topping",
      "isOptional": true
    }
  ],
  "instructions": [
    "Preheat oven to 375°F (190°C). Butter a 9x13 inch baking dish.",
    "Cook macaroni according to package directions until just al dente. Drain and set aside.",
    "In a large saucepan, melt butter over medium heat. Whisk in flour and cook for 1 minute, stirring constantly.",
    "Gradually whisk in warm milk. Cook, stirring frequently, until sauce thickens and coats the back of a spoon, about 8-10 minutes.",
    "Remove from heat. Stir in cheese, mustard, salt, and pepper until cheese is completely melted and sauce is smooth.",
    "Fold in cooked macaroni until evenly coated.",
    "Transfer to prepared baking dish. Top with buttered breadcrumbs if using.",
    "Bake for 25-30 minutes until golden and bubbling. Let rest 5 minutes before serving."
  ],
  "prepTime": 15,
  "cookTime": 40,
  "servings": 8,
  "imageURL": "https://storage.googleapis.com/heirloom-assets/recipes/automat-mac-cheese.jpg",
  "source": "Horn & Hardart Archives, adapted from 1952 recipe card",
  "story": "Horn & Hardart's macaroni and cheese was served in thousands of portions daily at the peak of the Automat's popularity. The secret was in the sauce—made with sharp cheddar and a touch of dry mustard that gave it a distinctive tang. When the last Automat closed in 1991, this recipe was thought lost until Marianne Hardart, the founder's great-granddaughter, discovered it in family papers.",
  "unlockDay": 1,
  "sortOrder": 1,
  "difficulty": "easy",
  "tags": ["comfort food", "classic", "kid-friendly"],
  "nutrition": {
    "calories": 520,
    "protein": 22,
    "carbohydrates": 48,
    "fat": 26,
    "sodium": 680
  },
  "createdAt": "2026-01-15T00:00:00Z",
  "updatedAt": "2026-01-15T00:00:00Z"
}
```

---

## Initial Theme Data

### Theme 1: Automat Classics

```json
{
  "id": "automat-classics",
  "name": "Automat Classics",
  "tagline": "Recipes from restaurants that no longer exist",
  "description": "Horn & Hardart's legendary cafeteria served NYC and Philadelphia from 1902-1991. Their mac and cheese, baked beans, and rice pudding became comfort food icons.",
  "iconName": "building.columns",
  "category": "source",
  "source": "Horn & Hardart Archives",
  "era": "1902-1991",
  "region": "New York / Philadelphia",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 1
}
```

### Theme 2: Golden Age of Rail

```json
{
  "id": "railroad-dining",
  "name": "Golden Age of Rail",
  "tagline": "Dining car recipes from the great American railroads",
  "description": "From the Harvey House restaurants along the Santa Fe to the elegant Pullman dining cars, these recipes defined travel luxury in the early 20th century.",
  "iconName": "tram.fill",
  "category": "source",
  "source": "Harvey House, Pullman Company Archives",
  "era": "1876-1968",
  "region": "Transcontinental USA",
  "totalRecipes": 12,
  "unlockSchedule": [1, 3, 5, 7, 9, 11, 14],
  "sortOrder": 2
}
```

### Theme 3: Victory Kitchen

```json
{
  "id": "victory-kitchen",
  "name": "Victory Kitchen",
  "tagline": "Ingenious recipes from the WWII rationing era",
  "description": "When sugar, butter, and meat were rationed, American home cooks got creative. These recipes show remarkable ingenuity in the face of scarcity.",
  "iconName": "leaf.fill",
  "category": "era",
  "source": "WWII Ration Cookbooks, Betty Crocker Archives",
  "era": "1941-1945",
  "region": "United States",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 3
}
```

### Theme 4: Navy Mess Hall

```json
{
  "id": "navy-mess",
  "name": "Navy Mess Hall",
  "tagline": "Hearty recipes from the US Navy Cookbook",
  "description": "The 1944 US Navy Cookbook was designed to feed thousands of sailors. These scaled-down versions bring mess hall favorites to your home kitchen.",
  "iconName": "anchor",
  "category": "source",
  "source": "US Navy Cook Book, 1944",
  "era": "1940s",
  "region": "United States",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 4
}
```

### Theme 5: Boston Cooking School

```json
{
  "id": "boston-cooking-school",
  "name": "Boston Cooking School",
  "tagline": "Fannie Farmer's revolutionary recipes",
  "description": "Fannie Farmer's 1896 cookbook introduced standardized measurements to American cooking. These recipes launched a culinary revolution.",
  "iconName": "book.closed.fill",
  "category": "era",
  "source": "Boston Cooking-School Cook Book, 1896",
  "era": "1896",
  "region": "New England",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 5
}
```

### Theme 6: Southern Roots

```json
{
  "id": "southern-roots",
  "name": "Southern Roots",
  "tagline": "African American culinary pioneers",
  "description": "From Abby Fisher's groundbreaking 1881 cookbook to Edna Lewis's celebration of Virginia cooking, these recipes honor the pioneers of Southern cuisine.",
  "iconName": "sun.max.fill",
  "category": "cuisine",
  "source": "Abby Fisher, Malinda Russell, Rufus Estes",
  "era": "1866-1911",
  "region": "American South",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 6
}
```

### Theme 7: Scandinavian Heritage

```json
{
  "id": "scandinavian-heritage",
  "name": "Scandinavian Heritage",
  "tagline": "Nordic traditions from the Midwest",
  "description": "Scandinavian immigrants brought their culinary traditions to the American Midwest. These recipes preserve the flavors of the old country.",
  "iconName": "snowflake",
  "category": "cuisine",
  "source": "South Dakota State University Archives",
  "era": "1880s-1940s",
  "region": "Upper Midwest / Scandinavia",
  "totalRecipes": 12,
  "unlockSchedule": [1, 3, 5, 7, 9, 11, 14],
  "sortOrder": 7
}
```

### Theme 8: German-American Kitchen

```json
{
  "id": "german-american",
  "name": "German-American Kitchen",
  "tagline": "Pennsylvania Dutch and German immigrant recipes",
  "description": "German immigrants shaped American cuisine in profound ways. From pretzels to pot pie, these recipes celebrate that delicious heritage.",
  "iconName": "house.fill",
  "category": "cuisine",
  "source": "Pennsylvania Dutch Archives, MSU Feeding America",
  "era": "1850s-1920s",
  "region": "Pennsylvania / Midwest",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 8
}
```

### Theme 9: Quick Weeknight Classics

```json
{
  "id": "quick-weeknight",
  "name": "Quick Weeknight Classics",
  "tagline": "Delicious meals in 30 minutes or less",
  "description": "Busy schedules demand efficient cooking. These recipes deliver big flavor in minimal time, perfect for weeknight dinners.",
  "iconName": "clock.fill",
  "category": "difficulty",
  "totalRecipes": 14,
  "unlockSchedule": [1, 2, 3, 5, 7, 9, 11, 14],
  "sortOrder": 9
}
```

### Theme 10: Sunday Suppers

```json
{
  "id": "sunday-suppers",
  "name": "Sunday Suppers",
  "tagline": "Slow-cooked comfort for leisurely weekends",
  "description": "Some recipes are worth the wait. These Sunday suppers reward patience with deep, complex flavors that bring families together.",
  "iconName": "sun.horizon.fill",
  "category": "difficulty",
  "totalRecipes": 12,
  "unlockSchedule": [1, 3, 5, 7, 9, 11, 14],
  "sortOrder": 10
}
```

---

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Themes are read-only for all authenticated users
    match /themes/{themeId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only via Firebase Console or Cloud Functions
      
      // Recipes within themes
      match /recipes/{recipeId} {
        allow read: if request.auth != null;
        allow write: if false; // Admin only
      }
    }
    
    // User-specific data (if needed)
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Indexes

Create these composite indexes for efficient queries:

```javascript
// themes collection
{
  collectionGroup: "themes",
  fields: [
    { fieldPath: "category", order: "ASCENDING" },
    { fieldPath: "sortOrder", order: "ASCENDING" }
  ]
}

// recipes subcollection
{
  collectionGroup: "recipes",
  fields: [
    { fieldPath: "unlockDay", order: "ASCENDING" },
    { fieldPath: "sortOrder", order: "ASCENDING" }
  ]
}
```

---

## Seeding Script

**File:** `scripts/seed-themes.js`

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const themes = [
  // ... paste theme objects from above
];

async function seedThemes() {
  const batch = db.batch();
  
  for (const theme of themes) {
    const ref = db.collection('themes').doc(theme.id);
    batch.set(ref, {
      ...theme,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  
  await batch.commit();
  console.log(`Seeded ${themes.length} themes`);
}

seedThemes().catch(console.error);
```

---

## Storage Structure

For recipe images and theme covers:

```
gs://heirloom-assets/
├── themes/
│   ├── automat-classics.jpg
│   ├── railroad-dining.jpg
│   └── ...
└── recipes/
    ├── automat/
    │   ├── mac-cheese.jpg
    │   ├── baked-beans.jpg
    │   └── ...
    ├── railroad/
    │   └── ...
    └── ...
```

**Storage Rules:**

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /themes/{imageFile} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only
    }
    match /recipes/{themeId}/{imageFile} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only
    }
  }
}
```

---

## Migration Notes

If migrating from the existing heritage system:

1. Export existing heritage recipes
2. Map to new schema structure
3. Assign to appropriate themes
4. Update `unlockDay` based on current schedule
5. Run seeding script
6. Verify in Firebase Console

---

## Maintenance Tasks

### Adding New Recipes

1. Add recipe document to appropriate theme's `recipes` subcollection
2. Update theme's `totalRecipes` count
3. Adjust `unlockSchedule` if needed
4. Upload image to Storage

### Adding New Themes

1. Create theme document in `themes` collection
2. Add recipes to `recipes` subcollection
3. Upload cover image
4. Update app to fetch new themes

### Updating Recipes

1. Update document in Firestore
2. Increment `updatedAt` timestamp
3. Update image in Storage if changed
