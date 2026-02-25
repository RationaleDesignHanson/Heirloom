/**
 * Set up complete profile data for test accounts
 *
 * Adds full profile info (bio, location, handle, specialties, etc.) for:
 * - demo@heirloomrecipebox.app (App Store demo)
 * - deletetest@heirloomrecipebox.app (Deletion testing)
 * - tester01@heirloomrecipebox.app (Internal testing)
 *
 * Run: npx ts-node src/setup-test-account-profiles.ts
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app',
  });
}

const db = admin.firestore();
const auth = admin.auth();

interface TestAccountProfile {
  email: string;
  displayName: string;
  handle: string;
  bio: string;
  location: string;
  specialties: string[];
  websiteURL?: string;
  photoURL?: string;
  // Theme progress (optional - if set, syncs to Firebase for returning user experience)
  themeProgress?: {
    selectedThemeIds: string[];
    trialDay: number; // 1-14, determines trialStartDate
  };
}

const TEST_ACCOUNTS: TestAccountProfile[] = [
  {
    email: 'demo@heirloomrecipebox.app',
    displayName: 'Sarah Mitchell',
    handle: 'sarahmitchell',
    bio: 'Home cook and recipe collector. I love recreating my grandmother\'s recipes and sharing them with friends and family.',
    location: 'Portland, OR',
    specialties: ['Comfort Food', 'Baking', 'Family Recipes'],
    websiteURL: 'https://heirloomrecipebox.app',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/test-accounts/demo-avatar.webp',
    // Demo account on day 3 - shows Apple reviewers theme content without waiting
    themeProgress: {
      selectedThemeIds: ['german-american', 'scandinavian-heritage'],
      trialDay: 3,
    },
  },
  {
    email: 'deletetest@heirloomrecipebox.app',
    displayName: 'Alex Thompson',
    handle: 'alexthompson',
    bio: 'Weekend chef who loves experimenting with new flavors. Collecting recipes from travels around the world.',
    location: 'Austin, TX',
    specialties: ['International Cuisine', 'Grilling', 'Quick Meals'],
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/test-accounts/deletion-demo-avatar.webp',
    // Deletion test account on day 3 - same as demo for consistency
    themeProgress: {
      selectedThemeIds: ['german-american', 'scandinavian-heritage'],
      trialDay: 3,
    },
  },
  {
    email: 'tester01@heirloomrecipebox.app',
    displayName: 'Jamie Chen',
    handle: 'jamiechen',
    bio: 'Passionate about preserving family food traditions. My kitchen is always open for friends.',
    location: 'San Francisco, CA',
    specialties: ['Asian Fusion', 'Desserts', 'Meal Prep'],
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/test-accounts/tester01-avatar.webp',
    // Internal testing account - can use different themes if needed
    themeProgress: {
      selectedThemeIds: ['german-american', 'scandinavian-heritage'],
      trialDay: 3,
    },
  },
];

async function getUserIdByEmail(email: string): Promise<string | null> {
  try {
    const user = await auth.getUserByEmail(email);
    return user.uid;
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log(`  User not found: ${email}`);
      return null;
    }
    throw error;
  }
}

async function setupProfile(account: TestAccountProfile): Promise<void> {
  console.log('\n' + '='.repeat(60));
  console.log(`Setting up: ${account.email}`);
  console.log('='.repeat(60));

  const userId = await getUserIdByEmail(account.email);
  if (!userId) {
    console.log(`  Skipping - user does not exist`);
    return;
  }

  console.log(`  User ID: ${userId}`);

  const now = new Date();
  const joinedAt = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000); // 90 days ago

  // Calculate trial start date from trialDay (e.g., day 3 = started 2 days ago)
  let themeTrialStartDate: Date | null = null;
  if (account.themeProgress) {
    const daysAgo = account.themeProgress.trialDay - 1;
    themeTrialStartDate = new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000);
  }

  // Update the profile subcollection (used by ProfileService)
  const profileData: Record<string, any> = {
    userId: userId,
    displayName: account.displayName,
    handle: account.handle,
    bio: account.bio,
    location: account.location,
    specialties: account.specialties,
    websiteURL: account.websiteURL || null,
    photoURL: account.photoURL || null,
    email: account.email,
    hasCompletedOnboarding: true,
    joinedAt: admin.firestore.Timestamp.fromDate(joinedAt),
    connectionCount: 2, // Demo connections
    sharedRecipeCount: 0,
    heritageGenerationCount: 0,
    // Privacy settings (defaults)
    privacySettings: {
      profileVisibility: 'connections',
      recipeVisibility: 'connections',
      kitchenTableVisibility: 'private',
      whoCanConnect: 'everyone',
      allowRecipeResharing: true,
      allowMentions: true,
      allowSearchIndexing: false,
    },
    createdAt: admin.firestore.Timestamp.fromDate(joinedAt),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Add theme progress if specified (for returning user experience)
  if (account.themeProgress && themeTrialStartDate) {
    profileData.selectedThemeIds = account.themeProgress.selectedThemeIds;
    profileData.themeTrialStartDate = admin.firestore.Timestamp.fromDate(themeTrialStartDate);
  }

  // Write to profile subcollection
  await db.collection('users').doc(userId).collection('profile').doc('data').set(profileData, { merge: true });
  console.log(`  ✓ Profile subcollection updated`);

  // Also update the root user document (for quick lookups)
  await db.collection('users').doc(userId).set({
    displayName: account.displayName,
    handle: account.handle,
    photoURL: account.photoURL || null,
    email: account.email,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`  ✓ Root user document updated`);

  // Update Firebase Auth display name
  await auth.updateUser(userId, {
    displayName: account.displayName,
    photoURL: account.photoURL || undefined,
  });
  console.log(`  ✓ Firebase Auth updated`);

  console.log(`\n  Profile summary:`);
  console.log(`    Name: ${account.displayName}`);
  console.log(`    Handle: @${account.handle}`);
  console.log(`    Location: ${account.location}`);
  console.log(`    Bio: ${account.bio.substring(0, 50)}...`);
  console.log(`    Specialties: ${account.specialties.join(', ')}`);
  if (account.themeProgress) {
    console.log(`    Theme Progress:`);
    console.log(`      - Themes: ${account.themeProgress.selectedThemeIds.join(', ')}`);
    console.log(`      - Trial Day: ${account.themeProgress.trialDay}`);
  }
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║        Setting Up Test Account Profiles                    ║');
  console.log('╚════════════════════════════════════════════════════════════╝');

  for (const account of TEST_ACCOUNTS) {
    await setupProfile(account);
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ ALL PROFILES UPDATED');
  console.log('='.repeat(60));
  console.log('\nAccounts updated:');
  for (const account of TEST_ACCOUNTS) {
    console.log(`  - ${account.email} → ${account.displayName} (@${account.handle})`);
  }
}

main().then(() => process.exit(0)).catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
