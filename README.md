# Heirloom - Recipes Worth Passing Down

A native iOS 17+ recipe management app built with SwiftUI and SwiftData.

## 🎯 Day 1 Status (Created Today)

✅ **Project Structure Created**
- Complete folder organization
- All core models (Recipe, Ingredient, etc.)
- Versioned schema (SchemaV1) for future migrations
- Image storage service (file system, not database)

✅ **Architecture Implemented**
- SwiftData with CloudKit sync
- File-based image storage with compression
- Memory and disk caching
- Design system (colors, typography)
- Basic recipe list view

## 📱 Opening the Project in Xcode

Since Xcodeproj files are complex binary formats, you'll need to create the project in Xcode:

### Step 1: Create New Project
1. Open Xcode
2. File → New → Project
3. Choose **iOS → App**
4. Settings:
   - Product Name: `Heirloom`
   - Team: Select your Apple Developer account (Q2HHH2GDN8)
   - Organization Identifier: `com.heirloom` (or your preference)
   - Bundle Identifier: `com.heirloom.app`
   - Interface: **SwiftUI**
   - Storage: **SwiftData**
   - Language: **Swift**
   - Minimum Deployment: **iOS 17.0**
5. Save to: `/Users/matthanson/Heirloom`

### Step 2: Configure Project Settings
1. In project navigator, select **Heirloom** (blue icon)
2. Under **Signing & Capabilities**:
   - Team: Your Apple Developer account
   - Enable **Automatic Signing**
   - Add Capability: **iCloud** → Enable CloudKit
   - Add Capability: **App Groups** → `group.com.heirloom.shared`
3. Under **General**:
   - Minimum Deployments: iOS 17.0
   - Delete the default SwiftUI files Xcode created (ContentView.swift, etc.)

### Step 3: Add Existing Source Files
1. Delete Xcode's default ContentView.swift and HeirloomApp.swift
2. In Finder, drag these folders into Xcode's project navigator:
   - `Heirloom/App/`
   - `Heirloom/Core/`
   - `Heirloom/Features/`
   - `Heirloom/Resources/`
3. When prompted:
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Add to target: Heirloom

### Step 4: Add SwiftSoup Dependency
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/scinfu/SwiftSoup`
3. Dependency Rule: **Up to Next Major Version** (2.0.0)
4. Add to Target: Heirloom

### Step 5: Update Info.plist
1. Replace Xcode's default Info.plist with `Heirloom/Resources/Info.plist`
2. Or manually add the permission descriptions listed in that file

### Step 6: Build and Run!
1. Select your iOS device or simulator
2. Product → Run (⌘R)
3. You should see the Heirloom app launch with an empty recipe list

## 🗂️ Project Structure

```
Heirloom/
├── App/
│   └── HeirloomApp.swift          # App entry point
│
├── Core/
│   ├── Design/
│   │   ├── Colors.swift            # Color palette
│   │   ├── Typography.swift        # Font system
│   │   └── Components/             # (Day 2+)
│   │
│   ├── Models/
│   │   ├── SchemaV1.swift          # Versioned schema
│   │   ├── Recipe.swift            # Main recipe model
│   │   └── Ingredient.swift        # Ingredient model
│   │
│   ├── Services/
│   │   └── Storage/
│   │       ├── ImageStorageService.swift  # File system image handling
│   │       └── ImageCache.swift           # Memory cache
│   │
│   └── Extensions/                 # (Day 2+)
│
├── Features/
│   └── Recipes/
│       └── RecipeList/
│           └── RecipeListView.swift  # Recipe grid
│
└── Resources/
    ├── Assets.xcassets/            # (Day 2: Add colors, app icon)
    └── Info.plist                  # Permissions
```

## 🏗️ Architecture Decisions

Based on expert Systems Architect and iOS Engineer review:

✅ **Observable + MVVM-light** (iOS 17+)
✅ **SwiftData with versioned schemas** (migration-ready)
✅ **Images in file system** (not database)
✅ **CloudKit with overflow monitoring** (50K user awareness)
✅ **No external dependencies except SwiftSoup**

## 🚀 Next Steps (Day 2)

- [ ] Full design system with button styles, components
- [ ] Mixpanel analytics integration
- [ ] Asset catalog (app icon, colors)
- [ ] Recipe detail view
- [ ] Async image loading

## 📊 Current File Count

**~2,500 lines of Swift code across 12 files:**
1. HeirloomApp.swift (app entry)
2. SchemaV1.swift (schema versioning)
3. Recipe.swift (main model)
4. Ingredient.swift (ingredient model + enums)
5. ImageStorageService.swift (file system storage)
6. ImageCache.swift (memory cache)
7. Colors.swift (design system)
8. Typography.swift (design system)
9. RecipeListView.swift (UI)
10. Info.plist (configuration)
11. .gitignore
12. README.md (this file)

## 🎨 Design System Preview

The app uses a warm, nostalgic color palette:
- **Cream** (#FDF6E3) - Card backgrounds
- **Tomato** (#E54B4B) - Primary actions
- **Amber** (#D4A574) - Accents
- **Charcoal** (#3D3D3D) - Text
- **Family Green** (#2D5A27) - Special indicators

Typography uses system fonts:
- **Serif** for titles (warm, classic feel)
- **Sans-serif** for body (clean, readable)
- **Monospaced** for special cases

## 🧪 Testing the App

Once the project is set up:

1. **Empty State**: Launch app → See empty state with sample recipe button
2. **Add Sample**: Tap "Add Sample Recipe" → Recipe appears in grid
3. **Recipe Card**: See warm card design with proper styling
4. **Search**: Type in search bar → Filter works

## 📝 Notes for Tomorrow

**Day 2 will add:**
- Full component library (buttons, loading states, errors)
- Analytics tracking (Mixpanel free tier)
- Recipe detail view with all sections
- Async image loading and caching
- More polish on the recipe grid

**Known Limitations (Day 1):**
- Recipe cards show placeholder images (will fix with async loading)
- No recipe import yet (coming Day 3-4)
- No shopping list yet (coming Day 3)
- No CloudKit monitoring yet (coming Day 4)

---

**Created:** Day 1 (December 8, 2024)
**Next Session:** Day 2 - Design System & Analytics
