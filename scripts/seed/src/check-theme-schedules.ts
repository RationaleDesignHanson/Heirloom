/**
 * Check theme unlock schedules in Firebase
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

async function checkThemes() {
  const snapshot = await db.collection('themes').orderBy('sortOrder').get();
  console.log('Theme Unlock Schedules in Firebase:\n');

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const schedule = data.unlockSchedule || [];
    console.log(`${doc.id}:`);
    console.log(`  name: ${data.name}`);
    console.log(`  totalRecipes: ${data.totalRecipes}`);
    console.log(`  unlockSchedule length: ${schedule.length}`);
    if (schedule.length > 0) {
      // Count recipes per day
      const byDay = new Map<number, number>();
      schedule.forEach((day: number) => {
        byDay.set(day, (byDay.get(day) || 0) + 1);
      });
      const days = Array.from(byDay.entries()).sort((a, b) => a[0] - b[0]);
      console.log(`  recipes per day: ${days.map(([d, c]) => `Day ${d}: ${c}`).join(', ')}`);
    }
    console.log();
  }
}

checkThemes().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
