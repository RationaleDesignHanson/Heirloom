# PDF Recipe Import Guide

## Overview

Heirloom now supports importing recipes from PDF files with intelligent multi-page detection. This feature uses the same queue-based processing architecture as video imports, camera scanning, and photo library imports for a unified, resumable experience.

## Features

### ✨ Core Capabilities
- **Batch PDF Import**: Select up to 20 PDFs at once from iOS Files
- **Smart Multi-Page Detection**: Automatically detects recipes spanning multiple pages
- **Queue-Based Processing**: Resumable, progress-tracked imports
- **Premium Tiers**:
  - Free: Up to 50 pages per PDF
  - Premium ($4.99): Up to 250 pages per PDF (hard cap)

### 🧠 Intelligent Page Analysis

Using Claude Vision API, the system intelligently analyzes each PDF page to determine:
- **Recipe Start**: New recipe begins (has title/heading)
- **Recipe Continuation**: Page continues previous recipe
- **Complete Recipe**: Standalone recipe on single page
- **Non-Recipe**: Table of contents, index, introductions

This ensures multi-page recipes (e.g., a recipe spanning pages 42-44) are:
1. **Grouped together** into a single ImportItem
2. **Combined** into one tall image for unified extraction
3. **Processed once** with a single API call

## User Experience

### Entry Points

1. **EnhancedScannerView** (Camera scanning)
   - Tap PDF icon in toolbar → Opens PDFImportView

2. **CookbookScannerView** (Photo library scanning)
   - Tap PDF icon in toolbar → Opens PDFImportView

3. **Direct Navigation** (future)
   - Recipe list → Add button → Import from PDF

### Import Flow

```
1. Tap "Import PDF" button
   ↓
2. iOS Files picker opens (filtered to PDFs only)
   ↓
3. Select up to 20 PDFs
   ↓
4. Validation phase:
   - Check page counts
   - Verify not password-protected
   - Show premium gate if needed
   ↓
5. For each PDF:
   - Render all pages to images
   - Analyze page boundaries (Claude Vision)
   - Group multi-page recipes
   - Create ImportJob with recipe groups
   ↓
6. Queue processing begins:
   - Show ImportProgressView
   - Real-time progress per recipe
   - Background processing
   ↓
7. Recipes extracted and saved
   - User can review in import history
   - Synced to Firebase if enabled
```

### Progress States

Each PDF import item shows:
- **Queued**: Waiting to process
- **Processing**: AI extracting recipe
- **Complete**: Recipe extracted successfully
- **Failed**: Error (with detailed message)

Progress indicators display:
- PDF document icon (red)
- Page range (e.g., "Page 5" or "Pages 5-7")
- Multi-page indicator if applicable

## Architecture

### Unified Import Queue

All import types now use the same queue system:

```
┌─────────────────────────────────────────────────────────────┐
│                    Import Sources                            │
├─────────────┬─────────────┬─────────────┬──────────────────┤
│   Camera    │  Photo Lib  │    PDF      │     Video        │
│   Capture   │   Import    │   Import    │    Import        │
└──────┬──────┴──────┬──────┴──────┬──────┴────────┬─────────┘
       │             │             │               │
       └─────────────┴─────────────┴───────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │     ImportJobManager (Actor)             │
        │  - createPDFImportJob()                  │
        │  - createCameraImportJob()               │
        │  - createPhotoLibraryImportJob()         │
        │  - createVideoImportJob()                │
        └────────────────┬─────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────────┐
        │     ImportJob (SwiftData @Model)       │
        │  - jobName, status, progress           │
        │  - totalItems, completedItems          │
        └────────────────┬───────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────────┐
        │    ImportItem (SwiftData @Model)       │
        │  - source: ImportSource enum           │
        │  - urlString / imageData / pdfURL      │
        │  - pageNumber, totalPages              │
        │  - isMultiPageRecipe                   │
        └────────────────┬───────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────────┐
        │      Recipe Extraction Pipeline        │
        │  - AIRecipeExtractor                   │
        │  - Claude Vision API                   │
        │  - Recipe model creation               │
        └────────────────────────────────────────┘
```

### Key Components

#### 1. PDFProcessor
**Location**: `/Core/Services/PDF/PDFProcessor.swift`

**Responsibilities**:
- PDF rendering to images (2x scale for OCR quality)
- Page count validation
- Premium gate enforcement (50+ pages)
- Hard cap enforcement (250 pages)
- Password protection detection

**Key Methods**:
```swift
func renderPDFPages(from url: URL) async throws -> [(pageNumber: Int, image: UIImage)]
func getPageCount(_ url: URL) -> Int?
func validatePDF(_ url: URL) async -> PDFValidationResult
```

#### 2. MultiPageRecipeAnalyzer
**Location**: `/Core/Services/PDF/MultiPageRecipeAnalyzer.swift`

**Responsibilities**:
- Analyze PDF pages with Claude Vision API
- Detect recipe boundaries
- Group multi-page recipes
- Combine continuation pages

**Key Methods**:
```swift
func analyzePageBoundaries(pages: [(pageNumber: Int, image: UIImage)]) async throws -> [RecipePageGroup]
```

**Page Analysis Logic**:
```swift
struct PageAnalysis: Codable {
    enum PageType: String, Codable {
        case recipeStart         // New recipe begins
        case recipeContinuation  // Continues previous
        case completeRecipe      // Standalone recipe
        case nonRecipe          // Not a recipe
    }

    let type: PageType
    let title: String?
    let confidence: Double
    let reasoning: String
}
```

#### 3. ImportJobManager
**Location**: `/Features/Recipes/BulkImport/Services/ImportJobManager.swift`

**Responsibilities**:
- Create import jobs for all sources
- Manage queue processing
- Handle concurrency (max 3 concurrent)
- Rate limiting (20 requests/minute)
- Persist jobs to SwiftData

**PDF-Specific Method**:
```swift
func createPDFImportJob(
    pdfPages: [(pageNumber: Int, image: UIImage)],
    fileName: String,
    context: ModelContext
) async throws -> ImportJob {
    // Step 1: Analyze page boundaries
    let recipeGroups = try await multiPageAnalyzer.analyzePageBoundaries(pages: pdfPages)

    // Step 2: Create job with one item per recipe (not per page!)
    let job = ImportJob(jobName: "Import \(fileName)", continueOnError: true)
    job.totalItems = recipeGroups.count

    // Step 3: Create ImportItem for each recipe group
    for group in recipeGroups {
        let combinedImage = group.pageCount == 1 ? group.pages[0] : group.combinedImage()
        let imageData = combinedImage.jpegData(compressionQuality: 0.9)!

        let item = ImportItem(
            source: .pdf,
            imageData: imageData,
            pageNumber: group.startPage,
            totalPages: group.pageCount,
            isMultiPageRecipe: group.isMultiPage
        )
        item.job = job
        context.insert(item)
    }

    return job
}
```

#### 4. PDFImportView
**Location**: `/Features/Recipes/PDFImport/PDFImportView.swift`

**Responsibilities**:
- PDF document picker UI
- Real-time validation display
- Premium gate presentation
- Job creation and initiation

**Features**:
- Shows page count for each PDF
- Premium indicator for 50+ page PDFs
- Error display for invalid PDFs
- Info cards explaining features

#### 5. PDFDocumentPicker
**Location**: `/Features/Recipes/PDFImport/PDFDocumentPicker.swift`

**Responsibilities**:
- UIDocumentPickerViewController wrapper
- Multi-file selection (up to 20)
- Security-scoped resource access
- Error handling

## Data Models

### ImportItem Extensions

```swift
enum ImportSource: String, Codable {
    case url           // Video/recipe URL
    case pdf           // PDF document
    case camera        // Camera capture
    case photoLibrary  // Photo library import
}

@Model
final class ImportItem {
    // Source Type
    var source: ImportSource = ImportSource.url

    // URL Information (for .url source)
    var urlString: String?
    var normalizedURL: String?

    // Image Information (for .pdf, .camera, .photoLibrary sources)
    var imageData: Data?
    var pdfURL: String?
    var pageNumber: Int?
    var totalPages: Int?
    var isMultiPageRecipe: Bool?

    // Status
    var status: ImportItemStatus
    var errorMessage: String?
    var retryCount: Int

    // Relationships
    var job: ImportJob?
    var recipeID: UUID?
}
```

### RecipePageGroup

```swift
struct RecipePageGroup: Identifiable {
    let id = UUID()
    var title: String
    var startPage: Int
    var endPage: Int
    var pages: [UIImage]
    var confidence: Double
    var isMultiPage: Bool

    var pageRange: String {
        if startPage == endPage {
            return "Page \(startPage)"
        } else {
            return "Pages \(startPage)-\(endPage)"
        }
    }

    func combinedImage() -> UIImage {
        // Stacks pages vertically for multi-page recipes
    }
}
```

## Error Handling

### PDF Import Errors

```swift
enum PDFImportError: LocalizedError {
    case tooManyFiles(selected: Int, max: Int)
    case unreadable(fileName: String)
    case passwordProtected(fileName: String)
    case tooManyPages(fileName: String, pageCount: Int, max: Int)
    case corruptedFile(fileName: String)
    case requiresPremium(fileName: String, pageCount: Int)
}
```

### Handling Strategy

1. **Validation Phase**: Catch errors before processing begins
2. **User Feedback**: Clear error messages with actionable steps
3. **Graceful Degradation**: Continue processing other PDFs on single failure
4. **Retry Logic**: Allow users to retry failed imports (up to 3 attempts)

## Edge Cases

### 1. Multi-Page Recipe Detection

**Scenario**: Recipe spans pages 5-7 in a cookbook

**Handling**:
- Page 5: Detected as `recipeStart` (has "Chocolate Chip Cookies" title)
- Page 6: Detected as `recipeContinuation` (continues instructions)
- Page 7: Detected as `recipeContinuation` (final steps + notes)
- **Result**: Single ImportItem with pages 5-7 combined

### 2. Mixed Content PDFs

**Scenario**: PDF has table of contents, intro, then recipes

**Handling**:
- Pages 1-3: Detected as `nonRecipe` → skipped
- Page 4: Detected as `recipeStart` → new recipe group
- Page 5: Detected as `completeRecipe` → separate recipe group
- **Result**: Two ImportItems for actual recipes only

### 3. Scanned vs. Digital PDFs

**Both Supported**:
- **Digital PDFs** (text layer): Claude extracts text directly
- **Scanned PDFs** (images only): Claude uses Vision OCR
- **Mixed PDFs**: Handles both text and image content

### 4. Very Large PDFs

**Scenario**: 150-page cookbook PDF

**Handling**:
- Premium user: Allowed (under 250 limit)
- Multi-page analysis: Processes all 150 pages
- Memory: Pages processed sequentially, not all in RAM
- Progress: User sees real-time progress per recipe

### 5. Duplicate Recipes

**Detection**: Same as URL imports
- Check for similar titles
- Compare ingredient lists
- **Action**: Mark as skipped with reason

## Performance Considerations

### Memory Management

- **PDF Rendering**: Pages rendered on-demand, not cached
- **Image Compression**: 0.9 JPEG quality (balance size/quality)
- **Max Concurrent**: 3 PDFs processing simultaneously
- **Rate Limiting**: 20 API requests per minute

### Optimization Strategies

1. **Lazy Loading**: Only render pages when needed
2. **Progressive Processing**: Show progress incrementally
3. **Background Processing**: Continues if app backgrounded
4. **Smart Caching**: API responses cached for retries

### Expected Timing

- **PDF Rendering**: ~2 seconds per page
- **Multi-Page Analysis**: ~3 seconds per page (Claude Vision API)
- **Recipe Extraction**: ~5 seconds per recipe
- **Total for 10-page PDF**: ~2-3 minutes

## Premium Integration

### Paywall Trigger

```swift
enum PaywallTrigger {
    // ... existing triggers ...
    case largePDFImport(pageCount: Int)
}
```

### Gate Logic

```swift
// In PDFProcessor.renderPDFPages()
if pageCount >= 50 {
    let isPremium = await subscriptionManager.isPremium

    if !isPremium {
        throw PDFImportError.requiresPremium(
            fileName: url.lastPathComponent,
            pageCount: pageCount
        )
    }
}
```

### User Experience

1. User selects PDF with 75 pages
2. Validation detects > 50 pages
3. **Premium indicator** shows: "75 pages • Premium required"
4. On import attempt → **Paywall presented**
5. After upgrade → Import proceeds

## Testing

### Manual Testing Checklist

- [ ] Import single-page PDF recipe
- [ ] Import multi-page PDF recipe (spanning 3+ pages)
- [ ] Import batch of 10 PDFs
- [ ] Attempt to import 21 PDFs (should error)
- [ ] Import 49-page PDF (free tier, should work)
- [ ] Attempt 51-page PDF without premium (should show paywall)
- [ ] Import 51-page PDF with premium (should work)
- [ ] Attempt 251-page PDF (should error even with premium)
- [ ] Import password-protected PDF (should error gracefully)
- [ ] Import corrupted PDF (should error gracefully)
- [ ] Import PDF with no recipes (should complete with 0 recipes)
- [ ] Background app during processing (should resume)
- [ ] Cancel import job (should clean up)
- [ ] Retry failed import (should work)

### Integration Testing

See `/HeirloomTestsV2/Integration/` for:
- `PDFImportEndToEndTests.swift`
- `MultiPageRecipeAnalyzerTests.swift`
- `ImportQueueTests.swift`

## Future Enhancements

### Planned Features

1. **Cookbook Mode**:
   - Detect entire cookbook structure
   - Extract table of contents
   - Link recipes to chapters
   - Preserve book metadata

2. **OCR Improvements**:
   - Handwritten recipe support
   - Multiple language support
   - Recipe card recognition

3. **Batch Editing**:
   - Review all recipes before saving
   - Bulk edit metadata
   - Merge duplicate recipes

4. **Cloud Processing**:
   - Offload PDF rendering to server
   - Faster multi-page analysis
   - Reduced device battery usage

### API Enhancements

1. **Streaming Progress**:
   - Real-time page-by-page updates
   - Estimated time remaining

2. **Smart Batching**:
   - Group similar recipes
   - Detect recipe variations

3. **Quality Scoring**:
   - Confidence per extracted field
   - Suggest user review for low confidence

## Troubleshooting

### Common Issues

**"PDF has too many pages"**
- **Cause**: PDF exceeds 250-page hard limit
- **Solution**: Split PDF into smaller files

**"Premium required"**
- **Cause**: PDF has 50+ pages
- **Solution**: Upgrade to premium or split PDF

**"Could not read PDF"**
- **Cause**: Corrupted file or unsupported format
- **Solution**: Re-download PDF or convert to standard PDF

**"No recipes found"**
- **Cause**: PDF contains no actual recipes
- **Solution**: Verify PDF contains recipe content

**"Password protected PDF"**
- **Cause**: PDF is locked
- **Solution**: Unlock PDF before importing

### Debug Logging

Enable detailed logs:
```swift
Log.info("PDF import started", category: .import)
Log.info("Multi-page analysis result", category: .import, metadata: [
    "recipe_groups": groups.count,
    "total_pages": pages.count
])
```

## Support & Documentation

- **Main Documentation**: This file
- **Architecture Summary**: `/FEATURE_DEVELOPMENT_GUIDE.md`
- **Test Strategy**: `/HeirloomTestsV2/Integration/AI/README.md`
- **Firebase Setup**: `/FIREBASE_REMOTE_CONFIG_SETUP.md`

---

**Last Updated**: 2026-01-13
**Version**: 2.1.0
**Status**: Production Ready
