# Firebase Hosting & Cloud Functions Deployment Guide
## Phase 10: Public Profile URLs

This guide covers deploying Firebase Hosting and the Cloud Function for Open Graph preview generation.

---

## Prerequisites

1. Firebase CLI installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Authenticated with Firebase:
   ```bash
   firebase login
   ```

3. Project initialized:
   ```bash
   firebase use heirloom-ios-prod
   ```

---

## Step 1: Prepare Cloud Function

### Install Dependencies

```bash
cd firebase/functions
npm install firebase-functions firebase-admin
```

### Deploy Cloud Function

```bash
# Deploy only the ogProfile function
firebase deploy --only functions:ogProfile
```

**Expected output:**
```
✔  functions[ogProfile(us-central1)] Successful create operation.
Function URL: https://us-central1-heirloom-ios-prod.cloudfunctions.net/ogProfile
```

---

## Step 2: Prepare Hosting Files

### Create Public Directory

```bash
mkdir -p public
```

### Add Apple App Site Association File

Copy the AASA file to the public directory:

```bash
cp apple-app-site-association public/.well-known/apple-app-site-association
```

**Note:** The `.well-known` directory must be created:
```bash
mkdir -p public/.well-known
```

### Create Default OG Image (Optional)

Create a default profile image for users without avatars:
- Size: 1200x630px
- Save as: `public/default-profile-og.png`
- Include Heirloom branding

---

## Step 3: Deploy Firebase Hosting

### Deploy Hosting

```bash
# Deploy hosting configuration and public files
firebase deploy --only hosting
```

**Expected output:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/heirloom-ios-prod/overview
Hosting URL: https://heirloom-ios-prod.web.app
```

---

## Verification & Troubleshooting

See full deployment guide for:
- Testing profile URLs
- Verifying AASA file
- Testing deep links
- Open Graph previews
- Cost estimation

**Total estimated cost: $0/month** (within Firebase free tier)

---

For complete deployment instructions, troubleshooting, and maintenance:
See full guide in firebase/DEPLOYMENT_GUIDE.md
