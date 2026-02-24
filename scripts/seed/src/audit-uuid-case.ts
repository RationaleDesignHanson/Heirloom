/**
 * Audit UUID Case Consistency in Firebase
 *
 * Checks all Firestore collections for uppercase UUIDs that could cause
 * sync issues between Swift (uppercase) and seed scripts (lowercase).
 *
 * Run: npx ts-node src/audit-uuid-case.ts
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

// UUID regex pattern (matches both uppercase and lowercase)
const UUID_PATTERN = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

interface AuditResult {
  collection: string;
  documentId: string;
  field?: string;
  value?: string;
  issue: string;
}

const issues: AuditResult[] = [];
let totalDocumentsChecked = 0;

function hasUppercase(str: string): boolean {
  return str !== str.toLowerCase();
}

function isUUID(str: string): boolean {
  return UUID_PATTERN.test(str);
}

function checkValue(collection: string, docId: string, field: string, value: unknown): void {
  if (typeof value === 'string' && isUUID(value) && hasUppercase(value)) {
    issues.push({
      collection,
      documentId: docId,
      field,
      value,
      issue: 'Uppercase UUID in field value'
    });
  } else if (Array.isArray(value)) {
    value.forEach((item, index) => {
      if (typeof item === 'string' && isUUID(item) && hasUppercase(item)) {
        issues.push({
          collection,
          documentId: docId,
          field: `${field}[${index}]`,
          value: item,
          issue: 'Uppercase UUID in array'
        });
      }
    });
  }
}

async function auditUserData(userId: string): Promise<void> {
  // Check recipes subcollection
  const recipesSnapshot = await db.collection(`users/${userId}/recipes`).get();
  for (const doc of recipesSnapshot.docs) {
    totalDocumentsChecked++;

    // Check document ID
    if (isUUID(doc.id) && hasUppercase(doc.id)) {
      issues.push({
        collection: `users/${userId}/recipes`,
        documentId: doc.id,
        issue: 'Uppercase UUID as document ID'
      });
    }

    // Check specific fields that should contain UUIDs
    const data = doc.data();
    checkValue(`users/${userId}/recipes`, doc.id, 'collectionIds', data.collectionIds);
    checkValue(`users/${userId}/recipes`, doc.id, 'publicRecipeId', data.publicRecipeId);
    checkValue(`users/${userId}/recipes`, doc.id, 'sourcePublicRecipeId', data.sourcePublicRecipeId);
  }

  // Check collections subcollection
  const collectionsSnapshot = await db.collection(`users/${userId}/collections`).get();
  for (const doc of collectionsSnapshot.docs) {
    totalDocumentsChecked++;

    // Check document ID
    if (isUUID(doc.id) && hasUppercase(doc.id)) {
      issues.push({
        collection: `users/${userId}/collections`,
        documentId: doc.id,
        issue: 'Uppercase UUID as document ID'
      });
    }

    // Check recipeIds field
    const data = doc.data();
    checkValue(`users/${userId}/collections`, doc.id, 'recipeIds', data.recipeIds);
  }
}

async function auditShares(): Promise<void> {
  console.log('\nChecking shares collection...');
  const sharesSnapshot = await db.collection('shares').get();

  for (const doc of sharesSnapshot.docs) {
    totalDocumentsChecked++;

    // Check document ID (shareId)
    if (isUUID(doc.id) && hasUppercase(doc.id)) {
      issues.push({
        collection: 'shares',
        documentId: doc.id,
        issue: 'Uppercase UUID as document ID'
      });
    }

    // Check fields
    const data = doc.data();
    checkValue('shares', doc.id, 'recipeId', data.recipeId);
    checkValue('shares', doc.id, 'senderId', data.senderId);
    checkValue('shares', doc.id, 'recipientId', data.recipientId);
  }

  console.log(`  Checked ${sharesSnapshot.size} share documents`);
}

async function auditPublicRecipes(): Promise<void> {
  console.log('\nChecking publicRecipes collection...');
  const publicSnapshot = await db.collection('publicRecipes').get();

  for (const doc of publicSnapshot.docs) {
    totalDocumentsChecked++;

    // Check document ID (publicRecipeId)
    if (isUUID(doc.id) && hasUppercase(doc.id)) {
      issues.push({
        collection: 'publicRecipes',
        documentId: doc.id,
        issue: 'Uppercase UUID as document ID'
      });
    }

    // Check sourceRecipeId
    const data = doc.data();
    checkValue('publicRecipes', doc.id, 'sourceRecipeId', data.sourceRecipeId);
    checkValue('publicRecipes', doc.id, 'ownerId', data.ownerId);
  }

  console.log(`  Checked ${publicSnapshot.size} public recipe documents`);
}

async function auditConnections(): Promise<void> {
  console.log('\nChecking connections collection...');
  const connectionsSnapshot = await db.collection('connections').get();

  for (const doc of connectionsSnapshot.docs) {
    totalDocumentsChecked++;

    // Check document ID (connectionId)
    if (isUUID(doc.id) && hasUppercase(doc.id)) {
      issues.push({
        collection: 'connections',
        documentId: doc.id,
        issue: 'Uppercase UUID as document ID'
      });
    }
  }

  console.log(`  Checked ${connectionsSnapshot.size} connection documents`);
}

async function fixPublicRecipes(): Promise<void> {
  console.log('\nFixing publicRecipes with uppercase UUIDs...\n');

  const snapshot = await db.collection('publicRecipes').get();
  let fixed = 0;
  let deleted = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const oldId = doc.id;

    // Check if document ID has uppercase
    if (isUUID(oldId) && hasUppercase(oldId)) {
      const newId = oldId.toLowerCase();

      // Check if lowercase version already exists
      const existingDoc = await db.collection('publicRecipes').doc(newId).get();
      if (existingDoc.exists) {
        // Delete the uppercase duplicate
        console.log(`  Deleting duplicate: ${oldId} (lowercase ${newId} exists)`);
        await db.collection('publicRecipes').doc(oldId).delete();
        deleted++;
      } else {
        // Migrate to lowercase ID
        const newData = { ...data };

        // Also fix sourceRecipeId if it has uppercase
        if (typeof newData.sourceRecipeId === 'string' && hasUppercase(newData.sourceRecipeId)) {
          newData.sourceRecipeId = newData.sourceRecipeId.toLowerCase();
        }

        console.log(`  Migrating: ${oldId} -> ${newId}`);
        await db.collection('publicRecipes').doc(newId).set(newData);
        await db.collection('publicRecipes').doc(oldId).delete();
        fixed++;
      }
    }
  }

  console.log(`\n✅ Fixed ${fixed} documents, deleted ${deleted} duplicates`);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const shouldFix = args.includes('--fix');

  if (shouldFix) {
    console.log('='.repeat(60));
    console.log('UUID Case Fix Mode');
    console.log('='.repeat(60));
    await fixPublicRecipes();
    console.log('\nRe-running audit to verify...\n');
  }

  console.log('='.repeat(60));
  console.log('UUID Case Consistency Audit');
  console.log('='.repeat(60));
  console.log('\nScanning Firebase for uppercase UUIDs...\n');

  // Get all users
  console.log('Checking user data...');
  const usersSnapshot = await db.collection('users').get();
  console.log(`  Found ${usersSnapshot.size} users`);

  let userCount = 0;
  for (const userDoc of usersSnapshot.docs) {
    userCount++;
    process.stdout.write(`\r  Processing user ${userCount}/${usersSnapshot.size}: ${userDoc.id.substring(0, 20)}...`);
    await auditUserData(userDoc.id);
  }
  console.log('\n  Done checking user data');

  // Check top-level collections
  await auditShares();
  await auditPublicRecipes();
  await auditConnections();

  // Print results
  console.log('\n' + '='.repeat(60));
  console.log('AUDIT RESULTS');
  console.log('='.repeat(60));
  console.log(`\nTotal documents checked: ${totalDocumentsChecked}`);
  console.log(`Issues found: ${issues.length}`);

  if (issues.length === 0) {
    console.log('\n✅ No uppercase UUID issues found! All UUIDs are lowercase.');
  } else {
    console.log('\n❌ Found uppercase UUID issues:\n');

    // Group by collection
    const byCollection = new Map<string, AuditResult[]>();
    for (const issue of issues) {
      const key = issue.collection;
      if (!byCollection.has(key)) {
        byCollection.set(key, []);
      }
      byCollection.get(key)!.push(issue);
    }

    for (const [collection, collectionIssues] of byCollection) {
      console.log(`\n📁 ${collection} (${collectionIssues.length} issues):`);
      for (const issue of collectionIssues.slice(0, 5)) {
        if (issue.field) {
          console.log(`   - Doc ${issue.documentId.substring(0, 8)}... field "${issue.field}": ${issue.value}`);
        } else {
          console.log(`   - Doc ID: ${issue.documentId}`);
        }
      }
      if (collectionIssues.length > 5) {
        console.log(`   ... and ${collectionIssues.length - 5} more`);
      }
    }

    console.log('\n⚠️  These uppercase UUIDs may cause sync issues.');
    console.log('   Run with --fix flag to convert them to lowercase (not implemented yet).');
  }

  console.log('\n');
  process.exit(issues.length > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('Audit failed:', error);
  process.exit(1);
});
