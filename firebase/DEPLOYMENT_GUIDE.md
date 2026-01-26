# Firebase Deployment Guide
## Heirloom Theme Collections

**Date:** January 26, 2026
**Purpose:** Deploy Firebase infrastructure for theme-based recipe discovery

---

## Prerequisites

- Firebase Console access: https://console.firebase.google.com
- Firebase CLI installed (optional, for command-line deployment)
- Admin access to Heirloom Firebase project

---

## Step 1: Deploy Firestore Security Rules

### Option A: Firebase Console (Recommended)

1. Go to https://console.firebase.google.com
2. Select your Heirloom project
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the contents of `firestore.rules` file
5. Paste into the editor
6. Click **Publish**

### Option B: Firebase CLI

```bash
cd /Users/matthanson/Heirloom
firebase deploy --only firestore:rules
```

**Expected Output:**
```
✔ Deploy complete!
Firestore Rules deployed successfully
```

---

## Step 2: Deploy Firestore Indexes

### Option A: Firebase Console

1. Go to **Firestore Database** → **Indexes** tab
2. Click **Add Index**

**Index 1: Themes by Category**
- Collection ID: `themes`
- Fields to index:
  - `category` (Ascending)
  - `sortOrder` (Ascending)
- Query scope: Collection
- Click **Create**

**Index 2: Recipes by Unlock Day**
- Collection group ID: `recipes`
- Fields to index:
  - `unlockDay` (Ascending)
  - `sortOrder` (Ascending)
- Query scope: Collection group
- Click **Create**

### Option B: Firebase CLI (Recommended)

```bash
cd /Users/matthanson/Heirloom
firebase deploy --only firestore:indexes
```

**Wait for indexes to build** (usually 5-10 minutes). Check status:
- Go to **Firestore Database** → **Indexes** tab
- Look for "Building..." status

---

## Step 3: Deploy Storage Security Rules

### Option A: Firebase Console

1. Go to **Storage** → **Rules** tab
2. Copy the contents of `storage.rules` file
3. Paste into the editor
4. Click **Publish**

### Option B: Firebase CLI

```bash
cd /Users/matthanson/Heirloom
firebase deploy --only storage
```

---

## Step 4: Create Storage Folder Structure

Go to **Storage** → **Files** tab and create these folders:

```
/ (root)
├── themes/           (for theme cover images)
└── recipes/          (for recipe images, organized by theme)
    ├── automat-classics/
    ├── railroad-dining/
    ├── victory-kitchen/
    ├── navy-mess/
    ├── boston-cooking-school/
    ├── southern-roots/
    ├── scandinavian-heritage/
    ├── german-american/
    ├── quick-weeknight/
    └── sunday-suppers/
```

**Note:** Folders are automatically created when you upload files to them.

---

## Step 5: Verify Deployment

### Test Firestore Rules

1. Go to **Firestore Database** → **Rules** tab
2. Click **Simulator**
3. Test read access:
   - Location: `/themes/automat-classics`
   - Authenticated: Yes
   - Expected: ✅ Allow

### Test Storage Rules

1. Go to **Storage** → **Rules** tab
2. Click **Simulator**
3. Test read access:
   - File: `themes/automat-classics.jpg`
   - Authenticated: Yes
   - Expected: ✅ Allow

---

## Step 6: Initial Data Seeding (Next Phase)

After infrastructure is deployed, proceed to seeding theme metadata:

1. Run theme seeding script (see `SEEDING_GUIDE.md`)
2. Verify themes appear in Firestore Console
3. Upload cover images to Storage

---

## Troubleshooting

### Issue: Index Build Failing

**Solution:** Delete and recreate the index. Check for:
- Correct field names (case-sensitive)
- Correct order (Ascending/Descending)
- Collection vs Collection Group scope

### Issue: Rules Syntax Error

**Solution:** Validate rules syntax:
```bash
firebase deploy --only firestore:rules --dry-run
```

### Issue: Storage Upload Permission Denied

**Solution:** Check:
- User is authenticated
- Storage rules are deployed
- Bucket name is correct

---

## Firebase CLI Setup (Optional)

If you haven't installed Firebase CLI:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize project (if not already done)
cd /Users/matthanson/Heirloom
firebase init

# Select:
# - Firestore
# - Storage
# - Use existing project: heirloom
```

---

## Deployment Checklist

- [ ] Firestore rules deployed
- [ ] Firestore indexes created (and built)
- [ ] Storage rules deployed
- [ ] Storage folders created
- [ ] Rules tested in simulator
- [ ] Ready for data seeding

---

## Next Steps

After completing this deployment:

1. ✅ **Infrastructure ready**
2. → **Seed theme metadata** (Phase 2)
3. → **Build content pipeline** (Phase 3)
4. → **Upload recipes** (Phase 4)
5. → **Generate cover images** (Phase 4B)
6. → **Integration testing** (Phase 5)

---

## Support

If you encounter issues:
- Check Firebase Console logs
- Review security rules syntax
- Verify authentication status
- Check index build status

**Deployment should take ~15-30 minutes total.**
