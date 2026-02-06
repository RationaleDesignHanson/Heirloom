import { initializeFirebase, getDb } from './src/utils/firebase';

async function checkCollections() {
  initializeFirebase();
  const db = getDb();
  const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

  const collections = await db.collection('users').doc(userId).collection('collections').get();
  console.log(`Found ${collections.size} collections:\n`);

  for (const doc of collections.docs) {
    const d = doc.data();
    console.log(`${d.name}:`);
    console.log(`  id: ${doc.id}`);
    console.log(`  imageURL: ${d.imageURL || 'NONE'}`);
    console.log(`  firebaseImageURL: ${d.firebaseImageURL || 'NONE'}`);
    console.log(`  recipes: ${(d.recipeIds || []).length}`);
    console.log('');
  }
}

checkCollections().catch(console.error);
