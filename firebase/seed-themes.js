#!/usr/bin/env node

/**
 * Theme Seeding Script
 * Seeds 10 theme documents to Firestore
 *
 * Usage: node seed-themes.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
// Expects serviceAccountKey.json in the same directory
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Theme data
const themes = [
  {
    id: 'automat-classics',
    name: 'Automat Classics',
    tagline: 'Recipes from restaurants that no longer exist',
    description: "Horn & Hardart's legendary cafeteria served NYC and Philadelphia from 1902-1991. Their mac and cheese, baked beans, and rice pudding became comfort food icons. These recipes have been adapted from original sources and family archives.",
    iconName: 'building.columns',
    category: 'source',
    source: 'Horn & Hardart Archives',
    era: '1902-1991',
    region: 'New York / Philadelphia',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 1,
    coverImagePrompt: 'Warm art deco cafeteria interior with chrome coffee dispensers and glass pie cases, soft lighting, 1950s nostalgia, watercolor illustration style'
  },
  {
    id: 'railroad-dining',
    name: 'Golden Age of Rail',
    tagline: 'Dining car recipes from the great American railroads',
    description: 'From the Harvey House restaurants along the Santa Fe to the elegant Pullman dining cars, these recipes defined travel luxury in the early 20th century.',
    iconName: 'tram.fill',
    category: 'source',
    source: 'Harvey House, Pullman Company Archives',
    era: '1876-1968',
    region: 'Transcontinental USA',
    totalRecipes: 12,
    unlockSchedule: [1, 3, 5, 7, 9, 11, 14],
    sortOrder: 2,
    coverImagePrompt: 'Elegant vintage train dining car with white tablecloths and art deco details, golden hour light through windows, watercolor illustration'
  },
  {
    id: 'victory-kitchen',
    name: 'Victory Kitchen',
    tagline: 'Ingenious recipes from the WWII rationing era',
    description: 'When sugar, butter, and meat were rationed, American home cooks got creative. These recipes show remarkable ingenuity in the face of scarcity.',
    iconName: 'leaf.fill',
    category: 'era',
    source: 'WWII Ration Cookbooks, Betty Crocker Archives',
    era: '1941-1945',
    region: 'United States',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 3,
    coverImagePrompt: '1940s kitchen with victory garden vegetables and ration books, warm homey atmosphere, vintage advertisement style'
  },
  {
    id: 'navy-mess',
    name: 'Navy Mess Hall',
    tagline: 'Hearty recipes from the US Navy Cookbook',
    description: 'The 1944 US Navy Cookbook was designed to feed thousands of sailors. These scaled-down versions bring mess hall favorites to your home kitchen.',
    iconName: 'anchor',
    category: 'source',
    source: 'US Navy Cook Book, 1944',
    era: '1940s',
    region: 'United States',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 4,
    coverImagePrompt: 'Navy ship galley with gleaming steel surfaces and hearty meal preparations, nautical color palette, vintage poster style'
  },
  {
    id: 'boston-cooking-school',
    name: 'Boston Cooking School',
    tagline: "Fannie Farmer's revolutionary recipes",
    description: "Fannie Farmer's 1896 cookbook introduced standardized measurements to American cooking. These recipes launched a culinary revolution.",
    iconName: 'book.closed.fill',
    category: 'era',
    source: 'Boston Cooking-School Cook Book, 1896',
    era: '1896',
    region: 'New England',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 5,
    coverImagePrompt: 'Victorian-era kitchen classroom with measuring cups and vintage cookbook, soft sepia tones, historical illustration style'
  },
  {
    id: 'southern-roots',
    name: 'Southern Roots',
    tagline: 'African American culinary pioneers',
    description: "From Abby Fisher's groundbreaking 1881 cookbook to Edna Lewis's celebration of Virginia cooking, these recipes honor the pioneers of Southern cuisine.",
    iconName: 'sun.max.fill',
    category: 'cuisine',
    source: 'Abby Fisher, Malinda Russell, Rufus Estes',
    era: '1866-1911',
    region: 'American South',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 6,
    coverImagePrompt: 'Southern farmhouse kitchen with fresh vegetables and cast iron cookware, warm golden light, folk art illustration style'
  },
  {
    id: 'scandinavian-heritage',
    name: 'Scandinavian Heritage',
    tagline: 'Nordic traditions from the Midwest',
    description: 'Scandinavian immigrants brought their culinary traditions to the American Midwest. These recipes preserve the flavors of the old country.',
    iconName: 'snowflake',
    category: 'cuisine',
    source: 'South Dakota State University Archives',
    era: '1880s-1940s',
    region: 'Upper Midwest / Scandinavia',
    totalRecipes: 12,
    unlockSchedule: [1, 3, 5, 7, 9, 11, 14],
    sortOrder: 7,
    coverImagePrompt: 'Cozy Nordic kitchen with traditional baked goods and winter landscape through window, cool color palette, Scandinavian design aesthetic'
  },
  {
    id: 'german-american',
    name: 'German-American Kitchen',
    tagline: 'Pennsylvania Dutch and German immigrant recipes',
    description: 'German immigrants shaped American cuisine in profound ways. From pretzels to pot pie, these recipes celebrate that delicious heritage.',
    iconName: 'house.fill',
    category: 'cuisine',
    source: 'Pennsylvania Dutch Archives, MSU Feeding America',
    era: '1850s-1920s',
    region: 'Pennsylvania / Midwest',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 8,
    coverImagePrompt: 'Pennsylvania Dutch farmhouse kitchen with traditional hearth and baked goods, warm rustic atmosphere, folk art style'
  },
  {
    id: 'quick-weeknight',
    name: 'Quick Weeknight Classics',
    tagline: 'Delicious meals in 30 minutes or less',
    description: 'Busy schedules demand efficient cooking. These recipes deliver big flavor in minimal time, perfect for weeknight dinners.',
    iconName: 'clock.fill',
    category: 'difficulty',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 9,
    coverImagePrompt: 'Modern efficient kitchen with fresh ingredients and quick prep setup, bright clean aesthetic, contemporary illustration'
  },
  {
    id: 'sunday-suppers',
    name: 'Sunday Suppers',
    tagline: 'Slow-cooked comfort for leisurely weekends',
    description: 'Some recipes are worth the wait. These Sunday suppers reward patience with deep, complex flavors that bring families together.',
    iconName: 'sun.horizon.fill',
    category: 'difficulty',
    totalRecipes: 12,
    unlockSchedule: [1, 3, 5, 7, 9, 11, 14],
    sortOrder: 10,
    coverImagePrompt: 'Cozy Sunday dinner table with slow-cooked roast and family gathering, warm inviting light, Norman Rockwell style'
  },
  {
    id: 'presidential-pantry',
    name: 'Presidential Pantry',
    tagline: 'Recipes from the White House kitchens',
    description: "From Martha Washington's Great Cake to Reagan's Cobb Salad, these recipes reveal what America's presidents ate at home and served to dignitaries.",
    iconName: 'building.columns.fill',
    category: 'historical',
    source: 'White House Archives, Presidential Libraries',
    era: '1789-1989',
    region: 'Washington, D.C.',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 11,
    coverImagePrompt: 'Elegant White House state dining room with presidential china and formal place settings, patriotic color accents, historical illustration style'
  },
  {
    id: 'literary-kitchen',
    name: 'Literary Kitchen',
    tagline: 'Dishes inspired by classic literature',
    description: "From Moby-Dick's chowder to Proust's madeleines, these recipes bring beloved books to life through food mentioned in their pages.",
    iconName: 'book.closed.fill',
    category: 'historical',
    source: 'Classic Literature, Historical Cookbooks',
    era: '1800s-1960s',
    region: 'Global',
    totalRecipes: 14,
    unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14],
    sortOrder: 12,
    coverImagePrompt: 'Cozy library reading nook with vintage cookbooks and literary-inspired dishes, warm candlelight, storybook illustration style'
  },
  {
    id: 'ancient-table',
    name: 'Ancient Table',
    tagline: 'Culinary treasures from ancient civilizations',
    description: 'Roman garum, Greek olive cakes, Egyptian flatbread - these recipes connect us to the dinner tables of Rome, Athens, and the ancient world.',
    iconName: 'building.columns',
    category: 'historical',
    source: 'Apicius, Archaeological Sources, Historical Records',
    era: '3000 BCE - 500 CE',
    region: 'Mediterranean / Ancient World',
    totalRecipes: 12,
    unlockSchedule: [1, 3, 5, 7, 9, 11, 14],
    sortOrder: 13,
    coverImagePrompt: 'Ancient Roman or Greek dining room with amphoras and olive branches, classical architecture, archaeological illustration style'
  },
  {
    id: 'american-foundation',
    name: 'American Foundation',
    tagline: 'Colonial and early American recipes',
    description: 'Johnnycakes, succotash, and election cake - these foundational recipes shaped American cuisine from colonial times through the early republic.',
    iconName: 'flag.fill',
    category: 'historical',
    source: 'Colonial Cookbooks, Shaker Communities, Early American Archives',
    era: '1620-1850',
    region: 'Colonial America / New England',
    totalRecipes: 12,
    unlockSchedule: [1, 3, 5, 7, 9, 11, 14],
    sortOrder: 14,
    coverImagePrompt: 'Colonial American hearth kitchen with copper pots and wooden utensils, candlelit warmth, Americana folk art style'
  }
];

async function seedThemes() {
  console.log('🔥 Starting theme seeding...\n');

  const batch = db.batch();
  let successCount = 0;
  let errorCount = 0;

  for (const theme of themes) {
    try {
      const themeRef = db.collection('themes').doc(theme.id);

      batch.set(themeRef, {
        ...theme,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`✓ Queued: ${theme.name} (${theme.id})`);
      successCount++;
    } catch (error) {
      console.error(`✗ Error queuing ${theme.name}:`, error.message);
      errorCount++;
    }
  }

  try {
    await batch.commit();
    console.log(`\n✅ Successfully seeded ${successCount} themes to Firestore!`);

    if (errorCount > 0) {
      console.log(`⚠️  ${errorCount} theme(s) failed to seed`);
    }

    console.log('\n📊 Theme Summary:');
    console.log(`   - Total themes: ${themes.length}`);
    console.log(`   - Successfully seeded: ${successCount}`);
    console.log(`   - Failed: ${errorCount}`);
    console.log('\n🎯 Next Steps:');
    console.log('   1. Verify themes in Firebase Console');
    console.log('   2. Run recipe seeding script');
    console.log('   3. Generate and upload cover images');

  } catch (error) {
    console.error('\n❌ Batch commit failed:', error);
    process.exit(1);
  }

  process.exit(0);
}

// Run the seeding script
seedThemes().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
