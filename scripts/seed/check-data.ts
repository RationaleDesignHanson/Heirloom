import { initializeFirebase, getDb } from './src/utils/firebase';

async function checkData() {
  initializeFirebase();
  const db = getDb();
  const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

  // Check collections
  console.log('COLLECTIONS');
  console.log('============================================================');
  const collectionsRef = db.collection('users').doc(userId).collection('collections');
  const collections = await collectionsRef.get();

  if (collections.empty) {
    console.log('No collections found.');
  } else {
    for (const doc of collections.docs) {
      const data = doc.data();
      const recipeIds = data.recipeIds || [];
      const hasModified = data.modifiedAt ? 'YES' : 'NO';
      console.log(`${data.name}: ${recipeIds.length} recipes, modifiedAt: ${hasModified}`);
    }
  }

  // Check recipes
  console.log('');
  console.log('RECIPES');
  console.log('============================================================');
  const recipesRef = db.collection('users').doc(userId).collection('recipes');
  const recipes = await recipesRef.get();
  console.log(`Total recipes: ${recipes.size}`);

  if (!recipes.empty) {
    let withModifiedAt = 0;
    let withoutModifiedAt = 0;
    for (const doc of recipes.docs) {
      if (doc.data().modifiedAt) {
        withModifiedAt++;
      } else {
        withoutModifiedAt++;
      }
    }
    console.log(`  With modifiedAt: ${withModifiedAt}`);
    console.log(`  Without modifiedAt: ${withoutModifiedAt}`);

    console.log('');
    console.log('Sample recipes:');
    const sample = recipes.docs.slice(0, 5);
    for (const doc of sample) {
      console.log(`  - ${doc.data().title}`);
    }
  }

  // Check pending shares
  console.log('');
  console.log('PENDING SHARES');
  console.log('============================================================');
  const sharesRef = db.collection('shares').where('recipientUserIds', 'array-contains', userId);
  const shares = await sharesRef.get();

  if (shares.empty) {
    console.log('No pending shares found.');
  } else {
    for (const doc of shares.docs) {
      const data = doc.data();
      console.log(`Share from: ${data.ownerName}`);
      console.log(`  Recipe: ${data.recipeTitle}`);
      console.log(`  Is Demo: ${data.isDemoShare || false}`);
      console.log(`  Is Welcome: ${data.isWelcomeShare || false}`);
      console.log('');
    }
  }
}

checkData().catch(console.error);
