import { initializeFirebase, getDb } from './src/utils/firebase';

async function verifyDemoRecipes() {
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

  console.log('Verifying demo user recipes...');
  console.log('='.repeat(60));

  for (const userId of demoUsers) {
    const recipesRef = db.collection('users').doc(userId).collection('recipes');
    const recipes = await recipesRef.get();

    for (const recipeDoc of recipes.docs) {
      const recipe = recipeDoc.data();
      console.log(`\n${userId} / ${recipeDoc.id}:`);
      console.log(`  title: ${recipe.title}`);
      console.log(`  firebaseImageURL: ${recipe.firebaseImageURL ? 'SET' : 'MISSING'}`);

      // Check image URL is valid
      if (recipe.firebaseImageURL) {
        const response = await fetch(recipe.firebaseImageURL, { method: 'HEAD' });
        console.log(`  image status: ${response.status === 200 ? 'OK' : 'BROKEN (' + response.status + ')'}`);
      }

      // Check ingredients
      const ings = await recipeDoc.ref.collection('ingredients').get();
      console.log(`  ingredients: ${ings.size}`);
      if (ings.size > 0) {
        const firstIng = ings.docs[0].data();
        console.log(`    - originalText: ${firstIng.originalText ? 'SET' : 'MISSING'}`);
        console.log(`    - quantity: ${firstIng.quantity !== undefined ? 'SET' : 'MISSING'}`);
        console.log(`    - sample: "${firstIng.originalText || firstIng.text || 'NO TEXT'}"`);
      }

      // Check instructions
      const insts = await recipeDoc.ref.collection('instructions').get();
      console.log(`  instructions: ${insts.size}`);
    }
  }
}

verifyDemoRecipes().catch(console.error);
