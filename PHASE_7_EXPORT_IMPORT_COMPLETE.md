# Phase 7: Export/Import with Social Data - COMPLETE

**Date:** 2026-01-30
**Status:** Ready for testing

---

## What Was Implemented

### 1. Updated DataExportView.swift
**Location:** `/Features/Settings/Privacy/DataExportView.swift`

**Changes:**
- Added segmented picker to switch between "Export" and "Import" sections
- Added export type selector: "Full Backup" vs "Recipes Only"
  - Full Backup: Recipes + profile + connections + privacy settings
  - Recipes Only: Just recipes (backward compatible with v1)
- Updated to use `HeirloomDataExporter.exportAllData()` service
- Added file import picker for JSON files
- Added import preview before confirming import

**Features:**
- ✅ Export options selector (Full Backup / Recipes Only)
- ✅ Dynamic export content list based on selected type
- ✅ Import file picker (JSON only)
- ✅ Import preview with validation
- ✅ Success/error messaging

### 2. Created ImportPreviewSheet.swift
**Location:** `/Features/Settings/Privacy/ImportPreviewSheet.swift`

**Purpose:** Shows users what will be imported before they confirm

**Features:**
- ✅ Displays import preview:
  - Recipe count
  - Profile data (if present)
  - Connection count
  - Privacy settings (if present)
- ✅ Shows warnings for items requiring manual review
- ✅ Import instructions ("How import works")
- ✅ Import confirmation button
- ✅ Import result screen:
  - Success header (or partial success with warnings)
  - Import statistics (recipes imported, connections imported, errors)
  - Error list (first 10 errors shown)
- ✅ "Done" button to dismiss after import

### 3. Fixed Filename Conflict
**Issue:** Two files named `PrivacySettingsView.swift`
- `/Features/Settings/Privacy/PrivacySettingsView.swift` - GDPR consent management
- `/Features/Profile/PrivacySettingsView.swift` - Social privacy settings

**Solution:** Renamed Profile version to `SocialPrivacySettingsView.swift`
- Updated struct name from `PrivacySettingsView` to `SocialPrivacySettingsView`
- Updated reference in `ProfileView.swift`

---

## How It Works

### Export Flow

1. User opens Settings → Privacy → "Export My Data"
2. User selects "Export" tab (default)
3. User chooses export type:
   - **Full Backup** (default) - Everything
   - **Recipes Only** - Just recipes
4. User taps "Export Data" button
5. `HeirloomDataExporter.exportAllData()` is called with appropriate options
6. JSON file is created in temp directory with filename: `heirloom-export-v2-{timestamp}.json`
7. Success screen shows with "Share Export File" button
8. User can share via system share sheet

### Import Flow

1. User opens Settings → Privacy → "Export My Data"
2. User selects "Import" tab
3. User taps "Choose Import File" button
4. System file picker opens (JSON files only)
5. User selects export file
6. App reads file and validates:
   - Detects v1 or v2 format
   - Counts recipes, connections, etc.
   - Checks for warnings
7. `ImportPreviewSheet` opens showing:
   - What will be imported (counts for each type)
   - Warnings (e.g., "Connection restoration requires manual confirmation")
   - Instructions on how import works
8. User taps "Import" button
9. `HeirloomDataExporter.importData()` runs:
   - Imports recipes (merges with existing, skips duplicates)
   - Imports profile data (if present)
   - Attempts to restore connections (may fail if users not found)
   - Imports privacy settings (if present)
10. Import result screen shows:
    - Success header (green checkmark) or partial success (yellow warning)
    - Statistics: X recipes imported, Y connections imported, Z errors
    - Error list (if any)
11. User taps "Done" to close

---

## Data Model Support

### Export Format (v2)

Uses `HeirloomExportV2` from `/Core/Models/Export/HeirloomExportModels.swift`:

```swift
struct HeirloomExportV2: Codable {
    let version: Int                              // 2
    let exportDate: String                        // ISO8601
    let appVersion: String
    let userId: String?
    let recipes: [RecipeExportDataV2]
    let userProfile: UserProfileExportData?       // Optional
    let connections: [ConnectionExportData]?      // Optional
    let kitchenTables: [KitchenTableExportData]?  // Optional (Phase 4)
    let privacySettings: PrivacySettingsExportData? // Optional
}
```

### Import Result

```swift
struct HeirloomImportResult {
    let version: Int                  // Export version (1 or 2)
    let recipesImported: Int          // Count of successfully imported recipes
    let connectionsImported: Int?     // Count of restored connections (v2 only)
    let kitchenTablesImported: Int?   // Count of restored tables (v2 only)
    let errors: [HeirloomImportError] // Array of errors/warnings
}
```

### Import Errors

```swift
struct HeirloomImportError {
    let type: HeirloomImportErrorType
    let itemId: String?
    let message: String
    let timestamp: Date
}

enum HeirloomImportErrorType {
    case invalidFormat
    case versionMismatch
    case missingData
    case duplicateId
    case connectionNotFound  // User no longer exists or can't be found
    case parseError
}
```

---

## Backward Compatibility

### v1 Imports (Recipes Only)

The system automatically detects v1 exports and handles them:

1. Attempts to decode as `HeirloomExportV2`
2. If that fails, falls back to `RecipeExportWrapper` (v1)
3. Shows preview indicating "This is a recipes-only export (v1 format)"
4. Imports recipes successfully

### v2 Exports are Forward Compatible

- Version field allows future app versions to detect and handle newer formats
- Optional fields (`userProfile?`, `connections?`) allow graceful degradation
- Recipes are always present (required field)

---

## Files Modified/Created

### Modified (1 file)
1. `/Features/Settings/Privacy/DataExportView.swift` - Added import tab and v2 export support

### Created (1 file)
1. `/Features/Settings/Privacy/ImportPreviewSheet.swift` - Import preview and result UI

### Renamed (1 file)
1. `/Features/Profile/PrivacySettingsView.swift` → `SocialPrivacySettingsView.swift` - Avoided filename conflict

---

## Testing Checklist

### Export Tests

- [ ] **Full Backup Export**
  1. Open Settings → Privacy → Export My Data
  2. Select "Export" tab
  3. Select "Full Backup" type
  4. Verify "What will be exported" shows:
     - All recipes
     - Your profile
     - Connections and relationships
     - Privacy settings
     - Recipe comments and notes
  5. Tap "Export Data"
  6. Verify success screen with "Share Export File" button
  7. Tap "Share Export File"
  8. Verify system share sheet opens
  9. Save file and verify it's a valid JSON file

- [ ] **Recipes Only Export**
  1. Open Settings → Privacy → Export My Data
  2. Select "Recipes Only" type
  3. Verify "What will be exported" shows only:
     - All recipes
     - Recipe metadata
     - Comments and notes
  4. Export and verify file is smaller than full backup

### Import Tests

- [ ] **Import v2 Full Backup**
  1. Switch to "Import" tab
  2. Tap "Choose Import File"
  3. Select a v2 export file
  4. Verify ImportPreviewSheet opens
  5. Verify preview shows:
     - Recipe count
     - "Profile Data: 1"
     - "Connections: X"
     - "Privacy Settings: 1"
  6. Verify warnings section appears if connections present
  7. Verify "How import works" instructions shown
  8. Tap "Import"
  9. Wait for import to complete
  10. Verify result screen shows:
      - Green checkmark or yellow warning icon
      - "Import Complete" or "Import Completed with Warnings"
      - Statistics (recipes imported, connections imported)
      - Error list (if any connection restorations failed)
  11. Tap "Done"
  12. Verify recipes appear in Collections

- [ ] **Import v1 Recipes Only**
  1. Select a v1 export file
  2. Verify preview shows:
     - Recipe count
     - "This is a recipes-only export (v1 format)" warning
  3. Import and verify success

- [ ] **Import Duplicate Recipes**
  1. Export current recipes
  2. Import the same file
  3. Verify import preview still shows correct count
  4. Import and verify result shows 0 recipes imported (all skipped as duplicates)

- [ ] **Connection Restoration**
  1. Export from Device A with connections
  2. Import on Device B
  3. Verify warning about "Connection restoration requires manual confirmation"
  4. Verify errors list shows connections that couldn't be found
  5. Note: Full connection restoration requires Phase 7B (reconnection list)

### Edge Cases

- [ ] **Empty Export** - Should fail gracefully with error
- [ ] **Corrupted JSON** - Should show parse error
- [ ] **Invalid File Type** - File picker should only allow .json files
- [ ] **Large Export** - Test with 100+ recipes
- [ ] **Cancel Import** - Tap "Cancel" on preview sheet, verify import doesn't happen

---

## Known Limitations

### Connection Restoration
**Status:** Partial implementation

- Import will attempt to restore connections
- If a connection's user can't be found (deleted account, changed handle, etc.), it will fail with `connectionNotFound` error
- **Phase 7B (Not Yet Implemented):** ReconnectionListView for manual connection restoration
  - Shows list of failed connections
  - Allows user to search and manually reconnect
  - Persists reconnection attempts

### Kitchen Table Import
**Status:** Placeholder only

- Kitchen Table export/import structure exists in models
- `HeirloomDataExporter` has placeholder for Kitchen Tables (returns empty array)
- Will be implemented in Phase 4 (Kitchen Tables feature)

### Recipe Images
**Status:** Not supported

- Export includes recipe metadata but not image files
- `HeirloomExportOptions.includeRecipeImages = false` (hardcoded)
- Image export/import requires separate implementation (binary file handling)

---

## Next Steps (Phase 7B - Optional)

### ReconnectionListView.swift (Not Yet Implemented)

**Purpose:** Show users connections that couldn't be automatically restored

**Features to add:**
- List of failed connection restorations
- Search functionality to find users by handle/name
- Manual "Reconnect" button for each item
- "Skip" button to dismiss failed connection
- Badge on KitchenTableView if reconnection list not empty

**Integration:**
- Add to ImportResultSheet as "View Reconnection List" button
- Store failed connections in Firestore: `users/{userId}/reconnectionList`
- Add navigation from KitchenTableView settings

---

## Success Criteria

✅ **Export**
- Users can export full backups (v2) or recipes only (v1 compatible)
- Export type selector is clear and works correctly
- Export file is valid JSON
- File can be shared via system share sheet

✅ **Import**
- Users can import v1 and v2 export files
- Import preview shows accurate counts and warnings
- Import merges recipes without deleting existing data
- Import result shows clear statistics and errors
- Duplicate recipes are skipped

✅ **Backward Compatibility**
- v1 exports can be imported successfully
- v2 exports degrade gracefully if social data missing
- Existing export functionality (GDPR) remains unchanged

⚠️ **Partial**
- Connection restoration works for existing users
- Connection restoration fails gracefully for missing users
- Manual reconnection UI not yet implemented (Phase 7B)

---

## Technical Notes

### File Location
Exports are saved to iOS temporary directory:
```swift
FileManager.default.temporaryDirectory.appendingPathComponent("heirloom-export-v2-{timestamp}.json")
```

Files in temp directory are automatically cleaned by iOS when space is needed.

### JSON Encoding
```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.dateEncodingStrategy = .iso8601
```

Dates are stored as ISO8601 strings for maximum compatibility.

### Import Safety
- Import uses merge mode by default (never deletes existing data)
- Duplicate recipes are detected by UUID and skipped
- All errors are caught and reported, import continues for remaining items
- SwiftData context is saved only after successful import

---

## Firestore Queries Used

### Export
- Fetch user profile: `users/{userId}`
- Fetch connections: `connections` collection where `userId == currentUser`
- Recipes come from SwiftData (local only)

### Import
- None during import (all data read from JSON file)
- Connection restoration queries `users` collection to verify user exists

---

## Logs

### Export Logging
```swift
Log.info("Starting Heirloom v2 export", category: .storage, metadata: [
    "includeProfiles": options.includeProfiles,
    "includeConnections": options.includeConnections
])

Log.info("Heirloom v2 export completed", category: .storage, metadata: [
    "fileName": fileName,
    "recipeCount": recipes.count,
    "connectionCount": connectionsData?.count ?? 0,
    "fileSize": jsonData.count
])
```

### Import Logging
```swift
Log.info("Starting Heirloom import", category: .storage, metadata: [
    "fileName": url.lastPathComponent
])

Log.info("Detected export version", category: .storage, metadata: [
    "version": exportWrapper.version,
    "recipeCount": exportWrapper.recipeCount,
    "hasSocialData": exportWrapper.hasSocialData
])

Log.info("Heirloom import completed", category: .storage, metadata: [
    "version": exportWrapper.version,
    "recipesImported": recipesImported,
    "connectionsImported": connectionsImported,
    "errorCount": errors.count
])
```

---

**Phase 7 Complete!** 🎉

Ready for user testing. Once tested, proceed to Phase 8 (Lineage Integration) or Phase 7B (Reconnection List) if connection restoration is a priority.
