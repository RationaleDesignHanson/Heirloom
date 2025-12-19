# Heirloom Phase 2: Prompt Sequence Reference

**Created:** December 18, 2024
**Purpose:** Detailed outline of all 12 implementation prompts
**Status:** Ready to execute sequentially

---

## How to Use This Document

1. **Sequential Execution:** Execute prompts in order (dependencies marked)
2. **Testing Between Prompts:** Complete testing checklist before moving to next
3. **Reference Master Plan:** Check PHASE_2_MASTER_PLAN.md for big picture context
4. **Track Progress:** Mark completed in PHASE_2_PROGRESS_TRACKER.md

---

## 📋 Prompt Overview

| # | Prompt Name | Phase | Estimated Time | Dependencies |
|---|-------------|-------|----------------|--------------|
| 1 | CloudKit Infrastructure & Education | 2A | 3-4 hours | None |
| 2 | Local Provenance Model | 2A | 2-3 hours | Prompt 1 |
| 3 | CKShare-Based Recipe Sharing | 2A | 3-4 hours | Prompts 1, 2 |
| 4 | Share Acceptance & Recipe Import | 2A | 3-4 hours | Prompts 1, 2, 3 |
| 5 | Server-Side Web Recipe Import | 2B | 4-6 hours | None (parallel) |
| 6 | World-Class OCR Enhancement | 2B | 4-6 hours | None (parallel) |
| 7 | Shared Comments System | 2C | 3-4 hours | Prompts 1, 3, 4 |
| 8 | QR Code & Deep Link Sharing | 2C | 2-3 hours | Prompt 3 |
| 9 | Privacy Policy & Opt-In Flows | 2C | 3-4 hours | Prompts 1, 3, 7 |
| 10 | Advanced Lineage Visualization | 2D | 4-5 hours | Prompts 2, 3, 4 |
| 11 | Analytics & Trending Algorithm | 2D | 4-5 hours | Prompts 1, 7 |
| 12 | Comprehensive Testing & Integration | 2D | 6-8 hours | All prompts |

**Total Estimated Time:** 40-54 hours (spread over 5-6 weeks)

---

## PHASE 2A: CloudKit Foundation & Core Sharing

### Prompt 1: CloudKit Infrastructure & Education

**Goal:** Build robust CloudKit sync infrastructure and educate on CloudKit fundamentals

**What You'll Learn:**
- CloudKit databases: Private, Public, Shared
- CKRecord basics
- Subscriptions and notifications
- Conflict resolution strategies
- Error handling and retry logic

**What You'll Build:**
- `CloudKitSyncCoordinator.swift` service (400+ lines)
  - Batch operations for efficiency
  - Offline operation queue
  - Retry logic with exponential backoff
  - Error handling and logging
  - Subscription management
- CloudKit dashboard schema setup
- Development vs production environment config
- Test scenarios for 2-device validation

**Files Created:**
- `/Heirloom/Core/Services/CloudKit/CloudKitSyncCoordinator.swift`
- `/Heirloom/Core/Services/CloudKit/CloudKitError.swift`
- `/Heirloom/Core/Services/CloudKit/SyncOperation.swift`

**Testing Checklist:**
- [ ] CloudKit dashboard shows development schema
- [ ] Create record on Device A, appears in dashboard
- [ ] Fetch record on Device B
- [ ] Offline queue: Create record offline, processes when online
- [ ] Retry logic: Simulate network failure, verify 3 retry attempts
- [ ] Subscription: Update record on Device A, Device B receives notification

**Deliverable:** Working CloudKit infrastructure with proven 2-device sync

---

### Prompt 2: Local Provenance Model

**Goal:** Track recipe origin, lineage, and share chain locally

**What You'll Learn:**
- SwiftData schema versioning
- Migration from SchemaV1 to SchemaV2
- Codable structs for embedded data
- Computed properties for derived state

**What You'll Build:**
- `ProvenanceMetadata` struct (embedded in Recipe)
  ```swift
  struct ProvenanceMetadata: Codable {
      var sourceType: SourceType  // .userCreated, .imported, .shared
      var sourceURL: String?
      var sourceAttribution: String?
      var rootProvenanceHash: String
      var generation: Int  // 0 = original, 1+ = shared
      var parentShareID: String?
      var createdAt: Date
      var cachedMetrics: AggregatedMetrics
      var lastSyncedAt: Date
  }
  ```
- Update Recipe model to include provenance
- Migration plan: SchemaV1 → SchemaV2
- Attribution display helpers
- Generation badge UI component

**Files Modified:**
- `/Heirloom/Core/Models/Recipe.swift`
- `/Heirloom/Core/Models/SchemaV1.swift` → `SchemaV2.swift`

**Files Created:**
- `/Heirloom/Core/Models/ProvenanceMetadata.swift`
- `/Heirloom/Core/Components/AttributionBadge.swift`

**Testing Checklist:**
- [ ] Create recipe, provenance metadata populated
- [ ] Migration: Existing recipes preserve data
- [ ] Attribution badge displays correctly
- [ ] Generation badge shows correct number
- [ ] Computed properties return expected values

**Deliverable:** Recipe model tracks provenance locally

---

### Prompt 3: CKShare-Based Recipe Sharing

**Goal:** Implement recipe sharing using Apple's CKShare infrastructure

**What You'll Learn:**
- CKShare creation and configuration
- Share permissions (read-only vs read-write)
- Share URL generation
- CKShare.participants management
- Share expiration handling

**What You'll Build:**
- `RecipeShareService.swift` (300+ lines)
  ```swift
  @MainActor
  final class RecipeShareService {
      func createShare(for recipe: Recipe, options: ShareOptions) async throws -> CKShare
      func generateShareURL(from share: CKShare) -> URL
      func revokeShare(_ share: CKShare) async throws
      func checkShareStatus(_ shareID: String) async throws -> ShareStatus
  }
  ```
- Share options configuration
  - Include personal notes
  - Include my comments
  - Include my rating
  - Expiration duration
- Share sheet UI component
  - Live preview of recipe card
  - Customization toggles
  - Personal message field
  - Share method picker (Messages, Email, Copy Link, AirDrop)

**Files Created:**
- `/Heirloom/Core/Services/CloudKit/RecipeShareService.swift`
- `/Heirloom/Features/Sharing/Views/RecipeShareSheet.swift`
- `/Heirloom/Features/Sharing/Views/SharePreviewCard.swift`
- `/Heirloom/Core/Models/ShareOptions.swift`

**Testing Checklist:**
- [ ] Create share on Device A
- [ ] Share URL generated
- [ ] Send via Messages to Device B
- [ ] Share appears in CloudKit dashboard
- [ ] Share permissions correct (read-only)
- [ ] Expiration set correctly (7 days default)

**Deliverable:** Working share creation flow

---

### Prompt 4: Share Acceptance & Recipe Import

**Goal:** Handle incoming shares and import recipes to recipient's collection

**What You'll Learn:**
- Deep link handling (URL schemes)
- Universal links configuration
- CKShare acceptance flow
- Recipe duplication with provenance linking

**What You'll Build:**
- Deep link handler (AppDelegate/SceneDelegate)
  - Handle `heirloom://share/{shareID}`
  - Handle `https://heirloom.app/r/{shortcode}`
- `RecipeReceiveSheet.swift` UI
  - Beautiful share preview
  - Sharer name + personal message
  - Lineage summary ("Shared by Sarah, originally from AllRecipes")
  - Collection picker (which box to add to)
  - "Add to My Recipes" CTA
- Share acceptance logic
  - Fetch CKShare data
  - Create local Recipe copy
  - Link provenance (parentShareID, generation+1)
  - Import selected comments
  - Save to ModelContext
- Thank sender notification (optional)

**Files Modified:**
- `/Heirloom/App/HeirloomApp.swift` (deep link registration)
- `/Heirloom/Info.plist` (URL schemes)

**Files Created:**
- `/Heirloom/Core/Services/DeepLinkHandler.swift`
- `/Heirloom/Features/Sharing/Views/RecipeReceiveSheet.swift`
- `/Heirloom/Core/Services/CloudKit/ShareAcceptanceService.swift`

**Testing Checklist:**
- [ ] Tap share link on Device B
- [ ] RecipeReceiveSheet displays
- [ ] Accept share
- [ ] Recipe appears in Device B's collection
- [ ] Provenance shows "Shared by Device A"
- [ ] Generation = 1 (parent was 0)
- [ ] Selected comments imported
- [ ] Original recipe on Device A unchanged

**Deliverable:** End-to-end sharing flow working (create → send → accept → import)

---

## PHASE 2B: Content Import

### Prompt 5: Server-Side Web Recipe Import

**Goal:** Import recipes from web URLs using Google Cloud Function

**What You'll Learn:**
- Google Cloud Functions deployment
- HTML parsing with Cheerio (Node.js) or BeautifulSoup (Python)
- Recipe schema detection (JSON-LD, schema.org)
- Paywall detection strategies
- Rate limiting and caching

**What You'll Build:**

**Server-Side (Google Cloud Function):**
- `parseRecipeURL` function (Node.js recommended)
  - Accept POST with URL
  - Fetch HTML with user-agent header
  - Detect recipe schema (JSON-LD first)
  - Parse ingredients, instructions, metadata
  - Detect paywall (subscription gate, login required)
  - Return structured JSON
- Platform-specific parsers
  - AllRecipes.com
  - NYTCooking.com (paywalled)
  - SeriousEats.com
  - Generic fallback (schema.org)
- Caching layer (Cloud Firestore or Memcache)
  - Cache parsed recipes for 24 hours
  - Reduce redundant requests
- Rate limiting
  - Max 1 request/second per site
  - Max 10 requests/minute per user

**iOS Client:**
- `WebRecipeImportService.swift`
  ```swift
  @MainActor
  final class WebRecipeImportService {
      func importRecipe(from url: URL) async throws -> Recipe
      func checkPaywall(for url: URL) async throws -> PaywallStatus
      func previewRecipe(from url: URL) async throws -> RecipePreview
  }
  ```
- Import flow UI
  - URL input field with paste button
  - Loading indicator during parsing
  - Preview before import (title, image, author)
  - Paywall handling: Show "Subscribe" button → open Safari
  - Attribution display
  - Edit before save option

**Files Created:**
- **Server:** `/cloud-functions/parseRecipeURL/index.js`
- **Server:** `/cloud-functions/parseRecipeURL/package.json`
- **Server:** `/cloud-functions/parsers/allrecipes.js`
- **Server:** `/cloud-functions/parsers/nytcooking.js`
- **Server:** `/cloud-functions/parsers/generic.js`
- **iOS:** `/Heirloom/Core/Services/Import/WebRecipeImportService.swift`
- **iOS:** `/Heirloom/Features/Import/Views/WebRecipeImportView.swift`
- **iOS:** `/Heirloom/Core/Models/PaywallStatus.swift`

**Testing Checklist:**
- [ ] Deploy Cloud Function to Google Cloud
- [ ] Test with AllRecipes.com URL → full recipe imported
- [ ] Test with NYTCooking.com URL → paywall detected, preview shown
- [ ] Test with random blog → generic parser works
- [ ] Test invalid URL → graceful error
- [ ] Test offline → queued for later
- [ ] Attribution preserved correctly

**Deliverable:** Working web import with paywall detection

---

### Prompt 6: World-Class OCR Enhancement

**Goal:** Implement multi-engine OCR for handwritten and printed recipes

**What You'll Learn:**
- Vision framework VNRecognizeTextRequest
- Image preprocessing (rotation, contrast, noise reduction)
- Handwriting vs print detection
- Recipe structure parsing with AI (Claude API)
- Real-time camera viewfinder UI

**What You'll Build:**

**OCR Engine:**
- `EnhancedOCRService.swift` (500+ lines)
  - Primary: Vision framework (.accurate level)
  - Fallback: Claude Vision API for difficult cases
  - Handwriting detection heuristic
  - Route to appropriate engine
- Image preprocessing pipeline
  - Auto-rotation detection
  - Perspective correction (for angled photos)
  - Contrast enhancement
  - Shadow removal
  - Noise reduction

**Recipe Structure Parser:**
- `RecipeStructureParser.swift`
  - Use Claude API to parse unstructured OCR text
  - Detect: title, ingredients, instructions, notes, attribution
  - Handle multi-page recipes
  - Extract structured ingredient data (amount, unit, item, prep)
  - Recognize fractions (½, ¼, 1/2, etc.)
  - Expand abbreviations (tsp → teaspoon, etc.)

**OCR Quality Analyzer:**
- `ScanQualityAnalyzer.swift`
  - Analyze image before processing
  - Provide real-time feedback:
    - "Move closer"
    - "Better lighting needed"
    - "Hold steady"
  - Confidence scoring for OCR results
  - Flag low-confidence sections for user review

**UI Components:**
- Camera viewfinder with region overlay
  - Highlight detected regions (title=blue, ingredients=green, instructions=yellow)
  - Real-time quality feedback
  - Multi-page scanning session
- Side-by-side review UI
  - Original image + parsed result
  - Inline editing for corrections
  - Confidence indicators on each section

**Files Created:**
- `/Heirloom/Core/Services/OCR/EnhancedOCRService.swift`
- `/Heirloom/Core/Services/OCR/RecipeStructureParser.swift`
- `/Heirloom/Core/Services/OCR/ScanQualityAnalyzer.swift`
- `/Heirloom/Core/Services/OCR/ImagePreprocessor.swift`
- `/Heirloom/Features/Scan/Views/EnhancedScannerView.swift`
- `/Heirloom/Features/Scan/Views/OCRReviewView.swift`

**Testing Checklist:**
- [ ] Scan 5 clear handwritten recipes → 85%+ accuracy
- [ ] Scan 5 messy handwritten recipes → 70%+ accuracy (with corrections)
- [ ] Scan 5 printed recipes → 95%+ accuracy
- [ ] Multi-page recipe → correctly merged
- [ ] Real-time feedback works in viewfinder
- [ ] User corrections save properly
- [ ] Ingredient parsing extracts amounts/units correctly

**Deliverable:** Production-quality OCR with handwriting support

---

## PHASE 2C: Social Comments & Privacy

### Prompt 7: Shared Comments System

**Goal:** Comments that persist and travel with shared recipes

**What You'll Learn:**
- CloudKit public database writes
- Comment propagation strategies
- Lazy loading patterns
- Anonymization for public data

**What You'll Build:**

**Extended Comment Model:**
- Add `shareScope` to RecipeComment
  ```swift
  enum CommentShareScope: String, Codable {
      case `private`      // Only visible to me
      case directShares   // Visible to people I share with
      case fullChain      // Visible to entire lineage
      case `public`       // Visible to all users (trending comments)
  }
  ```
- Add `originProvenanceHash` (where comment was first created)
- Add `endorsementCount` (cross-user helpfulness votes)

**Public Database Schema:**
- `SharedCommentAggregate` CKRecord
  - Linked to root provenance hash
  - Anonymized author ID
  - Comment content + type
  - Sentiment score
  - Endorsement count
  - Propagation depth

**SharedCommentService:**
- `SharedCommentService.swift`
  ```swift
  @MainActor
  final class SharedCommentService {
      // Lazy loading
      func getCommentsForRecipe(_ recipe: Recipe) async throws -> [RecipeComment]

      // Fetches from local + parent provenance
      func fetchCommentsFromLineage(provenanceHash: String) async throws -> [RecipeComment]

      // Publish to public DB
      func publishComment(_ comment: RecipeComment) async throws

      // Endorsement
      func endorseComment(_ commentID: UUID) async throws
  }
  ```

**UI Updates:**
- Comment share scope picker (when creating comment)
- Endorsement button (heart icon)
- Attribution badge on comments ("From Sarah, 2 generations up")
- Filter: "Show comments from lineage"

**Files Modified:**
- `/Heirloom/Core/Models/RecipeComment.swift`

**Files Created:**
- `/Heirloom/Core/Services/CloudKit/SharedCommentService.swift`
- `/Heirloom/Features/Comments/Views/CommentScopePickerView.swift`

**Testing Checklist:**
- [ ] Create comment with "Direct Shares" scope on Device A
- [ ] Share recipe to Device B
- [ ] Device B sees comment in lineage
- [ ] Device B endorses comment
- [ ] Endorsement count increments
- [ ] Device A sees updated endorsement count
- [ ] Comment appears in CloudKit public database

**Deliverable:** Comments travel with shared recipes

---

### Prompt 8: QR Code & Deep Link Sharing

**Goal:** Additional sharing methods (QR codes, universal links)

**What You'll Learn:**
- QR code generation with Core Image
- Universal links configuration (apple-app-site-association)
- Share URL shortening
- Share analytics tracking

**What You'll Build:**

**QR Code Generation:**
- `QRCodeGenerator.swift`
  ```swift
  struct QRCodeGenerator {
      static func generate(from url: URL, size: CGSize) -> UIImage?
      static func generateWithBranding(from url: URL, logo: UIImage?) -> UIImage?
  }
  ```
- Branded QR code (Heirloom logo in center)
- High-resolution for printing
- Save to Photos option

**Universal Links:**
- Configure apple-app-site-association file (hosted on heirloom.app)
- Handle https://heirloom.app/r/{shortcode}
- URL shortening service
  - Generate 6-character shortcode
  - Store mapping: shortcode → CKShare.recordID
  - Redirect to app or web preview

**Share Analytics:**
- Track share creation
- Track link opens (anonymous)
- Track share acceptance
- Display in share history: "3 people opened, 1 accepted"

**UI Components:**
- QR code display sheet
  - Large QR code
  - "Save to Photos" button
  - "Print" button
  - Share QR code image
- Share history view
  - List of shares you've sent
  - Status: Pending, Accepted, Expired
  - Analytics: Opens, Accepts

**Files Created:**
- `/Heirloom/Core/Utilities/QRCodeGenerator.swift`
- `/Heirloom/Core/Services/UniversalLinkService.swift`
- `/Heirloom/Core/Services/ShareAnalyticsService.swift`
- `/Heirloom/Features/Sharing/Views/QRCodeSheet.swift`
- `/Heirloom/Features/Sharing/Views/ShareHistoryView.swift`

**Testing Checklist:**
- [ ] Generate QR code for recipe
- [ ] Scan QR code with different device → opens share
- [ ] Universal link (heirloom.app/r/abc123) opens app
- [ ] Share analytics track opens
- [ ] Share history shows correct status
- [ ] QR code saves to Photos correctly

**Deliverable:** QR code and universal link sharing working

---

### Prompt 9: Privacy Policy & Opt-In Flows

**Goal:** Implement privacy-first consent and data controls

**What You'll Learn:**
- GDPR/CCPA compliance requirements
- Privacy policy drafting
- Opt-in UI best practices
- Data export and deletion

**What You'll Build:**

**Privacy Policy:**
- Comprehensive privacy policy document
  - What data we collect
  - How we use it
  - Third-party services
  - User rights
  - Contact information
- In-app privacy policy viewer
- Link in Settings

**Opt-In Consent UI:**
- First-time share prompt
  ```
  ┌─────────────────────────────────────┐
  │  Share Recipes with Friends?        │
  ├─────────────────────────────────────┤
  │  Heirloom can share recipes via     │
  │  secure iCloud links.               │
  │                                     │
  │  ✓ End-to-end encrypted            │
  │  ✓ You control permissions         │
  │  ✓ Revoke anytime                  │
  │                                     │
  │  [ ] Also contribute anonymous      │
  │      stats to help discover         │
  │      trending recipes               │
  │                                     │
  │  [Privacy Policy] [Not Now] [OK]   │
  └─────────────────────────────────────┘
  ```
- Two-tier consent:
  1. Sharing features (required for social)
  2. Aggregated metrics (optional)

**Privacy Settings:**
- Settings screen additions
  - Toggle: Enable sharing features
  - Toggle: Contribute to aggregated metrics
  - Button: View Privacy Policy
  - Button: Export My Data
  - Button: Delete My Account

**Data Export:**
- `DataExportService.swift`
  - Export all recipes to JSON
  - Export comments to JSON
  - Export share history
  - Zip and share via standard share sheet

**Data Deletion:**
- `DataDeletionService.swift`
  - Delete all local recipes
  - Delete all CloudKit private records
  - Request deletion of public DB contributions
  - Clear all caches
  - Sign out

**Files Created:**
- `/Heirloom/Resources/PrivacyPolicy.md`
- `/Heirloom/Features/Settings/Views/PrivacySettingsView.swift`
- `/Heirloom/Features/Settings/Views/PrivacyPolicyView.swift`
- `/Heirloom/Core/Services/DataExportService.swift`
- `/Heirloom/Core/Services/DataDeletionService.swift`
- `/Heirloom/Core/Models/PrivacySettings.swift`

**Testing Checklist:**
- [ ] First share shows consent UI
- [ ] Declining consent disables sharing features
- [ ] Accepting consent enables sharing
- [ ] Opt-out of metrics prevents public DB writes
- [ ] Privacy policy displays correctly
- [ ] Export data creates valid JSON
- [ ] Delete account removes all data (verify in CloudKit dashboard)

**Deliverable:** Privacy-compliant sharing features

---

## PHASE 2D: Discovery & Analytics

### Prompt 10: Advanced Lineage Visualization

**Goal:** Build interactive graph showing complete recipe share tree

**What You'll Learn:**
- SwiftUI Canvas for custom drawing
- Graph layout algorithms (force-directed, hierarchical)
- Touch gesture handling (pinch, pan, tap)
- Performance optimization for large graphs
- Animation and transitions

**What You'll Build:**

**Interactive Node Graph:**
- `LineageGraphView.swift` (600+ lines)
  - Node rendering (circles with avatars/initials)
  - Edge rendering (connecting lines)
  - Layout algorithm (hierarchical or force-directed)
  - Touch handling (pan, pinch-to-zoom, tap)
  - Animated transitions

**Graph Data Model:**
- `LineageNode` struct
  ```swift
  struct LineageNode: Identifiable {
      var id: UUID
      var provenanceHash: String
      var generation: Int
      var position: CGPoint
      var userInitials: String?
      var dateReceived: Date
      var children: [LineageNode]
      var metadata: LineageMetadata
  }
  ```

**UI Features:**
- Zoom controls (pinch gesture + buttons)
- Pan to navigate large trees
- Tap node to see details (user, date, comments)
- Path highlighting (from root to current user)
- Trending badges (🔥 for viral recipes)
- Compact summary card (embed in RecipeDetailView)
- Full-screen graph view (modal)

**Performance Optimizations:**
- Virtualization for 100+ node graphs
- Lazy loading of node details
- Cached layout calculations
- Smooth animations at 60fps

**Files Created:**
- `/Heirloom/Features/Lineage/Views/LineageGraphView.swift`
- `/Heirloom/Features/Lineage/Views/LineageNodeView.swift`
- `/Heirloom/Features/Lineage/Models/LineageNode.swift`
- `/Heirloom/Features/Lineage/Services/LineageGraphService.swift`
- `/Heirloom/Core/Utilities/GraphLayoutEngine.swift`

**Testing Checklist:**
- [ ] Render graph with 10 nodes correctly
- [ ] Pan gesture works smoothly
- [ ] Pinch-to-zoom works (2x to 10x)
- [ ] Tap node shows details sheet
- [ ] Path highlighting from root to current user
- [ ] Performance: 60fps with 100 nodes
- [ ] Viral badge appears on recipes with 100+ shares
- [ ] Compact summary embeds in RecipeDetailView

**Deliverable:** Interactive lineage visualization

---

### Prompt 11: Analytics & Trending Algorithm

**Goal:** Surface popular recipes and track engagement metrics

**What You'll Learn:**
- Time-decay algorithms
- Weighted scoring for trending
- CloudKit queries with sorting/filtering
- Analytics event tracking
- Data aggregation patterns

**What You'll Build:**

**Trending Score Algorithm:**
- `TrendingScoreCalculator.swift`
  ```swift
  func calculateTrendingScore(
      shares24h: Int,
      cooks24h: Int,
      shares7d: Int,
      cooks7d: Int,
      totalUsers: Int,
      avgRating: Double,
      ageInDays: Int
  ) -> Double {
      let recentActivity = (shares24h * 10) + (cooks24h * 5)
      let weeklyActivity = (shares7d * 3) + (cooks7d * 2)
      let popularity = totalUsers * 0.1
      let quality = avgRating * 2
      let timeDecay = exp(-0.1 * Double(ageInDays))

      return (recentActivity + weeklyActivity + popularity + quality) * timeDecay
  }
  ```

**Analytics Service:**
- `RecipeAnalyticsService.swift` (400+ lines)
  - Track recipe viewed
  - Track recipe cooked
  - Track recipe shared
  - Track share accepted
  - Track comment added
  - Batch upload to CloudKit public DB
  - Handle offline queue

**Trending Service:**
- `TrendingRecipeService.swift` (300+ lines)
  - Get trending global (all users)
  - Get trending in network (your connections)
  - Get trending by category
  - Get recently popular
  - Get rising recipes (gaining momentum)

**Discovery Feed UI:**
- `DiscoverView.swift` (500+ lines)
  - Sections:
    - "Trending This Week" (horizontal carousel)
    - "Popular in Your Network" (grid)
    - "Rising Recipes" (list)
    - "Hidden Gems" (high rating, low discovery)
    - "Most Cooked" (all-time favorites)
  - Trending badges (🔥 Viral, ⭐ Popular, 📈 Rising)
  - Quick-add button (imports with provenance)
  - Filter by category, cuisine, dietary restriction

**Analytics Dashboard:**
- `AnalyticsDashboardView.swift`
  - Recipe popularity over time (line chart)
  - Share network visualization
  - Cook counts by region (if available)
  - Top modifications (from comments)
  - Engagement metrics

**Viral Recipe Detection:**
- Auto-detect when recipe crosses thresholds:
  - 25+ users → "Popular" badge
  - 100+ users → "Viral" badge
  - 5+ shares this week → "Rising" badge

**Files Created:**
- `/Heirloom/Core/Services/Analytics/RecipeAnalyticsService.swift`
- `/Heirloom/Core/Services/Analytics/TrendingScoreCalculator.swift`
- `/Heirloom/Core/Services/Analytics/TrendingRecipeService.swift`
- `/Heirloom/Features/Discover/Views/DiscoverView.swift`
- `/Heirloom/Features/Discover/Views/TrendingRecipeCard.swift`
- `/Heirloom/Features/Analytics/Views/AnalyticsDashboardView.swift`
- `/Heirloom/Core/Models/TrendingRecipe.swift`

**Testing Checklist:**
- [ ] Analytics events tracked correctly
- [ ] Trending score calculation correct
- [ ] Trending feed displays recipes
- [ ] Filter by category works
- [ ] Quick-add imports recipe with provenance
- [ ] Viral badge appears at 100+ users
- [ ] Analytics dashboard shows charts
- [ ] Offline events queue and sync later

**Deliverable:** Complete discovery and analytics system

---

### Prompt 12: ML Comment Deduplication & Final Integration

**Goal:** Implement ML-based comment deduplication and comprehensive testing

**What You'll Learn:**
- Text embeddings for similarity detection
- OpenAI/Claude embeddings API
- Cosine similarity calculations
- Vector storage and retrieval
- Comprehensive integration testing

**What You'll Build:**

**ML Deduplication Service:**
- `CommentDeduplicationService.swift` (400+ lines)
  - Generate embeddings for comment text
  - Calculate cosine similarity between comments
  - Detect duplicates (threshold: 0.85+ similarity)
  - Merge duplicate comments
  - Combine upvote counts
  - Preserve all variations in metadata

**Embedding Generation:**
- Use Claude API or OpenAI embeddings
  ```swift
  func generateEmbedding(for text: String) async throws -> [Double] {
      // Call Claude/OpenAI embeddings API
      // Returns 1536-dimensional vector
  }
  ```

**Similarity Detection:**
- Cosine similarity calculation
  ```swift
  func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
      let dotProduct = zip(a, b).map(*).reduce(0, +)
      let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
      let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
      return dotProduct / (magnitudeA * magnitudeB)
  }
  ```

**Deduplication Flow:**
1. User imports recipe from web (20 scraped comments)
2. Generate embeddings for all comments
3. Compare each pair for similarity
4. Group similar comments (similarity > 0.85)
5. Create canonical comment with merged data
6. Store variations in metadata

**Comprehensive Testing:**

**Unit Tests (100+ tests):**
- CloudKitSyncCoordinator
- All service classes
- Data models
- Analytics calculations
- Deduplication logic

**Integration Tests (50+ tests):**
- End-to-end share flow
- Comment propagation
- Web import + deduplication
- OCR + structure parsing
- Trending algorithm with real data

**UI Tests (30+ tests):**
- Critical user flows
- Share → Accept → View lineage
- Import → Review → Save
- Discover → Add → Cook
- Analytics dashboard

**Performance Tests:**
- CloudKit batch operations (100+ records)
- Graph rendering (100+ nodes)
- OCR processing (10 recipes)
- Trending calculation (1000+ recipes)

**Load Testing:**
- Simulate 100 concurrent users
- Measure CloudKit quota usage
- Validate rate limiting
- Test conflict resolution

**Files Created:**
- `/Heirloom/Core/Services/AI/CommentDeduplicationService.swift`
- `/HeirloomTests/UnitTests/CloudKitSyncCoordinatorTests.swift`
- `/HeirloomTests/UnitTests/TrendingAlgorithmTests.swift`
- `/HeirloomTests/IntegrationTests/ShareFlowTests.swift`
- `/HeirloomTests/IntegrationTests/WebImportTests.swift`
- `/HeirloomUITests/DiscoverFlowTests.swift`
- `/HeirloomUITests/ShareAcceptanceTests.swift`

**Testing Checklist:**
- [ ] 100+ unit tests passing
- [ ] 50+ integration tests passing
- [ ] 30+ UI tests passing
- [ ] Performance tests meet targets
- [ ] Load tests complete without errors
- [ ] All 12 prompts integrated
- [ ] No critical bugs
- [ ] App Store review-ready

**Deliverable:** Production-ready app with full test coverage

---

## 🔄 Progress Tracking

**As you complete each prompt:**
1. ✅ Mark completed in todo list (`TodoWrite`)
2. ✅ Update PHASE_2_PROGRESS_TRACKER.md
3. ✅ Complete testing checklist
4. ✅ Verify on 2 devices (where applicable)
5. ✅ Document any issues or deviations
6. ✅ Proceed to next prompt

**If you encounter issues:**
- Reference prompt dependencies
- Check CloudKit dashboard for errors
- Review Systems Architect recommendations
- Ask for help before proceeding

---

## 📞 Questions & Support

**For each prompt, you can ask:**
- "Can you explain [concept] in more detail?"
- "Why are we building it this way?"
- "What are alternatives to [approach]?"
- "How do I test [feature]?"
- "What if [scenario] happens?"

**Don't proceed if:**
- Tests are failing
- CloudKit sync not working
- Unclear about architecture
- Privacy concerns unresolved

**Better to clarify now than refactor later!**

---

**Last Updated:** December 18, 2024
**Next Action:** Execute Prompt 1
