#!/usr/bin/env node

/**
 * Backup all theme recipes from Firebase to local JSON files
 *
 * Creates timestamped backup in scripts/backups/
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./firebase/serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

const BACKUP_DIR = path.join(__dirname, 'backups');

async function backupThemeRecipes() {
  // Create backup directory with timestamp
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const backupPath = path.join(BACKUP_DIR, `firebase-backup-${timestamp}`);

  if (!fs.existsSync(backupPath)) {
    fs.mkdirSync(backupPath, { recursive: true });
  }

  console.log(`\nBacking up Firebase recipes to: ${backupPath}\n`);

  // Get all themes
  const themesSnapshot = await db.collection('themes').orderBy('sortOrder').get();
  console.log(`Found ${themesSnapshot.size} themes\n`);

  const summary = [];

  for (const themeDoc of themesSnapshot.docs) {
    const themeId = themeDoc.id;
    const themeData = themeDoc.data();

    console.log(`📚 ${themeId} (${themeData.name})...`);

    // Get all recipes for this theme
    const recipesSnapshot = await db
      .collection('themes')
      .doc(themeId)
      .collection('recipes')
      .orderBy('sortOrder')
      .get();

    const recipes = [];

    for (const recipeDoc of recipesSnapshot.docs) {
      const recipeData = recipeDoc.data();

      // Get ingredients subcollection
      const ingredientsSnapshot = await recipeDoc.ref
        .collection('ingredients')
        .orderBy('order')
        .get();

      const ingredients = ingredientsSnapshot.docs.map(doc => doc.data());

      // Get instructions subcollection
      const instructionsSnapshot = await recipeDoc.ref
        .collection('instructions')
        .orderBy('order')
        .get();

      const instructions = instructionsSnapshot.docs.map(doc => doc.data().text);

      recipes.push({
        id: recipeDoc.id,
        ...recipeData,
        ingredients,
        instructions,
        // Convert Firestore timestamps to ISO strings
        createdAt: recipeData.createdAt?.toDate?.()?.toISOString() || null,
        updatedAt: recipeData.updatedAt?.toDate?.()?.toISOString() || null,
      });
    }

    // Save theme backup
    const backupData = {
      themeId,
      themeName: themeData.name,
      themeData: {
        ...themeData,
        createdAt: themeData.createdAt?.toDate?.()?.toISOString() || null,
        updatedAt: themeData.updatedAt?.toDate?.()?.toISOString() || null,
      },
      recipes,
      backupTimestamp: new Date().toISOString()
    };

    const fileName = `${themeId}.json`;
    fs.writeFileSync(
      path.join(backupPath, fileName),
      JSON.stringify(backupData, null, 2)
    );

    console.log(`   ✅ ${recipes.length} recipes saved to ${fileName}`);

    // Track unlock day distribution
    const byDay = new Map();
    recipes.forEach(r => {
      const day = r.unlockDay || 1;
      byDay.set(day, (byDay.get(day) || 0) + 1);
    });
    const days = Array.from(byDay.entries()).sort((a, b) => a[0] - b[0]);
    console.log(`      Distribution: ${days.map(([d, c]) => `D${d}:${c}`).join(', ')}`);

    summary.push({
      themeId,
      themeName: themeData.name,
      recipeCount: recipes.length,
      distribution: Object.fromEntries(byDay)
    });
  }

  // Save summary
  fs.writeFileSync(
    path.join(backupPath, '_summary.json'),
    JSON.stringify({ timestamp, themes: summary }, null, 2)
  );

  console.log(`\n✅ Backup complete!`);
  console.log(`   Location: ${backupPath}`);
  console.log(`   Themes: ${summary.length}`);
  console.log(`   Total recipes: ${summary.reduce((sum, t) => sum + t.recipeCount, 0)}`);

  return backupPath;
}

backupThemeRecipes()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Backup failed:', err);
    process.exit(1);
  });
