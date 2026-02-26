# Theme Recipe Version Refresh System

## Overview

Implement a version-based refresh mechanism so theme recipe updates in Firebase automatically sync to user devices.

---

## Problem

When we update theme recipes in Firebase (fix typos, update instructions, add recipes), user devices keep their cached SwiftData copies and never see the updates.

---

## Solution: Version Number + Automatic Sync

### How It Works

1. Each theme in Firebase has a `recipeVersion: Int` field
2. Each local `RecipeTheme` in SwiftData stores `downloadedVersion: Int`
3. App compares versions on launch and when opening theme collections
4. If `firebaseVersion > localVersion` → re-download all recipes for that theme

---

## Implementation Steps

### Step 1: Add Version Field to Firebase Theme Metadata

Create script: `scripts/add-theme-versions.js`

### Step 2: Update RecipeTheme SwiftData Model

Add `downloadedVersion: Int = 0` property

### Step 3: Update ThemeLoader to Parse Version

Parse `recipeVersion` from Firebase theme docs

### Step 4: Create ThemeVersionChecker

New actor that checks Firebase version vs local version

### Step 5: Integrate Version Check on App Launch

Background check for theme updates

### Step 6: Integrate Version Check When Opening Theme Collection

Check version when viewing theme collection

### Step 7: Update Seed Script to Bump Version

Auto-increment `recipeVersion` after re-seeding

---

## Estimated Effort: ~3.5 hours

See full implementation details in original plan document.
