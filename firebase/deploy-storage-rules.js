#!/usr/bin/env node

/**
 * Deploy Firebase Storage Rules
 * Deploys storage.rules to Firebase
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const rulesFile = path.join(__dirname, 'storage.rules');

if (!fs.existsSync(rulesFile)) {
  console.error('❌ storage.rules file not found');
  process.exit(1);
}

console.log('🔥 Deploying Firebase Storage Rules...\n');
console.log('📄 Rules file:', rulesFile);
console.log('\n');

try {
  // Deploy using Firebase CLI
  execSync('firebase deploy --only storage', {
    cwd: __dirname,
    stdio: 'inherit'
  });

  console.log('\n✅ Storage rules deployed successfully!');
  console.log('\n🎯 Next Steps:');
  console.log('   1. Test image loading: https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/recipes/victory-kitchen/victory-kitchen-carrot-cookies.webp');
  console.log('   2. Rebuild and run the app');
  console.log('   3. Images should now load correctly');

  process.exit(0);
} catch (error) {
  console.error('\n❌ Deployment failed');
  console.error('\n💡 Manual deployment:');
  console.error('   1. Go to Firebase Console → Storage → Rules');
  console.error('   2. Copy contents of storage.rules');
  console.error('   3. Paste and publish');
  process.exit(1);
}
