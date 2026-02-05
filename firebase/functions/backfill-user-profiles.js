/**
 * Backfill User Profiles Migration Script
 *
 * This script migrates user profiles from the legacy `userProfiles/{userId}` collection
 * to the correct `users/{userId}/profile/data` path that triggers Algolia indexing.
 *
 * Run with: node backfill-user-profiles.js
 *
 * Prerequisites:
 * 1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable to your service account key
 *    OR run from a machine with Firebase Admin SDK credentials
 * 2. npm install (to ensure firebase-admin is available)
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

// Initialize Firebase Admin with project ID
initializeApp({
  projectId: 'heirloom-ios-prod'
});

const db = getFirestore();
const auth = getAuth();

async function backfillUserProfiles() {
  console.log('Starting user profile backfill migration...\n');

  let migrated = 0;
  let skipped = 0;
  let errors = 0;
  let alreadyExists = 0;

  try {
    // Get all users from legacy userProfiles collection
    console.log('Fetching users from legacy userProfiles collection...');
    const legacyProfilesSnapshot = await db.collection('userProfiles').get();
    console.log(`Found ${legacyProfilesSnapshot.size} legacy profiles\n`);

    for (const doc of legacyProfilesSnapshot.docs) {
      const userId = doc.id;
      const legacyData = doc.data();

      try {
        // Check if user already has a profile in the correct location
        const correctProfileRef = db.collection('users').doc(userId)
          .collection('profile').doc('data');
        const existingProfile = await correctProfileRef.get();

        if (existingProfile.exists) {
          // Profile exists - check if it has email
          const existingData = existingProfile.data();
          if (existingData.email) {
            console.log(`  ⏭️  ${userId}: Already has profile with email, skipping`);
            alreadyExists++;
            continue;
          }
          // Profile exists but no email - we'll update it
          console.log(`  🔄 ${userId}: Profile exists but missing email, updating...`);
        }

        // Try to get additional info from Firebase Auth
        let authUser = null;
        try {
          authUser = await auth.getUser(userId);
        } catch (authError) {
          // User might not exist in Auth (deleted account)
          console.log(`  ⚠️  ${userId}: Not found in Firebase Auth`);
        }

        // Build the profile data
        const profileData = {
          userId: userId,
          displayName: legacyData.displayName || authUser?.displayName || 'Unknown',
          email: legacyData.email || authUser?.email || null,
          photoURL: legacyData.photoURL || authUser?.photoURL || null,
          updatedAt: Timestamp.now(),
          // Default privacy settings - allow search indexing
          privacySettings: {
            hideFromSearch: false,
            showLocationInSearch: true,
            showSpecialtiesInSearch: true,
            profileVisibility: 'connections'
          },
          // Initialize social fields if not present
          connectionCount: existingProfile.exists ? (existingProfile.data().connectionCount || 0) : 0,
          followerCount: existingProfile.exists ? (existingProfile.data().followerCount || 0) : 0,
          isVerified: false
        };

        // Preserve existing fields if updating
        if (existingProfile.exists) {
          const existing = existingProfile.data();
          profileData.bio = existing.bio || null;
          profileData.location = existing.location || null;
          profileData.specialties = existing.specialties || [];
          profileData.joinedAt = existing.joinedAt || Timestamp.now();
          // Preserve privacy settings if they exist
          if (existing.privacySettings) {
            profileData.privacySettings = {
              ...profileData.privacySettings,
              ...existing.privacySettings
            };
          }
        } else {
          profileData.joinedAt = legacyData.lastUpdated || Timestamp.now();
        }

        // Write to the correct path
        await correctProfileRef.set(profileData, { merge: true });

        const emailStatus = profileData.email ? `✉️  ${profileData.email}` : '(no email)';
        console.log(`  ✅ ${userId}: ${profileData.displayName} ${emailStatus}`);
        migrated++;

      } catch (userError) {
        console.error(`  ❌ ${userId}: Error - ${userError.message}`);
        errors++;
      }
    }

    // Also check Firebase Auth for users who might not be in userProfiles
    console.log('\nChecking Firebase Auth for additional users...');

    let nextPageToken;
    let authOnlyUsers = 0;

    do {
      const listResult = await auth.listUsers(1000, nextPageToken);

      for (const authUser of listResult.users) {
        const userId = authUser.uid;

        // Check if we already processed this user
        const correctProfileRef = db.collection('users').doc(userId)
          .collection('profile').doc('data');
        const existingProfile = await correctProfileRef.get();

        if (existingProfile.exists && existingProfile.data().email) {
          continue; // Already has complete profile
        }

        // Check if user was in legacy collection (already processed)
        const legacyDoc = await db.collection('userProfiles').doc(userId).get();
        if (legacyDoc.exists) {
          continue; // Already processed above
        }

        // This is an Auth-only user with no Firestore profile
        try {
          const profileData = {
            userId: userId,
            displayName: authUser.displayName || authUser.email?.split('@')[0] || 'Unknown',
            email: authUser.email || null,
            photoURL: authUser.photoURL || null,
            updatedAt: Timestamp.now(),
            joinedAt: Timestamp.fromDate(new Date(authUser.metadata.creationTime)),
            privacySettings: {
              hideFromSearch: false,
              showLocationInSearch: true,
              showSpecialtiesInSearch: true,
              profileVisibility: 'connections'
            },
            connectionCount: 0,
            followerCount: 0,
            isVerified: false
          };

          await correctProfileRef.set(profileData, { merge: true });

          const emailStatus = profileData.email ? `✉️  ${profileData.email}` : '(no email)';
          console.log(`  ✅ ${userId} (Auth only): ${profileData.displayName} ${emailStatus}`);
          authOnlyUsers++;
          migrated++;

        } catch (userError) {
          console.error(`  ❌ ${userId} (Auth only): Error - ${userError.message}`);
          errors++;
        }
      }

      nextPageToken = listResult.pageToken;
    } while (nextPageToken);

    if (authOnlyUsers > 0) {
      console.log(`Found ${authOnlyUsers} users in Auth without Firestore profiles`);
    }

  } catch (error) {
    console.error('Fatal error during migration:', error);
    process.exit(1);
  }

  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('MIGRATION COMPLETE');
  console.log('='.repeat(50));
  console.log(`✅ Migrated:       ${migrated}`);
  console.log(`⏭️  Already exists: ${alreadyExists}`);
  console.log(`❌ Errors:         ${errors}`);
  console.log(`📊 Total processed: ${migrated + alreadyExists + errors}`);
  console.log('='.repeat(50));

  if (migrated > 0) {
    console.log('\n📝 Note: Algolia sync will be triggered automatically for migrated users.');
    console.log('   Check Algolia dashboard to verify users are indexed.');
  }

  process.exit(errors > 0 ? 1 : 0);
}

// Run the migration
backfillUserProfiles();
