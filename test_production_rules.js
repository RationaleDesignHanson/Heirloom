#!/usr/bin/env node
/**
 * Firebase Production Security Rules Manual Test Guide
 * Since we can't run emulator without Java, this script provides
 * manual test instructions and helps verify the rules are deployed
 */

const admin = require('firebase-admin');
const fs = require('fs');

// Color output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[36m',
  bold: '\x1b[1m',
};

function log(color, message) {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function section(title) {
  log('blue', '\n' + '='.repeat(60));
  log('bold', title);
  log('blue', '='.repeat(60));
}

async function checkRulesDeployment() {
  section('🔍 Firebase Security Rules Deployment Check');

  // Check if rules files exist
  log('yellow', '\n📄 Checking rules files...');

  const firestoreRulesExist = fs.existsSync('./firestore.rules');
  const storageRulesExist = fs.existsSync('./storage.rules');

  if (firestoreRulesExist) {
    log('green', '  ✅ firestore.rules found');

    // Read and show key rules
    const rules = fs.readFileSync('./firestore.rules', 'utf8');

    if (rules.includes('isOwner(userId)')) {
      log('green', '  ✅ Recipe owner check present');
    }

    if (rules.includes('isSharedWith')) {
      log('green', '  ✅ Share permission check present');
    }

    if (rules.includes('isKitchenTableMember')) {
      log('green', '  ✅ Kitchen Table check present');
    }
  } else {
    log('red', '  ❌ firestore.rules NOT found');
  }

  if (storageRulesExist) {
    log('green', '  ✅ storage.rules found');

    const storageRules = fs.readFileSync('./storage.rules', 'utf8');

    if (storageRules.includes('request.auth.uid == userId')) {
      log('green', '  ✅ Storage owner-only check present');
    }
  } else {
    log('red', '  ❌ storage.rules NOT found');
  }

  section('📋 Manual Testing Instructions');

  log('yellow', '\n🧪 Test Scenario 1: Create Two Test Users');
  log('blue', '  1. Open your Heirloom app');
  log('blue', '  2. Create first test account: test-a@heirloom.test');
  log('blue', '  3. Sign out');
  log('blue', '  4. Create second test account: test-b@heirloom.test');

  log('yellow', '\n🧪 Test Scenario 2: User A Creates Recipe');
  log('blue', '  1. Sign in as test-a@heirloom.test');
  log('blue', '  2. Create a recipe: "Test Recipe A"');
  log('blue', '  3. Note the recipe appears in your list');
  log('blue', '  4. Sign out');

  log('yellow', '\n🧪 Test Scenario 3: User B Cannot See User A\'s Recipe');
  log('blue', '  1. Sign in as test-b@heirloom.test');
  log('blue', '  2. Go to your recipes list');
  log('green', '  ✅ EXPECTED: You should NOT see "Test Recipe A"');
  log('red', '  ❌ IF YOU SEE IT: Security rules not working!');

  log('yellow', '\n🧪 Test Scenario 4: User A Shares Recipe with User B');
  log('blue', '  1. Sign in as test-a@heirloom.test');
  log('blue', '  2. Open "Test Recipe A"');
  log('blue', '  3. Tap Share button');
  log('blue', '  4. Generate share link');
  log('blue', '  5. Sign out');

  log('yellow', '\n🧪 Test Scenario 5: User B Accepts Share');
  log('blue', '  1. Sign in as test-b@heirloom.test');
  log('blue', '  2. Open the share link (or accept from notifications)');
  log('blue', '  3. Accept the shared recipe');
  log('green', '  ✅ EXPECTED: Recipe now appears in your shared recipes');
  log('green', '  ✅ EXPECTED: You can view but not edit');

  section('🔗 Quick Verification Links');

  log('yellow', '\nFirebase Console:');
  log('blue', '  • Firestore Rules: https://console.firebase.google.com/project/heirloom-ios-prod/firestore/rules');
  log('blue', '  • Storage Rules: https://console.firebase.google.com/project/heirloom-ios-prod/storage/rules');
  log('blue', '  • Authentication: https://console.firebase.google.com/project/heirloom-ios-prod/authentication/users');
  log('blue', '  • Firestore Data: https://console.firebase.google.com/project/heirloom-ios-prod/firestore/databases/-default-/data');

  section('✅ Security Rules Verification Checklist');

  log('yellow', '\nBefore App Store Release:');
  log('blue', '  [ ] Two test accounts created');
  log('blue', '  [ ] User A created a recipe');
  log('blue', '  [ ] User B CANNOT see User A\'s recipe');
  log('blue', '  [ ] User A shared recipe with User B');
  log('blue', '  [ ] User B CAN see shared recipe');
  log('blue', '  [ ] User B CANNOT edit shared recipe');
  log('blue', '  [ ] Checked Firebase Console to verify rules deployed');

  section('🚀 Next Steps');

  log('yellow', '\n1. Manual Testing (Option B)');
  log('blue', '   Open Firebase Console and verify:');
  log('blue', '   - Rules are deployed (check timestamps)');
  log('blue', '   - No test data exists yet');

  log('yellow', '\n2. App Testing (Option A)');
  log('blue', '   Follow the test scenarios above');

  log('yellow', '\n3. If Tests Pass');
  log('green', '   ✅ Security rules are working!');
  log('green', '   ✅ Ready to create Release build');

  log('yellow', '\n4. If Tests Fail');
  log('red', '   ❌ Review rules in Firebase Console');
  log('red', '   ❌ Check deployment logs');
  log('red', '   ❌ Re-deploy: firebase deploy --only firestore:rules,storage:rules');

  console.log('\n');
}

// Run check
checkRulesDeployment().catch(error => {
  log('red', `\n💥 Error: ${error.message}`);
  console.error(error);
  process.exit(1);
});
