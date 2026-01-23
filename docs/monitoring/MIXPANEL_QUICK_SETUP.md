# Mixpanel Quick Setup Guide

**Time**: 10 minutes
**Optional**: App works without Mixpanel (console logging fallback)

---

## Quick Steps

### 1. Get Tokens (5 min)

1. Go to https://mixpanel.com
2. Sign up or log in
3. Create project: "Heirloom Production"
4. Click project name → "Project Settings"
5. Copy "Project Token" (32 characters: `1234567890abcdef1234567890abcdef`)

**Optional**: Create second project "Heirloom Development" for testing

### 2. Add to Config.xcconfig (1 min)

Edit `/Users/matthanson/Heirloom/Config.xcconfig`:

```
MIXPANEL_PRODUCTION_TOKEN = <paste your production token here>
MIXPANEL_DEVELOPMENT_TOKEN = <paste your dev token here or same as prod>
```

**Example**:
```
MIXPANEL_PRODUCTION_TOKEN = 1234567890abcdef1234567890abcdef
MIXPANEL_DEVELOPMENT_TOKEN = fedcba0987654321fedcba0987654321
```

### 3. Test (2 min)

1. Build and run app
2. Create a recipe
3. Go to https://mixpanel.com → Events → Live View
4. Should see "Recipe Created" event within 30 seconds

---

## That's It!

The code is already configured to read from Config.xcconfig.

**If you skip this**: App still works, just logs events to console instead of Mixpanel.

**For full documentation**: See `MIXPANEL_SETUP.md`

---

**Last Updated**: 2026-01-23
