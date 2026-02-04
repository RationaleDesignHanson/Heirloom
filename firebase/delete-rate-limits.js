const admin = require('firebase-admin');

const serviceAccount = require('./heirloom-ios-prod-firebase-adminsdk-cq6cd-af0ca8c006.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

async function deleteRateLimits() {
  console.log(`Deleting rate limits for user: ${userId}\n`);
  
  const operations = ['ai_complete', 'ai_vision', 'google_vision', 'brave_search'];
  
  for (const op of operations) {
    const docId = `${userId}:${op}`;
    try {
      await db.collection('rateLimits').doc(docId).delete();
      console.log(`✅ Deleted: ${docId}`);
    } catch (error) {
      console.log(`⚠️  Error deleting ${docId}:`, error.message);
    }
  }
  
  console.log('\n✅ Rate limits reset! New limits (after redeploy):');
  console.log('   - 400 vision AI requests (recipe extraction + multi-page analysis)');
  console.log('   - 1000 text AI requests');
  console.log('   - 1000 OCR requests');
  console.log('   - 1000 web searches');
  
  process.exit(0);
}

deleteRateLimits();
