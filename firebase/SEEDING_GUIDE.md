# Theme Seeding Guide

This guide walks you through seeding the 10 theme documents to Firestore.

---

## Prerequisites

1. ✅ Firestore rules deployed
2. ✅ Storage rules deployed
3. ✅ Node.js installed (v16 or higher)
4. ✅ Firebase project admin access

---

## Step 1: Get Service Account Key

You need a Firebase Admin SDK service account key to authenticate the seeding script.

### Option A: Firebase Console (Recommended)

1. Go to https://console.firebase.google.com
2. Select your **Heirloom** project
3. Click the **gear icon** ⚙️ → **Project settings**
4. Go to **Service accounts** tab
5. Click **Generate new private key**
6. Click **Generate key** in the confirmation dialog
7. A JSON file will download automatically

### Option B: Google Cloud Console

1. Go to https://console.cloud.google.com
2. Select your Heirloom project
3. Navigate to **IAM & Admin** → **Service Accounts**
4. Click on the Firebase Admin SDK service account
5. Go to **Keys** tab
6. Click **Add Key** → **Create new key**
7. Choose **JSON** format
8. Click **Create**

---

## Step 2: Save Service Account Key

1. Rename the downloaded file to `serviceAccountKey.json`
2. Move it to the firebase directory:
   ```bash
   mv ~/Downloads/heirloom-*-firebase-adminsdk-*.json /Users/matthanson/Heirloom/firebase/serviceAccountKey.json
   ```

**⚠️ SECURITY WARNING:**
- **Never commit this file to git!**
- It's already in `.gitignore`
- Keep it secure and private

---

## Step 3: Install Dependencies

```bash
cd /Users/matthanson/Heirloom/firebase
npm install
```

This installs `firebase-admin` package.

---

## Step 4: Run Seeding Script

```bash
npm run seed-themes
```

Or directly:
```bash
node seed-themes.js
```

**Expected Output:**
```
🔥 Starting theme seeding...

✓ Queued: Automat Classics (automat-classics)
✓ Queued: Golden Age of Rail (railroad-dining)
✓ Queued: Victory Kitchen (victory-kitchen)
✓ Queued: Navy Mess Hall (navy-mess)
✓ Queued: Boston Cooking School (boston-cooking-school)
✓ Queued: Southern Roots (southern-roots)
✓ Queued: Scandinavian Heritage (scandinavian-heritage)
✓ Queued: German-American Kitchen (german-american)
✓ Queued: Quick Weeknight Classics (quick-weeknight)
✓ Queued: Sunday Suppers (sunday-suppers)

✅ Successfully seeded 10 themes to Firestore!

📊 Theme Summary:
   - Total themes: 10
   - Successfully seeded: 10
   - Failed: 0

🎯 Next Steps:
   1. Verify themes in Firebase Console
   2. Run recipe seeding script
   3. Generate and upload cover images
```

---

## Step 5: Verify in Firebase Console

1. Go to https://console.firebase.google.com
2. Navigate to **Firestore Database**
3. Check for `/themes` collection
4. Verify 10 theme documents exist:
   - `automat-classics`
   - `railroad-dining`
   - `victory-kitchen`
   - `navy-mess`
   - `boston-cooking-school`
   - `southern-roots`
   - `scandinavian-heritage`
   - `german-american`
   - `quick-weeknight`
   - `sunday-suppers`

5. Click on any theme to verify fields:
   - `name`
   - `tagline`
   - `description`
   - `category`
   - `totalRecipes`
   - `unlockSchedule`
   - `sortOrder`
   - `createdAt`
   - `updatedAt`

---

## Troubleshooting

### Error: "ENOENT: no such file or directory, open 'serviceAccountKey.json'"

**Solution:** Make sure `serviceAccountKey.json` is in `/Users/matthanson/Heirloom/firebase/` directory.

```bash
ls -la /Users/matthanson/Heirloom/firebase/serviceAccountKey.json
```

### Error: "Permission denied"

**Solution:** Verify your service account has Firestore Admin permissions:
1. Go to Firebase Console → Project Settings → Service Accounts
2. Check that the service account has "Firebase Admin SDK" role

### Error: "PERMISSION_DENIED: Missing or insufficient permissions"

**Solution:**
1. Check that Firestore rules are deployed correctly
2. Verify the service account has admin access
3. Try regenerating the service account key

### Error: "Cannot find module 'firebase-admin'"

**Solution:** Install dependencies:
```bash
cd /Users/matthanson/Heirloom/firebase
npm install
```

---

## What This Script Does

1. **Connects to Firestore** using Admin SDK
2. **Creates 10 theme documents** in `/themes` collection
3. **Sets metadata** for each theme:
   - Display information (name, tagline, description)
   - Classification (category, source, era, region)
   - Content metadata (totalRecipes, unlockSchedule)
   - Timestamps (createdAt, updatedAt)
4. **Uses batch write** for efficiency (single network call)

---

## Data Seeded

The script seeds these 10 themes:

| ID | Name | Category | Total Recipes |
|---|---|---|---|
| automat-classics | Automat Classics | source | 14 |
| railroad-dining | Golden Age of Rail | source | 12 |
| victory-kitchen | Victory Kitchen | era | 14 |
| navy-mess | Navy Mess Hall | source | 14 |
| boston-cooking-school | Boston Cooking School | era | 14 |
| southern-roots | Southern Roots | cuisine | 14 |
| scandinavian-heritage | Scandinavian Heritage | cuisine | 12 |
| german-american | German-American Kitchen | cuisine | 14 |
| quick-weeknight | Quick Weeknight Classics | difficulty | 14 |
| sunday-suppers | Sunday Suppers | difficulty | 12 |

**Total:** 136 recipes across 10 themes

---

## Next Phase

After themes are seeded:

→ **Phase 3:** Build content pipeline for recipe seeding
→ **Phase 4:** Curate and upload 136 recipes
→ **Phase 4B:** Generate cover images for themes

---

## File Structure

```
/Users/matthanson/Heirloom/firebase/
├── seed-themes.js              # This seeding script
├── package.json                # Node.js dependencies
├── serviceAccountKey.json      # Service account (DO NOT COMMIT)
├── firestore.rules             # Firestore security rules
├── storage.rules               # Storage security rules
├── firestore.indexes.json      # Firestore indexes
├── SEEDING_GUIDE.md           # This file
└── DEPLOYMENT_GUIDE.md        # Deployment instructions
```

---

**Estimated Time:** 5-10 minutes (including key download and setup)
