import { initializeFirebase, getDb } from './src/utils/firebase';

async function checkDemoRecipeDetails() {
  initializeFirebase();
  const db = getDb();

  const demoUserId = 'demo_phillipfry';
  const recipeId = 'demo_phillipfry_one_pot_pasta';

  console.log(`Checking recipe: ${recipeId} for user: ${demoUserId}`);
  console.log('='.repeat(60));

  // Get recipe document
  const recipeRef = db.collection('users').doc(demoUserId).collection('recipes').doc(recipeId);
  const recipeDoc = await recipeRef.get();

  if (!recipeDoc.exists) {
    console.log('Recipe not found!');
    return;
  }

  const recipe = recipeDoc.data();
  console.log('\nRecipe document:');
  console.log('  title:', recipe?.title);
  console.log('  description:', recipe?.description?.substring(0, 50) + '...');
  console.log('  firebaseImageURL:', recipe?.firebaseImageURL ? 'SET' : 'NONE');
  console.log('  servings:', recipe?.servings);
  console.log('  prepTime:', recipe?.prepTime);
  console.log('  cookTime:', recipe?.cookTime);

  // Check ingredients subcollection
  const ingredientsSnap = await recipeRef.collection('ingredients').get();
  console.log('\nIngredients subcollection:', ingredientsSnap.size, 'items');
  if (ingredientsSnap.size > 0) {
    ingredientsSnap.docs.slice(0, 3).forEach(doc => {
      const ing = doc.data();
      console.log(`  - ${ing.text || ing.name || 'NO TEXT'}`);
    });
    if (ingredientsSnap.size > 3) {
      console.log(`  ... and ${ingredientsSnap.size - 3} more`);
    }
  }

  // Check instructions subcollection
  const instructionsSnap = await recipeRef.collection('instructions').get();
  console.log('\nInstructions subcollection:', instructionsSnap.size, 'items');
  if (instructionsSnap.size > 0) {
    instructionsSnap.docs.slice(0, 2).forEach(doc => {
      const inst = doc.data();
      console.log(`  - ${(inst.text || 'NO TEXT').substring(0, 60)}...`);
    });
  }
}

checkDemoRecipeDetails().catch(console.error);
