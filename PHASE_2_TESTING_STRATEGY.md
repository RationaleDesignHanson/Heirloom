# Heirloom Phase 2: Testing & Validation Strategy

**Created:** December 18, 2024
**Purpose:** Comprehensive testing approach for all Phase 2 features

---

## 🎯 Testing Philosophy

**Test Early, Test Often:**
- Test after each prompt completion (don't batch)
- Validate on real devices (not just simulator)
- Test failure scenarios, not just happy paths
- Document edge cases and bugs immediately

**2-Device Testing:**
- All cross-user features MUST be tested with 2 physical devices
- Use different iCloud accounts
- Test with network interruptions
- Validate CloudKit dashboard shows expected records

---

## 📱 Test Environment Setup

### Required Hardware

**Device A (Primary):**
- Your iPhone with your iCloud account
- Latest iOS version
- Development build via Xcode

**Device B (Secondary):**
- Different iPhone with different iCloud account
- Can be family member's or friend's device
- TestFlight build (internal track)

**Alternative:** Use iPad as Device B if available

### Required Accounts

**iCloud Accounts:**
- Account A: Your personal iCloud
- Account B: Different iCloud (family member or create test account)
- Both must have iCloud Drive enabled

**TestFlight:**
- Set up internal testing
- Add Account B as internal tester
- Distribute builds via TestFlight for cross-device testing

**CloudKit Dashboard:**
- Log in at https://icloud.developer.apple.com/
- Select Heirloom app
- View "Development" environment
- Monitor records during testing

### Sample Data Required

**For OCR Testing (Prompt 6):**
- 5 clear handwritten recipe cards (blue pen, lined paper)
- 5 messy handwritten recipes (pencil, aged, stained)
- 5 printed recipes (magazine clippings, cookbook pages)
- 5 mixed recipes (handwritten notes on printed recipe)

**For Web Import Testing (Prompt 5):**
- 10 recipe URLs:
  - 3 from AllRecipes.com
  - 2 from NYT Cooking (paywalled)
  - 2 from food blogs
  - 1 from Serious Eats
  - 1 from Reddit r/recipes
  - 1 invalid/broken URL

**For Sharing Testing (Prompts 3-4):**
- 3 test recipes with varying content:
  - Simple recipe (5 ingredients, 3 steps)
  - Complex recipe (20 ingredients, 15 steps, photos)
  - Recipe with comments (10+ comments of various types)

---

## ✅ Testing Checklists by Prompt

### Prompt 1: CloudKit Infrastructure

#### Setup Validation
- [ ] CloudKit container configured in Xcode project
- [ ] Entitlements file includes CloudKit
- [ ] Developer account has CloudKit access
- [ ] Dashboard shows "Heirloom" app

#### Schema Validation
- [ ] Public database schema created
- [ ] Shared database enabled
- [ ] Record types defined (ProvenanceAggregate, etc.)
- [ ] Indexes created for common queries

#### Service Validation
- [ ] CloudKitSyncCoordinator initializes without errors
- [ ] Can connect to CloudKit (check account status)
- [ ] Error handling catches common errors (network, quota, etc.)

#### 2-Device Tests

**Test 1.1: Basic Record Creation**
- [ ] Device A: Create record in public database
- [ ] CloudKit Dashboard: Verify record appears
- [ ] Device B: Fetch record by ID
- [ ] Result: Record data matches on both devices

**Test 1.2: Offline Queue**
- [ ] Device A: Enable airplane mode
- [ ] Device A: Create 3 records (queued locally)
- [ ] Device A: Disable airplane mode
- [ ] CloudKit Dashboard: Verify 3 records appear
- [ ] Device B: Fetch records successfully

**Test 1.3: Retry Logic**
- [ ] Device A: Simulate network error (Charles Proxy or Network Link Conditioner)
- [ ] Device A: Attempt to create record
- [ ] Observe: 3 retry attempts with exponential backoff
- [ ] Network restored: Operation succeeds

**Test 1.4: Subscription**
- [ ] Device A: Subscribe to record type changes
- [ ] Device B: Create record
- [ ] Device A: Receives push notification
- [ ] Device A: Fetches new record

#### Performance Tests
- [ ] Batch operation: Create 100 records < 10 seconds
- [ ] Fetch operation: Retrieve 100 records < 5 seconds
- [ ] Subscription: Notification received < 3 seconds

#### Edge Cases
- [ ] CloudKit quota exceeded: Shows user-friendly error
- [ ] iCloud account not logged in: Shows sign-in prompt
- [ ] Network timeout: Queues operation, retries later
- [ ] Concurrent modifications: Last-write-wins, no crashes

---

### Prompt 2: Local Provenance Model

#### Model Validation
- [ ] ProvenanceMetadata struct compiles
- [ ] Recipe includes provenance property
- [ ] SchemaV2 defined correctly
- [ ] Migration plan exists

#### Migration Testing

**Test 2.1: Fresh Install**
- [ ] Delete app from Device A
- [ ] Install new build
- [ ] Create recipe
- [ ] Provenance metadata populated with defaults

**Test 2.2: Migration from SchemaV1**
- [ ] Device A has existing recipes (SchemaV1)
- [ ] Install SchemaV2 build
- [ ] Open app (migration runs)
- [ ] All existing recipes preserved
- [ ] Provenance metadata added (sourceType = .userCreated)

**Test 2.3: Computed Properties**
- [ ] Create recipe with generation = 0
- [ ] Verify `isOriginal` returns true
- [ ] Create shared recipe with generation = 2
- [ ] Verify `shareDepth` returns 2

#### UI Validation
- [ ] Attribution badge displays for imported recipes
- [ ] Generation badge shows correct number
- [ ] Source icon correct (web, scan, manual, shared)

#### Edge Cases
- [ ] Recipe with nil provenance: Shows "Unknown Source"
- [ ] Very long attribution text: Truncates gracefully
- [ ] Missing sourceURL: Doesn't crash

---

### Prompt 3: CKShare-Based Recipe Sharing

#### Share Creation

**Test 3.1: Basic Share**
- [ ] Device A: Open recipe detail
- [ ] Device A: Tap "Share" button
- [ ] Device A: RecipeShareSheet displays
- [ ] Device A: Preview shows recipe card correctly
- [ ] Device A: Tap "Create Share"
- [ ] Result: Share created successfully
- [ ] CloudKit Dashboard: CKShare record appears

**Test 3.2: Share Options**
- [ ] Device A: Toggle "Include my notes" → preview updates
- [ ] Device A: Toggle "Include my rating" → preview updates
- [ ] Device A: Set expiration to 7 days
- [ ] Device A: Add personal message
- [ ] Device A: Create share
- [ ] Result: All options preserved in share

**Test 3.3: Share Methods**
- [ ] Device A: Share via Messages → rich preview appears
- [ ] Device A: Share via Email → HTML email generated
- [ ] Device A: Copy Link → URL copied to clipboard
- [ ] Device A: Share via AirDrop → recipient receives link

#### Share URL Validation
- [ ] Share URL format: `heirloom://share/{shareID}` or `https://heirloom.app/r/{code}`
- [ ] URL opens in browser → shows "Open in Heirloom" button
- [ ] URL opens on device with app → launches app

#### Permissions
- [ ] CKShare permissions set to read-only
- [ ] Recipient cannot modify original recipe
- [ ] Owner can revoke share

#### Edge Cases
- [ ] Share recipe with no ingredients: Prevents share with error
- [ ] Share while offline: Queues, processes when online
- [ ] Share same recipe twice: Creates separate shares
- [ ] Revoke share: Recipients lose access

---

### Prompt 4: Share Acceptance & Recipe Import

#### Deep Link Handling

**Test 4.1: URL Scheme**
- [ ] Device B: Tap `heirloom://share/abc123`
- [ ] App launches
- [ ] RecipeReceiveSheet displays

**Test 4.2: Universal Link**
- [ ] Device B: Tap `https://heirloom.app/r/abc123`
- [ ] App launches (not browser)
- [ ] RecipeReceiveSheet displays

#### Share Preview

**Test 4.3: Preview Display**
- [ ] RecipeReceiveSheet shows recipe title
- [ ] Hero image displays
- [ ] Sharer name: "Shared by [Device A Name]"
- [ ] Personal message displays (if included)
- [ ] Lineage summary: "Originally from [source]"
- [ ] Comment count: "3 comments included"

#### Share Acceptance

**Test 4.4: Accept Flow**
- [ ] Device B: Tap "Add to My Recipes"
- [ ] Collection picker appears
- [ ] Select "Weeknight Dinners" collection
- [ ] Recipe imports
- [ ] Recipe appears in Device B's collection
- [ ] Provenance metadata:
  - [ ] sourceType = .shared
  - [ ] parentShareID = Device A's share ID
  - [ ] generation = 1 (or parent generation + 1)
  - [ ] rootProvenanceHash = original recipe's hash

**Test 4.5: Comment Import**
- [ ] Device A's comments imported to Device B
- [ ] Comment attribution: "From Device A"
- [ ] Comment count correct

#### Independence Validation
- [ ] Device B: Edit imported recipe
- [ ] Device A: Original recipe unchanged
- [ ] Device B: Delete imported recipe
- [ ] Device A: Original recipe still exists
- [ ] Device A: Revoke share
- [ ] Device B: Imported recipe still accessible (not deleted)

#### Edge Cases
- [ ] Expired share link: Shows "Share has expired"
- [ ] Already accepted share: Shows "Already in your collection"
- [ ] Accept while offline: Queues, imports when online
- [ ] Malformed share URL: Shows error, doesn't crash

#### End-to-End Flow

**Test 4.6: Complete Sharing Journey**
1. [ ] Device A: Create recipe with 5 ingredients
2. [ ] Device A: Add 2 comments
3. [ ] Device A: Rate 5 stars
4. [ ] Device A: Share with personal note "Try this!"
5. [ ] Device B: Receive share link
6. [ ] Device B: Preview shows all details
7. [ ] Device B: Accept and import
8. [ ] Device B: Recipe appears in collection
9. [ ] Device B: Ingredients match Device A
10. [ ] Device B: Comments visible and attributed
11. [ ] Device B: Lineage shows "Shared by Device A"
12. [ ] Device A: Check share status → "Accepted"

---

### Prompt 5: Server-Side Web Recipe Import

#### Server Setup
- [ ] Google Cloud Function deployed
- [ ] Function URL accessible
- [ ] API key configured (if needed)
- [ ] Rate limiting enabled

#### Recipe Parsing Tests

**Test 5.1: AllRecipes.com**
- [ ] Input: AllRecipes URL
- [ ] Output: Full recipe extracted
- [ ] Ingredients: Parsed correctly
- [ ] Instructions: In correct order
- [ ] Attribution: "AllRecipes.com, [author name]"
- [ ] Image: Downloaded and displayed

**Test 5.2: NYT Cooking (Paywalled)**
- [ ] Input: NYT Cooking URL
- [ ] Paywall detected: true
- [ ] Preview: Title, author, image only
- [ ] UI: Shows "Subscribe" button
- [ ] Tap button: Opens Safari to NYT subscription page

**Test 5.3: Food Blog**
- [ ] Input: Random food blog URL
- [ ] Generic parser used
- [ ] Recipe detected via schema.org
- [ ] Data: 80%+ complete

**Test 5.4: Invalid URL**
- [ ] Input: Non-recipe URL
- [ ] Error: "No recipe found at this URL"
- [ ] Graceful: Doesn't crash

#### Attribution Validation
- [ ] Source URL preserved
- [ ] Author name extracted
- [ ] Website name displayed
- [ ] Original publish date (if available)

#### Performance
- [ ] Parsing time: < 5 seconds for most sites
- [ ] Cached recipe: < 1 second
- [ ] Image download: < 3 seconds

#### Edge Cases
- [ ] URL with tracking parameters: Cleaned correctly
- [ ] Recipe behind login: Paywall detected
- [ ] Malformed JSON-LD: Falls back to HTML parsing
- [ ] Very long recipe (100+ steps): Parsed fully
- [ ] No image available: Uses placeholder

---

### Prompt 6: World-Class OCR Enhancement

#### OCR Accuracy Tests

**Test 6.1: Clear Handwritten**
- [ ] Scan 5 clear handwritten recipes
- [ ] Accuracy: 85%+ overall
- [ ] Ingredients: 90%+ correct
- [ ] Instructions: 80%+ correct
- [ ] Timing: < 10 seconds per recipe

**Test 6.2: Messy Handwritten**
- [ ] Scan 5 messy/aged handwritten recipes
- [ ] Accuracy: 70%+ overall
- [ ] Low-confidence sections flagged for review
- [ ] User corrections easy to make

**Test 6.3: Printed Recipes**
- [ ] Scan 5 printed recipes
- [ ] Accuracy: 95%+ overall
- [ ] Formatting: Preserved correctly
- [ ] Timing: < 5 seconds per recipe

**Test 6.4: Mixed (Handwritten Notes + Print)**
- [ ] Scan 5 mixed recipes
- [ ] Both parts detected separately
- [ ] Handwritten notes: Added to recipe notes field
- [ ] Printed recipe: Parsed as main content

#### Structure Parsing

**Test 6.5: Recipe Sections**
- [ ] Title detected: Correctly extracted
- [ ] Ingredients section: Identified and parsed
- [ ] Instructions section: Identified and parsed
- [ ] Notes section: Identified (if present)
- [ ] Attribution: Detected (cookbook title, page number)

**Test 6.6: Ingredient Parsing**
- [ ] Fractions: "1/2 cup" and "½ cup" both recognized
- [ ] Abbreviations: "tsp" → "teaspoon", "tbsp" → "tablespoon"
- [ ] Amounts: "2-3" parsed as range
- [ ] Prep notes: "(chopped)" extracted separately

#### Real-Time Feedback

**Test 6.7: Viewfinder UI**
- [ ] Camera opens correctly
- [ ] Region overlay: Highlights recipe sections (blue, green, yellow)
- [ ] Quality feedback: "Move closer" when too far
- [ ] Quality feedback: "Better lighting" in dim conditions
- [ ] Quality feedback: "Hold steady" when blurry
- [ ] Capture button: Enabled only when quality good

#### Multi-Page Scanning

**Test 6.8: Multiple Pages**
- [ ] Scan page 1, tap "Add Page"
- [ ] Scan page 2, tap "Add Page"
- [ ] Scan page 3, tap "Done"
- [ ] Result: Single recipe with all content merged

#### Review & Correction

**Test 6.9: OCR Review UI**
- [ ] Side-by-side: Original image + parsed text
- [ ] Low-confidence sections: Highlighted in yellow
- [ ] Inline editing: Tap to correct
- [ ] Confidence indicators: Visible on each section
- [ ] Save button: Commits corrections

#### Performance
- [ ] Preprocessing: < 2 seconds
- [ ] OCR (Vision): < 5 seconds
- [ ] OCR (Claude fallback): < 10 seconds
- [ ] Structure parsing: < 3 seconds

#### Edge Cases
- [ ] Angled photo: Auto-rotates and corrects perspective
- [ ] Dark image: Enhances contrast automatically
- [ ] Handwriting with flourishes: Falls back to Claude
- [ ] No recipe detected: Error message, retry option
- [ ] Very long recipe (3+ pages): Handles gracefully

---

### Prompt 7: Shared Comments System

#### Comment Scope

**Test 7.1: Private Comment**
- [ ] Device A: Create comment with scope = "Private"
- [ ] Device A: Share recipe to Device B
- [ ] Device B: Accepts recipe
- [ ] Result: Private comment NOT visible on Device B

**Test 7.2: Direct Shares Comment**
- [ ] Device A: Create comment with scope = "Direct Shares"
- [ ] Device A: Share recipe to Device B
- [ ] Device B: Accepts recipe
- [ ] Result: Comment visible on Device B
- [ ] Attribution: "From Device A"

**Test 7.3: Full Chain Comment**
- [ ] Device A: Create comment with scope = "Full Chain"
- [ ] Device A: Share to Device B
- [ ] Device B: Accepts and shares to Device C
- [ ] Result: Comment visible on Device C
- [ ] Attribution: "From Device A, via Device B"

#### Lazy Loading

**Test 7.4: Comment Fetching**
- [ ] Device B: Open shared recipe
- [ ] Device B: Tap "View Comments"
- [ ] Loading indicator appears
- [ ] Comments fetch from CloudKit public DB
- [ ] Local comments + lineage comments displayed
- [ ] Fetch time: < 3 seconds

#### Endorsement

**Test 7.5: Endorsement Flow**
- [ ] Device B: View comment from Device A
- [ ] Device B: Tap heart icon (endorse)
- [ ] Endorsement count increments locally
- [ ] CloudKit public DB: Endorsement count updated
- [ ] Device A: Views comment
- [ ] Result: Endorsement count reflects Device B's endorsement

#### Public Database

**Test 7.6: Comment Aggregation**
- [ ] Device A: Create comment, scope = "Full Chain"
- [ ] Comment published to CloudKit public DB
- [ ] CloudKit Dashboard: SharedCommentAggregate record appears
- [ ] Fields: Anonymized author ID, comment text, provenance hash
- [ ] No PII: User name NOT included

#### Edge Cases
- [ ] Comment with no scope: Defaults to "Private"
- [ ] Endorsement while offline: Queued, processes later
- [ ] Fetch comments while offline: Shows cached only
- [ ] Very long comment (1000+ chars): Displays correctly

---

### Prompt 8: QR Code & Deep Link Sharing

#### QR Code Generation

**Test 8.1: Basic QR Code**
- [ ] Device A: Tap "Share via QR Code"
- [ ] QR code generated
- [ ] High resolution (512x512 or larger)
- [ ] Contains share URL
- [ ] Generation time: < 1 second

**Test 8.2: Branded QR Code**
- [ ] Heirloom logo in center
- [ ] Logo doesn't interfere with scanning
- [ ] Branded version displays correctly

**Test 8.3: QR Code Scanning**
- [ ] Device B: Open camera app
- [ ] Point at QR code on Device A
- [ ] Camera recognizes QR code
- [ ] Notification: "Open in Heirloom"
- [ ] Tap notification: App opens with share

**Test 8.4: Save & Print**
- [ ] Tap "Save to Photos"
- [ ] QR code saved to camera roll
- [ ] Tap "Print"
- [ ] Print dialog appears with QR code

#### Universal Links

**Test 8.5: Universal Link Handling**
- [ ] Device A: Generate share link (heirloom.app/r/abc123)
- [ ] Send link to Device B via Messages
- [ ] Device B: Tap link
- [ ] Result: App opens (not browser)
- [ ] RecipeReceiveSheet displays

**Test 8.6: Web Fallback**
- [ ] Copy link: heirloom.app/r/abc123
- [ ] Open in browser (desktop computer)
- [ ] Result: Web page displays recipe preview
- [ ] Shows "Download Heirloom" button
- [ ] Shows "Open in Heirloom" button (if app installed)

#### Share Analytics

**Test 8.7: Analytics Tracking**
- [ ] Device A: Create share, get URL
- [ ] Device B: Opens URL (tracked)
- [ ] Device C: Opens URL (tracked)
- [ ] Device B: Accepts share (tracked)
- [ ] Device A: View share history
- [ ] Result: Shows "2 opens, 1 accept"

**Test 8.8: Share History**
- [ ] Device A: View share history
- [ ] List shows all shares created
- [ ] Each share shows:
  - [ ] Recipe name
  - [ ] Date created
  - [ ] Status (Pending, Accepted, Expired)
  - [ ] Analytics (opens, accepts)
- [ ] Tap share: View details
- [ ] Tap "Revoke": Confirms, then revokes

#### Edge Cases
- [ ] QR code too small to scan: Shows zoom option
- [ ] Universal link on device without app: Web fallback works
- [ ] Analytics tracking blocked: Graceful degradation
- [ ] Share history with 100+ shares: Paginated correctly

---

### Prompt 9: Privacy Policy & Opt-In Flows

#### Privacy Policy

**Test 9.1: Policy Display**
- [ ] Settings → Privacy Policy
- [ ] Full policy displays
- [ ] Readable font size
- [ ] Scrollable
- [ ] All sections present:
  - [ ] Data Collection
  - [ ] Data Usage
  - [ ] Third-Party Services
  - [ ] User Rights
  - [ ] Contact Info

#### Opt-In Flow

**Test 9.2: First Share**
- [ ] Fresh install
- [ ] Attempt to share recipe (first time)
- [ ] Consent dialog displays
- [ ] Clear explanation of sharing features
- [ ] Privacy policy link (opens policy)
- [ ] Two checkboxes:
  - [ ] Enable sharing features (required)
  - [ ] Contribute to aggregated metrics (optional)
- [ ] Tap "Not Now": Sharing disabled
- [ ] Tap "Enable": Sharing enabled

**Test 9.3: Consent Preferences**
- [ ] Settings → Privacy Settings
- [ ] Toggle "Enable Sharing": Can disable after enabling
- [ ] Toggle "Aggregated Metrics": Can change anytime
- [ ] Changes take effect immediately

**Test 9.4: Consent Enforcement**
- [ ] Disable sharing in settings
- [ ] Attempt to share recipe
- [ ] Result: Share button disabled or shows re-enable prompt
- [ ] Disable aggregated metrics
- [ ] Create comment with "Full Chain" scope
- [ ] Result: Comment NOT published to public DB

#### Data Export

**Test 9.5: Export My Data**
- [ ] Settings → Export My Data
- [ ] Tap "Export"
- [ ] Progress indicator displays
- [ ] Export completes (< 30 seconds for 100 recipes)
- [ ] Share sheet appears
- [ ] Select "Save to Files"
- [ ] Result: ZIP file with:
  - [ ] recipes.json (all recipes)
  - [ ] comments.json (all comments)
  - [ ] share-history.json (all shares)
  - [ ] images/ (folder with all recipe images)

**Test 9.6: Export Data Validity**
- [ ] Unzip exported file
- [ ] recipes.json: Valid JSON, all recipes present
- [ ] comments.json: Valid JSON, all comments present
- [ ] Images: All referenced images included

#### Data Deletion

**Test 9.7: Delete My Account**
- [ ] Settings → Delete My Account
- [ ] Warning dialog: "This is permanent"
- [ ] Type "DELETE" to confirm
- [ ] Tap "Delete My Account"
- [ ] Result:
  - [ ] All local recipes deleted
  - [ ] All CloudKit private records deleted
  - [ ] Public DB contributions marked for deletion
  - [ ] All caches cleared
  - [ ] User signed out
  - [ ] App returns to onboarding

**Test 9.8: Deletion Verification**
- [ ] CloudKit Dashboard: Private records gone
- [ ] Public DB: Contributions marked as deleted
- [ ] Device: No recipes in app
- [ ] Photos app: Exported data still accessible (not deleted)

#### Edge Cases
- [ ] Decline consent twice: Shows "Enable in Settings" message
- [ ] Export with no data: Empty JSON files, no errors
- [ ] Delete while offline: Queued, processes when online
- [ ] Very large export (1000+ recipes): Completes successfully

---

## 🏁 End-to-End Integration Tests

### Full Sharing Journey (All Prompts Combined)

**Test E2E.1: Complete Share Flow**
1. [ ] Device A: Import recipe from AllRecipes.com
2. [ ] Device A: Scan handwritten notes, add to recipe
3. [ ] Device A: Add 3 comments (2 tips, 1 modification)
4. [ ] Device A: Customize card back
5. [ ] Device A: Share recipe via Messages
6. [ ] Device B: Receive share notification
7. [ ] Device B: Open share (deep link)
8. [ ] Device B: Preview displays correctly
9. [ ] Device B: Accept share
10. [ ] Device B: Recipe imports with full lineage
11. [ ] Device B: Comments visible and attributed
12. [ ] Device B: Endorse comment from Device A
13. [ ] Device B: Add own comment
14. [ ] Device B: Share to Device C via QR code
15. [ ] Device C: Scan QR code
16. [ ] Device C: Accept share
17. [ ] Device C: Lineage shows full chain (A → B → C)
18. [ ] Device C: All comments visible (from A and B)
19. [ ] Device A: View share history
20. [ ] Device A: Analytics show 2 accepts

**Expected Results:**
- [ ] No errors at any step
- [ ] All data transferred correctly
- [ ] Lineage chain accurate
- [ ] Comments from all users visible
- [ ] Analytics accurate
- [ ] Performance acceptable (< 10s per step)

---

## 🐛 Bug Triage & Reporting

### Severity Levels

**Critical (P0):**
- App crashes
- Data loss
- Cannot share or accept shares
- CloudKit sync completely broken
- Privacy violation (PII exposed)

**High (P1):**
- Feature not working as designed
- Sync conflicts causing data corruption
- Poor performance (> 30s operations)
- UI rendering issues

**Medium (P2):**
- Minor feature issues
- Edge cases not handled
- UI polish needed
- Performance optimization needed

**Low (P3):**
- Nice-to-have improvements
- Cosmetic issues
- Documentation gaps

### Bug Report Template

```
**Title:** [Brief description]

**Severity:** P0 / P1 / P2 / P3

**Prompt:** [Which prompt this relates to]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Environment:**
- Device: iPhone 14 Pro
- iOS Version: 17.2
- Build: [Build number]
- CloudKit Environment: Development / Production

**Screenshots/Logs:**
[Attach if available]

**Notes:**
[Any additional context]
```

---

## 📊 Success Metrics Summary

### Phase 2A
- [ ] Share success rate: 95%+
- [ ] Share acceptance time: < 10 seconds
- [ ] Offline queue: Processes 100% of queued operations
- [ ] CloudKit sync: 95%+ success rate
- [ ] Zero sync conflicts in testing

### Phase 2B
- [ ] Web import success: 90%+ for major sites
- [ ] Paywall detection: 100% accurate
- [ ] OCR accuracy: 95%+ print, 85%+ handwriting
- [ ] Import time: < 10 seconds per recipe

### Phase 2C
- [ ] Comment sync: < 5 seconds
- [ ] QR code generation: < 1 second
- [ ] QR code scan success: 100%
- [ ] Data export: < 30 seconds for 100 recipes
- [ ] Data deletion: Removes 100% of user data

### Overall MVP
- [ ] 10+ successful beta shares (real users)
- [ ] Zero critical bugs
- [ ] All tests passing
- [ ] App Store review-ready

---

**Last Updated:** December 18, 2024
**Status:** Ready for testing
**Next:** Begin testing with Prompt 1
