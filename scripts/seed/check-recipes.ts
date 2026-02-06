import { initializeFirebase, getDb } from './src/utils/firebase';

async function checkRecipes() {
  initializeFirebase();
  const db = getDb();
  const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

  const recipes = await db.collection('users').doc(userId).collection('recipes').get();
  console.log('Total recipes in Firestore:', recipes.size);
  console.log('');

  // Group by source/type
  const bySource: Record<string, number> = {};
  const noImage: string[] = [];
  const titles: string[] = [];

  for (const doc of recipes.docs) {
    const d = doc.data();
    const source = d.sourceType || d.source || 'unknown';
    bySource[source] = (bySource[source] || 0) + 1;

    if (!d.firebaseImageURL && !d.imageURL) {
      noImage.push(d.title || doc.id);
    }
    titles.push(d.title || 'Untitled');
  }

  console.log('By source type:');
  for (const [source, count] of Object.entries(bySource)) {
    console.log(`  ${source}: ${count}`);
  }

  console.log('');
  console.log(`Recipes without images (${noImage.length}):`);
  noImage.slice(0, 15).forEach(t => console.log(`  - ${t}`));
  if (noImage.length > 15) console.log(`  ... and ${noImage.length - 15} more`);

  console.log('');
  console.log('All recipe titles:');
  titles.sort().forEach(t => console.log(`  - ${t}`));
}

checkRecipes().catch(console.error);
