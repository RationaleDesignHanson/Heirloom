import { initializeFirebase, getDb } from './src/utils/firebase';

async function cleanupDemoRecipes() {
  initializeFirebase();
  const db = getDb();

  const demoUsers = [
    'demo_phillipfry',
    'demo_grillmaster',
    'demo_grandmazing',
    'demo_chef_maria',
    'demo_fitfoodie',
    'demo_bakingbelle'
  ];

  console.log('Cleaning up demo user recipes...');
  console.log('='.repeat(60));

  for (const userId of demoUsers) {
    const recipesRef = db.collection('users').doc(userId).collection('recipes');
    const recipes = await recipesRef.get();

    for (const recipeDoc of recipes.docs) {
      // Delete ingredients subcollection
      const ingredients = await recipeDoc.ref.collection('ingredients').get();
      for (const ing of ingredients.docs) {
        await ing.ref.delete();
      }
      console.log(`  Deleted ${ingredients.size} ingredients from ${recipeDoc.id}`);

      // Delete instructions subcollection
      const instructions = await recipeDoc.ref.collection('instructions').get();
      for (const inst of instructions.docs) {
        await inst.ref.delete();
      }
      console.log(`  Deleted ${instructions.size} instructions from ${recipeDoc.id}`);

      // Delete recipe document
      await recipeDoc.ref.delete();
      console.log(`  Deleted recipe: ${recipeDoc.id}`);
    }

    console.log(`Cleaned ${userId}`);
  }

  console.log('\nDone! Now run: npx ts-node src/demo-user-recipes/seed.ts');
}

cleanupDemoRecipes().catch(console.error);
