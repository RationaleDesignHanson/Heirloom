#!/usr/bin/env node

/**
 * Update Firestore theme documents with coverImageURL fields
 *
 * After uploading images to Storage, we need to set the coverImageURL
 * field on each theme document so the app can load the covers.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./firebase/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const THEME_COVER_URLS = {
  'automat-classics': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/automat-classics.webp',
  'railroad-dining': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/railroad-dining.webp',
  'victory-kitchen': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/victory-kitchen.webp',
  'navy-mess': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/navy-mess.webp',
  'boston-cooking-school': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/boston-cooking.webp',
  'southern-roots': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/southern-roots.webp',
  'scandinavian-heritage': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/scandinavian-heritage.webp',
  'german-american': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/german-american.webp',
  'quick-weeknight': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/quick-weeknight.webp',
  'sunday-suppers': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/sunday-suppers.webp',
  'presidential-pantry': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/presidential-pantry.webp',
  'literary-kitchen': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/literary-kitchen.webp',
  'ancient-table': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/ancient-table.webp',
  'american-foundation': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/american-foundation.webp',
  'classic-literature': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/classic-literature.webp',
  'childrens-stories': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/childrens-stories.webp',
  'fantasy-scifi': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/fantasy-scifi.webp',
  'crime-cult-classics': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/crime-cult-classics.webp',
  'magical-realism': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/magical-realism.webp',
  'romance-indulgence': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/romance-indulgence.webp',
  'dystopian-fiction': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/dystopian-fiction.webp',
  'film-tv-favourites': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/film-tv-favourites.webp',
  'feasts-banquets': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/feasts-banquets.webp',
  'cocktails-confections': 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/cocktails-confections.webp'
};

async function updateThemeCoverUrls() {
  console.log('🖼️  Updating theme cover URLs in Firestore...\n');

  let successCount = 0;
  let failCount = 0;

  for (const [themeId, coverUrl] of Object.entries(THEME_COVER_URLS)) {
    try {
      const themeRef = db.collection('themes').doc(themeId);
      const doc = await themeRef.get();

      if (!doc.exists) {
        console.log(`⚠️  Theme not found: ${themeId}`);
        failCount++;
        continue;
      }

      await themeRef.update({
        coverImageURL: coverUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`✓ Updated ${themeId}`);
      successCount++;
    } catch (error) {
      console.error(`✗ Failed to update ${themeId}:`, error.message);
      failCount++;
    }
  }

  console.log(`\n📊 Summary: ${successCount} updated, ${failCount} failed`);

  if (successCount === Object.keys(THEME_COVER_URLS).length) {
    console.log('\n✅ All theme cover URLs updated successfully!');
    console.log('\n💡 Next step: Delete app and reinstall to test');
  }
}

updateThemeCoverUrls()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('\n❌ Update failed:', error);
    process.exit(1);
  });
