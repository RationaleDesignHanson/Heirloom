# Heirloom Architecture - Quick Reference Guide

## Core Architectural Patterns

### 1. **Layer Pattern: Views → Services → Models → Data**

```
SwiftUI Views (UI Layer)
    ↓ (call through environment)
@MainActor Services (Business Logic)
    ↓ (receive/return models)
@Model Classes (SwiftData Entities)
    ↓ (automatic persistence)
SwiftData + CloudKit (Data Layer)
```

### 2. **Service Singleton Pattern**

All major services are stateless singletons accessed via `.shared`:

```swift
// CommentService - CRUD operations for comments
CommentService.shared.addComment(to: recipe, text: "...", context: modelContext)

// CloudKitShareService - Network sharing via CloudKit
CloudKitShareService.shared.shareRecipe(recipe, message: "...", completion: { ... })

// CommentAnalysisService - AI-powered sentiment analysis
try await CommentAnalysisService.shared.analyzeComment(comment)

// ImageStorageService - File-safe image handling (Actor pattern)
let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: id)
```

### 3. **ModelContext Parameter Pattern**

Services receive ModelContext as parameter, never manage it themselves:

```swift
// ✅ CORRECT: Service takes context as parameter
func addComment(to recipe: Recipe, text: String, context: ModelContext) throws -> RecipeComment

// ❌ AVOID: Service managing its own context
private let modelContainer: ModelContainer
var context: ModelContext { /* ... */ }
```

### 4. **Relationship Cascade Deletion**

Delete parent → children auto-deleted:

```swift
@Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
var ingredients: [Ingredient]?

@Relationship(deleteRule: .cascade, inverse: \RecipeComment.recipe)
var comments: [RecipeComment]?

// When recipe is deleted, all ingredients & comments cascade delete
```

## Key Components for Social Features

### Recipe Model
- **Location:** `Core/Models/Recipe.swift`
- **Key properties:** 
  - `comments: [RecipeComment]?` - Comment array with cascade delete
  - `cardBack: RecipeCardBack?` - One-to-one customization
  - `generationCount: Int` - Track pass-down history
  - `sharedDate: Date?`, `sharedBy: String?` - Share metadata

### RecipeComment Model
- **Location:** `Core/Models/RecipeComment.swift`
- **Key features:**
  - Threaded comments (parentComment → replies)
  - AI sentiment analysis (-1.0 to 1.0)
  - Comment types (tip, modification, warning, etc.)
  - User interactions (upvotes, pinning, card back visibility)
  - Moderation (flagging, hiding)

### RecipeCardBack Model
- **Location:** `Core/Models/RecipeCardBack.swift`
- **Key features:**
  - Personal notes & tips
  - Pinned comment IDs for display
  - Visual customization (background, colors, fonts)
  - Privacy levels (private, friendsOnly, public)
  - Share messaging

### CommentService
- **Location:** `Core/Services/CommentService.swift`
- **Key methods:**
  - `addComment()` - Create comment (supports threading)
  - `importComments()` - Batch import from scraped source
  - `getTopLevelComments()`, `getTopComments()`, `getPinnedComments()`
  - `upvoteComment()`, `downvoteComment()`, `togglePin()`
  - `updateSentiment()` - Called by analysis service
  - `searchComments()` - Full-text search with topic matching
  - `getStatistics()` - Returns CommentStatistics struct

### CommentAnalysisService
- **Location:** `Core/Services/AI/CommentAnalysisService.swift`
- **Key methods:**
  - `analyzeComment()` async - Returns sentiment, topics, type
  - `analyzeComments()` async - Batch analysis with graceful fallback
  - `extractInsights()` async - Common themes, modifications, warnings
- **Integration:** Directly updates RecipeComment via CommentService.updateSentiment()

### CloudKitShareService
- **Location:** `Core/Services/CloudKitShareService.swift`
- **Key methods:**
  - `shareRecipe()` - Create shareable link with message
  - `passDownRecipe()` - Special sharing with generation tracking
  - `acceptSharedRecipe()` - Import shared recipe from URL
  - `getCurrentUserName()` async - Get user info for attribution

### RecipeShareService
- **Location:** `Core/Services/RecipeShareService.swift`
- **Formats:** `.text`, `.pdf`, `.url` (for CloudKit)
- **Integration:** Uses UIActivityViewController for native share sheet

## View Patterns for Social Features

### RecipeDetailView
- **Location:** `Features/Recipes/RecipeDetail/RecipeDetailView.swift`
- **Integration points:**
  - Menu option: "Comments (count)" → opens RecipeCommentListView
  - Menu option: "Customize Card Back" → opens CardBackEditorView
  - Menu option: "Share" submenu with all share formats
  - Shows comment count in toolbar

### RecipeCommentListView
- **Location:** `Features/Comments/Views/RecipeCommentListView.swift`
- **Features:**
  - Search, sort (topRated, recent, sentiment), filter (type, source, sentiment)
  - Statistics display (total, upvotes, sentiment)
  - Recursive rendering of threaded comments
  - OnAppear analytics tracking

### RecipeCommentView
- **Location:** `Features/Comments/Views/RecipeCommentView.swift`
- **Features:**
  - Type-based color coding & icons
  - Sentiment visualization (score as %)
  - Vote & pin buttons with callbacks
  - Topic tags with scroll
  - "Show on Card Back" option
  - Recursive nested reply rendering

### CardBackEditorView
- **Location:** `Features/Comments/Views/CardBackEditorView.swift`
- **Features:**
  - Note to friends (TextEditor)
  - Personal tips (add/remove list)
  - Rating & custom tags
  - Style picker (background, layout)
  - Visible sections toggle
  - Live preview

## Swift Concurrency Patterns

### @MainActor Services
Services that interact with UI use @MainActor:
```swift
@MainActor
final class CommentService {
    // All methods implicitly run on main thread
    func addComment(...) throws -> RecipeComment
}
```

### Actor for File I/O
ImageStorageService uses Actor for thread-safe file operations:
```swift
actor ImageStorageService {
    // Thread-safe: only one thread accesses methods at a time
    func saveImage(_ image: UIImage, recipeId: UUID) async throws -> String
    func loadImage(fileName: String) async -> UIImage?
}
```

### Async/Await for API Calls
```swift
@MainActor
final class CommentAnalysisService {
    func analyzeComment(_ comment: RecipeComment) async throws -> CommentAnalysis {
        let response = try await callClaude(with: prompt)
        return try parseAnalysisResponse(response)
    }
}

// In view:
Task {
    let analysis = try await CommentAnalysisService.shared.analyzeComment(comment)
    // Update comment with sentiment
}
```

### Completion Handlers (Legacy)
CloudKitShareService still uses completion handlers:
```swift
CloudKitShareService.shared.shareRecipe(recipe, message: msg) { result in
    switch result {
    case .success(let url):
        // Share URL
    case .failure(let error):
        // Show error
    }
}
```

## Error Handling

### Custom Error Types
```swift
enum CommentAnalysisError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int)
    case invalidJSON
    
    var errorDescription: String? {
        // Localized message for UI
    }
}
```

### View Error Handling
```swift
do {
    try CommentService.shared.upvoteComment(comment, context: modelContext)
} catch {
    // Log or show toast
    ToastManager.shared.error(title: "Failed", message: error.localizedDescription)
}
```

## Design System

### Colors
```swift
HeirloomColors.tomato      // Primary
HeirloomColors.cream       // Background
HeirloomColors.charcoal    // Text
HeirloomColors.sage        // Accents
```

### Spacing
```swift
HeirloomSpacing.xs   // 4
HeirloomSpacing.sm   // 8
HeirloomSpacing.md   // 12
HeirloomSpacing.lg   // 16
HeirloomSpacing.xl   // 24
```

### Fonts
```swift
HeirloomFonts.title1
HeirloomFonts.caption1
HeirloomFonts.caption2
```

## Navigation Pattern

**Sheet-based for details:**
```swift
@State private var showComments = false

// Trigger
Button("Comments") { showComments = true }

// Present
.sheet(isPresented: $showComments) {
    NavigationStack {
        RecipeCommentListView(recipe: recipe)
    }
}
```

**No deep NavigationStack in RecipeDetailView** - uses sheets/fullScreenCover instead

## Data Persistence

### SwiftData Configuration
```swift
// HeirloomApp.swift
let config = ModelConfiguration(
    schema: SchemaV1.schema,
    cloudKitDatabase: .automatic  // iCloud sync enabled
)

let container = try ModelContainer(for: schema, configurations: config)
```

### Schema Versioning
```swift
// Core/Models/SchemaV1.swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Recipe.self, Ingredient.self, RecipeComment.self, ...]
    }
}
```

## Integration Checklist for Social Sharing

- [ ] Comments CRUD ✅ CommentService exists
- [ ] Comment analysis ✅ CommentAnalysisService exists
- [ ] Threading ✅ parentComment relationships exist
- [ ] Card back customization ✅ CardBackEditorView exists
- [ ] Local sharing ✅ RecipeShareService (text/PDF)
- [ ] CloudKit sharing ✅ CloudKitShareService (basic implementation)
- [ ] Deep linking ❌ Not yet implemented
- [ ] Real-time collaboration ❌ Not yet implemented
- [ ] User profiles/following ❌ Not yet implemented

---

## File Paths for Extension

### Key Files to Modify/Extend
```
RecipeDetailView
├── Add share sheet customization
├── Pass card back preview to share
└── Add deep link handling

RecipeCommentListView
├── Add reply UI
├── Enhance filter UI
└── Add comment composition

CardBackEditorView
├── Add pinned comment selection UI
├── Add preview rendering
└── Add sticker/image positioning

CommentService
├── Already comprehensive CRUD
└── Add batch operations if needed

CloudKitShareService
├── Convert to async/await
├── Add real-time sync monitoring
└── Enhance with permissions

RecipeCardBack
├── Already has all fields needed
└── Ready for UI implementation
```

---

## Quick Reference: Adding a New Feature

1. **Create Model** (Core/Models/)
   - Add @Model class
   - Define relationships
   - Add to SchemaV1

2. **Create Service** (Core/Services/)
   - Mark with @MainActor or actor
   - Make singleton with static shared
   - Accept ModelContext as parameter

3. **Create View** (Features/)
   - Use @Environment(\.modelContext)
   - Call service.shared methods
   - Handle errors gracefully

4. **Add to Recipe** (if needed)
   - Add relationship with cascade deletion
   - Update inverse relationships

5. **Test**
   - Use preview with in-memory model container
   - Mock service responses in DEBUG
   - Test with real data

---

## Recommended Modernizations

1. **CloudKitShareService:** Convert completion handlers to async/await
2. **Error propagation:** More comprehensive error UI feedback
3. **Services:** Extract protocols for easier testing/mocking
4. **View state:** Consider ViewModel pattern for complex views
5. **Real-time sync:** Monitor CloudKit subscription changes
