/**
 * Check recipe unlockDay values in Firebase
 */

import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      path.resolve(__dirname, '../../../service-account-key.json')
    ),
  });
}

const db = admin.firestore();

async function checkRecipeUnlockDays() {
  const themesSnapshot = await db.collection('themes').orderBy('sortOrder').get();
  console.log('Recipe unlockDay Values in Firebase:\n');

  for (const themeDoc of themesSnapshot.docs) {
    const themeData = themeDoc.data();
    const recipesSnapshot = await db
      .collection('themes')
      .doc(themeDoc.id)
      .collection('recipes')
      .orderBy('sortOrder')
      .get();

    console.log(`${themeDoc.id} (${themeData.name}):`);
    console.log(`  Total recipes: ${recipesSnapshot.size}`);

    // Count by unlockDay
    const byDay = new Map<number, number>();
    let missingUnlockDay = 0;

    for (const recipeDoc of recipesSnapshot.docs) {
      const data = recipeDoc.data();
      const unlockDay = data.unlockDay;
      if (unlockDay === undefined) {
        missingUnlockDay++;
      } else {
        byDay.set(unlockDay, (byDay.get(unlockDay) || 0) + 1);
      }
    }

    if (missingUnlockDay > 0) {
      console.log(`  ⚠️ Missing unlockDay: ${missingUnlockDay} recipes`);
    }

    const days = Array.from(byDay.entries()).sort((a, b) => a[0] - b[0]);
    console.log(`  By unlockDay: ${days.map(([d, c]) => `Day ${d}: ${c}`).join(', ')}`);
    console.log();
  }
}

checkRecipeUnlockDays().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
