#!/usr/bin/env node
/**
 * Firebase Security Rules Test Script
 * Tests that recipes and images are properly access-controlled
 */

const admin = require('firebase-admin');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

// Color output for terminal
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[36m',
};

function log(color, message) {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

async function runSecurityTests() {
  log('blue', '\n🧪 Starting Firebase Security Rules Tests\n');
  log('blue', '='.repeat(50));

  let testEnv;

  try {
    // Initialize test environment
    log('yellow', '\n📦 Initializing test environment...');
    testEnv = await initializeTestEnvironment({
      projectId: 'heirloom-ios-prod',
      firestore: {
        rules: require('fs').readFileSync('./firestore.rules', 'utf8'),
      },
      storage: {
        rules: require('fs').readFileSync('./storage.rules', 'utf8'),
      },
    });

    log('green', '✅ Test environment initialized');

    // Test data
    const userAId = 'test-user-a';
    const userBId = 'test-user-b';
    const recipeId = 'test-recipe-123';
    const shareId = 'test-share-456';

    // Clear all data before tests
    await testEnv.clearFirestore();
    log('yellow', '\n🧹 Cleared test data');

    log('blue', '\n' + '='.repeat(50));
    log('blue', 'TEST SUITE: Recipe Access Control');
    log('blue', '='.repeat(50));

    // Test 1: User A can create their own recipe
    log('yellow', '\n📝 Test 1: User A creates a recipe');
    const userAContext = testEnv.authenticatedContext(userAId);
    await assertSucceeds(
      userAContext.firestore()
        .collection('users').doc(userAId)
        .collection('recipes').doc(recipeId)
        .set({
          title: 'User A\'s Secret Recipe',
          ownerId: userAId,
          createdAt: new Date(),
        })
    );
    log('green', '✅ PASS: User A can create their own recipe');

    // Test 2: User A can read their own recipe
    log('yellow', '\n📖 Test 2: User A reads their own recipe');
    await assertSucceeds(
      userAContext.firestore()
        .collection('users').doc(userAId)
        .collection('recipes').doc(recipeId)
        .get()
    );
    log('green', '✅ PASS: User A can read their own recipe');

    // Test 3: User B CANNOT read User A's recipe (CRITICAL SECURITY TEST)
    log('yellow', '\n🚫 Test 3: User B tries to read User A\'s recipe (should FAIL)');
    const userBContext = testEnv.authenticatedContext(userBId);
    await assertFails(
      userBContext.firestore()
        .collection('users').doc(userAId)
        .collection('recipes').doc(recipeId)
        .get()
    );
    log('green', '✅ PASS: User B cannot read User A\'s private recipe');

    // Test 4: Unauthenticated user CANNOT read recipes
    log('yellow', '\n🚫 Test 4: Unauthenticated user tries to read recipe (should FAIL)');
    const unauthContext = testEnv.unauthenticatedContext();
    await assertFails(
      unauthContext.firestore()
        .collection('users').doc(userAId)
        .collection('recipes').doc(recipeId)
        .get()
    );
    log('green', '✅ PASS: Unauthenticated users cannot read recipes');

    // Test 5: Create a share document
    log('yellow', '\n🔗 Test 5: User A creates a share');
    await assertSucceeds(
      userAContext.firestore()
        .collection('shares').doc(shareId)
        .set({
          shareId: shareId,
          recipeId: recipeId,
          ownerId: userAId,
          ownerName: 'User A',
          acceptedBy: [],
          createdAt: new Date(),
        })
    );
    log('green', '✅ PASS: User A can create a share');

    // Test 6: User B accepts the share
    log('yellow', '\n✅ Test 6: User B accepts the share');
    await assertSucceeds(
      userBContext.firestore()
        .collection('shares').doc(shareId)
        .update({
          acceptedBy: admin.firestore.FieldValue.arrayUnion(userBId),
        })
    );
    log('green', '✅ PASS: User B can accept the share');

    // Test 7: User B can NOW read the shared recipe
    log('yellow', '\n📖 Test 7: User B reads shared recipe');
    await assertSucceeds(
      userBContext.firestore()
        .collection('users').doc(userAId)
        .collection('recipes').doc(recipeId)
        .get()
    );
    log('green', '✅ PASS: User B can read shared recipe');

    // Test 8: User B CANNOT update User A's recipe
    log('yellow', '\n🚫 Test 8: User B tries to update User A\'s recipe (should FAIL)');
    await assertFails(
      userBContext.firestore()
        .collection('users').doc(userAId)
        .collection('recipes').doc(recipeId)
        .update({ title: 'Modified by User B' })
    );
    log('green', '✅ PASS: User B cannot update User A\'s recipe');

    // Test 9: User B CANNOT delete User A's recipe
    log('yellow', '\n🚫 Test 9: User B tries to delete User A\'s recipe (should FAIL)');
    await assertFails(
      userBContext.firestore()
        .collection('users').doc(userAId)
        .collection('recipes').doc(recipeId)
        .delete()
    );
    log('green', '✅ PASS: User B cannot delete User A\'s recipe');

    log('blue', '\n' + '='.repeat(50));
    log('blue', 'TEST SUITE: Storage Access Control');
    log('blue', '='.repeat(50));

    // Test 10: User A can read their own recipe images
    log('yellow', '\n📷 Test 10: User A reads their own recipe image');
    await assertSucceeds(
      userAContext.storage()
        .ref(`users/${userAId}/recipes/${recipeId}/image.jpg`)
        .getDownloadURL()
    );
    log('green', '✅ PASS: User A can read their own recipe images');

    // Test 11: User B CANNOT read User A's recipe images (even if shared)
    log('yellow', '\n🚫 Test 11: User B tries to read User A\'s recipe image (should FAIL)');
    log('yellow', '   Note: Storage rules only allow owner access. Sharing requires signed URLs.');
    await assertFails(
      userBContext.storage()
        .ref(`users/${userAId}/recipes/${recipeId}/image.jpg`)
        .getDownloadURL()
    );
    log('green', '✅ PASS: User B cannot directly access User A\'s recipe images');

    // Test 12: Unauthenticated user CANNOT read images
    log('yellow', '\n🚫 Test 12: Unauthenticated user tries to read recipe image (should FAIL)');
    await assertFails(
      unauthContext.storage()
        .ref(`users/${userAId}/recipes/${recipeId}/image.jpg`)
        .getDownloadURL()
    );
    log('green', '✅ PASS: Unauthenticated users cannot access recipe images');

    log('blue', '\n' + '='.repeat(50));
    log('green', '\n🎉 ALL TESTS PASSED!');
    log('blue', '='.repeat(50));

    log('yellow', '\n📊 Test Summary:');
    log('green', '  ✅ Recipe access control working correctly');
    log('green', '  ✅ Sharing mechanism working correctly');
    log('green', '  ✅ Storage access control working correctly');
    log('green', '  ✅ No unauthorized access possible');

    log('yellow', '\n⚠️  Important Notes:');
    log('yellow', '  • Recipe images require owner-only access in Storage Rules');
    log('yellow', '  • For shared recipes, use Firebase signed URLs or backend proxy');
    log('yellow', '  • All security rules are enforced server-side');

  } catch (error) {
    log('red', `\n❌ TEST FAILED: ${error.message}`);
    console.error(error);
    process.exit(1);
  } finally {
    if (testEnv) {
      await testEnv.cleanup();
      log('yellow', '\n🧹 Cleaned up test environment');
    }
  }
}

// Run tests
runSecurityTests().catch(error => {
  log('red', `\n💥 Fatal error: ${error.message}`);
  console.error(error);
  process.exit(1);
});
