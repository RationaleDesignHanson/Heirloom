# Heirloom Phase 2: Social Sharing & Recipe Lineage - Master Implementation Plan

**Created:** December 18, 2024
**Status:** Planning Complete, Ready to Build
**Target Timeline:** 8-10 weeks (full feature set)
**Risk Level:** High (CloudKit complexity, analytics requires data volume, ML deduplication)
**Scope:** All 12 prompts required for launch

---

## 🎯 Executive Summary

Building comprehensive social sharing features for Heirloom recipe app, enabling users to share recipes with friends/family, track recipe lineage, import web recipes, and enhance OCR capabilities.

### What We're Building

**Complete Feature Set:**
- ✅ Share recipe with friends via link/AirDrop/QR code
- ✅ Track who shared recipe to you (provenance)
- ✅ Import recipes from web URLs with proper attribution
- ✅ Enhanced OCR for handwritten recipes
- ✅ See recipe "lineage" (share chain visualization)
- ✅ Comments that travel with shared recipes
- ✅ Advanced lineage tree visualization (interactive node graph)
- ✅ Viral recipe analytics (popularity metrics, cook counts)
- ✅ Discover trending recipes (discovery feed)
- ✅ Geographic spread tracking
- ✅ ML-based comment deduplication

---

## 🏗️ Architecture Overview

### Two-Tier Data Architecture

**Tier 1: Local/Private (SwiftData + CloudKit Private DB)**
- User's recipes, comments, card customizations
- ProvenanceMetadata (lightweight cache of lineage info)
- ShareMetadata (references to CKShare records)
- **Automatic sync** via SwiftData's `.automatic` CloudKit integration

**Tier 2: Public/Shared (Manual CloudKit APIs)**
- ProvenanceAggregateRecord (CKRecord) - Anonymized metrics
- SharedCommentAggregate (CKRecord) - Propagated comments
- CKShare records for direct user-to-user sharing
- **Manual sync** via CloudKitSyncCoordinator service

**Sync Bridge: CloudKitSyncCoordinator**
- Batches updates from private → public every 15 min
- Fetches aggregated data from public → local cache
- Handles offline queue with retry logic
- Manages conflict resolution

### Why This Architecture?

**Problem:** SwiftData's automatic sync ONLY works with CloudKit private database. The original plan assumed SwiftData relationships would work across databases - they don't.

**Solution:** Keep SwiftData for local data (Phase 1 pattern), use manual CloudKit for cross-user features, bridge them with a coordinator service.

---

## 📋 Implementation Phases

### **Phase 2A: CloudKit Foundation & Core Sharing** (Weeks 1-3)

**Goal:** Build robust CloudKit infrastructure and basic sharing functionality

**Deliverables:**
- CloudKitSyncCoordinator service with retry/offline queue
- ProvenanceMetadata model (local cache)
- CKShare-based recipe sharing
- Share acceptance flow
- Basic lineage display ("Shared by Sarah")

**Features Delivered:**
- Share recipe with friends via link/AirDrop
- Track who shared recipe to you
- See recipe "lineage" (basic version)

**Prompts:** 1, 2, 3, 4

---

### **Phase 2B: Content Import** (Weeks 4-5)

**Goal:** Import recipes from external sources (web + OCR)

**Deliverables:**
- Google Cloud Function for web scraping
- Paywall detection + "Subscribe" CTA
- Attribution preservation (legal compliance)
- Multi-engine OCR (Vision + Claude fallback)
- Handwriting detection
- Recipe structure parser

**Features Delivered:**
- Import recipes from web URLs
- Enhanced OCR for handwritten recipes

**Prompts:** 5, 6

---

### **Phase 2C: Social Comments & Advanced Sharing** (Weeks 6-7)

**Goal:** Comments that travel with recipes, additional share methods

**Deliverables:**
- SharedComment system with lazy loading
- CloudKit public DB sync for comments
- QR code generation
- Deep link handling (heirloom://share/...)
- Universal links (heirloom.app/r/...)
- Privacy policy + opt-in consent flows

**Features Delivered:**
- Comments that travel with shared recipes
- QR code sharing

**Prompts:** 7, 8, 9

---

### **Phase 2D: Discovery & Analytics** (Weeks 8-10)

**Goal:** Discovery, trending, advanced visualizations, analytics

**Deliverables:**
- Interactive lineage tree graph with pan/zoom
- Trending algorithm with time decay
- Discovery feed UI
- Analytics dashboard
- Viral recipe detection
- Geographic spread tracking
- ML-based comment deduplication using embeddings

**Features Completed:**
- Advanced lineage visualization (interactive node graph)
- Trending algorithm (surfaces popular recipes)
- Discovery feed (curated trending content)
- Viral recipe analytics (100+ user tracking)
- Geographic spread metrics
- ML comment deduplication

**Prompts:** 10, 11, 12

---

## 🔑 Key Architectural Decisions

### Decision 1: Use CKShare, Not Custom Share Model

**Original Plan:** Build custom RecipeShare model with SwiftData
**Problem:** Doesn't handle PII security, authentication, permissions properly
**Solution:** Use Apple's CKShare (handles security, expiration, permissions automatically)

**Benefits:**
- ✅ Built-in authentication via iCloud
- ✅ Apple handles PII securely (email/phone)
- ✅ Automatic expiration support
- ✅ Revocation built-in
- ✅ Less code to maintain

### Decision 2: Server-Side Web Scraping

**Original Plan:** In-app web scraping
**Problem:** IP blocking, legal compliance, rate limiting
**Solution:** Google Cloud Function for server-side scraping

**Benefits:**
- ✅ Centralized rate limiting
- ✅ Caching parsed recipes (faster, cheaper)
- ✅ Easier legal compliance
- ✅ Better parsing libraries (Cheerio/BeautifulSoup)
- ✅ Smaller iOS app binary

### Decision 3: Lazy-Loaded Comments

**Original Plan:** Actively propagate comments down share chain
**Problem:** Infinite loops, sync conflicts, storage bloat
**Solution:** Lazy-load comments when viewing recipe

**Benefits:**
- ✅ No infinite loops
- ✅ Always fresh data
- ✅ No local storage bloat
- ✅ Simpler conflict resolution

### Decision 4: Privacy-First Approach

**Original Plan:** Implicit consent for aggregated metrics
**Problem:** GDPR/CCPA compliance, user trust
**Solution:** Explicit opt-in for all cross-user features

**Benefits:**
- ✅ GDPR/CCPA compliant
- ✅ Builds user trust
- ✅ Clear data deletion path
- ✅ Two-tier consent (sharing vs metrics)

---

## 🧪 Testing & Validation Strategy

### Test Environment Requirements

**Devices:**
- 2 physical iOS devices (CloudKit sharing doesn't work fully in simulator)
- Device A: Your primary iCloud account
- Device B: Different iCloud account (family member/friend)

**Accounts:**
- TestFlight internal track (just you, 2 accounts)
- TestFlight external track (5-10 beta testers)
- CloudKit development environment (separate from production)

**Sample Data:**
- 15-20 handwritten recipe cards (various quality levels)
- 10 web recipe URLs (mix of free and paywalled sites)
- 5 test recipes with comments for sharing

### Testing Phases

**Phase 2A Testing:**
- CloudKit dashboard setup verified
- Sync coordinator handles offline scenarios
- Share creation works on Device A
- Share acceptance works on Device B
- Provenance link displays correctly
- Network interruption recovery works

**Phase 2B Testing:**
- Web import works for 5+ sites
- Paywall detection accurate
- OCR accuracy: >95% for print, >85% for handwriting
- Recipe structure parsing correct
- Attribution preserved

**Phase 2C Testing:**
- Comments appear on recipient device
- QR code scans correctly
- Deep links work
- Privacy opt-in flows correctly
- Data deletion works

### Per-Prompt Testing Checklist

Each prompt includes:
- ✅ Unit tests for services
- ✅ Integration tests for flows
- ✅ UI tests for critical paths
- ✅ 2-device validation scenarios
- ✅ Network failure scenarios
- ✅ CloudKit dashboard verification

---

## 🔒 Privacy & Legal Compliance

### Privacy Policy Requirements

**What We Collect:**
- Recipe content (ingredients, instructions, photos)
- Comments and ratings
- Share relationships (who shared to whom)
- Aggregated metrics (opt-in only): cook counts, average ratings

**What We DON'T Collect:**
- User names, emails, photos (CloudKit/iCloud handles this)
- Location data
- Device identifiers
- Usage analytics (unless explicitly opted in)

**Third-Party Services:**
- Claude AI: Anonymous sentiment analysis of comments
- Google Cloud: URL-only for recipe parsing (no user data)
- CloudKit: Covered by Apple's iCloud Terms of Service

**User Rights:**
- View all your data
- Export recipes (JSON format)
- Delete account (removes all contributed data)
- Opt out of aggregated metrics
- Local-only mode (no cross-user features)

### Opt-In Consent Flow

**Two-Tier Consent:**

1. **Sharing Features** (required for social functionality)
   - Presented first time user taps "Share"
   - Clear explanation of what's shared
   - Can be disabled in Settings

2. **Aggregated Metrics** (optional, separate checkbox)
   - Contribute anonymous stats (cook counts, ratings)
   - Powers trending/discovery features
   - Can opt in/out anytime

### Web Scraping Legal Compliance

**Approach:**
- Respect robots.txt
- Identify as Heirloom in User-Agent
- Rate limit requests (max 1 per second per site)
- Cache results (avoid redundant requests)
- **Paywall handling:**
  - Detect paywall via HTML analysis
  - Show preview only (title, author, image)
  - Display "Subscribe" CTA linking to original site
  - Do NOT scrape full paywalled content

---

## 📊 Success Metrics

### Phase 2A Success Criteria
- [ ] 2-device sharing works reliably
- [ ] Share acceptance flow < 10 seconds
- [ ] Offline queue processes when online
- [ ] Zero sync conflicts in testing
- [ ] CloudKit operations have 95%+ success rate

### Phase 2B Success Criteria
- [ ] Web import works for 10+ major sites
- [ ] OCR accuracy: 95%+ print, 85%+ handwriting
- [ ] Paywall detection: 100% accurate
- [ ] Recipe parsing: 90%+ complete data extraction

### Phase 2C Success Criteria
- [ ] Comments appear on recipient device within 5 seconds
- [ ] QR code scans work 100% of time
- [ ] Privacy opt-in flows tested with 5+ users
- [ ] Data deletion removes all contributed data

### MVP Launch Criteria
- [ ] All Phase 2A-2C tests passing
- [ ] 10+ successful TestFlight beta shares
- [ ] Privacy policy reviewed by legal (if available)
- [ ] Zero critical bugs in issue tracker
- [ ] App Store review-ready (no crashes, proper attribution)

---

## 🚧 Risk Mitigation

### High-Risk Areas

**Risk 1: CloudKit Sync Complexity**
- **Mitigation:** Start with CloudKitSyncCoordinator, test thoroughly before features
- **Fallback:** Local-only mode if CloudKit unavailable

**Risk 2: Web Scraping Blocked**
- **Mitigation:** Server-side scraping, respect rate limits, use official APIs when available
- **Fallback:** Manual recipe entry, browser extension (future)

**Risk 3: OCR Accuracy Below Target**
- **Mitigation:** Multi-engine approach (Vision + Claude), user correction flow
- **Fallback:** Manual editing after OCR

**Risk 4: Privacy Compliance**
- **Mitigation:** Opt-in from day 1, clear data deletion, legal review
- **Fallback:** Disable aggregated metrics if concerns arise

### Contingency Plans

**If CloudKit Public DB Too Complex:**
- Fall back to CKShare only (no aggregated metrics)
- Defer trending/discovery to v2
- Still deliver core sharing functionality

**If Web Scraping Legal Concerns:**
- Partner with recipe sites for official API access
- Focus on user-submitted recipes only
- Manual import as primary method

**If Testing Reveals Major Issues:**
- Roll back to previous phase
- Extended testing period before moving forward
- Defer launch until stable

---

## 📅 Detailed Timeline

### Week 1: CloudKit Infrastructure
- **Days 1-2:** CloudKit 101 education, dashboard setup
- **Days 3-4:** Build CloudKitSyncCoordinator with retry logic
- **Day 5:** Test on 2 devices, validate offline queue

### Week 2: Local Provenance & CKShare
- **Days 1-2:** Add ProvenanceMetadata model, migrate to SchemaV2
- **Days 3-4:** Implement CKShare creation and share sheet UI
- **Day 5:** Test sharing between 2 iCloud accounts

### Week 3: Share Acceptance Flow
- **Days 1-3:** Build deep link handling, share preview UI
- **Days 4-5:** Implement accept flow, test end-to-end

**Phase 2A Complete** ✅

### Week 4: Server-Side Web Scraping
- **Days 1-2:** Build Google Cloud Function, implement parsers
- **Days 3-4:** Add paywall detection, attribution handling
- **Day 5:** Test with 10+ recipe sites

### Week 5: Enhanced OCR
- **Days 1-3:** Implement multi-engine OCR, handwriting detection
- **Days 4-5:** Build recipe structure parser, test with 20 samples

**Phase 2B Complete** ✅

### Week 6: Shared Comments
- **Days 1-3:** Extend RecipeComment model, implement lazy loading
- **Days 4-5:** CloudKit public DB sync, test cross-user comments

### Week 7: QR Codes & Privacy
- **Days 1-2:** Implement QR code generation, deep links
- **Days 3-5:** Build privacy policy UI, opt-in flows, test data deletion

**Phase 2C Complete** ✅

### Week 8: Advanced Lineage Visualization
- **Days 1-3:** Build interactive node graph component
- **Days 4-5:** Implement pan/zoom, node interactions, path highlighting

### Week 9: Analytics & Trending
- **Days 1-2:** Implement trending score algorithm
- **Days 3-4:** Build analytics dashboard, viral detection
- **Day 5:** Implement geographic spread tracking

### Week 10: ML Deduplication & Final Integration
- **Days 1-3:** Implement ML-based comment deduplication (embeddings)
- **Days 4-5:** Build discovery feed UI, integrate all Phase 2D features

**Phase 2D Complete** ✅

---

## 🎓 Learning Resources

### CloudKit Resources
- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CKShare Documentation](https://developer.apple.com/documentation/cloudkit/ckshare)
- [CloudKit Best Practices (WWDC)](https://developer.apple.com/videos/play/wwdc2021/10086/)

### SwiftData Resources
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [SwiftData Migration Guide](https://developer.apple.com/documentation/swiftdata/migrating-your-data)

### Privacy & Legal
- [GDPR Compliance Checklist](https://gdpr.eu/checklist/)
- [Apple App Store Privacy Guidelines](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [robots.txt Specification](https://www.robotstxt.org/)

---

## 📝 Next Steps

### Immediate Actions (Today)

1. **Review this master plan** - Confirm approach aligns with vision
2. **Set up test devices** - 2 physical iOS devices with different iCloud accounts
3. **Read Prompt 1** - CloudKit Infrastructure & Education
4. **Begin implementation** - Start building CloudKitSyncCoordinator

### This Week

- Complete Prompt 1 (CloudKit infrastructure)
- Test on 2 devices with network interruption scenarios
- Validate CloudKit dashboard shows records correctly
- Report progress, move to Prompt 2

### This Month

- Complete Phase 2A (Prompts 1-4)
- Validate end-to-end sharing works reliably
- Begin Phase 2B (web import)

### This Quarter (10 weeks)

- Complete Phase 2A: CloudKit & Core Sharing (Weeks 1-3)
- Complete Phase 2B: Content Import (Weeks 4-5)
- Complete Phase 2C: Social Comments & Privacy (Weeks 6-7)
- Complete Phase 2D: Discovery & Analytics (Weeks 8-10)
- Launch with full feature set on TestFlight
- Gather user feedback and iterate

---

## ✅ Completion Checklist

### Phase 2A: CloudKit Foundation & Core Sharing
- [ ] CloudKitSyncCoordinator service built and tested
- [ ] ProvenanceMetadata model added to Recipe
- [ ] CKShare-based sharing works on 2 devices
- [ ] Share acceptance flow complete
- [ ] Basic lineage display implemented
- [ ] All Phase 2A tests passing

### Phase 2B: Content Import
- [ ] Google Cloud Function deployed and tested
- [ ] Web import works for 10+ sites
- [ ] Paywall detection accurate
- [ ] Enhanced OCR implemented
- [ ] OCR accuracy targets met (95% print, 85% handwriting)
- [ ] All Phase 2B tests passing

### Phase 2C: Social Comments & Privacy
- [ ] SharedComment system implemented
- [ ] Comments sync across users
- [ ] QR code generation works
- [ ] Deep links handled correctly
- [ ] Privacy policy created
- [ ] Opt-in flows implemented and tested
- [ ] All Phase 2C tests passing

### Phase 2D: Discovery & Analytics
- [ ] Interactive lineage tree graph implemented
- [ ] Pan/zoom/node interactions working
- [ ] Trending score algorithm implemented
- [ ] Analytics dashboard built
- [ ] Viral recipe detection working
- [ ] Geographic spread tracking implemented
- [ ] ML-based comment deduplication working
- [ ] Discovery feed UI complete
- [ ] All Phase 2D tests passing

### Launch Readiness
- [ ] All 12 prompts complete
- [ ] All phases (2A, 2B, 2C, 2D) tested and working
- [ ] 20+ successful beta shares across all features
- [ ] Trending algorithm validated with test data
- [ ] Privacy policy finalized
- [ ] App Store ready
- [ ] Zero critical bugs
- [ ] TestFlight beta successful (10+ users)

---

## 📞 Support & Questions

**As you work through prompts:**
- Reference this master plan for big picture
- Check PHASE_2_PROMPT_SEQUENCE.md for detailed instructions
- Use PHASE_2_TESTING_STRATEGY.md for validation
- Track progress in PHASE_2_PROGRESS_TRACKER.md
- Ask questions anytime - better to clarify than assume

**Common Questions:**
- "Where am I in the plan?" → Check todo list or progress tracker
- "What's next?" → Next pending todo in sequence
- "Is this critical?" → Check "Must-Have" vs "Nice-to-Have" sections
- "Can I skip this?" → Check dependencies in prompt sequence doc

---

**Last Updated:** December 18, 2024
**Plan Status:** Approved, Ready to Execute
**Next Action:** Begin Prompt 1 (CloudKit Infrastructure)
