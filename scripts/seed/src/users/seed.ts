/**
 * Seed demo user profiles to Firestore
 *
 * Creates user documents for demo creators (Grandmazing, Phillip Fry)
 * so they appear in user search via Algolia.
 *
 * User profiles are stored at: users/{userId}/profile/data
 * This triggers the syncUserToAlgolia Cloud Function.
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

// Demo user profiles
const DEMO_USERS = [
  {
    id: 'demo_grandmazing',
    displayName: 'Grandmazing',
    email: 'grandmazing@example.com',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grandmazing-avatar.webp',
    bio: 'Sharing recipes passed down through generations. Every dish tells a story.',
    location: 'Vermont',
    specialties: ['Comfort Food', 'Baking', 'Family Recipes', 'Southern Cooking'],
    connectionCount: 1247,
    isVerified: true,
    isDemoSeed: true,
    demoSeedVersion: 'v2',
    demoSeedLabel: 'discover-capture',
  },
  {
    id: 'demo_phillipfry',
    displayName: 'Phillip Fry',
    email: 'phillip.fry@example.com',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_phillipfry-avatar.webp',
    bio: 'Home cook exploring quick weeknight meals. Making dinner easy and delicious.',
    location: 'Brooklyn, NY',
    specialties: ['Quick Meals', 'One-Pot Dishes', 'Vegetarian', 'Budget Cooking'],
    connectionCount: 523,
    isVerified: false,
    isDemoSeed: true,
    demoSeedVersion: 'v2',
    demoSeedLabel: 'discover-capture',
  },
  {
    id: 'demo_chef_maria',
    displayName: 'Maria Santos',
    email: 'maria.santos@example.com',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_chef_maria-avatar.webp',
    bio: 'Professional chef bringing Latin flavors to your home kitchen. From Miami with love.',
    location: 'Miami, FL',
    specialties: ['Latin Cuisine', 'Seafood', 'Fine Dining', 'Cuban'],
    connectionCount: 2840,
    isVerified: true,
    isDemoSeed: true,
    demoSeedVersion: 'v2',
    demoSeedLabel: 'discover-capture',
  },
  {
    id: 'demo_fitfoodie',
    displayName: 'Alex Chen',
    email: 'alex.chen@example.com',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_fitfoodie-avatar.webp',
    bio: 'Fitness enthusiast sharing healthy recipes that actually taste amazing. Fuel your gains!',
    location: 'Austin, TX',
    specialties: ['Healthy Eating', 'Meal Prep', 'High-Protein', 'Bowls'],
    connectionCount: 890,
    isVerified: false,
    isDemoSeed: true,
    demoSeedVersion: 'v2',
    demoSeedLabel: 'discover-capture',
  },
  {
    id: 'demo_bakingbelle',
    displayName: 'Belle Thompson',
    email: 'belle.thompson@example.com',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bakingbelle-avatar.webp',
    bio: 'Baker, dessert enthusiast, and pastry perfectionist. Life is short, eat dessert first!',
    location: 'Portland, OR',
    specialties: ['Baking', 'Desserts', 'Pastry', 'Cakes'],
    connectionCount: 1560,
    isVerified: true,
    isDemoSeed: true,
    demoSeedVersion: 'v2',
    demoSeedLabel: 'discover-capture',
  },
  {
    id: 'demo_grillmaster',
    displayName: 'Marcus Johnson',
    email: 'marcus.johnson@example.com',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grillmaster-avatar.webp',
    bio: 'BBQ pitmaster and grilling expert. Low and slow is the way to go.',
    location: 'Kansas City, MO',
    specialties: ['BBQ', 'Grilling', 'Smoking', 'Ribs'],
    connectionCount: 720,
    isVerified: false,
    isDemoSeed: true,
    demoSeedVersion: 'v2',
    demoSeedLabel: 'discover-capture',
  },
  {
    id: 'demo_bigshare',
    displayName: 'Big Share',
    email: 'bigshare@example.com',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bigshare-avatar.webp',
    bio: 'I believe every great recipe deserves to travel. Share freely, cook boldly.',
    location: 'Everywhere',
    specialties: ['Italian', 'Comfort Food', 'Slow Cooking', 'Community'],
    connectionCount: 5420,
    isVerified: true,
    isDemoSeed: true,
    demoSeedVersion: 'v2',
    demoSeedLabel: 'bigshare-lineage',
  },
];

/**
 * Seed demo users to Firestore
 */
export async function seedDemoUsers(): Promise<void> {
  console.log('Seeding demo user profiles...\n');

  for (const user of DEMO_USERS) {
    const { id, ...userData } = user;
    const profileRef = db.collection('users').doc(id).collection('profile').doc('data');

    console.log(`  Creating user: ${user.displayName} (${id})`);

    await profileRef.set({
      ...userData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`    ✓ Profile created at users/${id}/profile/data`);
  }

  console.log(`\n✅ Seeded ${DEMO_USERS.length} demo users`);
  console.log('   Users will sync to Algolia via Cloud Function trigger.');
}

/**
 * Cleanup demo users from Firestore
 */
export async function cleanupDemoUsers(): Promise<void> {
  console.log('Cleaning up demo user profiles...\n');

  for (const user of DEMO_USERS) {
    const profileRef = db.collection('users').doc(user.id).collection('profile').doc('data');

    console.log(`  Deleting user: ${user.displayName} (${user.id})`);

    await profileRef.delete();

    console.log(`    ✓ Deleted`);
  }

  console.log(`\n✅ Cleaned up ${DEMO_USERS.length} demo users`);
}

// CLI handling
if (require.main === module) {
  const command = process.argv[2];

  if (command === 'cleanup') {
    cleanupDemoUsers()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  } else {
    seedDemoUsers()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  }
}
