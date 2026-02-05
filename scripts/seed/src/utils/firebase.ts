/**
 * Firebase Admin SDK initialization
 * Provides Firestore and Storage access for seeding
 */

import { initializeApp, cert, getApps, App } from 'firebase-admin/app';
import { getFirestore, Firestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage, Storage } from 'firebase-admin/storage';
import { config } from 'dotenv';
import { resolve } from 'path';

// Load environment variables
config({ path: resolve(__dirname, '../../.env') });

// Singleton instances
let app: App | null = null;
let db: Firestore | null = null;
let storage: Storage | null = null;

/**
 * Initialize Firebase Admin SDK
 * Uses service account from GOOGLE_APPLICATION_CREDENTIALS env var
 */
export function initializeFirebase(): { db: Firestore; storage: Storage } {
  if (db && storage) {
    return { db, storage };
  }

  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const storageBucket = process.env.FIREBASE_STORAGE_BUCKET;

  if (!serviceAccountPath) {
    throw new Error('GOOGLE_APPLICATION_CREDENTIALS environment variable not set');
  }

  if (!storageBucket) {
    throw new Error('FIREBASE_STORAGE_BUCKET environment variable not set');
  }

  // Resolve relative path from scripts/seed directory
  const absolutePath = resolve(__dirname, '../..', serviceAccountPath);

  console.log(`Initializing Firebase with service account: ${absolutePath}`);
  console.log(`Storage bucket: ${storageBucket}`);

  if (getApps().length === 0) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const serviceAccount = require(absolutePath);

    app = initializeApp({
      credential: cert(serviceAccount),
      storageBucket: storageBucket,
    });
  } else {
    app = getApps()[0];
  }

  db = getFirestore();
  storage = getStorage();

  return { db, storage };
}

/**
 * Get Firestore instance (must call initializeFirebase first)
 */
export function getDb(): Firestore {
  if (!db) {
    throw new Error('Firebase not initialized. Call initializeFirebase() first.');
  }
  return db;
}

/**
 * Get Storage instance (must call initializeFirebase first)
 */
export function getStorageInstance(): Storage {
  if (!storage) {
    throw new Error('Firebase not initialized. Call initializeFirebase() first.');
  }
  return storage;
}

/**
 * Convert Date to Firestore Timestamp
 */
export function toTimestamp(date: Date): Timestamp {
  return Timestamp.fromDate(date);
}

/**
 * Get date relative to now (for seed data)
 */
export function daysAgo(days: number): Date {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date;
}

// Re-export Firestore types
export { Timestamp, Firestore };
