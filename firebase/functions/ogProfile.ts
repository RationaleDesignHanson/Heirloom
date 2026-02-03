/**
 * Firebase Cloud Function for generating Open Graph meta tags and images
 * for public profile URLs
 *
 * Phase 10: Public Profile URLs
 *
 * Deployment Instructions:
 * 1. cd firebase/functions
 * 2. npm install
 * 3. firebase deploy --only functions:ogProfile
 *
 * URL Pattern:
 * https://us-central1-heirloom-ios-prod.cloudfunctions.net/ogProfile?userId={userId}
 *
 * Or via Firebase Hosting rewrite in firebase.json:
 * /u/{userId} -> ogProfile function
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface UserProfile {
  userId: string;
  displayName: string;
  bio?: string;
  photoURL?: string;
  location?: string;
  connectionCount: number;
  sharedRecipeCount: number;
  heritageGenerationCount: number;
}

/**
 * Generate Open Graph HTML for profile URLs
 *
 * This function fetches the user's profile from Firestore and generates
 * HTML with Open Graph meta tags for rich link previews in Messages, Twitter, etc.
 */
export const ogProfile = functions.https.onRequest(async (req, res) => {
  try {
    // Extract userId from query parameter
    const userId = req.query.userId as string;

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

    const profileData = profileDoc.data() as UserProfile;

    // Check if profile is public (visibility = "open")
    const visibility = (profileData as any)['profileVisibility'] || 'closed';
    if (visibility !== 'open') {
      res.status(403).send('Profile is not public');
      return;
    }

    // Generate Open Graph meta tags
    const ogTitle = `${profileData.displayName} - Heirloom`;
    const ogDescription = profileData.bio ||
      `${profileData.displayName} shares family recipes on Heirloom. ${profileData.sharedRecipeCount} shared recipes, ${profileData.connectionCount} connections.`;
    const ogImage = profileData.photoURL ||
      'https://heirloom-ios-prod.web.app/default-profile-og.png'; // You'll need to create this default image
    const ogUrl = `https://heirloom-ios-prod.web.app/u/${userId}`;

    // Generate HTML with Open Graph meta tags
    const html = `
<!DOCTYPE html>
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
        <div class="stat-value">${profileData.sharedRecipeCount}</div>
        <div class="stat-label">Recipes</div>
      </div>
      <div class="stat">
        <div class="stat-value">${profileData.connectionCount}</div>
        <div class="stat-label">Connections</div>
      </div>
      <div class="stat">
        <div class="stat-value">${profileData.heritageGenerationCount}</div>
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
</html>
    `;

    // Set content type and send response
    res.set('Content-Type', 'text/html');
    res.set('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour
    res.status(200).send(html);

  } catch (error) {
    console.error('Error generating OG profile:', error);
    res.status(500).send('Internal server error');
  }
});
