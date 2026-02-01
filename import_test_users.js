#!/usr/bin/env node

// Import test users to Firestore
// Run with: node import_test_users.js

const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin with service account
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'heirloom-ios-prod'
});

const db = admin.firestore();

const testUsers = [
  {
    userId: 'test-user-1',
    displayName: 'Matt Chef',
    bio: 'Love Italian cooking and fresh pasta',
    location: 'New York',
    specialties: ['Italian', 'Pasta', 'Baking']
  },
  {
    userId: 'test-user-2',
    displayName: 'Sarah Baker',
    bio: 'Specializing in artisan breads and pastries',
    location: 'San Francisco',
    specialties: ['Baking', 'Desserts', 'Soups']
  },
  {
    userId: 'test-user-3',
    displayName: 'Maria Garcia',
    bio: 'Mexican cuisine enthusiast and taco expert',
    location: 'Austin',
    specialties: ['Mexican', 'Grilling', 'Salads']
  },
  {
    userId: 'test-user-4',
    displayName: 'John Smith',
    bio: 'BBQ and grilling expert, competition winner',
    location: 'Dallas',
    specialties: ['Grilling', 'BBQ', 'Seafood']
  },
  {
    userId: 'test-user-5',
    displayName: 'Emily Chen',
    bio: 'Asian fusion and vegetarian dishes',
    location: 'Seattle',
    specialties: ['Asian', 'Vegetarian', 'Vegan']
  },
  {
    userId: 'test-user-6',
    displayName: 'Matthew Anderson',
    bio: 'Home cook learning new techniques',
    location: 'Portland',
    specialties: ['Soups', 'Salads', 'Pasta']
  }
];

async function importUsers() {
  console.log('Starting import of test users...\n');

  for (const user of testUsers) {
    const profileData = {
      userId: user.userId,
      displayName: user.displayName,
      bio: user.bio,
      photoURL: null,
      handle: null,
      location: user.location,
      specialties: user.specialties,
      websiteURL: null,
      currentKitchenTableId: null,
      kitchenTableIds: null,
      connectionCount: 0,
      followerCount: 0,
      followingCount: 0,
      sharedRecipeCount: 0,
      heritageGenerationCount: 0,
      recipeAcceptanceCount: 0,
      privacySettings: {
        profileVisibility: 'private',
        allowMentions: true,
        allowSearchIndexing: true,
        hideFromSearch: false,
        showLocationInSearch: true,
        showSpecialtiesInSearch: true
      },
      hasPublicProfile: false,
      publicProfileSlug: null,
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActiveAt: null,
      locale: 'en_US',
      isVerified: false,
      verificationType: null
    };

    try {
      await db
        .collection('users')
        .doc(user.userId)
        .collection('profile')
        .doc('data')
        .set(profileData);

      console.log(`✅ Imported: ${user.displayName} (${user.userId})`);
    } catch (error) {
      console.error(`❌ Failed to import ${user.displayName}:`, error.message);
    }
  }

  console.log('\n✨ Import complete!');
  console.log('\nTest search queries:');
  console.log('- "Matt" → should find "Matt Chef" and "Matthew Anderson"');
  console.log('- "Sarah" → should find "Sarah Baker"');
  console.log('- "Maria" → should find "Maria Garcia"');
  console.log('- "John" → should find "John Smith"');
  console.log('- "Emily" → should find "Emily Chen"');

  process.exit(0);
}

importUsers().catch((error) => {
  console.error('Import failed:', error);
  process.exit(1);
});
