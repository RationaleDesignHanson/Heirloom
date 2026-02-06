import { initializeFirebase, getDb } from './src/utils/firebase';

async function checkAllData() {
  initializeFirebase();
  const db = getDb();
  const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

  console.log('='.repeat(60));
  console.log('CHECKING ALL DATA');
  console.log('='.repeat(60));

  // 1. Check demo user recipes
  console.log('\n1. DEMO USER RECIPES');
  console.log('-'.repeat(40));
  const demoUsers = ['demo_phillipfry', 'demo_grillmaster', 'demo_grandmazing'];

  for (const demoUserId of demoUsers) {
    const recipesRef = db.collection('users').doc(demoUserId).collection('recipes');
    const snapshot = await recipesRef.get();
    console.log(`${demoUserId}: ${snapshot.size} recipes`);

    if (!snapshot.empty) {
      for (const doc of snapshot.docs.slice(0, 2)) {
        const data = doc.data();
        console.log(`  - ${doc.id}: ${data.title || 'no title'}`);
      }
    }
  }

  // 2. Check user's collections
  console.log('\n2. USER COLLECTIONS');
  console.log('-'.repeat(40));
  const collectionsRef = db.collection('users').doc(userId).collection('collections');
  const collections = await collectionsRef.get();
  console.log(`Total: ${collections.size} collections`);

  for (const doc of collections.docs) {
    const data = doc.data();
    const recipeIds = data.recipeIds || [];
    console.log(`  ${data.name}: ${recipeIds.length} recipes, modifiedAt: ${data.modifiedAt ? 'YES' : 'NO'}`);
  }

  // 3. Check user's recipes
  console.log('\n3. USER RECIPES');
  console.log('-'.repeat(40));
  const recipesRef = db.collection('users').doc(userId).collection('recipes');
  const recipes = await recipesRef.get();
  console.log(`Total: ${recipes.size} recipes`);

  // 4. Check theme recipe ingredients (sample)
  console.log('\n4. THEME RECIPE INGREDIENTS (SAMPLE)');
  console.log('-'.repeat(40));
  const themeRecipesRef = db.collection('themes').doc('railroad-dining').collection('recipes');
  const themeRecipes = await themeRecipesRef.limit(2).get();

  for (const doc of themeRecipes.docs) {
    const ingredientsSub = await doc.ref.collection('ingredients').get();
    console.log(`${doc.data().title}: ${ingredientsSub.size} ingredients in subcollection`);
  }

  // 5. Check pending shares
  console.log('\n5. PENDING SHARES FOR USER');
  console.log('-'.repeat(40));
  const sharesRef = db.collection('shares').where('recipientUserIds', 'array-contains', userId);
  const shares = await sharesRef.get();
  console.log(`Total: ${shares.size} shares`);

  for (const doc of shares.docs) {
    const data = doc.data();
    console.log(`  From ${data.ownerName}: ${data.recipeTitle} (recipeId: ${data.recipeId})`);
  }
}

checkAllData().catch(console.error);
