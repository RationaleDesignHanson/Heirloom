#!/usr/bin/env node

/**
 * Deploy Firestore Rules Script
 * Deploys updated Firestore security rules to Firebase
 *
 * Usage: node deploy-firestore-rules.js
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// Read service account key
const serviceAccount = require('./serviceAccountKey.json');
const projectId = serviceAccount.project_id;

// Read rules file
const rulesPath = path.join(__dirname, 'firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

console.log('🔥 Deploying Firestore rules...\n');
console.log(`Project: ${projectId}\n`);

// Get OAuth token
async function getAccessToken() {
  const { GoogleAuth } = require('google-auth-library');
  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/cloud-platform']
  });

  const client = await auth.getClient();
  const token = await client.getAccessToken();
  return token.token;
}

async function deployRules() {
  try {
    const accessToken = await getAccessToken();

    const requestBody = JSON.stringify({
      source: {
        files: [{
          name: 'firestore.rules',
          content: rules
        }]
      }
    });

    const options = {
      hostname: 'firebaserules.googleapis.com',
      path: `/v1/projects/${projectId}/rulesets`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(requestBody)
      }
    };

    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200 || res.statusCode === 201) {
            const response = JSON.parse(data);
            resolve(response.name);
          } else {
            reject(new Error(`Failed to create ruleset: ${res.statusCode} ${data}`));
          }
        });
      });

      req.on('error', reject);
      req.write(requestBody);
      req.end();
    });
  } catch (error) {
    throw new Error(`Failed to get access token: ${error.message}`);
  }
}

async function activateRuleset(rulesetName) {
  const accessToken = await getAccessToken();

  const requestBody = JSON.stringify({
    name: `projects/${projectId}/releases/cloud.firestore`,
    ruleset: rulesetName
  });

  const options = {
    hostname: 'firebaserules.googleapis.com',
    path: `/v1/projects/${projectId}/releases/cloud.firestore`,
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(requestBody)
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve();
        } else {
          reject(new Error(`Failed to activate ruleset: ${res.statusCode} ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(requestBody);
    req.end();
  });
}

async function main() {
  try {
    console.log('📤 Creating new ruleset...');
    const rulesetName = await deployRules();
    console.log(`✓ Created ruleset: ${rulesetName}\n`);

    console.log('🔄 Activating ruleset...');
    await activateRuleset(rulesetName);
    console.log('✓ Ruleset activated\n');

    console.log('✅ Firestore rules deployed successfully!');
    console.log('\n🎯 Next Steps:');
    console.log('   1. Restart the app to download recipes');
    console.log('   2. Verify recipes appear in theme collections');
    console.log('   3. Check that images load correctly');

    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to deploy rules:', error.message);
    console.error('\n💡 Manual deployment:');
    console.error('   1. Go to Firebase Console: https://console.firebase.google.com');
    console.error('   2. Select project: heirloom-ios-prod');
    console.error('   3. Go to Firestore Database → Rules');
    console.error('   4. Copy the rules from firestore.rules and publish');
    process.exit(1);
  }
}

main();
