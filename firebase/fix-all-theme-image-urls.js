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
  // === FULLY WORKING THEMES (minor fixes) ===
  'automat-classics': {
    'Horn & Hardart Macaroni and Cheese': 'automat-classics-automat-mac-cheese.webp',
    'Automat Meatloaf with Gravy': 'automat-classics-automat-meatloaf.webp'
  },
  'boston-cooking-school': {
    'New England Fish Chowder': 'boston-cooking-school-fannie-farmer-fish-chowder.webp',
    'New England Clam Fritters': 'boston-cooking-school-fannie-farmer-clam-fritters.webp'
  },
  'german-american': {
    'Sauerbraten (German Pot Roast)': 'german-american-sauerbraten.webp',
    'Wiener Schnitzel': 'german-american-schnitzel.webp',
    'Spätzle (German Egg Noodles)': 'german-american-spaetzle.webp',
    'Lebkuchen (German Spice Cookies)': 'german-american-lebkuchen.webp',
    'Christmas Stollen': 'german-american-stollen.webp',
    'Kartoffelpuffer (German Potato Pancakes)': 'german-american-kartoffelpuffer.webp',
    'Rotkohl (German Red Cabbage)': 'german-american-german-red-cabbage.webp',
    'Rouladen (Beef Rolls)': 'german-american-rouladen.webp',
    'Beer-Braised Bratwurst': 'german-american-bratwurst.webp',
    'Jägerschnitzel (Hunter\'s Schnitzel)': 'german-american-german-pork-schnitzel.webp'
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
  },

  // === PARTIALLY WORKING THEMES ===
  'navy-mess': {
    'Navy Goulash (American Chop Suey)': 'navy-mess-navy-goulash.webp',
    'Mess Hall Rice Pudding': 'navy-mess-navy-rice-pudding.webp',
    'Mess Hall Coleslaw': 'navy-mess-navy-coleslaw.webp',
    'Navy S.O.S. (Creamed Chipped Beef)': 'navy-mess-navy-sos.webp'
  },
  'quick-weeknight': {
    'Shake-and-Bake Style Pork Chops': 'quick-weeknight-baked-pork-chops.webp',
    'Quick Chicken Stir-Fry': 'quick-weeknight-chicken-stir-fry.webp',
    'Homemade Beef Stroganoff Skillet': 'quick-weeknight-hamburger-helper-style.webp',
    'Stovetop Mac and Cheese': 'quick-weeknight-skillet-mac-cheese.webp'
  },
  'victory-kitchen': {
    'Scalloped Potatoes': 'victory-kitchen-potato-scallop.webp',
    'Honey-Oatmeal Drop Cookies': 'victory-kitchen-honey-oatmeal-cookies.webp'
  },
  'southern-roots': {
    'Mrs. Russell\'s Tennessee Catfish Stew': 'southern-roots-malinda-russell-catfish-stew.webp',
    'New Orleans Red Beans and Rice': 'southern-roots-red-beans-rice.webp'
  },
  'sunday-suppers': {
    'Brown Sugar Glazed Ham': 'sunday-suppers-baked-ham.webp',
    'Herb-Crusted Pork Loin Roast': 'sunday-suppers-pork-roast-sunday.webp',
    'Homemade Dinner Rolls': 'sunday-suppers-parker-house-rolls-sunday.webp',
    'Classic Chocolate Layer Cake': 'sunday-suppers-chocolate-cake-sunday.webp'
  },

  // === NOT WORKING THEMES (numbered images mapped to recipe order) ===
  'american-foundation': {
    'Colonial Brown Bread': 'american-foundation-american-001.webp',
    'Shaker Lemon Pie': 'american-foundation-american-002.webp',
    'Johnnycakes': 'american-foundation-american-003.webp',
    'Succotash': 'american-foundation-american-004.webp',
    'Pumpkin Butter': 'american-foundation-american-005.webp',
    'Apple Pandowdy': 'american-foundation-american-006.webp',
    'Hasty Pudding': 'american-foundation-american-007.webp',
    'Election Cake': 'american-foundation-american-008.webp',
    'Switchel': 'american-foundation-american-009.webp',
    'Syllabub': 'american-foundation-american-010.webp',
    'Mincemeat': 'american-foundation-american-011.webp',
    'Corn Dodgers': 'american-foundation-american-012.webp',
    // New images to be generated
    'Samp and Beans': 'american-foundation-american-013.webp',
    'Rye and Injun Bread': 'american-foundation-american-014.webp',
    'Pone': 'american-foundation-american-015.webp',
    'Flummery': 'american-foundation-american-016.webp',
    'Persimmon Pudding': 'american-foundation-american-017.webp',
    'Hominy Grits': 'american-foundation-american-018.webp',
    'Shrub': 'american-foundation-american-019.webp',
    'Indian Pudding (Baked)': 'american-foundation-american-020.webp',
    'Corn Oysters': 'american-foundation-american-021.webp',
    'Anadama Bread': 'american-foundation-american-022.webp',
    'Sally Lunn Bread': 'american-foundation-american-023.webp',
    'Ash Cakes': 'american-foundation-american-024.webp',
    'Spider Corn Cake': 'american-foundation-american-025.webp'
  },
  'ancient-table': {
    'Apicius\' Conditum Paradoxum': 'ancient-table-ancient-001.webp',
    'Roman Patina de Piris': 'ancient-table-ancient-002.webp',
    'Greek Olive & Honey Cakes': 'ancient-table-ancient-003.webp',
    'Roman Garum Sauce': 'ancient-table-ancient-004.webp',
    'Egyptian Flatbread': 'ancient-table-ancient-005.webp',
    'Mesopotamian Beer Bread': 'ancient-table-ancient-006.webp',
    'Greek Lentil Soup': 'ancient-table-ancient-007.webp',
    'Roman Moretum': 'ancient-table-ancient-008.webp',
    'Persian Rice Pilaf': 'ancient-table-ancient-009.webp',
    'Byzantine Honey Fritters': 'ancient-table-ancient-010.webp',
    'Greek Barley Cakes': 'ancient-table-ancient-011.webp',
    'Roman Stuffed Dormice': 'ancient-table-ancient-012.webp',
    // New images to be generated
    'Phoenician Fish Stew': 'ancient-table-ancient-013.webp',
    'Carthaginian Couscous': 'ancient-table-ancient-014.webp',
    'Etruscan Polenta': 'ancient-table-ancient-015.webp',
    'Sumerian Date Cake': 'ancient-table-ancient-016.webp',
    'Chinese Jiaozi Dumplings': 'ancient-table-ancient-017.webp',
    'Viking Smoked Fish': 'ancient-table-ancient-018.webp',
    'Celtic Oat Porridge': 'ancient-table-ancient-019.webp',
    'Aztec Chocolate Drink': 'ancient-table-ancient-020.webp',
    'Inca Quinoa Soup': 'ancient-table-ancient-021.webp',
    'Medieval Pottage': 'ancient-table-ancient-022.webp',
    'Roman Puls': 'ancient-table-ancient-023.webp',
    'Greek Symposium Wine': 'ancient-table-ancient-024.webp',
    'Babylonian Beer': 'ancient-table-ancient-025.webp'
  },
  'literary-kitchen': {
    'Mrs. Beeton\'s Beefsteak and Kidney Pudding': 'literary-kitchen-literary-001.webp',
    'Moby-Dick\'s Chowder': 'literary-kitchen-literary-002.webp',
    'Great Gatsby\'s Champagne Cocktails': 'literary-kitchen-literary-003.webp',
    'Alice\'s Tea Cakes': 'literary-kitchen-literary-004.webp',
    'Little Women\'s Apple Slump': 'literary-kitchen-literary-005.webp',
    'Pride & Prejudice White Soup': 'literary-kitchen-literary-006.webp',
    'A Christmas Carol Roast Goose': 'literary-kitchen-literary-007.webp',
    'Hemingway\'s Death in the Afternoon': 'literary-kitchen-literary-008.webp',
    'To Kill a Mockingbird\'s Lane Cake': 'literary-kitchen-literary-009.webp',
    'Laura Ingalls\' Vanity Cakes': 'literary-kitchen-literary-010.webp',
    'Sherlock Holmes\' Seed Cake': 'literary-kitchen-literary-011.webp',
    'Anne of Green Gables\' Raspberry Cordial': 'literary-kitchen-literary-012.webp',
    'Wuthering Heights Oatcakes': 'literary-kitchen-literary-013.webp',
    'Winnie the Pooh\'s Honey Buns': 'literary-kitchen-literary-014.webp',
    // New images to be generated
    'Oliver Twist\'s Gruel': 'literary-kitchen-literary-015.webp',
    'The Hobbit\'s Seed-cakes': 'literary-kitchen-literary-016.webp',
    'Proust\'s Madeleines': 'literary-kitchen-literary-017.webp',
    'James Bond\'s Vesper Martini': 'literary-kitchen-literary-018.webp',
    'The Bell Jar\'s Avocado Pear': 'literary-kitchen-literary-019.webp',
    'Don Quixote\'s Olla Podrida': 'literary-kitchen-literary-020.webp',
    'The Old Man and the Sea\'s Fried Dolphinfish': 'literary-kitchen-literary-021.webp',
    'Emma\'s Wedding Cake': 'literary-kitchen-literary-022.webp',
    'The Grapes of Wrath\'s Biscuits': 'literary-kitchen-literary-023.webp',
    'Babette\'s Feast Blinis': 'literary-kitchen-literary-024.webp',
    'Catch-22\'s Milo\'s Egyptian Cotton': 'literary-kitchen-literary-025.webp'
  },
  'presidential-pantry': {
    'Martha Washington\'s Great Cake': 'presidential-pantry-presidential-001.webp',
    'Thomas Jefferson\'s Ice Cream': 'presidential-pantry-presidential-002.webp',
    'Abraham Lincoln\'s Gingerbread': 'presidential-pantry-presidential-003.webp',
    'Eleanor Roosevelt\'s Scrambled Eggs': 'presidential-pantry-presidential-004.webp',
    'Dolley Madison\'s Oyster Soup': 'presidential-pantry-presidential-005.webp',
    'Jacqueline Kennedy\'s Chicken Casserole': 'presidential-pantry-presidential-006.webp',
    'FDR\'s Favorite Grilled Cheese': 'presidential-pantry-presidential-007.webp',
    'Harry Truman\'s Ozark Pudding': 'presidential-pantry-presidential-008.webp',
    'LBJ\'s Pedernales River Chili': 'presidential-pantry-presidential-009.webp',
    'George Washington\'s Hoecakes': 'presidential-pantry-presidential-010.webp',
    'John Adams\' Indian Pudding': 'presidential-pantry-presidential-011.webp',
    'Reagan\'s California Cobb Salad': 'presidential-pantry-presidential-012.webp',
    'Calvin Coolidge\'s Chicken Pie': 'presidential-pantry-presidential-013.webp',
    'James Monroe\'s Spoon Bread': 'presidential-pantry-presidential-014.webp',
    // New images to be generated
    'Herbert Hoover\'s Waldorf Salad': 'presidential-pantry-presidential-015.webp',
    'Ulysses S. Grant\'s Rice Pudding': 'presidential-pantry-presidential-016.webp',
    'William Howard Taft\'s Steak': 'presidential-pantry-presidential-017.webp',
    'Benjamin Harrison\'s Corn Relish': 'presidential-pantry-presidential-018.webp',
    'Rutherford B. Hayes\' Mashed Potatoes': 'presidential-pantry-presidential-019.webp',
    'James Buchanan\'s Sauerkraut': 'presidential-pantry-presidential-020.webp',
    'Grover Cleveland\'s Corned Beef Hash': 'presidential-pantry-presidential-021.webp',
    'Chester Arthur\'s Lobster Newburg': 'presidential-pantry-presidential-022.webp',
    'Millard Fillmore\'s Apple Dumplings': 'presidential-pantry-presidential-023.webp',
    'Franklin Pierce\'s Rum Punch': 'presidential-pantry-presidential-024.webp',
    'William McKinley\'s Gingerbread Cookies': 'presidential-pantry-presidential-025.webp'
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
