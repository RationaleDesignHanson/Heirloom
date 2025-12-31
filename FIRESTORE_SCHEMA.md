# Firestore Schema Design for Heirloom

## Overview
Firestore database structure for migrating from CloudKit to Firebase.

**Key Design Principles:**
1. User-scoped data: All recipes under `users/{userId}/`
2. Subcollections for child records (ingredients, comments, cardBack)
3. Atomic updates within a user's scope
4. Query-friendly structure (no CloudKit limitations!)
5. Offline-first with automatic sync

---

## Schema Structure

```
users/
  {userId}/                           # Firebase Auth UID
    recipes/                          # User's recipes
      {recipeId}/                     # Recipe document (UUID)
        - id: string                  # Recipe UUID
        - title: string               # Recipe title
        - sourceType: string          # manual|url|cookbook|scan|family
        - sourceURL: string?          # Source URL if from web
        - instructions: string[]      # Cooking steps
        - servings: string?           # e.g., "4-6 servings"
        - prepTime: string?           # e.g., "15 minutes"
        - cookTime: string?           # e.g., "30 minutes"
        - notes: string?              # User notes
        - isFavorite: boolean         # Favorite flag

        # Image storage
        - imageFileName: string?      # Local filename
        - imageStoragePath: string?   # Firebase Storage path
        - sourceImageURL: string?     # Original URL

        # Metadata
        - timesCooked: number         # Cook count
        - lastCooked: timestamp?      # Last cook date
        - createdAt: timestamp        # Creation date
        - modifiedAt: timestamp       # Last modification

        # Social/Sharing
        - sharedBy: string?           # Original author
        - sharedDate: timestamp?      # When shared
        - passedDownMessage: string?  # Message from sender
        - generationCount: number     # How many times shared

        # Provenance (JSON)
        - provenanceJSON: string?     # ProvenanceMetadata encoded

        # Sync metadata
        - lastSyncedAt: timestamp?    # Last successful sync

        # Subcollections
        ingredients/                  # Recipe ingredients
          {ingredientId}/             # Ingredient document (UUID)
            - id: string              # Ingredient UUID
            - originalText: string    # "2 cups flour"
            - name: string            # "flour"
            - quantity: number?       # 2.0
            - quantityMax: number?    # For ranges
            - unit: string?           # "cups"
            - normalizedUnit: string? # Standardized unit
            - preparation: string?    # "chopped", "diced"
            - size: string?           # "large", "small"
            - category: string        # Grocery category
            - orderIndex: number      # Display order
            - isSelected: boolean     # For shopping
            - isCheckedOff: boolean   # Purchased
            - isOptional: boolean     # Optional ingredient

        comments/                     # Recipe comments
          {commentId}/                # Comment document (UUID)
            - id: string              # Comment UUID
            - text: string            # Comment text
            - authorName: string?     # Commenter name
            - createdAt: timestamp    # When posted
            - isPinned: boolean       # Pinned to top
            - sentimentScore: number? # Sentiment analysis

        cardBack/                     # Recipe card back (single doc)
          metadata                    # Single document
            - noteToFriends: string?  # Personal note
            - personalTips: string[]  # Cooking tips
            - userRating: number?     # 1-5 stars
            - showAttribution: boolean
            - customAttributionText: string?
            - attributionPosition: string # top|bottom|none
            - pinnedCommentIDs: string[] # UUIDs
            - maxCommentsToDisplay: number
            - backgroundStyle: string # style enum
            - textColor: string       # hex color
            - visibleSections: string[] # section names
```

---

## Firebase Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // User can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Recipes
      match /recipes/{recipeId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;

        // Ingredients
        match /ingredients/{ingredientId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }

        // Comments
        match /comments/{commentId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }

        // Card Back
        match /cardBack/{document} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
  }
}
```

---

## Data Flow

### Upload (Local → Firebase)

```
Recipe created locally
  ↓
Check BackendConfig.isFirebaseActive
  ↓
Convert Recipe to Firestore document
  ↓
Upload to users/{userId}/recipes/{recipeId}
  ↓
Upload ingredients to .../ingredients/ subcollection
  ↓
Upload comments to .../comments/ subcollection
  ↓
Upload card back to .../cardBack/metadata
  ↓
Update recipe.lastSyncedAt locally
```

### Download (Firebase → Local)

```
Listen for Firestore changes
  ↓
Receive recipe document
  ↓
Convert to Recipe model
  ↓
Fetch ingredients from subcollection
  ↓
Fetch comments from subcollection
  ↓
Fetch card back from subcollection
  ↓
Merge with local SwiftData
  ↓
Handle conflicts (last-write-wins)
```

---

## Key Differences from CloudKit

| Feature | CloudKit | Firebase |
|---------|----------|----------|
| **User scope** | iCloud account | Firebase Auth UID |
| **Child records** | CKReference | Subcollections |
| **Queries** | Limited (indexes required) | Flexible (no index issues) |
| **Offline** | Manual sync | Automatic offline cache |
| **Sharing** | CKShare (complex) | Custom permissions + security rules |
| **Zones** | Custom zones required | Not needed |
| **Change tracking** | Manual tokens | Realtime listeners |

---

## Migration Strategy

### Phase 2: Implementation (Current)
- ✅ Design schema (this document)
- ⏳ Create FirebaseSyncService
- ⏳ Implement Recipe CRUD
- ⏳ Implement Ingredient sync
- ⏳ Test operations

### Phase 7: Data Migration
- Export existing CloudKit data
- Transform to Firestore format
- Batch upload to Firebase
- Verify data integrity

### Phase 9: Dual-Write Period
- Write to both CloudKit AND Firebase
- Read from CloudKit (current production)
- Monitor for issues
- 2-4 week validation period

### Phase 10: Switch to Firebase
- Flip backend to Firebase-only
- Deprecate CloudKit code
- Remove CloudKit dependencies

---

## Query Examples

### Fetch all user's recipes
```swift
let snapshot = try await db.collection("users/\(userId)/recipes")
    .order(by: "modifiedAt", descending: true)
    .getDocuments()
```

### Fetch ingredients for recipe
```swift
let snapshot = try await db.collection("users/\(userId)/recipes/\(recipeId)/ingredients")
    .order(by: "orderIndex")
    .getDocuments()
```

### Fetch favorites only
```swift
let snapshot = try await db.collection("users/\(userId)/recipes")
    .whereField("isFavorite", isEqualTo: true)
    .getDocuments()
```

### Search by title
```swift
// Note: Full-text search requires Algolia or similar
// Basic prefix search:
let snapshot = try await db.collection("users/\(userId)/recipes")
    .whereField("title", isGreaterThanOrEqualTo: searchText)
    .whereField("title", isLessThan: searchText + "z")
    .getDocuments()
```

---

## Storage Structure (Firebase Storage)

```
users/
  {userId}/
    recipes/
      {recipeId}/
        image.jpg              # Main recipe image
        image_thumbnail.jpg    # Thumbnail (optional)
```

**Upload flow:**
1. Convert UIImage to JPEG
2. Upload to `users/{userId}/recipes/{recipeId}/image.jpg`
3. Get download URL
4. Store `imageStoragePath` in Firestore document

---

## Indexed Fields (Performance)

Firestore automatically indexes:
- Single-field queries
- Document ID queries

**Manual indexes needed for:**
- Compound queries (e.g., `isFavorite == true AND modifiedAt > date`)
- Array-contains + other filters

Firebase will prompt to create indexes when queries fail.

---

## Advantages of This Schema

1. **No hierarchical sharing bug**: Subcollections work perfectly for participants
2. **User-scoped security**: Firebase Auth + security rules = simple, secure
3. **Flexible queries**: No CloudKit index limitations
4. **Offline-first**: Firestore SDK handles caching automatically
5. **Realtime sync**: Optional real-time listeners for instant updates
6. **Scalable**: Firestore handles millions of documents efficiently

---

**Last Updated**: December 30, 2025
**Status**: Schema design complete, ready for implementation
