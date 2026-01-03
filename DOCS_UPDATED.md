# Documentation Updated for v1.1.4 TestFlight Release

**Date:** December 31, 2024
**Build:** 20
**Status:** Ready for TestFlight distribution

---

## 📝 Documents Updated

### ✅ README.md
**Location:** `/Users/matthanson/Heirloom/README.md`

**Changes:**
- Updated to reflect Firebase architecture (was CloudKit)
- Added Google Sign-In to authentication section
- Documented all recent features:
  - AI spelling suggestions
  - Recipe version tracking with diff view
  - Deterministic progress indicators
  - Dinner party precision scaling
  - Multi-recipe import enhancements
- Added Firebase Console configuration instructions
- Updated setup instructions with Config.xcconfig details
- Removed outdated CloudKit references
- Added TestFlight distribution section
- Updated current metrics (version, build number)

**Audience:** Developers, contributors, future maintainers

---

### ✅ BETA_DESCRIPTION.md
**Location:** `/Users/matthanson/Heirloom/BETA_DESCRIPTION.md`

**Changes:**
- Complete rewrite for v1.1.4 build
- Prioritized testing areas (6 priority levels)
- Detailed "What's New" section covering:
  - Firebase authentication (Apple + Google)
  - Enhanced OCR with progress indicators
  - AI spelling suggestions
  - Recipe version tracking
  - Dinner party precision
  - Multi-recipe import polish
- Added comprehensive testing guide with specific scenarios
- Included feedback instructions (in-app, TestFlight, email)
- Listed known issues and expected behaviors
- Added testing tips for different scenarios
- Roadmap preview for v1.2

**Audience:** Beta testers (TestFlight)

---

### ✅ TestFlightPlans/v1.1.4-release-notes.md
**Location:** `/Users/matthanson/Heirloom/TestFlightPlans/v1.1.4-release-notes.md`

**Status:** New file created

**Content:**
- Detailed changelog for v1.1.4
- All new features with descriptions
- Bug fixes list
- UI/UX improvements
- Technical details (dependencies, configuration)
- What to test priorities
- Known issues
- Privacy & security notes
- Roadmap preview

**Audience:** Beta testers, release tracking, internal reference

---

### ✅ TestFlightPlans/testflight-whats-new.txt
**Location:** `/Users/matthanson/Heirloom/TestFlightPlans/testflight-whats-new.txt`

**Status:** New file created

**Content:**
- Concise "What's New" text for TestFlight upload
- Under 4000 characters (TestFlight limit)
- Formatted for readability in TestFlight app
- Key features with emojis for visual scanning
- Testing priorities
- Feedback instructions
- Quick roadmap preview

**Audience:** Beta testers (appears in TestFlight app)

**Usage:** Copy/paste into App Store Connect → TestFlight → "What to Test" field

---

### ✅ APP_STORE_LISTING.md
**Location:** `/Users/matthanson/Heirloom/heirloom-deliverables/APP_STORE_LISTING.md`

**Changes:**
- Updated version to 1.1.4
- Added TestFlight status note
- Updated sync description (CloudKit → Firebase)
- Added Google Sign-In to features list
- Updated last modified date

**Note:** This document is for eventual App Store submission. Most content is still accurate for future launch.

**Audience:** App Store submission, marketing, ASO

---

## 📋 Summary of Key Feature Updates Documented

### 🔐 Authentication
- ✅ Google Sign-In added alongside Apple Sign-In
- ✅ Firebase Authentication backend
- ✅ Session restoration on launch
- ✅ Fixed multiple login attempts bug

### 🤖 AI Features
- ✅ Real-time ingredient spell checking
- ✅ Inline suggestion chips with one-tap corrections
- ✅ Debounced checking (1 second delay)
- ✅ Improved OCR with PNG-first processing

### 🎯 Recipe Management
- ✅ Recipe version tracking with full history
- ✅ Visual diff highlighting (green/red/yellow)
- ✅ Provenance tracking ("Shared by X, from Y")
- ✅ Default version selection

### 🍽️ Dinner Party
- ✅ Precise scaling (eliminated confusing ranges)
- ✅ Algorithm improvement: uses minimum value from ranges
- ✅ Multi-recipe planning with accurate shopping lists

### 📱 UX Polish
- ✅ Deterministic progress indicators throughout
- ✅ Multi-recipe import with enhanced accordion
- ✅ Smart button text ("Retake Photo" vs "Replace Photo")
- ✅ Share extension restored

### 🔧 Removed Features
- ✅ JSON import (documented as removed)
- ✅ Test AI API (documented as removed)
- ✅ CloudKit (migrated to Firebase)

---

## 🎯 Documents Ready for TestFlight

All documents are now current and ready for your TestFlight upload and broad sharing today!

### For Testers:
- **BETA_DESCRIPTION.md** - Comprehensive testing guide
- **testflight-whats-new.txt** - Quick "What's New" summary

### For Internal Reference:
- **README.md** - Technical documentation
- **v1.1.4-release-notes.md** - Detailed changelog

### For Future App Store:
- **APP_STORE_LISTING.md** - Updated with current features

---

## 📤 Next Steps

1. **Upload to TestFlight:**
   - Use Xcode Organizer to upload Build 20
   - Copy/paste content from `testflight-whats-new.txt` into "What to Test" field
   - Set build status to "External Testing"

2. **Share with Testers:**
   - Send TestFlight invite links
   - Reference BETA_DESCRIPTION.md for comprehensive testing guide
   - Point testers to in-app feedback or support@heirloomapp.com

3. **Monitor Feedback:**
   - Check TestFlight feedback daily
   - Monitor crash reports
   - Track analytics for feature usage

---

## 📊 Current State

**Build:** 20
**Version:** 1.1.4
**Date:** December 31, 2024
**Status:** Build succeeded ✅
**Docs:** Updated ✅
**Ready for:** TestFlight distribution & broad sharing ✅

---

**All documentation is current and aligned with the actual app features.**
**No outdated references or missing features.**
**Ready to share broadly!** 🚀
