# Heirloom - Recipes Worth Passing Down

A native iOS 17+ recipe management app built with SwiftUI, SwiftData, and Firebase.

## 🎯 Current Status

**Version:** 1.1.4 (Build 20)
**Ready for TestFlight:** ✅
**Architecture:** SwiftUI + SwiftData + Firebase
**Backend:** Firebase Authentication, Firestore, Storage

## ✨ Key Features

### 🔐 Authentication
- **Sign in with Apple** - Native iOS authentication
- **Sign in with Google** - Multi-provider support
- Firebase Authentication backend
- Seamless session management across launches
- Account linking for same-email providers

### 📖 Recipe Management
- Import from 500+ websites (AllRecipes, NYT Cooking, etc.)
- **OCR Cookbook Scanner** - High-quality PNG-first image processing
- AI-powered ingredient parsing with spell checking
- Recipe versioning and lineage tracking
- Visual diff view for recipe changes
- Share extension for browser import

### 🛒 Smart Shopping & Meal Planning
- Intelligent shopping lists with category grouping
- **Dinner Party Mode** - Multi-recipe meal planning with precise scaling
- Cooking timelines for multi-dish meals
- Export to iOS Reminders with Grocery list type
- Scale recipes with precision (no confusing ranges)

### 🎨 Personalization
- 12 vintage backgrounds
- 50+ hand-drawn stickers
- Handwritten annotations
- Coffee stains and worn edges
- Customization travels with shared recipes

### ☁️ Sync & Sharing
- Firebase Firestore for real-time sync
- Recipe sharing with provenance tracking
- Cross-device synchronization
- Cloud image storage (Firebase Storage)

### 🤖 AI Features
- **Ingredient spell checking** - Real-time suggestions as you type
- AI-powered recipe extraction from photos
- Smart ingredient parsing
- Automatic error correction in OCR
- Default API key included (100 recipes/day per user)
- Deterministic progress indicators

## 🏗️ Architecture

### Frontend (iOS)
```
Heirloom/
├── App/
│   └── HeirloomApp.swift                 # App entry point with Firebase
├── Core/
│   ├── Design/                           # Design system (colors, typography, spacing)
│   ├── Models/                           # SwiftData models (Recipe, Ingredient, etc.)
│   ├── Services/
│   │   ├── AI/                           # Anthropic AI integration
│   │   ├── Firebase/                     # Auth, Sync, Share, Lineage
│   │   ├── Analytics/                    # Mixpanel tracking
│   │   ├── DeepLink/                     # URL scheme handling
│   │   ├── Storage/                      # Image storage
│   │   └── RecipeImport/                 # Web scraping + OCR
│   └── Extensions/                       # Swift extensions
├── Features/
│   ├── Auth/                             # Firebase sign-in views
│   ├── Recipes/                          # Recipe CRUD, editor, detail
│   ├── Shopping/                         # Shopping lists
│   ├── DinnerParty/                      # Multi-recipe planning
│   └── Settings/                         # App settings
└── Resources/
    ├── Assets.xcassets/                  # App icon, colors
    ├── Info.plist                        # Config + URL schemes
    └── Config.xcconfig                   # API keys (excluded from git)
```

### Backend (Firebase)
- **Authentication:** Apple Sign-In + Google Sign-In
- **Firestore:** Recipe sync with version control
- **Storage:** Cloud image hosting
- **Functions:** Recipe sharing endpoints (Node.js/TypeScript)

### Key Dependencies
- Firebase iOS SDK (Auth, Firestore, Storage)
- GoogleSignIn-iOS (for Google authentication)
- SwiftSoup (HTML parsing for recipe import)

## 🚀 Setup Instructions

### Prerequisites
1. Xcode 15+
2. iOS 17+ device or simulator
3. Apple Developer account
4. Firebase project configured

### Configuration Files

**Config.xcconfig** (create if missing):
```
DEFAULT_ANTHROPIC_KEY = sk-ant-api03-YOUR-KEY-HERE
REVERSED_CLIENT_ID = com.googleusercontent.apps.YOUR-CLIENT-ID-HERE
```

Get `REVERSED_CLIENT_ID` from Firebase Console → Project Settings → GoogleService-Info.plist

### Build & Run
1. Open `Heirloom.xcodeproj` in Xcode
2. Select your development team
3. Ensure `Config.xcconfig` is linked in project settings
4. Add GoogleService-Info.plist to project (from Firebase Console)
5. Build and run (⌘R)

## 🔧 Recent Updates

### Firebase Migration (Phase 3)
- ✅ Migrated from CloudKit to Firebase
- ✅ Apple Sign-In at launch (no longer buried in Settings)
- ✅ Google Sign-In added for broader user base
- ✅ Fixed multiple login attempts bug
- ✅ Recipe lineage tracking with version history
- ✅ Visual diff highlighting between versions

### UX Polish
- ✅ Deterministic progress indicators (no vague spinners)
- ✅ Multi-recipe selection with enhanced accordion UI
- ✅ Precise dinner party scaling (eliminated confusing ranges)
- ✅ Smart button text ("Retake Photo" vs "Replace Photo")
- ✅ Inline AI spelling suggestions for ingredients

### Performance
- ✅ PNG-first OCR for better text recognition
- ✅ Efficient image compression only when needed
- ✅ Debounced spell checking (1 second after typing stops)
- ✅ MainActor coordination for image display

### Removed Features
- ❌ JSON import (users won't use it)
- ❌ Test AI API menu item (no user value)
- ❌ CloudKit (replaced with Firebase)

## 📱 Testing the App

### Sign In
1. Launch app → See Firebase sign-in screen
2. Choose "Sign in with Apple" or "Sign in with Google"
3. Existing sessions restore immediately

### Import Recipes
**From Web:**
1. Copy recipe URL from browser
2. Open Heirloom → Share extension or paste in-app
3. Recipe imports automatically

**From Cookbook:**
1. Tap "+" → "Scan Cookbook"
2. Take photo of recipe page
3. Watch deterministic progress (Optimizing → Detecting → Extracting)
4. Recipe appears with image and structured data

### Shopping Lists
1. Select multiple recipes
2. Tap shopping bag icon → Combined shopping list
3. Export to Reminders → Check off while shopping

### Dinner Party Mode
1. Tap "Dinner Party" tab
2. Add multiple recipes for a meal
3. Set guest count → Ingredients scale precisely
4. View cooking timeline with start times
5. Generate consolidated shopping list

## 🔒 Privacy & Security

- **Authentication:** Firebase Auth (Apple + Google)
- **Data Storage:** User's Firebase Firestore account
- **API Keys:** Stored in iOS Keychain (never in code)
- **AI Processing:** Anthropic API (recipes NOT used for training)
- **Analytics:** Mixpanel (anonymous usage tracking)
- **Default AI Key:** Shared rate limit (100 recipes/day per user)

## 📊 Current Metrics

- **App Size:** ~40MB
- **Min iOS:** 17.0
- **Devices:** iPhone + iPad
- **Supported Languages:** English (US)
- **TestFlight Build:** 20
- **Version:** 1.1.4

## 🎨 Design System

**Colors:**
- Cream (#FDF6E3) - Card backgrounds
- Tomato (#E54B4B) - Primary actions
- Amber (#D4A574) - Accents
- Charcoal (#3D3D3D) - Text
- Family Green (#2D5A27) - Special indicators

**Typography:**
- Serif for titles (warm, classic)
- Sans-serif for body (clean, readable)
- Monospaced for special cases

## 🧪 Known Issues

**Minor:**
- First-time Firebase sync takes a few moments
- Google Sign-In requires `REVERSED_CLIENT_ID` in Config.xcconfig
- Some obscure recipe websites may not import correctly

## 📝 Firebase Console Configuration

### Enable Authentication Providers
1. Firebase Console → Authentication → Sign-in method
2. Enable **Apple** (set support email)
3. Enable **Google** (set OAuth client)
4. Save changes

### Get Google Configuration
1. Project Settings → Download GoogleService-Info.plist
2. Add to Xcode project root
3. Copy `REVERSED_CLIENT_ID` value to Config.xcconfig

## 🚀 TestFlight Distribution

**Current Build:** Ready for broad sharing
**Status:** Build succeeded ✅
**Next Step:** Upload to App Store Connect

### What Testers Should Focus On:
1. Firebase sign-in (Apple + Google)
2. OCR quality on various cookbooks
3. Multi-recipe dinner party planning
4. Shopping list accuracy
5. Recipe version tracking
6. Cross-device sync

## 🛣️ Roadmap

**Near-term:**
- [ ] Handwritten recipe recognition improvements
- [ ] Multi-language support (Spanish, French, German)
- [ ] Recipe sharing via public links
- [ ] Meal planning calendar view

**Long-term:**
- [ ] Apple Watch complication for cooking mode
- [ ] Voice control for hands-free cooking
- [ ] Nutritional information extraction
- [ ] Community recipe sharing (opt-in)

## 📧 Contact & Support

**Developer:** Matt Hanson
**Email:** support@heirloomapp.com
**TestFlight Feedback:** Use in-app feedback button
**Website:** heirloomapp.com (coming soon)

---

**Built with ❤️ for preserving family recipes**
**Last Updated:** December 31, 2024
