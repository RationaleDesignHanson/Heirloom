/**
 * Cloud Functions for Heirloom
 * Phase 7 Enhanced: Algolia user sync
 * Phase 10: Public Profile URLs
 * Phase 11: Public Recipe Discovery
 */

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onRequest, onCall } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const algoliasearch = require('algoliasearch');

initializeApp();
const db = getFirestore();

// Initialize Algolia client
const client = algoliasearch(
  'A1DITUD2QN',
  'e07b85696f6d023e0ac63434db054d16' // Admin API key (write access)
);
const index = client.initIndex('users');

/**
 * Sync user profile to Algolia
 * Triggered on create/update/delete of users/{userId}/profile/data
 */
exports.syncUserToAlgolia = onDocumentWritten('users/{userId}/profile/data', async (event) => {
  const userId = event.params.userId;
  const change = event.data;

  // Delete from Algolia if document was removed
  if (!change.after.exists) {
    console.log(`Deleting user ${userId} from Algolia`);
    await index.deleteObject(userId);
    return null;
  }

  const data = change.after.data();

  // Don't index if user has hidden their profile from search
  if (data.privacySettings?.hideFromSearch === true) {
    console.log(`User ${userId} has hideFromSearch=true, removing from Algolia`);
    await index.deleteObject(userId);
    return null;
  }

  // Prepare Algolia object
  const algoliaObject = {
    objectID: userId,
    displayName: data.displayName || '',
    photoURL: data.photoURL || null,
    bio: data.bio || null,
    location: data.location || null,
    specialties: data.specialties || [],
    connectionCount: data.connectionCount || 0,
    isVerified: data.isVerified || false,
    // Add timestamp for freshness ranking
    updatedAt: Timestamp.now().seconds
  };

  // Save to Algolia
  console.log(`Syncing user ${userId} (${data.displayName}) to Algolia`);
  await index.saveObject(algoliaObject);

  return null;
});

/**
 * Generate Open Graph HTML for public profile URLs
 * Phase 10: Public Profile URLs
 *
 * URL Pattern: /u/{userId} (via Firebase Hosting rewrite)
 * Direct URL: https://us-central1-heirloom-ios-prod.cloudfunctions.net/ogProfile?userId={userId}
 */
exports.ogProfile = onRequest(async (req, res) => {
  try {
    // Extract userId from query parameter or path
    const userId = req.query.userId || req.path.split('/').pop();

    if (!userId) {
      res.status(400).send('Missing userId parameter');
      return;
    }

    // Fetch user profile from Firestore
    const profileDoc = await db
      .collection('users')
      .doc(userId)
      .collection('profile')
      .doc('data')
      .get();

    if (!profileDoc.exists) {
      res.status(404).send('Profile not found');
      return;
    }

    const profileData = profileDoc.data();

    // Check if profile is public (visibility = "open")
    const visibility = profileData.profileVisibility || 'closed';
    if (visibility !== 'open') {
      res.status(403).send('Profile is not public');
      return;
    }

    // Generate Open Graph meta tags
    const ogTitle = `${profileData.displayName} - Heirloom`;
    const ogDescription = profileData.bio ||
      `${profileData.displayName} shares family recipes on Heirloom. ${profileData.sharedRecipeCount || 0} shared recipes, ${profileData.connectionCount || 0} connections.`;
    const ogImage = profileData.photoURL ||
      'https://heirloom-ios-prod.web.app/default-profile-og.png';
    const ogUrl = `https://heirloom-ios-prod.web.app/u/${userId}`;

    // Generate HTML with Open Graph meta tags
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- Open Graph / Facebook -->
  <meta property="og:type" content="profile">
  <meta property="og:url" content="${ogUrl}">
  <meta property="og:title" content="${ogTitle}">
  <meta property="og:description" content="${ogDescription}">
  <meta property="og:image" content="${ogImage}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">

  <!-- Twitter -->
  <meta property="twitter:card" content="summary_large_image">
  <meta property="twitter:url" content="${ogUrl}">
  <meta property="twitter:title" content="${ogTitle}">
  <meta property="twitter:description" content="${ogDescription}">
  <meta property="twitter:image" content="${ogImage}">

  <!-- App Store / iOS -->
  <meta name="apple-itunes-app" content="app-id=YOUR_APP_STORE_ID">

  <!-- Profile-specific meta -->
  <meta property="profile:username" content="${profileData.displayName}">

  <title>${ogTitle}</title>

  <!-- Redirect to app or app store -->
  <script>
    // Attempt to open the app
    window.location.href = 'heirloom://profile/${userId}';

    // Fallback to App Store after 1 second if app doesn't open
    setTimeout(function() {
      // Replace with your actual App Store URL
      window.location.href = 'https://apps.apple.com/app/heirloom/YOUR_APP_STORE_ID';
    }, 1000);
  </script>

  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      text-align: center;
    }
    .profile-card {
      background: rgba(255, 255, 255, 0.1);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 40px;
      max-width: 400px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    }
    .avatar {
      width: 120px;
      height: 120px;
      border-radius: 50%;
      margin: 0 auto 20px;
      object-fit: cover;
      border: 4px solid rgba(255, 255, 255, 0.3);
    }
    h1 {
      margin: 0 0 10px;
      font-size: 28px;
    }
    .bio {
      opacity: 0.9;
      margin: 0 0 20px;
      line-height: 1.5;
    }
    .stats {
      display: flex;
      gap: 20px;
      justify-content: center;
      margin-top: 20px;
    }
    .stat {
      text-align: center;
    }
    .stat-value {
      font-size: 24px;
      font-weight: bold;
    }
    .stat-label {
      font-size: 14px;
      opacity: 0.8;
    }
    .cta {
      margin-top: 30px;
      padding: 15px 30px;
      background: white;
      color: #667eea;
      border-radius: 25px;
      text-decoration: none;
      font-weight: 600;
      display: inline-block;
    }
  </style>
</head>
<body>
  <div class="profile-card">
    ${profileData.photoURL ? `<img src="${profileData.photoURL}" alt="${profileData.displayName}" class="avatar">` : ''}
    <h1>${profileData.displayName}</h1>
    ${profileData.bio ? `<p class="bio">${profileData.bio}</p>` : ''}
    ${profileData.location ? `<p style="opacity: 0.8;">📍 ${profileData.location}</p>` : ''}

    <div class="stats">
      <div class="stat">
        <div class="stat-value">${profileData.sharedRecipeCount || 0}</div>
        <div class="stat-label">Recipes</div>
      </div>
      <div class="stat">
        <div class="stat-value">${profileData.connectionCount || 0}</div>
        <div class="stat-label">Connections</div>
      </div>
      <div class="stat">
        <div class="stat-value">${profileData.heritageGenerationCount || 0}</div>
        <div class="stat-label">Generations</div>
      </div>
    </div>

    <a href="heirloom://profile/${userId}" class="cta">
      Open in Heirloom
    </a>

    <p style="margin-top: 20px; font-size: 14px; opacity: 0.7;">
      Opening the Heirloom app...
    </p>
  </div>
</body>
</html>`;

    // Set content type and send response
    res.set('Content-Type', 'text/html');
    res.set('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour
    res.status(200).send(html);

  } catch (error) {
    console.error('Error generating OG profile:', error);
    res.status(500).send('Internal server error');
  }
});

/**
 * Increment public recipe view count
 * Phase 11: Public Recipe Discovery
 *
 * Callable function that atomically increments the view count for a public recipe.
 * Called when a user views a public recipe detail page.
 *
 * @param {Object} data - { recipeId: string }
 * @returns {Object} { success: boolean, viewCount: number }
 */
exports.incrementPublicRecipeView = onCall(async (request) => {
  try {
    const { recipeId } = request.data;

    // Validate input
    if (!recipeId || typeof recipeId !== 'string') {
      throw new Error('Invalid recipeId parameter');
    }

    // Get reference to public recipe document
    const recipeRef = db.collection('publicRecipes').doc(recipeId);

    // Check if recipe exists
    const recipeDoc = await recipeRef.get();
    if (!recipeDoc.exists) {
      throw new Error('Public recipe not found');
    }

    // Atomically increment view count
    await recipeRef.update({
      viewCount: FieldValue.increment(1),
      updatedAt: Timestamp.now()
    });

    // Fetch updated view count
    const updatedDoc = await recipeRef.get();
    const newViewCount = updatedDoc.data().viewCount;

    console.log(`Incremented view count for recipe ${recipeId} to ${newViewCount}`);

    return {
      success: true,
      viewCount: newViewCount
    };

  } catch (error) {
    console.error('Error incrementing view count:', error);
    throw error;
  }
});

/**
 * Increment public recipe save count
 * Phase 11: Public Recipe Discovery
 *
 * Callable function that atomically increments the save count for a public recipe.
 * Called when a user saves a public recipe to their collection.
 *
 * @param {Object} data - { recipeId: string }
 * @returns {Object} { success: boolean, saveCount: number }
 */
exports.incrementPublicRecipeSave = onCall(async (request) => {
  try {
    const { recipeId } = request.data;

    // Validate input
    if (!recipeId || typeof recipeId !== 'string') {
      throw new Error('Invalid recipeId parameter');
    }

    // Require authentication for saves (prevent spam)
    if (!request.auth) {
      throw new Error('Authentication required to save recipes');
    }

    // Get reference to public recipe document
    const recipeRef = db.collection('publicRecipes').doc(recipeId);

    // Check if recipe exists
    const recipeDoc = await recipeRef.get();
    if (!recipeDoc.exists) {
      throw new Error('Public recipe not found');
    }

    // Atomically increment save count
    await recipeRef.update({
      saveCount: FieldValue.increment(1),
      updatedAt: Timestamp.now()
    });

    // Fetch updated save count
    const updatedDoc = await recipeRef.get();
    const newSaveCount = updatedDoc.data().saveCount;

    console.log(`Incremented save count for recipe ${recipeId} to ${newSaveCount} by user ${request.auth.uid}`);

    return {
      success: true,
      saveCount: newSaveCount
    };

  } catch (error) {
    console.error('Error incrementing save count:', error);
    throw error;
  }
});

/**
 * Calculate trending scores for public recipes
 * Phase 11: Public Recipe Discovery
 *
 * Scheduled function that runs daily to recalculate trending scores based on:
 * - View count (weight: 0.3)
 * - Save count (weight: 5.0)
 * - Recency boost (exponential decay over 30 days)
 *
 * Runs every day at 2:00 AM UTC
 */
exports.calculateTrendingScores = onSchedule('0 2 * * *', async (event) => {
  try {
    console.log('Starting trending score calculation...');

    // Fetch all public recipes
    const recipesSnapshot = await db.collection('publicRecipes').get();

    if (recipesSnapshot.empty) {
      console.log('No public recipes found');
      return null;
    }

    const batch = db.batch();
    let updateCount = 0;
    const now = new Date();

    for (const doc of recipesSnapshot.docs) {
      const data = doc.data();
      const publishedAt = data.publishedAt ? data.publishedAt.toDate() : now;

      // Calculate recency boost (exponential decay)
      const daysSincePublish = (now - publishedAt) / (1000 * 60 * 60 * 24);
      let recencyBoost = 0;

      if (daysSincePublish <= 2) {
        recencyBoost = 20.0;
      } else if (daysSincePublish <= 7) {
        recencyBoost = 20.0 * Math.exp(-daysSincePublish / 7.0);
      } else if (daysSincePublish <= 30) {
        recencyBoost = 20.0 * Math.exp(-daysSincePublish / 15.0);
      } else {
        recencyBoost = 0.0;
      }

      // Calculate trending score
      const viewCount = data.viewCount || 0;
      const saveCount = data.saveCount || 0;
      const trendingScore = Math.min(
        (viewCount * 0.3) + (saveCount * 5.0) + recencyBoost,
        100.0
      );

      // Update recipe with new trending score
      batch.update(doc.ref, {
        trendingScore: trendingScore,
        lastTrendingCalculation: Timestamp.now()
      });

      updateCount++;

      // Commit batch every 500 operations (Firestore limit)
      if (updateCount % 500 === 0) {
        await batch.commit();
        console.log(`Committed batch of 500 updates (total: ${updateCount})`);
      }
    }

    // Commit remaining updates
    if (updateCount % 500 !== 0) {
      await batch.commit();
    }

    console.log(`Trending score calculation complete. Updated ${updateCount} recipes.`);
    return null;

  } catch (error) {
    console.error('Error calculating trending scores:', error);
    throw error;
  }
});
