# Universal Links Deployment Guide

## What's Already Done ✅

Your app is **already configured** to handle universal links:
- ✅ Associated Domains capability added (`Heirloom.entitlements`)
- ✅ Deep link handler supports `https://heirloom.app/share/{shareId}` (DeepLinkHandler.swift:766-777)
- ✅ App listens for universal links via `onContinueUserActivity` (HeirloomApp.swift:318-323)
- ✅ Apple App Site Association (AASA) file created

## What You Need to Do

### 1. Host the AASA File

Upload the file `apple-app-site-association` (no file extension) to your web server at:

```
https://heirloom.app/.well-known/apple-app-site-association
```

**Requirements:**
- **No file extension** - The file MUST be named exactly `apple-app-site-association`
- **HTTPS required** - Must be served over HTTPS (not HTTP)
- **Content-Type** - Should be `application/json` or `application/pkcs7-mime`
- **No redirects** - The URL must return the file directly (301/302 redirects are not allowed)

### 2. Verify the File is Accessible

Test in a browser:
```
https://heirloom.app/.well-known/apple-app-site-association
```

You should see the JSON content without any errors.

### 3. Test Universal Links

After uploading the AASA file:

1. **Wait 15-30 minutes** for Apple's CDN to cache the file
2. **Uninstall and reinstall the app** to force iOS to re-fetch the AASA file
3. **Test the link**:
   - Send yourself an iMessage with a share link like:
     `https://heirloom.app/share/7241804D-8D38-43AD-8A79-6512F5EAC7BB`
   - Tap the link
   - It should open the app directly (not Safari)

### 4. Troubleshooting

If universal links don't work:

1. **Verify AASA file is valid**:
   - Visit https://branch.io/resources/aasa-validator/
   - Enter: `https://heirloom.app`
   - It should show your app's bundle ID

2. **Check iOS fetched the file**:
   - Open Notes app
   - Type: `https://heirloom.app/share/test123`
   - If it shows "Open in Heirloom", iOS fetched the AASA file successfully

3. **Force iOS to re-fetch**:
   - Uninstall app
   - Restart device
   - Reinstall app
   - Wait 15 minutes

4. **Check Xcode console for errors**:
   - Run app from Xcode
   - Tap a universal link
   - Look for swcd (Shared Web Credentials Daemon) errors

## Example Deployment (Static Hosting)

### Netlify / Vercel
Create a `_redirects` file (or next.config.js):
```
/.well-known/apple-app-site-association  /apple-app-site-association  200
```

### Firebase Hosting
Add to `firebase.json`:
```json
{
  "hosting": {
    "rewrites": [
      {
        "source": "/.well-known/apple-app-site-association",
        "destination": "/apple-app-site-association"
      }
    ],
    "headers": [
      {
        "source": "/.well-known/apple-app-site-association",
        "headers": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ]
      }
    ]
  }
}
```

### CloudFlare Pages
Create a `_headers` file:
```
/.well-known/apple-app-site-association
  Content-Type: application/json
```

## File Contents

The AASA file (`apple-app-site-association`) contains:

```json
{
    "applinks": {
        "details": [
            {
                "appIDs": [
                    "Q2HHH2GDN8.com.matthanson.heirloom"
                ],
                "components": [
                    {
                        "/": "/share/*",
                        "comment": "Matches any recipe share link"
                    }
                ]
            }
        ]
    },
    "webcredentials": {
        "apps": [
            "Q2HHH2GDN8.com.matthanson.heirloom"
        ]
    }
}
```

## What This Enables

After deployment:
- `https://heirloom.app/share/{shareId}` opens directly in the app
- `heirloom://share/{shareId}` continues to work (deep link fallback)
- Share links work from Messages, Notes, Mail, Safari, etc.
- No "Open in Safari" redirect - opens app immediately

## Current Behavior

- ✅ Deep links (`heirloom://share/...`) work
- ❌ Universal links (`https://heirloom.app/share/...`) open Safari with "server not found"

After deploying the AASA file, universal links will open the app directly.
