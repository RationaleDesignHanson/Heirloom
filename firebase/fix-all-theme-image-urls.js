#!/usr/bin/env node

/**
 * Fix ALL theme recipe image URLs to match actual Storage filenames
 * Maps recipe titles to actual image filenames
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const bucket = admin.storage().bucket('heirloom-ios-prod.firebasestorage.app');

// Manual overrides for recipes that don't match automatically
const MANUAL_OVERRIDES = {
  'automat-classics': {
    'Horn & Hardart Macaroni and Cheese': 'automat-classics-automat-mac-cheese.webp',
    'Automat Meatloaf with Gravy': 'automat-classics-automat-meatloaf.webp'
  },
  'boston-cooking-school': {
    'New England Fish Chowder': 'boston-cooking-school-fannie-farmer-fish-chowder.webp',
    'New England Clam Fritters': 'boston-cooking-school-fannie-farmer-clam-fritters.webp'
  },
  'railroad-dining': {
    'Harvey House Corned Beef Hash': 'railroad-dining-harvey-house-hash.webp',
    'Harvey House Tossed Green Salad': 'railroad-dining-harvey-house-salad.webp',
    'Harvey House Chili con Carne': 'railroad-dining-harvey-house-chili.webp',
    'Great Northern Railway Pot Roast': 'railroad-dining-railroad-pot-roast.webp',
    'Pennsylvania Railroad Salmon Croquettes': 'railroad-dining-dining-car-salmon-croquettes.webp',
    'Southern Pacific Bread Pudding': 'railroad-dining-railroad-bread-pudding.webp'
  },
  'scandinavian-heritage': {
    'Danish Roast Pork with Crackling (Flæskesteg)': 'scandinavian-heritage-danish-roast-pork.webp'
  }
};

// Helper to normalize strings for matching
function normalize(str) {
  return str.toLowerCase()
    .replace(/['\-&]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

// Remove common prefixes from recipe titles
function removePrefix(title) {
  const prefixes = [
    'horn & hardart ',
    'harvey house ',
    'dining car ',
    'pullman ',
    'railroad ',
    'automat ',
    'fannie farmer ',
    'boston ',
    'old-fashioned ',
    'old fashioned '
  ];

  let cleaned = title.toLowerCase();
  for (const prefix of prefixes) {
    if (cleaned.startsWith(prefix)) {
      cleaned = cleaned.substring(prefix.length);
    }
  }
  return cleaned;
}

// Extract recipe name from filename (remove prefix and extension)
function extractRecipeNameFromFilename(filename, themePrefix) {
  // Remove theme prefix and extension
  let name = filename
    .replace(themePrefix + '-', '')
    .replace('.webp', '')
    .replace(/-/g, ' ');
  return normalize(name);
}

// Check if recipe title matches filename with fuzzy matching
function scoreMatch(title, filename) {
  const normalizedTitle = normalize(removePrefix(title));
  const normalizedFilename = filename;

  // Exact match = perfect score
  if (normalizedTitle === normalizedFilename) return 100;

  // Check if filename contains all significant words from title
  const titleWords = normalizedTitle.split(' ').filter(w => w.length > 2);
  const filenameWords = normalizedFilename.split(' ');

  let matchedWords = 0;
  for (const titleWord of titleWords) {
    // Direct match
    if (filenameWords.some(fw => fw === titleWord)) {
      matchedWords++;
      continue;
    }
    // Partial match (substring)
    if (filenameWords.some(fw => fw.includes(titleWord) || titleWord.includes(fw))) {
      matchedWords += 0.5;
    }
  }

  return titleWords.length > 0 ? (matchedWords / titleWords.length) * 100 : 0;
}

async function fixThemeImages(themeId) {
  console.log(`\n📚 Processing theme: ${themeId}`);

  try {
    // Get all image files for this theme from Storage
    const [files] = await bucket.getFiles({ prefix: `recipes/${themeId}/` });
    const imageFiles = files.map(f => f.name.split('/').pop());

    if (imageFiles.length === 0) {
      console.log(`  ⚠️  No images found in Storage`);
      return 0;
    }

    console.log(`  Found ${imageFiles.length} images in Storage`);

    // Get all recipes for this theme
    const recipesSnapshot = await db
      .collection('themes')
      .doc(themeId)
      .collection('recipes')
      .get();

    if (recipesSnapshot.empty) {
      console.log(`  ⚠️  No recipes found in Firestore`);
      return 0;
    }

    console.log(`  Found ${recipesSnapshot.docs.length} recipes in Firestore`);

    const batch = db.batch();
    let fixedCount = 0;
    let notFoundCount = 0;

    // For each recipe, find matching image file
    for (const doc of recipesSnapshot.docs) {
      const recipe = doc.data();

      // Check manual overrides first
      let matchedFile = null;
      if (MANUAL_OVERRIDES[themeId] && MANUAL_OVERRIDES[themeId][recipe.title]) {
        matchedFile = MANUAL_OVERRIDES[themeId][recipe.title];
        console.log(`    ✓ ${recipe.title} → ${matchedFile} (manual override)`);
      } else {
        // Score all files and pick best match
        let bestMatch = null;
        let bestScore = 0;

        for (const filename of imageFiles) {
          const normalizedFilename = extractRecipeNameFromFilename(filename, themeId);
          const score = scoreMatch(recipe.title, normalizedFilename);

          if (score > bestScore) {
            bestScore = score;
            bestMatch = filename;
          }
        }

        // Only use match if score is good enough (>= 60%)
        matchedFile = bestScore >= 60 ? bestMatch : null;
      }

      if (matchedFile) {
        const newURL = `https://firebasestorage.googleapis.com/v0/b/heirloom-ios-prod.firebasestorage.app/o/recipes%2F${themeId}%2F${matchedFile}?alt=media`;
        batch.update(doc.ref, { imageURL: newURL });
        fixedCount++;
        console.log(`    ✓ ${recipe.title} → ${matchedFile}`);
      } else {
        notFoundCount++;
        console.log(`    ✗ ${recipe.title} - NO MATCH FOUND`);
        console.log(`       Available files:`, imageFiles.slice(0, 3).join(', '), '...');
      }
    }

    if (fixedCount > 0) {
      await batch.commit();
      console.log(`  ✅ Fixed ${fixedCount} URLs`);
    }

    if (notFoundCount > 0) {
      console.log(`  ⚠️  ${notFoundCount} recipes had no matching image`);
    }

    return fixedCount;

  } catch (error) {
    console.error(`  ❌ Error processing ${themeId}:`, error.message);
    return 0;
  }
}

async function fixAllThemes() {
  console.log('🔧 Fixing image URLs for all themes...');

  try {
    // Get all themes
    const themesSnapshot = await db.collection('themes').get();
    const themes = themesSnapshot.docs.map(doc => doc.id);

    console.log(`\nFound ${themes.length} themes to process\n`);

    let totalFixed = 0;

    for (const themeId of themes) {
      const fixed = await fixThemeImages(themeId);
      totalFixed += fixed;
    }

    console.log(`\n✅ Fixed ${totalFixed} total image URLs across all themes`);

  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

fixAllThemes();
