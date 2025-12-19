# Heirloom iOS App - Architecture & Implementation Analysis

## Executive Summary

The Heirloom app follows a **layered architecture** with clear separation of concerns:
- **App Layer** (HeirloomApp.swift) - SwiftData initialization & CloudKit configuration
- **Core Layer** - Models, Services, Design System, Extensions
- **Features Layer** - Feature-specific views, logic, and components

**Tech Stack:**
- SwiftUI for all views
- SwiftData for local persistence + CloudKit sync
- Claude AI API for comment analysis
- Native iOS frameworks (CloudKit, Reminders, etc.)

**Total Files:** ~82 Swift files (41 Core + 41 Features)

---

## 1. CURRENT ARCHITECTURE

### 1.1 Directory Structure

```
Heirloom/
├── App/
│   └── HeirloomApp.swift          [Main entry point, SwiftData & service initialization]
│
├── Core/
│   ├── Models/                    [SwiftData @Model entities]
│   │   ├── Recipe.swift           [Primary recipe model with relationships]
│   │   ├── Ingredient.swift       [Parsed ingredient with quantity/unit]
│   │   ├── RecipeComment.swift    [Comments with sentiment analysis]
│   │   ├── RecipeCardBack.swift   [Social card back customization]
│   │   ├── RecipeCollection.swift [Organization]
│   │   ├── Tag.swift
│   │   ├── DinnerParty.swift
│   │   ├── CardStyle.swift        [Visual customization]
│   │   ├── Sticker.swift
│   │   ├── Annotation.swift
│   │   ├── ShoppingCartRecipe.swift
│   │   └── SchemaV1.swift         [Versioned schema definition]
│   │
│   ├── Services/                  [Business logic layer]
│   │   ├── CommentService.swift   [@MainActor CRUD for comments]
│   │   ├── CloudKitShareService.swift
│   │   ├── RecipeShareService.swift
│   │   ├── RecipeImportService.swift
│   │   ├── RemindersService.swift
│   │   ├── IngredientParser.swift
│   │   │
│   │   ├── AI/                    [Claude API integration]
│   │   │   ├── CommentAnalysisService.swift
│   │   │   ├── AIRecipeExtractor.swift
│   │   │   ├── AnthropicAIService.swift
│   │   │   └── Configuration/
│   │   │
│   │   └── Storage/               [File system management]
│   │       ├── ImageStorageService.swift  [Actor pattern for async safety]
│   │       └── ImageCache.swift   [Memory caching]
│   │
│   ├── Design/                    [Design system]
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   └── Components/
│   │       ├── ToastView.swift    [Toast notifications]
│   │       ├── ButtonStyles.swift
│   │       ├── LoadingViews.swift
│   │       └── EmptyStateView.swift
│   │
│   └── Extensions/
│       └── UIImage+Helpers.swift
│
├── Features/                      [Feature modules]
│   ├── Recipes/
│   │   ├── RecipeDetail/
│   │   │   └── RecipeDetailView.swift  [Main detail view with all actions]
│   │   ├── RecipeList/
│   │   ├── RecipeEdit/
│   │   ├── RecipeEditor/
│   │   ├── RecipeImport/
│   │   ├── CookingMode/
│   │   ├── CookbookScanner/
│   │   └── BulkImport/
│   │
│   ├── Comments/
│   │   └── Views/
│   │       ├── RecipeCommentListView.swift  [List with filtering/sorting]
│   │       ├── RecipeCommentView.swift      [Individual comment component]
│   │       └── CardBackEditorView.swift     [Card customization]
│   │
│   ├── CardPersonalization/
│   ├── CloudKitSharing/
│   ├── CloudKitMonitoring/
│   ├── Collections/
│   ├── DinnerParty/
│   ├── Scaling/
│   ├── Shopping/
│   ├── Tags/
│   ├── Settings/
│   └── Onboarding/
│
└── Resources/
    └── Assets.xcassets
```

### 1.2 Data Flow Architecture

```
UI Layer (SwiftUI Views)
    ↓
    ├── @Environment(\.modelContext) [SwiftData context]
    ├── @State (local state)
    └── @Published properties
        ↓
Service Layer (@MainActor singletons)
    ├── CommentService.shared
    ├── CloudKitShareService.shared
    ├── CommentAnalysisService.shared (async AI calls)
    └── ImageStorageService.shared (Actor for safety)
        ↓
Data Persistence Layer
    ├── SwiftData ModelContext
    ├── File System (images)
    └── CloudKit Sync (automatic via SwiftData)
```

### 1.3 CloudKit Configuration

**Location:** `HeirloomApp.swift` (lines 10-49)

```swift
// Configuration in init():
let config = ModelConfiguration(
    schema: SchemaV1.schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .automatic  // iCloud sync enabled
)

modelContainer = try ModelContainer(
    for: schema,
    configurations: config
)
```

**Features:**
- Uses `.automatic` CloudKit database mode
- Fallback to local-only storage if CloudKit unavailable
- Uses versioned schema (SchemaV1) for future migrations
- Automatic sync - no manual sync code needed

---

## 2. KEY EXISTING COMPONENTS

### 2.1 Recipe Model (Core/Models/Recipe.swift)

**Key Pattern:** Relationships with cascade deletion

```swift
@Model
final class Recipe {
    var id: UUID
    var title: String
    
    // Relationships (cascade delete on recipe deletion)
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient]?
    
    @Relationship(deleteRule: .cascade, inverse: \RecipeComment.recipe)
    var comments: [RecipeComment]?
    
    @Relationship(deleteRule: .cascade, inverse: \RecipeCardBack.recipe)
    var cardBack: RecipeCardBack?
    
    // Computed properties
    var sourceDisplayName: String { ... }
    var shouldShowLoveMarks: Bool { ... }
    var listItem: RecipeListItem { ... }  // DTO pattern
    
    // Image helpers (async)
    func loadImage() async -> UIImage?
    func saveImage(_ image: UIImage) async throws
    func deleteImage() async
}
```

**Key Properties for Social Features:**
- `comments: [RecipeComment]?` - Array of comments with cascade delete
- `cardBack: RecipeCardBack?` - One-to-one relationship for card customization
- `passedDownMessage: String?` - Message when sharing
- `generationCount: Int` - Track how many times recipe has been passed down
- `sharedDate: Date?`, `sharedBy: String?` - Share metadata

### 2.2 RecipeComment Model (Core/Models/RecipeComment.swift)

**Pattern:** Threaded comments with sentiment analysis

```swift
@Model
final class RecipeComment {
    var id: UUID
    var createdAt: Date
    
    // Relationships
    @Relationship(inverse: \Recipe.comments)
    var recipe: Recipe?
    
    var parentComment: RecipeComment?  // For threading
    
    @Relationship(deleteRule: .cascade)
    var replies: [RecipeComment]?  // Child comments
    
    // AI Analysis
    var sentimentScore: Double?  // -1.0 to 1.0
    var topics: [String]  // ["texture", "timing", "garlic"]
    var commentType: CommentType  // .tip, .modification, .warning, etc.
    var analysisConfidence: Double?
    
    // User interaction
    var upvotes: Int = 0
    var downvotes: Int = 0
    var isPinned: Bool = false
    var showOnCardBack: Bool = false
    
    // Moderation
    var isFlagged: Bool = false
    var isHidden: Bool = false
    
    // Rich content
    var structuredData: CommentStructuredData?  // Extracted modifications
}

enum CommentType: String, Codable {
    case general, tip, modification, timing, technique
    case substitution, scaling, storage, pairing, warning, question, review
}

enum CommentSource: String, Codable {
    case user, scraped, ai, imported
}
```

**Key Extension Properties:**
- `isTopLevel: Bool` - parentComment == nil
- `voteScore: Int` - upvotes - downvotes
- `isHighEngagement: Bool` - upvotes >= 5 || voteScore >= 3
- `displayAuthor: String` - "Anonymous" fallback
- `displayDate: String` - RelativeDateTimeFormatter

### 2.3 RecipeCardBack Model (Core/Models/RecipeCardBack.swift)

**Pattern:** Configuration object for card display customization

```swift
@Model
final class RecipeCardBack {
    var id: UUID
    var recipe: Recipe?  // Inverse relationship
    
    // User content
    var noteToFriends: String?
    var personalTips: [String] = []
    var userRating: Int?  // 1-5 stars
    var userTags: [String] = []
    
    // Attribution
    var showAttribution: Bool = true
    var customAttributionText: String?
    var attributionPosition: AttributionPosition = .bottomLeft
    
    // Comment display
    var pinnedCommentIDs: [UUID] = []
    var maxCommentsToDisplay: Int = 3
    var showSentimentIndicators: Bool = true
    
    // Visual customization
    var backgroundStyle: CardBackgroundStyle = .cream  // enum
    var textColor: String = "#2D2D2D"
    var showBorder: Bool = true
    var fontSizeMultiplier: Double = 1.0
    
    // Sharing
    var shareMessage: String?
    var includeBackWhenSharing: Bool = true
    var privacyLevel: CardBackPrivacy = .friendsOnly
    
    // Layout
    var visibleSections: [CardBackSection] = [...]
    var layoutStyle: CardBackLayout = .standard
}

enum CardBackgroundStyle: String, Codable {
    case cream, vintage, lined, grid, photo, solid
}

enum CardBackSection: String, Codable, CaseIterable {
    case attribution, noteToFriends, pinnedComments, userTips, userRating, userTags, cookingHistory
}
```

### 2.4 CommentService (Core/Services/CommentService.swift)

**Pattern:** @MainActor singleton with CRUD operations

```swift
@MainActor
final class CommentService {
    static let shared = CommentService()
    private init() {}
    
    // MARK: - Create
    func addComment(
        to recipe: Recipe,
        text: String,
        authorName: String? = nil,
        source: CommentSource = .user,
        commentType: CommentType = .general,
        parentComment: RecipeComment? = nil,
        context: ModelContext
    ) throws -> RecipeComment
    
    func importComments(
        _ commentTexts: [String],
        to recipe: Recipe,
        source: CommentSource = .scraped,
        context: ModelContext
    ) throws -> [RecipeComment]
    
    // MARK: - Read
    func getTopLevelComments(for recipe: Recipe) -> [RecipeComment]
    func getTopComments(for recipe: Recipe, limit: Int = 5) -> [RecipeComment]
    func getPinnedComments(for recipe: Recipe) -> [RecipeComment]
    func getComments(for recipe: Recipe, ofType type: CommentType) -> [RecipeComment]
    func getHighEngagementComments(for recipe: Recipe) -> [RecipeComment]
    func getPositiveComments(for recipe: Recipe) -> [RecipeComment]
    func searchComments(for recipe: Recipe, query: String) -> [RecipeComment]
    
    // MARK: - Update
    func updateComment(_ comment: RecipeComment, text: String, context: ModelContext) throws
    func upvoteComment(_ comment: RecipeComment, context: ModelContext) throws
    func downvoteComment(_ comment: RecipeComment, context: ModelContext) throws
    func togglePin(_ comment: RecipeComment, context: ModelContext) throws
    func updateSentiment(for comment: RecipeComment, score: Double, confidence: Double, 
                         topics: [String], context: ModelContext) throws
    
    // MARK: - Delete
    func deleteComment(_ comment: RecipeComment, context: ModelContext) throws
    func deleteAllComments(for recipe: Recipe, context: ModelContext) throws
    func hideComment(_ comment: RecipeComment, reason: String?, context: ModelContext) throws
    
    // MARK: - Statistics
    func getStatistics(for recipe: Recipe) -> CommentStatistics
}
```

**Key Pattern:** All mutations require `ModelContext` parameter - services don't manage context

### 2.5 CommentAnalysisService (Core/Services/AI/CommentAnalysisService.swift)

**Pattern:** @MainActor async service for Claude API integration

```swift
@MainActor
final class CommentAnalysisService {
    static let shared = CommentAnalysisService()
    
    private let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    private let model = "claude-3-haiku-20240307"
    
    // Async analysis - returns structured results
    func analyzeComment(_ comment: RecipeComment) async throws -> CommentAnalysis
    
    func analyzeComments(_ comments: [RecipeComment]) async throws -> [CommentAnalysis]
    
    func extractInsights(from comments: [RecipeComment]) async throws -> RecipeInsights
    
    // Private helpers
    private func buildAnalysisPrompt(for commentText: String) -> String
    private func callClaude(with prompt: String) async throws -> String
    private func parseAnalysisResponse(_ response: String) throws -> CommentAnalysis
}

// Returned types
struct CommentAnalysis {
    let commentText: String
    let sentiment: Double  // -1.0 to 1.0
    let confidence: Double  // 0.0 to 1.0
    let commentType: CommentType
    let topics: [String]
    let structuredData: CommentStructuredData?
}

struct RecipeInsights {
    let commonThemes: [String]
    let popularModifications: [PopularModification]
    let topTips: [RecipeTip]
    let warnings: [String]
    let overallSentiment: Double
    let successRate: Double?
}
```

### 2.6 CloudKitShareService (Core/Services/CloudKitShareService.swift)

**Pattern:** High-level sharing abstraction with CloudKit backend

```swift
@MainActor
class CloudKitShareService {
    static let shared = CloudKitShareService()
    
    private let container = CKContainer.default()
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    // MARK: - Share
    func shareRecipe(
        _ recipe: Recipe,
        message: String? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    )
    
    func passDownRecipe(
        _ recipe: Recipe,
        to recipient: String,
        message: String,
        completion: @escaping (Result<URL, Error>) -> Void
    )
    
    // MARK: - Receive
    func acceptSharedRecipe(
        from url: URL,
        modelContext: ModelContext,
        completion: @escaping (Result<Recipe, Error>) -> Void
    )
    
    // MARK: - User Info
    func getCurrentUserName() async throws -> String
    
    // Private helpers
    private func createRecipeRecord(from recipe: Recipe, message: String? = nil) throws -> CKRecord
    private func createRecipe(from record: CKRecord) throws -> Recipe
    private func createShareURL(for record: CKRecord) async throws -> URL
}
```

**Key Pattern:** Completion-based API (older pattern, could be modernized to async/await)

### 2.7 RecipeShareService (Core/Services/RecipeShareService.swift)

**Pattern:** Local sharing (text/PDF) via UIActivityViewController

```swift
@MainActor
class RecipeShareService {
    static let shared = RecipeShareService()
    
    func shareRecipe(_ recipe: Recipe, as format: ShareFormat, from view: UIView)
    
    enum ShareFormat {
        case text
        case pdf
        case url  // For CloudKit sharing
    }
    
    // Private helpers
    private func prepareShareItems(for recipe: Recipe, format: ShareFormat) async throws -> [Any]
    private func formatRecipeAsText(_ recipe: Recipe) -> String
    private func generatePDF(for recipe: Recipe) async throws -> Data
    private func presentShareSheet(items: [Any], from view: UIView)
}
```

---

## 3. VIEW LAYER PATTERNS

### 3.1 RecipeDetailView (Features/Recipes/RecipeDetail/RecipeDetailView.swift)

**Pattern:** Complex view with multiple sheets and state management

```swift
struct RecipeDetailView: View {
    let recipe: Recipe
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Sheet controls
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showCookingMode = false
    @State private var showShareSheet = false
    @State private var showCloudKitShare = false
    @State private var showPassDown = false
    @State private var showComments = false
    @State private var showCardBack = false
    
    // Feature state
    @State private var servingMultiplier: Double = 1.0
    @State private var targetServings: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                recipeImage          // AsyncRecipeImage
                
                VStack(spacing: HeirloomSpacing.xl) {
                    headerSection    // Title + favorite/cook buttons
                    tagsAndCollectionsSection
                    metadataSection  // Servings dropdown, times
                    startCookingButton
                    ingredientsSection
                    instructionsSection
                    notesSection
                    sourceSection
                    commentsSection  // NEW - shows comment count
                }
                .padding(HeirloomSpacing.lg)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {  // Share menu with sub-options
                    Menu("Share") {
                        Button("As Text") { shareRecipe(as: .text) }
                        Button("As PDF") { shareRecipe(as: .pdf) }
                        Divider()
                        Button("Via iCloud (Live Recipe)") { showCloudKitShare = true }
                        Button("Pass Down (Special)") { showPassDown = true }
                    }
                    
                    Button("Comments (\(recipe.comments?.count ?? 0))") { showComments = true }
                    Button("Customize Card Back") { showCardBack = true }
                    // ... more menu items
                }
            }
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                RecipeCommentListView(recipe: recipe)
            }
        }
        .sheet(isPresented: $showCardBack) {
            CardBackEditorView(recipe: recipe)
        }
    }
    
    // MARK: - Private Helpers
    private func shareRecipe(as format: RecipeShareService.ShareFormat) {
        // Uses RecipeShareService.shared
    }
}
```

**Key Patterns:**
1. **Navigation:** Sheet-based (not NavigationStack for detail)
2. **State:** Multiple @State variables for sheet controls
3. **Environment:** Uses @Environment(\.modelContext) for SwiftData
4. **Computed Properties:** Separate views for each section
5. **Error Handling:** confirmationDialog for destructive actions

### 3.2 RecipeCommentListView (Features/Comments/Views/RecipeCommentListView.swift)

**Pattern:** Filterable/sortable list with search

```swift
struct RecipeCommentListView: View {
    let recipe: Recipe
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var sortOption: CommentSortOption = .topRated
    @State private var filterType: CommentType?
    @State private var filterSource: CommentSource?
    @State private var filterSentiment: SentimentFilter?
    
    // MARK: - Computed Properties (Filter & Sort)
    private var filteredComments: [RecipeComment] {
        var comments = recipe.comments ?? []
        
        // Apply all filters
        if !searchText.isEmpty {
            comments = CommentService.shared.searchComments(for: recipe, query: searchText)
        }
        if let type = filterType {
            comments = comments.filter { $0.commentType == type }
        }
        // ... more filters
        
        return comments.filter { !$0.isHidden }
    }
    
    private var sortedComments: [RecipeComment] {
        switch sortOption {
        case .topRated:
            return filteredComments.sorted { $0.voteScore > $1.voteScore }
        case .mostRecent:
            return filteredComments.sorted { $0.createdAt > $1.createdAt }
        // ...
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $searchText)
            
            // Filter/sort controls
            ScrollView(.horizontal) {
                HStack { /* filter buttons */ }
            }
            
            // Statistics
            HStack {
                Text("Total: \(statistics.totalComments)")
                // ... more stats
            }
            
            // Comment list
            List(displayComments) { comment in
                RecipeCommentView(
                    comment: comment,
                    onUpvote: { upvoteComment(comment) },
                    onDownvote: { downvoteComment(comment) },
                    onPin: { togglePin(comment) },
                    onReply: { /* TODO */ }
                )
            }
        }
    }
}

enum CommentSortOption {
    case topRated, mostRecent, mostPositive, mostNegative, mostReplies
}

enum SentimentFilter {
    case positive, neutral, negative
}
```

### 3.3 RecipeCommentView (Features/Comments/Views/RecipeCommentView.swift)

**Pattern:** Reusable component with callback actions

```swift
struct RecipeCommentView: View {
    let comment: RecipeComment
    let onUpvote: () -> Void
    let onDownvote: () -> Void
    let onPin: () -> Void
    let onReply: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Author info & sentiment
            HStack {
                Circle()  // Author avatar
                    .fill(commentTypeColor.opacity(0.2))
                    .overlay { Image(systemName: commentTypeIcon) }
                
                VStack(alignment: .leading) {
                    Text(comment.displayAuthor).font(.subheadline)
                    HStack {
                        Text(comment.displayDate).font(.caption2)
                        if comment.source == .scraped {
                            Text("• from web").font(.caption2)
                        }
                    }
                }
                
                Spacer()
                
                // Sentiment indicator
                if let sentiment = comment.sentimentScore {
                    sentimentIndicator(score: sentiment)
                }
                
                // Pinned badge
                if comment.isPinned {
                    Image(systemName: "pin.fill").font(.caption)
                }
            }
            
            // Comment text
            Text(comment.text).font(.subheadline)
            
            // Topics
            if !comment.topics.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(comment.topics, id: \.self) { topic in
                            Text(topic).font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.heirloomParchment).opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Actions bar
            HStack(spacing: 16) {
                Button { onUpvote() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("\(comment.upvotes)").font(.caption)
                    }
                    .foregroundStyle(comment.upvotes > 0 ? .green : .secondary)
                }
                
                Button { onDownvote() } label: { /* ... */ }
                Button { onReply() } label: { /* ... */ }
                
                Spacer()
                
                Button { onPin() } label: {
                    Image(systemName: comment.isPinned ? "pin.slash" : "pin")
                }
                
                Menu {
                    Button { /* copy */ } label: { Label("Copy", systemImage: "doc.on.doc") }
                    Button { toggleCardBackVisibility() } label: {
                        Label(
                            comment.showOnCardBack ? "Remove from Card" : "Show on Card Back",
                            systemImage: "rectangle.portrait"
                        )
                    }
                } label: { Image(systemName: "ellipsis") }
            }
            
            // Replies
            if let replies = comment.replies, !replies.isEmpty {
                Divider().padding(.leading, 32)
                VStack(alignment: .leading) {
                    ForEach(replies) { reply in
                        RecipeCommentView(  // Recursive rendering
                            comment: reply,
                            onUpvote: { upvoteComment(reply) },
                            onDownvote: { downvoteComment(reply) },
                            onPin: { togglePin(reply) },
                            onReply: {}
                        ).padding(.leading, 32)
                    }
                }
            }
        }
        .padding(16)
        .background(comment.showOnCardBack ? Color(.heirloomCream).opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helpers
    private var commentTypeColor: Color {
        switch comment.commentType {
        case .tip: return .blue
        case .modification: return .purple
        case .warning: return .red
        // ...
        default: return .gray
        }
    }
    
    private func upvoteComment(_ comment: RecipeComment) {
        do {
            try CommentService.shared.upvoteComment(comment, context: modelContext)
        } catch {
            print("Failed to upvote: \(error)")
        }
    }
}
```

**Key Patterns:**
1. **Callbacks:** Actions passed as closures (onUpvote, onPin, etc.)
2. **Recursive:** Can render nested replies
3. **Type-based styling:** commentTypeColor/Icon based on CommentType enum
4. **Sentiment visualization:** Shows score as percentage with color coding
5. **Service integration:** Calls CommentService.shared with modelContext

### 3.4 CardBackEditorView (Features/Comments/Views/CardBackEditorView.swift)

**Pattern:** Form-based editor with preview

```swift
struct CardBackEditorView: View {
    let recipe: Recipe
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var noteToFriends: String = ""
    @State private var personalTips: [String] = []
    @State private var maxCommentsToDisplay: Int = 3
    @State private var backgroundStyle: CardBackgroundStyle = .cream
    @State private var layoutStyle: CardBackLayout = .standard
    @State private var visibleSections: Set<CardBackSection> = [
        .attribution, .noteToFriends, .pinnedComments, .userTips
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // Preview section
                Section {
                    Button { showingPreview = true } label: {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("Preview Card Back")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                } header: { Text("Preview") }
                
                // Personal message
                Section {
                    TextEditor(text: $noteToFriends)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if noteToFriends.isEmpty {
                                Text("e.g., \"This recipe was passed down from my grandmother...\"")
                                    .foregroundStyle(.secondary)
                                    .allowsHitTesting(false)
                            }
                        }
                    
                    Toggle("Show on card back", isOn: visibleSectionBinding(.noteToFriends))
                } header: { Text("Note to Friends") }
                
                // Personal tips
                Section {
                    ForEach(Array(personalTips.enumerated()), id: \.offset) { index, tip in
                        HStack {
                            Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                            Text(tip).font(.subheadline)
                            Spacer()
                            Button { removeTip(at: index) } label: {
                                Image(systemName: "xmark").foregroundStyle(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add a tip...", text: $newTipText)
                        Button { addTip() } label: { Image(systemName: "plus.circle.fill") }
                    }
                } header: { Text("Personal Tips") }
                
                // Layout options
                Section {
                    Picker("Background", selection: $backgroundStyle) {
                        ForEach(CardBackgroundStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    
                    Picker("Layout", selection: $layoutStyle) {
                        ForEach(CardBackLayout.allCases, id: \.self) { layout in
                            Text(layout.rawValue).tag(layout)
                        }
                    }
                } header: { Text("Visual Style") }
            }
            .navigationTitle("Customize Card Back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { saveCardBack() }
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            CardBackPreviewView(recipe: recipe)
        }
    }
    
    private func visibleSectionBinding(_ section: CardBackSection) -> Binding<Bool> {
        Binding(
            get: { visibleSections.contains(section) },
            set: { 
                if $0 {
                    visibleSections.insert(section)
                } else {
                    visibleSections.remove(section)
                }
            }
        )
    }
    
    private func addTip() {
        personalTips.append(newTipText)
        newTipText = ""
    }
    
    private func saveCardBack() {
        // Update recipe.cardBack and save to context
        dismiss()
    }
}
```

**Key Patterns:**
1. **Form-based:** Uses Form + Section for organized input
2. **Binding transformations:** visibleSectionBinding converts Set to toggle binding
3. **Live editing:** @State variables for all customization options
4. **Preview:** Navigation to preview view
5. **Validation:** Type-safe enums for styles

---

## 4. ERROR HANDLING & ASYNC PATTERNS

### 4.1 Error Handling Strategy

**1. Custom Error Types with LocalizedError**

```swift
// CloudKitShareService.swift
enum CloudKitError: LocalizedError {
    case notAvailable
    case invalidRecord
    case invalidShare
    case shareCreationFailed
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "iCloud is not available..."
        case .shareCreationFailed: return "Failed to create share link..."
        }
    }
}

// CommentAnalysisService.swift
enum CommentAnalysisError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int)
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Claude API key not configured"
        case .apiError(let code): return "API error: HTTP \(code)"
        }
    }
}

// ImageStorageService.swift
enum ImageError: LocalizedError {
    case compressionFailed
    case writeFailed(Error)
    case notFound
}
```

**2. Async/Await for Async Operations**

Most services use async functions:
```swift
// CommentAnalysisService
func analyzeComment(_ comment: RecipeComment) async throws -> CommentAnalysis

func analyzeComments(_ comments: [RecipeComment]) async throws -> [CommentAnalysis] {
    var results: [CommentAnalysis] = []
    
    for comment in comments {
        do {
            let analysis = try await analyzeComment(comment)
            results.append(analysis)
        } catch {
            print("Failed to analyze comment: \(error)")
            // Continue with other comments - graceful degradation
        }
    }
    
    return results
}
```

**3. Completion Handlers (Legacy Pattern)**

CloudKitShareService still uses completion handlers:
```swift
func shareRecipe(
    _ recipe: Recipe,
    message: String? = nil,
    completion: @escaping (Result<URL, Error>) -> Void
) {
    Task {
        do {
            // ... work ...
            completion(.success(shareURL))
        } catch {
            completion(.failure(error))
        }
    }
}
```

**4. View-Level Error Handling**

```swift
// In views, errors typically shown via Toast
do {
    try CommentService.shared.upvoteComment(comment, context: modelContext)
} catch {
    print("Failed to upvote: \(error)")
    // Could also show ToastManager.shared.error(title:message:)
}
```

### 4.2 Concurrency Safety

**1. @MainActor for UI Updates**

Services that interact with UI use @MainActor:
```swift
@MainActor
final class CommentService {
    // All methods implicitly run on main thread
}

@MainActor
final class CloudKitShareService {
    // All methods implicitly run on main thread
}
```

**2. Actor Pattern for File I/O**

ImageStorageService uses Actor for thread-safe file operations:
```swift
actor ImageStorageService {
    // Only one thread can access methods at a time
    
    func saveImage(_ image: UIImage, recipeId: UUID) async throws -> String
    func loadImage(fileName: String) async -> UIImage?
    func deleteImage(fileName: String) async
}

// Called with await:
let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: recipe.id)
```

---

## 5. SERVICE ACCESS PATTERN

### How Services Access ModelContext

**Key Pattern:** Services DON'T manage ModelContext

```swift
// ✅ CORRECT: Service takes ModelContext as parameter
@MainActor
final class CommentService {
    func addComment(
        to recipe: Recipe,
        text: String,
        context: ModelContext  // Parameter, not stored
    ) throws -> RecipeComment {
        let comment = RecipeComment(text: text, recipe: recipe)
        context.insert(comment)  // Use provided context
        try context.save()
        return comment
    }
}

// ✅ In view, pass the context
@Environment(\.modelContext) private var modelContext

Button { 
    let comment = try CommentService.shared.addComment(
        to: recipe,
        text: "Great recipe!",
        context: modelContext  // Pass from view
    )
} label: { Text("Add Comment") }

// ❌ WRONG: Service managing its own context
// (This pattern is NOT used in Heirloom)
@MainActor
final class BadService {
    private let modelContainer: ModelContainer
    var modelContext: ModelContext { /* ... */ }
    
    func addComment(_ text: String) {
        // Anti-pattern - service creates context
    }
}
```

**Why This Pattern?**
1. **Single Context per Transaction:** Views already have a context, reuse it
2. **Testability:** Easy to mock or replace context in tests
3. **Consistency:** All changes in one operation save together
4. **Performance:** No competing contexts

---

## 6. STATE MANAGEMENT APPROACH

### View State Hierarchy

```swift
// App-level setup (HeirloomApp.swift)
@State private var modelContainer: ModelContainer?
    ↓
// Provided to all views via .modelContainer()
    ↓
// Feature views access via @Environment
@Environment(\.modelContext) private var modelContext

// Local view state (@State)
@State private var showComments = false
@State private var searchText = ""
@State private var sortOption: CommentSortOption = .topRated

// Computed derived state
private var filteredComments: [RecipeComment] {
    // Combine multiple @State variables
}

private var sortedComments: [RecipeComment] {
    // Sort the filtered results
}
```

### Service Singletons

All major services are stateless singletons:
```swift
CommentService.shared.addComment(...)
CloudKitShareService.shared.shareRecipe(...)
CommentAnalysisService.shared.analyzeComment(...)
ImageStorageService.shared.saveImage(...)
```

**Benefits:**
1. No duplication of service instances
2. Easy to call from any view
3. Consistent state across app
4. No initialization burden on views

---

## 7. NAMING CONVENTIONS

### Service Files
- `*Service.swift` - Business logic (CommentService, CloudKitShareService)
- `*Protocol.swift` - Interface definitions (AIServiceProtocol)
- `*Error.swift` - Error types

### Model Files
- `*.swift` - Single model per file (Recipe.swift, RecipeComment.swift)

### View Files
- `*View.swift` - SwiftUI views (RecipeDetailView, CardBackEditorView)
- Views in subfolders by feature (Features/Comments/Views/)

### Colors & Spacing
- `HeirloomColors.tomato`, `HeirloomColors.cream`, etc.
- `HeirloomSpacing.xs`, `.sm`, `.md`, `.lg`, `.xl`
- `HeirloomFonts.title1`, `.caption1`, etc.

### Component Naming
- Leading with feature context when specific (RecipeCommentView, not CommentView)
- Descriptive suffixes (RecipeDetailView, RecipeCommentListView)

---

## 8. DEEP LINKING & SHARE INTEGRATION POINTS

### Current Share Implementation Points

**1. RecipeShareService** (Local sharing)
- Text format: Plain text with structured layout
- PDF format: UIGraphicsPDFRenderer with recipe data
- Uses UIActivityViewController for system share sheet

**2. CloudKitShareService** (Network sharing)
- Converts Recipe → CKRecord
- Creates CKShare for read-only access
- Generates shareable URL
- Uses CloudKit public database

**3. RecipeDetailView Integration**
- Share menu in toolbar
- Multiple share options (Text, PDF, CloudKit, Pass Down)
- Shows as sheets

### Deep Linking Integration Points

**Current:** Not fully implemented
**Recommended Extensions:**
1. URL scheme for opening shared recipes
2. Universal Links support
3. Recipe importer for shared URLs

---

## 9. KEY ARCHITECTURAL DECISIONS

### 1. Image Storage (File System, Not Database)
- Images stored in `Documents/RecipeImages`
- Recipe only stores filename reference
- Prevents CloudKit/database bloat
- ImageCache for memory optimization

### 2. Relationship Cascading
```swift
@Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
var ingredients: [Ingredient]?

// When recipe is deleted, all ingredients cascade deleted
```

### 3. Versioned Schema (SchemaV1)
- Enables future migrations
- Currently V1.0.0
- Plan for V2, V3, etc. with custom migration logic

### 4. Computed Properties for DTOs
```swift
// Lightweight DTO to avoid loading all ingredients
var listItem: RecipeListItem {
    RecipeListItem(id: id, title: title, ...)
}
```

### 5. Service Isolation
- Services don't manage ModelContext
- Services don't import SwiftUI
- Clear separation: views ↔ services ↔ models

---

## 10. EXTENSION POINTS FOR SOCIAL SHARING

### Areas to Extend

**1. Deep Linking**
- Add URL scheme parsing in HeirloomApp
- Handle recipe:// or heirloom:// URLs
- Route to recipe view with animation

**2. Share Sheet Customization**
- RecipeDetailView.shareRecipe() → RecipeShareService
- Add preview/details to share sheet
- Include recipe image

**3. Cloud Sharing Enhancement**
- CloudKitShareService currently basic
- Could add real-time collaboration
- Could add permission levels

**4. Comment Threading**
- RecipeCommentView supports nested replies
- parentComment → replies relationship
- Could add reply compose UI

**5. Card Back Distribution**
- RecipeCardBack could be previewed in share
- Include in PDF exports
- Show when receiving shared recipe

---

## 11. TESTING PATTERNS

### Mock Support

**CommentAnalysisService Mock:**
```swift
#if DEBUG
extension CommentAnalysisService {
    static func mockAnalysis(for commentText: String) -> CommentAnalysis {
        CommentAnalysis(
            commentText: commentText,
            sentiment: 0.75,
            confidence: 0.85,
            commentType: .modification,
            topics: ["flavor", "texture"],
            structuredData: nil
        )
    }
}
#endif
```

### Preview Support

```swift
#Preview("Comment Variations") {
    List {
        RecipeCommentView(
            comment: .sample(
                text: "This recipe turned out amazing!",
                source: .user,
                commentType: .modification
            ),
            onUpvote: {},
            onDownvote: {},
            onPin: {},
            onReply: {}
        )
    }
    .modelContainer(for: RecipeComment.self, inMemory: true)
}
```

---

## CONCLUSION

The Heirloom architecture is well-structured for adding social sharing features:

✅ **Strengths:**
- Clear separation of concerns (views/services/models)
- Proper use of Swift concurrency (@MainActor, async/await, Actor)
- Established patterns for relationships and persistence
- Comment infrastructure already in place
- Multiple share mechanisms (local + CloudKit)

⚠️ **Areas to Watch:**
- CloudKitShareService uses completion handlers (could modernize)
- Deep linking not yet implemented
- Error handling could be more comprehensive in views
- Some services could benefit from protocol extraction for testing

🎯 **Ready for:**
- Share sheet enhancements
- Deep linking implementation
- Real-time collaboration features
- Advanced comment threading UI
- Social discovery features

