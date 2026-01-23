# Database Migration Strategy

**Date**: 2026-01-23
**Status**: 📋 Documentation

---

## Overview

This document outlines the strategy for managing database schema changes and migrations for Heirloom, which uses:
- **SwiftData** for local storage (iOS app)
- **Firebase Firestore** for cloud sync and sharing

---

## Migration Types

### 1. SwiftData Local Schema Migrations

**Current Approach**: SwiftData automatic migrations

**How It Works**:
- SwiftData provides automatic lightweight migrations for compatible changes
- Compatible changes: adding optional properties, adding entities, renaming properties (with `@Attribute(.originalName)`)
- Incompatible changes: removing properties, changing types, adding required properties

**When to Use Manual Migration**:
```swift
// Example: Custom migration container
let schema = Schema([Recipe.self, Collection.self])
let modelConfiguration = ModelConfiguration(
    schema: schema,
    migrationPlan: MyMigrationPlan.self
)
```

**Migration Steps**:
1. Update model with `@Attribute(.originalName)` for renames
2. Add optional properties (never required - breaks existing data)
3. Provide default values in model init
4. Test migration with existing data before release

---

### 2. Firestore Schema Migrations

**Current Approach**: Additive-only schema changes

**Philosophy**:
- **Never delete fields** (old app versions will break)
- **Always add new fields as optional**
- **Use field transformations in app code**, not in database

**Example Migration Pattern**:

```swift
// BAD: Changing field name in Firestore
// This breaks old app versions!
{
    "name": "Recipe Name",  // OLD
    "title": "Recipe Name"  // NEW - old versions won't see this!
}

// GOOD: Support both old and new fields
{
    "name": "Recipe Name",   // Keep for old versions
    "title": "Recipe Name"   // New field for new versions
}

// In code:
let title = document["title"] as? String ?? document["name"] as? String ?? ""
```

**Schema Version Strategy**:
```swift
// Add schema version to all Firestore documents
{
    "schemaVersion": 2,  // Track which schema version created this
    "title": "Recipe Name",
    ...
}

// In app code:
func parseRecipe(_ data: [String: Any]) -> Recipe {
    let version = data["schemaVersion"] as? Int ?? 1

    switch version {
    case 1:
        // Parse old schema
        return parseV1Recipe(data)
    case 2:
        // Parse new schema
        return parseV2Recipe(data)
    default:
        // Latest version
        return parseLatestRecipe(data)
    }
}
```

---

## Current Schema Version

### Firestore Collections

**Version**: 1 (implicit, no version field yet)

**Structure**:
```
users/{userId}/
  ├── recipes/{recipeId}
  │   ├── ingredients/{ingredientId}
  │   └── comments/{commentId}
  └── profile/
      └── [user profile data]

shares/{shareId}
  └── [share metadata]

lineage/{lineageId}
  └── [ancestry tracking]

heritage_recipes/{collectionId}/
  └── recipes/{recipeId}

heritage_schedules/{scheduleId}
  └── [release schedule data]
```

---

## Migration Scenarios

### Scenario 1: Adding a New Field

**Example**: Add `prepTime` field to recipes

**Steps**:
1. **Update model** (SwiftData):
   ```swift
   @Model
   final class Recipe {
       // ...existing fields...
       var prepTime: Int? = nil  // Optional, default nil
   }
   ```

2. **Update Firestore write** (always write new field):
   ```swift
   func uploadRecipe(_ recipe: Recipe) {
       var data: [String: Any] = [
           "title": recipe.title,
           // ...existing fields...
       ]

       if let prepTime = recipe.prepTime {
           data["prepTime"] = prepTime  // Write if present
       }

       db.collection("users/\(userId)/recipes").document(recipe.id).setData(data)
   }
   ```

3. **Update Firestore read** (handle missing field):
   ```swift
   func parseRecipe(_ data: [String: Any]) -> Recipe {
       let recipe = Recipe(
           title: data["title"] as? String ?? "",
           // ...existing fields...
       )
       recipe.prepTime = data["prepTime"] as? Int  // Nil if not present
       return recipe
   }
   ```

4. **Test**:
   - Old app versions still work (ignore new field)
   - New app versions handle missing field gracefully

---

### Scenario 2: Renaming a Field

**Example**: Rename `description` to `instructions`

**Steps**:
1. **Add new field, keep old field**:
   ```swift
   @Model
   final class Recipe {
       // KEEP both during transition period
       var description: String?  // Deprecated, but keep for old data
       var instructions: String? // New field

       // Computed property for seamless transition
       var displayInstructions: String? {
           return instructions ?? description
       }
   }
   ```

2. **Write both fields**:
   ```swift
   func uploadRecipe(_ recipe: Recipe) {
       let data: [String: Any] = [
           "description": recipe.displayInstructions ?? "",  // For old versions
           "instructions": recipe.displayInstructions ?? "", // For new versions
       ]
   }
   ```

3. **After 6-12 months** (all users updated):
   - Stop writing old field
   - Eventually deprecate old field entirely
   - Never delete from existing documents (costs storage, but safe)

---

### Scenario 3: Changing Field Type

**Example**: Change `servings` from `Int` to `String` (to support "4-6 servings")

**BAD Approach**:
```swift
// Don't do this! Breaks existing data!
var servings: String  // Changed from Int
```

**GOOD Approach**:
```swift
// Add new field with new type
var servings: Int?          // Keep old field
var servingsDisplay: String? // New field with flexible type

// Computed property for UI
var servingsText: String {
    if let display = servingsDisplay {
        return display
    }
    if let count = servings {
        return "\(count)"
    }
    return "4"
}
```

---

### Scenario 4: Adding Required Field

**Problem**: Can't add required field without breaking existing documents

**Solution**: Make it optional in code, provide default

```swift
// BAD:
var category: String  // Required - what about old recipes?

// GOOD:
var category: String? // Optional in model
var displayCategory: String {
    return category ?? "Uncategorized"  // Default in computed property
}
```

---

## Security Rules Migration

**File**: `/firestore.rules`

**Migration Process**:
1. **Test locally** with Firebase emulator
2. **Deploy to staging** (if staging project exists)
3. **Monitor Firebase Console** for rule rejections
4. **Deploy to production** during low-traffic window
5. **Watch metrics** for 24-48 hours
6. **Rollback if needed** (keep previous rules file in git)

**Rollback Command**:
```bash
# Revert rules file
git checkout HEAD~1 firestore.rules

# Deploy previous version
firebase deploy --only firestore:rules
```

**Testing Checklist**:
- [ ] Can users read their own recipes?
- [ ] Can users write their own recipes?
- [ ] Can users NOT read other users' recipes?
- [ ] Can shares be read by allowedRecipients?
- [ ] Can shares be updated by owner only?
- [ ] Can heritage recipes be read by all authenticated users?

---

## Data Validation & Sanitization

### Before Writing to Firestore

**Always validate**:
```swift
func uploadRecipe(_ recipe: Recipe) throws {
    // Validate required fields
    guard !recipe.title.trimmingCharacters(in: .whitespaces).isEmpty else {
        throw ValidationError.missingTitle
    }

    // Sanitize strings (prevent XSS, injection)
    let sanitizedTitle = recipe.title
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "<script>", with: "")  // Basic XSS prevention

    // Limit field sizes (prevent abuse)
    let truncatedDescription = String(recipe.description.prefix(10000))

    let data: [String: Any] = [
        "title": sanitizedTitle,
        "description": truncatedDescription,
        // ...
    ]

    try await db.collection(...).setData(data)
}
```

---

## Migration Rollout Strategy

### Phase 1: Preparation (Before Release)
1. Write migration code
2. Test with local SwiftData migrations
3. Test with Firebase emulator
4. Create rollback procedure
5. Document breaking changes (if any)

### Phase 2: Soft Launch (TestFlight)
1. Release to beta testers (100-500 users)
2. Monitor Crashlytics for errors
3. Monitor Firebase Console for rule rejections
4. Collect feedback on data integrity
5. Fix issues before wider release

### Phase 3: Production Rollout
1. Deploy during low-traffic window (2-4am local time)
2. Monitor metrics:
   - Crashlytics error rate (should be < 0.5%)
   - Firebase rule rejection rate (should be < 1%)
   - User retention (should not drop)
3. Keep rollback ready for 48 hours

### Phase 4: Monitoring (Post-Release)
1. Watch for 7 days
2. Check for edge cases
3. Validate data consistency
4. Document lessons learned

---

## Emergency Rollback Procedure

### If Migration Fails

**Step 1: Assess Impact**
- How many users affected?
- Is data corrupted or just inaccessible?
- Can issue be fixed in app update, or need database rollback?

**Step 2: Immediate Actions**
```bash
# 1. Revert app to previous version in App Store Connect
# (Removes problematic version from store)

# 2. Revert Firestore rules
git checkout HEAD~1 firestore.rules
firebase deploy --only firestore:rules

# 3. Communicate with users
# (Push notification, in-app banner, email)
```

**Step 3: Data Recovery**
```bash
# Restore Firestore data from backup (if needed)
firebase firestore:import gs://YOUR_BUCKET/backups/BACKUP_DATE \
  --project YOUR_PROJECT_ID
```

**Step 4: Hotfix**
- Fix migration code
- Test thoroughly
- Submit expedited App Store review
- Document root cause

---

## Testing Migrations

### Local Testing (SwiftData)

```swift
func testMigration() throws {
    // Create old schema data
    let oldContainer = try ModelContainer(
        for: OldRecipe.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Insert test data
    let context = oldContainer.mainContext
    let oldRecipe = OldRecipe(name: "Test Recipe")
    context.insert(oldRecipe)
    try context.save()

    // Migrate to new schema
    let newContainer = try ModelContainer(
        for: Recipe.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        migrationPlan: MyMigrationPlan.self
    )

    // Verify migration succeeded
    let recipes = try newContainer.mainContext.fetch(FetchDescriptor<Recipe>())
    XCTAssertEqual(recipes.first?.title, "Test Recipe")
}
```

### Firebase Emulator Testing

```bash
# Start emulator
firebase emulators:start

# Run test suite against emulator
FIRESTORE_EMULATOR_HOST=localhost:8080 \
  xcodebuild test -scheme Heirloom -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Migration Checklist

### Before Any Schema Change

- [ ] Is this change additive-only?
- [ ] Will old app versions still work?
- [ ] Can data be read without the new field?
- [ ] Is there a default value for missing data?
- [ ] Have I tested with empty/nil values?
- [ ] Is the migration documented?
- [ ] Is there a rollback plan?

### Before Deploying Firestore Rules

- [ ] Tested in Firebase emulator?
- [ ] Tested with multiple user scenarios?
- [ ] Backed up current rules?
- [ ] Tested rollback procedure?
- [ ] Identified low-traffic deployment window?
- [ ] Set up monitoring alerts?

### Before Releasing App Update

- [ ] SwiftData migration tested?
- [ ] Firestore read/write compatibility tested?
- [ ] Backward compatibility verified (old version reading new data)?
- [ ] Forward compatibility verified (new version reading old data)?
- [ ] Beta tested with real users?
- [ ] Crashlytics monitoring enabled?
- [ ] Rollback procedure documented?

---

## Future Improvements

### Versioning System

Add explicit schema versioning to all documents:

```swift
struct SchemaVersion {
    static let current: Int = 2
}

// In every Firestore write:
data["schemaVersion"] = SchemaVersion.current

// In every Firestore read:
let version = data["schemaVersion"] as? Int ?? 1
switch version {
    case 1: return parseV1(data)
    case 2: return parseV2(data)
    default: return parseLatest(data)
}
```

### Migration Scripts

Create server-side Cloud Functions for batch migrations:

```javascript
// Example: Backfill new field across all recipes
exports.migrateRecipes = functions.https.onRequest(async (req, res) => {
    const batch = db.batch();
    const recipes = await db.collectionGroup('recipes').get();

    recipes.docs.forEach(doc => {
        if (!doc.data().prepTime) {
            batch.update(doc.ref, { prepTime: null });
        }
    });

    await batch.commit();
    res.send('Migration complete');
});
```

### Monitoring Dashboard

Track migration health:
- Schema version distribution (how many users on old vs new schema?)
- Failed read/write attempts
- Rollback frequency
- Data consistency checks

---

## Resources

- **SwiftData Migrations**: https://developer.apple.com/documentation/swiftdata/migrating-your-models
- **Firestore Best Practices**: https://firebase.google.com/docs/firestore/best-practices
- **Schema Design**: https://firebase.google.com/docs/firestore/manage-data/structure-data

---

**Last Updated**: 2026-01-23
**Next Review**: Before next schema change
**Owner**: Development Team

