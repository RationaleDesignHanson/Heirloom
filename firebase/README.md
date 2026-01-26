# Firebase Configuration Files

This directory contains all Firebase deployment configuration for the Heirloom theme collections feature.

## 📁 Files

### `firestore.rules`
Firestore security rules that control read/write access to:
- `/themes/{themeId}` - Theme metadata (read-only for authenticated users)
- `/themes/{themeId}/recipes/{recipeId}` - Theme recipes (read-only)
- `/users/{userId}` - User-specific data (read/write for owner)

**Deploy:** `firebase deploy --only firestore:rules`

---

### `firestore.indexes.json`
Composite indexes for efficient Firestore queries:
- **Theme index:** Sort themes by category and sortOrder
- **Recipe index:** Query recipes by unlockDay and sortOrder (collection group)

**Deploy:** `firebase deploy --only firestore:indexes`

---

### `storage.rules`
Firebase Storage security rules for:
- `themes/` - Theme cover images (read-only)
- `recipes/{themeId}/` - Recipe images (read-only)
- `user-recipes/{userId}/` - User-uploaded images (read/write for owner)

**Deploy:** `firebase deploy --only storage`

---

### `firebase.json`
Firebase CLI configuration file that references all rule and index files.

---

### `deploy.sh`
Automated deployment script that deploys all Firebase configuration at once.

**Usage:**
```bash
./firebase/deploy.sh
```

---

### `DEPLOYMENT_GUIDE.md`
Comprehensive step-by-step guide for deploying Firebase infrastructure, including:
- Console UI instructions
- CLI commands
- Verification steps
- Troubleshooting

---

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
cd /Users/matthanson/Heirloom
./firebase/deploy.sh
```

### Option 2: Manual Deployment

```bash
# Deploy everything at once
firebase deploy --only firestore:rules,firestore:indexes,storage

# Or deploy individually
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

### Option 3: Firebase Console

Follow the step-by-step instructions in `DEPLOYMENT_GUIDE.md`.

---

## ⏱️ Time Estimates

- **Firestore Rules:** ~2 minutes
- **Storage Rules:** ~1 minute
- **Index Creation:** ~1 minute (+ 5-10 min build time)

**Total:** ~15-20 minutes

---

## ✅ Verification

After deployment, verify in Firebase Console:

1. **Firestore Rules:** Database → Rules tab → Check publish status
2. **Indexes:** Database → Indexes tab → Check build status
3. **Storage Rules:** Storage → Rules tab → Check publish status

---

## 📋 Next Phase

After infrastructure deployment is complete:

→ **Phase 2:** Seed theme metadata (10 theme documents)
→ **Phase 3:** Build content pipeline scripts
→ **Phase 4:** Upload 140 recipes with images

---

## 🔗 Related Documentation

- `/Heirloom2.1Prompts/firebase-schema.md` - Complete schema reference
- `/Heirloom2.1Prompts/phase-*.md` - Implementation phases

---

**Created:** January 26, 2026
**Purpose:** Week 4 infrastructure deployment
