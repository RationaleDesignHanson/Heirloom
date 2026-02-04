#!/usr/bin/env node

/**
 * Backfill emails from Firebase Auth to Firestore user profiles
 * This enables email masking in user search (Algolia)
 *
 * Run: node backfill-emails.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'heirloom-ios-prod'
});

const db = admin.firestore();
const auth = admin.auth();

async function backfillEmails() {
  console.log('🚀 Starting email backfill...\n');

  let updated = 0;
  let skipped = 0;
  let noEmail = 0;
  let errors = 0;

  // List all users from Firebase Auth (paginated)
  let nextPageToken;

  do {
    const listResult = await auth.listUsers(1000, nextPageToken);

    for (const userRecord of listResult.users) {
      const userId = userRecord.uid;
      const email = userRecord.email;
      const displayName = userRecord.displayName;

      if (!email) {
        console.log(`  ⚠️  ${userId} - no email in Auth`);
        noEmail++;
        continue;
      }

      try {
        // Check if profile exists
        const profileRef = db.collection('users').doc(userId).collection('profile').doc('data');
        const profileDoc = await profileRef.get();

        if (!profileDoc.exists) {
          console.log(`  ⚠️  ${userId} - no profile document`);
          skipped++;
          continue;
        }

        const profileData = profileDoc.data();

        // Check if email already exists
        if (profileData.email) {
          console.log(`  ✓  ${displayName || userId} - already has email`);
          skipped++;
          continue;
        }

        // Update profile with email
        await profileRef.update({
          email: email,
          updatedAt: admin.firestore.Timestamp.now()
        });

        console.log(`  ✅ ${displayName || userId} - added email: ${maskEmail(email)}`);
        updated++;

      } catch (error) {
        console.log(`  ❌ ${userId} - error: ${error.message}`);
        errors++;
      }
    }

    nextPageToken = listResult.pageToken;
  } while (nextPageToken);

  console.log(`\n📊 Summary:`);
  console.log(`   • Updated: ${updated} users`);
  console.log(`   • Skipped: ${skipped} users (already had email or no profile)`);
  console.log(`   • No email in Auth: ${noEmail} users`);
  console.log(`   • Errors: ${errors} users`);
  console.log(`\n✨ Backfill complete!`);
  console.log(`\n📝 Note: The Algolia sync function will automatically re-index`);
  console.log(`   updated profiles with their emails.`);

  process.exit(0);
}

// Helper to mask email for logging
function maskEmail(email) {
  const parts = email.split('@');
  if (parts.length !== 2) return email;
  const username = parts[0];
  const domain = parts[1];
  const visible = Math.min(Math.max(Math.floor(username.length * 0.4), 1), 10);
  return `${username.substring(0, visible)}***@${domain}`;
}

backfillEmails().catch((error) => {
  console.error('❌ Backfill failed:', error);
  process.exit(1);
});
