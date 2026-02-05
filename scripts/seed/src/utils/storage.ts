/**
 * Firebase Storage upload utilities
 * Handles uploading images to Firebase Storage for seed data
 */

import { getStorageInstance } from './firebase.js';
import { createWriteStream } from 'fs';
import { pipeline } from 'stream/promises';
import { Readable } from 'stream';

const SEED_STORAGE_PATH = 'seed/demo';

/**
 * Upload image buffer to Firebase Storage
 * Returns the public download URL
 */
export async function uploadImageToStorage(
  imageBuffer: Buffer,
  filename: string,
  contentType: string = 'image/webp'
): Promise<string> {
  const storage = getStorageInstance();
  const bucket = storage.bucket();
  const filePath = `${SEED_STORAGE_PATH}/${filename}`;

  const file = bucket.file(filePath);

  await file.save(imageBuffer, {
    metadata: {
      contentType,
      cacheControl: 'public, max-age=31536000', // 1 year cache
    },
  });

  // Make the file publicly accessible
  await file.makePublic();

  // Return public URL
  const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;
  return publicUrl;
}

/**
 * Upload image from URL to Firebase Storage
 * Downloads the image and re-uploads to our storage
 */
export async function uploadImageFromUrl(
  imageUrl: string,
  filename: string
): Promise<string> {
  console.log(`Downloading image from: ${imageUrl}`);

  const response = await fetch(imageUrl);
  if (!response.ok) {
    throw new Error(`Failed to download image: ${response.statusText}`);
  }

  const contentType = response.headers.get('content-type') || 'image/webp';
  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  return uploadImageToStorage(buffer, filename, contentType);
}

/**
 * Check if a file exists in storage
 */
export async function fileExistsInStorage(filename: string): Promise<boolean> {
  const storage = getStorageInstance();
  const bucket = storage.bucket();
  const filePath = `${SEED_STORAGE_PATH}/${filename}`;

  const [exists] = await bucket.file(filePath).exists();
  return exists;
}

/**
 * Delete a file from storage
 */
export async function deleteFromStorage(filename: string): Promise<void> {
  const storage = getStorageInstance();
  const bucket = storage.bucket();
  const filePath = `${SEED_STORAGE_PATH}/${filename}`;

  try {
    await bucket.file(filePath).delete();
    console.log(`Deleted: ${filePath}`);
  } catch (error: any) {
    if (error.code === 404) {
      console.log(`File not found (already deleted): ${filePath}`);
    } else {
      throw error;
    }
  }
}

/**
 * Delete all seed images from storage
 */
export async function deleteAllSeedImages(): Promise<number> {
  const storage = getStorageInstance();
  const bucket = storage.bucket();

  const [files] = await bucket.getFiles({ prefix: SEED_STORAGE_PATH });

  let deletedCount = 0;
  for (const file of files) {
    await file.delete();
    console.log(`Deleted: ${file.name}`);
    deletedCount++;
  }

  return deletedCount;
}

/**
 * Get public URL for a seed file
 */
export function getSeedFileUrl(filename: string, bucketName: string): string {
  return `https://storage.googleapis.com/${bucketName}/${SEED_STORAGE_PATH}/${filename}`;
}
