/**
 * Backfill script to sync all public recipes to Algolia
 * Run with: node backfill-public-recipes-algolia.js
 */

const admin = require('firebase-admin');
const algoliasearch = require('algoliasearch');

// Initialize Firebase Admin
const serviceAccount = require('../../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Initialize Algolia
const client = algoliasearch(
  'A1DITUD2QN',
  'e07b85696f6d023e0ac63434db054d16'
);
const publicRecipesIndex = client.initIndex('public_recipes');

async function backfillPublicRecipes() {
  console.log('Starting public recipes Algolia backfill...\n');

  // Configure index settings for optimal search
  await publicRecipesIndex.setSettings({
    searchableAttributes: [
      'title',
      'creatorName',
      'description',
      'tags',
      'ingredients',
      'category',
      '_searchText'
    ],
    attributesForFaceting: [
      'filterOnly(isDemoSeed)',
      'searchable(category)',
      'searchable(tags)',
      'searchable(creatorName)'
    ],
    customRanking: [
      'desc(trendingScore)',
      'desc(saveCount)',
      'desc(viewCount)',
      'desc(publishedAt)'
    ],
    // Typo tolerance for better matching
    typoTolerance: true,
    minWordSizefor1Typo: 3,
    minWordSizefor2Typos: 6,
    // Highlighting
    attributesToHighlight: ['title', 'description', 'creatorName'],
    highlightPreTag: '<em>',
    highlightPostTag: '</em>'
  });
  console.log('Index settings configured.\n');

  // Fetch all public recipes
  const snapshot = await db.collection('publicRecipes').get();

  if (snapshot.empty) {
    console.log('No public recipes found.');
    return;
  }

  console.log(`Found ${snapshot.size} public recipes to sync.\n`);

  const objects = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const recipeId = doc.id;

    // Skip hidden recipes
    if (data.isHidden === true) {
      console.log(`Skipping hidden recipe: ${recipeId}`);
      continue;
    }

    const algoliaObject = {
      objectID: recipeId,
      title: data.title || '',
      description: data.description || '',
      ingredients: data.ingredients || [],
      instructions: data.instructions || [],
      tags: data.tags || [],
      category: data.category || null,
      creatorName: data.creatorName || '',
      creatorId: data.ownerId || '',
      creatorPhotoURL: data.creatorPhotoURL || null,
      imageURL: data.imageURL || null,
      viewCount: data.viewCount || 0,
      saveCount: data.saveCount || 0,
      trendingScore: data.trendingScore || 0,
      servings: data.servings || null,
      prepTime: data.prepTime || null,
      cookTime: data.cookTime || null,
      totalTime: data.totalTime || null,
      _searchText: [
        data.title || '',
        data.description || '',
        data.creatorName || '',
        ...(data.ingredients || []),
        ...(data.tags || [])
      ].join(' ').toLowerCase(),
      publishedAt: data.publishedAt ? data.publishedAt.seconds : Date.now() / 1000,
      updatedAt: data.updatedAt ? data.updatedAt.seconds : Date.now() / 1000,
      isDemoSeed: data.isDemoSeed || false
    };

    objects.push(algoliaObject);
    console.log(`Prepared: ${data.title} by ${data.creatorName}`);
  }

  // Batch save to Algolia
  if (objects.length > 0) {
    console.log(`\nSaving ${objects.length} recipes to Algolia...`);
    await publicRecipesIndex.saveObjects(objects);
    console.log('Done!\n');
  }

  // Print summary
  console.log('=== Summary ===');
  console.log(`Total recipes synced: ${objects.length}`);
  console.log(`Index name: public_recipes`);
  console.log('\nYou can now search public recipes in Algolia!');
}

backfillPublicRecipes()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
