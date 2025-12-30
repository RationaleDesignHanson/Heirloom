# Heirloom User Milestone Roadmap
## Q1 2026 Launch Strategy - Detailed Phase Plan

**Document Version:** 1.0
**Last Updated:** December 29, 2025
**Owner:** Matt Hanson
**Status:** Phase 1 In Progress (Weeks 2-4 of Closed Beta)

---

## Overview

This roadmap defines 5 distinct phases from current beta testing through full public launch and growth scaling. Each phase has specific user targets, objectives, tactics, success criteria, and go/no-go decision gates.

**Strategic Timeline:**
- **Phase 1:** Closed Beta (Current - January 15, 2026)
- **Phase 2:** Expanded Beta (January 16 - February 1, 2026)
- **Phase 3:** Soft Launch (February 2 - February 15, 2026)
- **Phase 4:** Full Launch (February 16 - March 31, 2026)
- **Phase 5:** Growth & Scale (April 1 - December 31, 2026)

**Key Decision Point:** March 31, 2026 (End of Phase 4) - Evaluate bootstrap vs raise $150K based on traction metrics.

---

## Phase 1: Closed Beta - Product Validation
**Timeline:** Current (Week 2-4 of 4-week plan) → January 15, 2026
**Duration:** ~3 weeks remaining
**Current Status:** v1.1.0 Build 3 distributed via TestFlight

### User Targets

| Metric | Target | Current Status |
|--------|--------|----------------|
| Total Testers | 20-30 | 20-30 (achieved) |
| Active Testers (weekly) | 15-25 (75%+) | Tracking in progress |
| Test Scenarios Completed | 80% P1, 60% P2 | In progress |
| Premium Conversions (test) | N/A | N/A (no payment in beta) |

**Tester Composition:**
- Internal team: 3-5 (developers, friends with technical expertise)
- Friends & family: 10-15 (typical home cooks)
- Food bloggers: 5-7 (power users, cookbook collectors)
- Edge case testers: 2-3 (iOS 17 early builds, large recipe collections)

### Primary Objectives

1. **Validate Product Stability**
   - Achieve 99%+ crash-free rate (measured via TestFlight crashes)
   - Confirm 85%+ recipe import success rate across 500+ supported websites
   - Ensure CloudKit sync works reliably across devices
   - Validate AI features (OCR, bulk URL import) at 90%+ accuracy

2. **Identify Critical Bugs**
   - P1 (launch blockers): 0 open at phase end
   - P2 (important but not blocking): < 5 open at phase end
   - P3 (nice to have): Document for post-launch

3. **Test Core Workflows**
   - Recipe import (web, OCR, manual, bulk URL)
   - Card personalization (backgrounds, stickers, annotations)
   - Shopping list → iOS Reminders export
   - Dinner party mode with multi-recipe planning
   - CloudKit sharing with provenance tracking
   - Settings & AI API key configuration

4. **Collect Initial Feedback**
   - Usability issues in onboarding flow
   - Feature requests and missing functionality
   - Pricing perception (show $4.99 paywall, don't charge)
   - Testimonial candidates (identify 3-5 enthusiastic users)

### Tactics & Actions

**Week 1 (Current Week - End of December):**
- [x] Distribute v1.1.0 Build 3 via TestFlight
- [ ] Send detailed testing instructions via email (priority: P1 scenarios)
- [ ] Set up feedback collection:
  - TestFlight feedback mechanism (built-in)
  - Email: beta@heirloomapp.com (Help Scout)
  - Google Form: structured feedback survey
  - 1:1 interviews: Schedule 30-min calls with 5 testers
- [ ] Monitor crash analytics daily (TestFlight dashboard)
- [ ] Create bug tracking spreadsheet (Google Sheets: Bug ID, Description, Priority, Status, Assigned To, Resolution)

**Week 2 (January 6-12, 2026):**
- [ ] Send mid-beta check-in email: "How's testing going? Any blockers?"
- [ ] Conduct 1:1 interviews with 5 testers (mix of technical and non-technical)
- [ ] Triage bugs: Assign P1/P2/P3 priorities
- [ ] Fix P1 bugs immediately, release Build 4 if needed
- [ ] Test fixes on 2-3 devices before distributing new build
- [ ] Document feature requests in separate backlog (post-launch consideration)

**Week 3 (January 13-15, 2026):**
- [ ] Final bug sweep: Confirm P1 bugs resolved, P2 < 5 open
- [ ] Request testimonials from enthusiastic testers (email template: "Would you recommend Heirloom? Can we quote you?")
- [ ] Prepare go/no-go decision document:
  - Crash-free rate: [%]
  - Import success rate: [%]
  - P1 bugs open: [#]
  - Tester satisfaction (1-10): [avg]
  - Recommendation: GO / NO-GO / NEEDS WORK
- [ ] If GO: Proceed to Phase 2 (Expanded Beta)
- [ ] If NO-GO: Extend Phase 1 by 1-2 weeks, address blockers

### Success Criteria (Go/No-Go Gates)

**MUST ACHIEVE (Launch Blockers):**
- ✅ 99%+ crash-free rate across all testers (TestFlight data)
- ✅ 0 P1 bugs open (critical issues resolved)
- ✅ 85%+ recipe import success rate (test across 20+ websites)
- ✅ CloudKit sync works reliably (test on 2+ devices per tester)
- ✅ iOS Reminders export functional (test on iPhone + Apple Watch)
- ✅ AI features operational (OCR 90%+ accuracy on 10 test cookbooks)

**SHOULD ACHIEVE (Important but Not Blocking):**
- ☑️ 75%+ weekly active testers (15+ of 20 logging in weekly)
- ☑️ < 5 P2 bugs open (important issues mostly resolved)
- ☑️ 3+ testers provide testimonials ("I love this app, would recommend")
- ☑️ Average satisfaction score 7+/10 (Google Form survey)
- ☑️ 80%+ P1 test scenarios completed by testers

**NICE TO HAVE (Post-Launch Improvements):**
- ⭕ Feature requests documented for roadmap
- ⭕ Pricing feedback collected (reactions to $4.99 paywall)
- ⭕ Competitor comparisons from testers (vs Paprika, Mela)

**Decision Gate: GO if all MUST ACHIEVE + 3 of 5 SHOULD ACHIEVE met.**

### Key Metrics to Track

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Crash-Free Rate | 99%+ | TestFlight dashboard |
| Import Success Rate | 85%+ | Manual testing (20 websites × 3 testers) |
| P1 Bugs Open | 0 | Bug tracking spreadsheet |
| P2 Bugs Open | < 5 | Bug tracking spreadsheet |
| Weekly Active Testers | 75%+ (15+) | TestFlight analytics |
| Tester Satisfaction | 7+/10 | Google Form survey (1-10 scale) |
| Testimonials Collected | 3+ | Email requests |

### Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Critical bug discovered late** | Delays Phase 2 by 1-2 weeks | Medium | Daily monitoring, prioritize P1 fixes, maintain buffer time |
| **Low tester engagement (< 50% active)** | Insufficient feedback data | Low | Send reminder emails, offer incentive (free sticker pack), 1:1 calls |
| **AI API costs spike** | Budget concerns for launch | Low | Monitor token usage, implement rate limiting, test fallback to regex parser |
| **CloudKit quota issues** | Sync failures at scale | Low | Test with large recipe collections (100+ recipes), optimize image storage |
| **Tester churn (drop out)** | Lose institutional knowledge | Medium | Keep testers engaged with updates, ask for time commitment upfront |

### Deliverables

- ✅ v1.1.0 Build 3 distributed (current)
- [ ] Bug tracking spreadsheet (P1/P2/P3 priorities)
- [ ] Tester feedback summary document (usability issues, feature requests)
- [ ] 3+ testimonials collected ("I love Heirloom because...")
- [ ] Go/no-go decision document (metrics, recommendation)
- [ ] Updated TestFlight build (Build 4+ if critical bugs found)

---

## Phase 2: Expanded Beta - Conversion Testing
**Timeline:** January 16 - February 1, 2026
**Duration:** 16 days
**Goal:** Scale tester base, optimize conversion funnel, collect testimonials

### User Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Total Testers | 50-100 | TestFlight invite tracking |
| Weekly Active Testers | 70%+ (35-70) | TestFlight analytics |
| Premium Conversions | 10-15% (5-15 users) | In-app analytics (simulated paywall) |
| Testimonials Collected | 10+ | Email follow-ups |
| App Store Reviews | 15+ (4.5+ stars) | Request via TestFlight feedback |

**Tester Expansion Strategy:**
- Phase 1 testers: Retain 20-30 (core cohort)
- Food bloggers: Invite 10-15 (50K+ followers, target for launch partnerships)
- Cookbook collectors: Invite 10-15 (Reddit r/Cooking, Facebook groups)
- Friends of testers: Invite 10-20 (word-of-mouth expansion)
- Total new invites: 30-50 → Target 50-100 total active

### Primary Objectives

1. **Optimize Conversion Funnel**
   - Test paywall timing: After 3 recipes vs after first share vs after 7 days
   - Test pricing display: "$4.99 one-time" vs "$4.99 forever" vs "$4.99 (no subscription)"
   - Measure drop-off points: Onboarding → Import → Personalization → Paywall
   - A/B test promotional copy: "Join 500 families" vs "Preserve your heritage"

2. **Collect Social Proof**
   - Testimonials: 10+ detailed reviews for marketing website
   - App Store reviews: 15+ early reviews (4.5+ stars average)
   - Video testimonials: 2-3 testers record 30-60 sec videos
   - User-generated content: Encourage testers to share styled recipe cards on Instagram

3. **Validate Onboarding Flow**
   - Time-to-value: 80%+ of testers import first recipe within 5 minutes
   - Onboarding completion: 90%+ complete tutorial
   - Feature discovery: 70%+ try card personalization, 60%+ try shopping list export

4. **Test Marketing Messaging**
   - Survey testers: "How would you describe Heirloom to a friend?" (collect 20+ responses)
   - Pricing perception: "Is $4.99 too expensive, fair, or cheap?" (collect 30+ responses)
   - Feature priority: "Rank these features by importance" (collect 30+ responses)

### Tactics & Actions

**Week 1 (January 16-22):**
- [ ] Invite 30-50 new testers:
  - Email food bloggers: "We'd love your feedback on Heirloom..." (personalized, offer early access to sticker packs)
  - Post in cookbook communities: r/Cooking, r/Old_Recipes, Facebook "Vintage Recipes" group
  - Ask Phase 1 testers to invite 1-2 friends
- [ ] Send detailed onboarding email:
  - Welcome message
  - Priority test scenarios (focus: conversion funnel)
  - Links: TestFlight, feedback form, support email
  - Incentive: "Help shape the future of Heirloom + get free premium when we launch"
- [ ] Implement in-app analytics:
  - Track screen views: Onboarding → Import → Personalization → Paywall
  - Track button clicks: "Start Trial", "Maybe Later", "Restore Purchase"
  - Track time: Time to first recipe, time to first share, session duration
  - Tool: Mixpanel (placeholder tokens already in code, activate now)
- [ ] A/B test paywall timing:
  - Cohort A (25 users): Show paywall after 3 recipes imported
  - Cohort B (25 users): Show paywall after first share attempt
  - Measure: Conversion rate, user feedback (annoying vs well-timed)

**Week 2 (January 23-29):**
- [ ] Send mid-week check-in: "How's your experience so far?" (Google Form survey)
- [ ] Conduct 5 user interviews:
  - Questions: What do you love? What's frustrating? Would you pay $4.99? Why/why not?
  - Record notes in Google Doc
- [ ] Request testimonials from enthusiastic testers:
  - Email template: "Would you be willing to share why you love Heirloom? We'll feature you on our website."
  - Incentive: Free premium for life + your recipe featured on Instagram
- [ ] Analyze conversion funnel data:
  - Drop-off points: Where do users abandon onboarding/paywall?
  - Cohort comparison: Which paywall timing converts better?
  - Feature usage: Which features correlate with higher conversion?

**Week 3 (January 30 - February 1):**
- [ ] Request App Store reviews:
  - Email top 10 enthusiastic testers: "We'd love an honest review on TestFlight"
  - Incentive: Your feedback shapes our launch, thank you gift (sticker pack)
- [ ] Optimize based on data:
  - If Cohort A converts better: Ship paywall after 3 recipes
  - If Cohort B converts better: Ship paywall after first share attempt
  - Fix drop-off points in onboarding (simplify, add skip options)
- [ ] Prepare Phase 3 materials:
  - Finalize App Store listing (screenshots, description, keywords)
  - Prepare soft launch email (friends, family, waitlist)
  - Create press kit (1-pager, hi-res screenshots, logo assets)
- [ ] Go/no-go decision for soft launch:
  - Review metrics against success criteria (below)
  - Document recommendation: GO / NO-GO / NEEDS WORK

### Success Criteria (Go/No-Go Gates)

**MUST ACHIEVE (Soft Launch Blockers):**
- ✅ 50+ total active testers (50% response rate on invites)
- ✅ 10%+ premium conversion rate (simulated paywall)
- ✅ 99%+ crash-free rate maintained
- ✅ 4.5+ star average on TestFlight reviews (15+ reviews)
- ✅ 10+ testimonials collected (usable for marketing)

**SHOULD ACHIEVE (Important but Not Blocking):**
- ☑️ 70%+ weekly active testers (engagement sustained)
- ☑️ 90%+ onboarding completion rate
- ☑️ 70%+ try card personalization, 60%+ try shopping list export
- ☑️ 2+ video testimonials recorded
- ☑️ 20+ responses to "How would you describe Heirloom?" survey

**NICE TO HAVE (Post-Soft Launch Improvements):**
- ⭕ 15%+ conversion rate (exceeds baseline expectations)
- ⭕ User-generated content shared on Instagram (5+ posts)
- ⭕ Food blogger partnerships confirmed (3+ agree to promote at launch)

**Decision Gate: GO if all MUST ACHIEVE + 3 of 5 SHOULD ACHIEVE met.**

### Key Metrics to Track

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Total Active Testers | 50-100 | TestFlight dashboard |
| Weekly Active Rate | 70%+ | TestFlight analytics |
| Premium Conversion Rate | 10-15% | Mixpanel (simulated paywall) |
| Onboarding Completion | 90%+ | Mixpanel (tutorial finished) |
| Time to First Recipe | < 5 min (80% users) | Mixpanel (timestamp tracking) |
| Testimonials Collected | 10+ | Email/form submissions |
| App Store Reviews | 15+ (4.5+ avg) | TestFlight reviews |
| Video Testimonials | 2+ | Video submissions |

### Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Low tester response rate (< 30%)** | Miss user targets | Medium | Personalize invites, offer incentives (free premium), follow up 2x |
| **Conversion rate < 8%** | Revenue projections at risk | Low | A/B test pricing ($3.99 vs $4.99), optimize paywall copy, improve onboarding |
| **Negative reviews (< 4.0 stars)** | Damages launch reputation | Low | Address concerns quickly, fix bugs, over-communicate with testers |
| **Analytics not collecting data** | Can't optimize conversion | Low | Test Mixpanel integration thoroughly, fallback to manual surveys |
| **Tester fatigue (churn from Phase 1)** | Lose core cohort | Medium | Keep engaged with updates, show impact of their feedback, gratitude emails |

### Deliverables

- [ ] 50-100 active testers recruited and onboarded
- [ ] Conversion funnel analysis document (drop-off points, optimization recommendations)
- [ ] 10+ testimonials collected (text + 2 video)
- [ ] 15+ App Store reviews (4.5+ stars average)
- [ ] A/B test results report (paywall timing, pricing display)
- [ ] Optimized onboarding flow (ship updates based on data)
- [ ] Go/no-go decision document for soft launch

---

## Phase 3: Soft Launch - App Store Validation
**Timeline:** February 2 - February 15, 2026
**Duration:** 14 days
**Goal:** Accumulate reviews, validate App Store ranking, final polish before PR push

### User Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Total Downloads | 500-1,000 | App Store Connect |
| Daily Active Users | 300-600 (60% retention) | Mixpanel |
| Premium Conversions | 50-120 (10-12%) | App Store Connect (IAP) |
| App Store Reviews | 30+ (4.5+ stars) | App Store Connect |
| First-Week Retention | 70%+ | Mixpanel cohort analysis |

**Download Sources:**
- Friends & family: 100-200 (personal network)
- Phase 1-2 testers: 50-100 (upgrade from TestFlight)
- Waitlist: 200-400 (email blast to interested users)
- Organic App Store: 50-150 (keyword search, browsing)
- Social media: 100-150 (Twitter, LinkedIn, Instagram announcement)

### Primary Objectives

1. **Accumulate Social Proof**
   - 30+ App Store reviews (4.5+ stars) before full launch PR push
   - Reviews mention key features: "styled cards", "iOS Reminders", "cookbook scanner"
   - Respond to all reviews within 24 hours (thank positive, address negative)

2. **Validate App Store Ranking**
   - Reach top 100 in Food & Drink category (free apps)
   - Test keyword rankings: "recipe manager", "cookbook app", "recipe organizer"
   - Optimize ASO based on early search data (adjust keywords, screenshots)

3. **Final Polish**
   - Fix any bugs discovered in production environment
   - Monitor crash analytics daily (Xcode Organizer, App Store Connect)
   - Test payment flow end-to-end (real purchases, refunds, Family Sharing)

4. **Prepare for Full Launch**
   - Finalize press kit (1-pager, screenshots, logo, demo video)
   - Draft press release and pitch emails for TechCrunch, MacStories, 9to5Mac
   - Prepare Product Hunt launch materials (tagline, first comment, supporter list)
   - Set up marketing website (heirloomapp.com live with full content)

### Tactics & Actions

**Week 1 (February 2-8):**
- [ ] Submit app to App Store:
  - Final build from Xcode (Production configuration)
  - App Store Connect: Upload build, complete metadata, submit for review
  - Target: Approval within 24-48 hours (typical for first submission)
- [ ] Soft launch announcement (once approved):
  - Email friends & family: "Heirloom is live! Here's your early access link..."
  - Email waitlist: "You're in! Download Heirloom now before public launch..."
  - Email Phase 1-2 testers: "Thank you for testing! Upgrade to production app + free premium code"
  - Post on Twitter, LinkedIn, Instagram: "Soft launching Heirloom today 🎉 Link in bio"
- [ ] Request reviews:
  - Email all downloaders (Day 3): "Loving Heirloom? Leave a review!" (link to App Store)
  - In-app review prompt: Show after 3 recipes imported + 7 days active (Apple's StoreKit)
  - Incentive: "Your review helps us reach more families"
- [ ] Monitor metrics daily:
  - Downloads per day (target: 50-100/day)
  - Premium conversions (target: 10-12%)
  - Crash-free rate (target: 99%+)
  - Review count & rating (target: 4.5+ stars)

**Week 2 (February 9-15):**
- [ ] Optimize ASO:
  - Check keyword rankings: "recipe manager" (current rank: [?]), "cookbook app" (current rank: [?])
  - A/B test screenshots (App Store Connect feature): Test 2 variants of Hero screenshot
  - Update app description if low conversion (emphasize "no subscription", "iOS Reminders")
- [ ] Fix production bugs:
  - Monitor crash analytics (Xcode Organizer: Crashes section)
  - Prioritize P1 bugs, release hotfix (v1.1.1) if critical issue found
  - Test payment edge cases: Family Sharing, refunds, restore purchases
- [ ] Prepare full launch materials:
  - **Press kit:** 1-pager (PDF + web page), 10 hi-res screenshots, app icon (1024×1024), demo video (60-90 sec), founder bio & headshot
  - **Press release:** 500-word announcement (headline, lede, quotes, boilerplate, contact info)
  - **Pitch emails:** Personalized outreach to 20 journalists (TechCrunch, MacStories, 9to5Mac, The Verge, Lifehacker)
  - **Product Hunt:** Tagline (60 chars), description (260 chars), gallery (5 images + video), first comment draft, supporter list (ask 20 friends to upvote at 12:01am PT)
- [ ] Finalize marketing website:
  - Domain: heirloomapp.com (purchase + set up DNS)
  - Pages: Home, Features, Pricing, Support, Press
  - Tech stack: Static site (Netlify + Tailwind CSS) for speed
  - Content: Copy from APP_STORE_LISTING.md + MARKETING_WEBSITE.md
  - SEO: Meta tags, sitemap, robots.txt, schema markup
  - Launch deadline: February 14 (ready for Product Hunt launch Feb 16)
- [ ] Go/no-go decision for full launch:
  - Review metrics against success criteria (below)
  - Document recommendation: GO / NO-GO / NEEDS WORK

### Success Criteria (Go/No-Go Gates)

**MUST ACHIEVE (Full Launch Blockers):**
- ✅ 500+ downloads in soft launch period
- ✅ 30+ App Store reviews (4.5+ stars average)
- ✅ 99%+ crash-free rate in production
- ✅ 10%+ premium conversion rate (real purchases)
- ✅ Payment flow works (purchases, Family Sharing, refunds tested)

**SHOULD ACHIEVE (Important but Not Blocking):**
- ☑️ 70%+ first-week retention
- ☑️ Top 100 in Food & Drink category (free apps)
- ☑️ 60%+ downloaders open app on Day 1
- ☑️ Press kit finalized and reviewed by 2 advisors
- ☑️ Marketing website live at heirloomapp.com

**NICE TO HAVE (Post-Full Launch Improvements):**
- ⭕ Top 50 in Food & Drink category
- ⭕ Keyword rankings: "recipe manager" top 20, "cookbook app" top 30
- ⭕ 50+ reviews (exceed target)

**Decision Gate: GO if all MUST ACHIEVE + 3 of 5 SHOULD ACHIEVE met.**

### Key Metrics to Track

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Total Downloads | 500-1,000 | App Store Connect |
| Downloads per Day | 50-100 | App Store Connect |
| Premium Conversions | 50-120 (10-12%) | App Store Connect (IAP) |
| Crash-Free Rate | 99%+ | Xcode Organizer |
| App Store Reviews | 30+ (4.5+ avg) | App Store Connect |
| First-Week Retention | 70%+ | Mixpanel cohort analysis |
| Category Ranking | Top 100 (Food & Drink) | App Store charts |
| Keyword Rankings | Top 50 ("recipe manager") | App Store search |

### Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **App Store rejection** | Delays launch by 3-7 days | Low | Follow guidelines strictly, respond to reviewer notes within 24 hrs |
| **Production bug (crash)** | Negative reviews, reputation damage | Low | Monitor daily, release hotfix within 24 hrs, proactive communication |
| **Low download volume (< 300)** | Insufficient reviews for full launch | Medium | Expand outreach (larger waitlist, more social posts), extend soft launch by 1 week |
| **Poor reviews (< 4.0 stars)** | Damages full launch momentum | Low | Respond immediately, fix issues, ask satisfied users to review |
| **Payment issues** | Revenue loss, frustrated users | Low | Test thoroughly on multiple devices, monitor support email, refund promptly |

### Deliverables

- [ ] App live on App Store (approved and downloadable)
- [ ] 500-1,000 downloads achieved
- [ ] 30+ App Store reviews (4.5+ stars)
- [ ] Press kit finalized (1-pager, screenshots, video, founder bio)
- [ ] Press release drafted and reviewed
- [ ] Product Hunt materials prepared (tagline, gallery, supporters)
- [ ] Marketing website live at heirloomapp.com
- [ ] Go/no-go decision document for full launch

---

## Phase 4: Full Launch - Public Announcement
**Timeline:** February 16 - March 31, 2026
**Duration:** 44 days (6+ weeks)
**Goal:** Maximum visibility, press coverage, download spike, validate product-market fit

### User Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Total Downloads | 5,000-15,000 | App Store Connect |
| Daily Active Users (avg) | 3,000-9,000 (60%) | Mixpanel |
| Premium Conversions | 600-1,800 (10-12%) | App Store Connect |
| Revenue (6 weeks) | $3,000-$9,000 | App Store Connect |
| App Store Reviews | 50+ (4.5+ stars) | App Store Connect |
| Press Mentions | 3-5 major outlets | Google Alerts, manual tracking |

**Download Sources (Projected):**
- Product Hunt: 2,000-5,000 (aim for #1-3 Product of the Day)
- Press coverage: 1,000-3,000 (TechCrunch, MacStories, 9to5Mac)
- Apple Search Ads: 500-1,500 (test budget: $500-1,000/month)
- Organic App Store: 500-2,000 (ASO, word-of-mouth)
- Social media: 500-1,500 (Twitter, Instagram, TikTok, Reddit)
- Influencer partnerships: 500-2,000 (10 food bloggers with 50K+ followers)

### Primary Objectives

1. **Maximize Launch Visibility**
   - Product Hunt: Aim for #1-3 Product of the Day (400+ upvotes)
   - Press coverage: Featured in 3-5 major tech outlets (TechCrunch, MacStories, 9to5Mac, The Verge, Lifehacker)
   - Social media: 10K+ impressions across Twitter, Instagram, TikTok, Reddit
   - App Store featuring: Pitch to Apple for "New Apps We Love" (editorial team)

2. **Validate Product-Market Fit**
   - Conversion rate: Maintain 10-12% (baseline scenario)
   - Retention: 60%+ 30-day retention (users return after 1 month)
   - CAC: Paid channels (Apple Search Ads) < $3.00 per download
   - NPS: Survey 100 users, target NPS 50+ (strong word-of-mouth potential)

3. **Build Community**
   - Discord server: Launch with 100+ members
   - Reddit: Create r/HeirloomApp, post in r/Cooking, r/Old_Recipes (5+ high-engagement posts)
   - Instagram: 500+ followers, 20+ user-generated recipe card posts (branded hashtag #HeirloomRecipes)
   - Email list: Grow to 1,000+ subscribers (exit-intent popup, blog CTAs)

4. **Evaluate Fundraising Decision**
   - By March 31, determine: Bootstrap or raise $150K?
   - Metrics: Downloads, conversion, CAC, retention, revenue, press coverage, community growth
   - Decision framework: See "Phase 4 Decision Framework" below

### Tactics & Actions

**Week 1 (February 16-22): Launch Week**

**Product Hunt Launch (February 16, 12:01am PT):**
- [ ] Submit to Product Hunt: Upload tagline, description, gallery (5 images + video), first comment
- [ ] First comment: Founder story ("Why I built Heirloom..."), invite questions, offer promo code (20% off: $3.99 for first 100 users)
- [ ] Rally supporters: Ask 20 friends to upvote at 12:01am PT (coordinate via Discord/group chat)
- [ ] Engage all day: Respond to every comment within 30 minutes, thank upvoters, answer questions
- [ ] Goal: #1-3 Product of the Day (400+ upvotes, 50+ comments)

**Press Outreach (February 16-20):**
- [ ] Send press release + pitch emails to 20 journalists:
  - **TechCrunch:** App review pitch to app editor (personalized: "Heirloom solves 67% of family recipes lost...")
  - **MacStories:** iOS app spotlight pitch to Federico Viticci (angle: "Deep iOS integration only native apps can achieve")
  - **9to5Mac:** App announcement to app editor (angle: "iOS Reminders integration competitors can't replicate")
  - **The Verge:** Lifestyle tech pitch to consumer tech editor (angle: "Nostalgia meets AI: Digitizing grandma's cookbook")
  - **Lifehacker:** Productivity tip pitch (angle: "How Heirloom saves 2 hours per week on meal planning")
- [ ] Follow up: If no response in 3 days, send friendly follow-up email
- [ ] Offer: Exclusive demo, interview with founder, promo codes for readers
- [ ] Goal: Featured in 3-5 outlets within 2 weeks

**Social Media Blitz (February 16-22):**
- [ ] Twitter: 7-tweet thread on launch day (founder story, problem/solution, demo video, link)
- [ ] LinkedIn: Founder post (professional angle: "Lessons learned building Heirloom")
- [ ] Instagram: 5-post series (carousel: before/after recipe cards, Reels: 30-sec demo, Stories: behind-the-scenes)
- [ ] TikTok: 3 videos (cookbook scanning demo, styled card creation, shopping list export)
- [ ] Reddit: Post in r/iOSApps, r/Cooking, r/Old_Recipes (different angle for each: tech focus vs cooking focus vs nostalgia focus)
- [ ] Engage: Respond to all comments, DMs, mentions within 2 hours

**Apple Search Ads (February 16+):**
- [ ] Set up campaigns:
  - Campaign 1: Brand ("heirloom app") - $100/month
  - Campaign 2: Generic ("recipe manager", "cookbook app") - $400/month
  - Campaign 3: Competitor ("paprika app", "mela app") - $500/month (test)
- [ ] Target CPA: $3.00 per download
- [ ] Monitor daily: Adjust bids, pause low-performing keywords, scale winners
- [ ] Goal: 500-1,500 downloads in 6 weeks

**Week 2-3 (February 23 - March 8): Press Coverage & Influencers**

**Press Coverage Amplification:**
- [ ] If featured in TechCrunch/MacStories/9to5Mac:
  - Tweet about it immediately (quote + link)
  - Post on Instagram, LinkedIn, Reddit
  - Add "As Featured In" section to website homepage
  - Email list announcement: "We made TechCrunch! 🎉"
- [ ] If no press coverage yet:
  - Follow up with journalists (2nd email)
  - Offer new angle: User stories, AI cookbook scanning deep-dive, technical moat explanation
  - Pitch to tier-2 outlets: Cult of Mac, iMore, MacRumors

**Influencer Partnerships (February 23+):**
- [ ] Identify 10 food bloggers/recipe creators (50K+ followers):
  - Instagram: @minimalistbaker, @halfbakedharvest, @thepioneerwoman (tier 1, $5K+ budget)
  - YouTube: Sorted Food, Binging with Babish (tier 1, $10K+ budget - skip for bootstrap)
  - TikTok: @cookingwithshereen, @feeling_foodish (tier 2, $500-1K budget)
  - Micro-influencers: 10-50K followers, $100-500 budget (prioritize if bootstrapping)
- [ ] Outreach email: "We'd love to partner with you on Heirloom launch..."
  - Offer: Free premium for life, commission on sales (20% via affiliate link), flat fee ($100-5K depending on tier)
  - Deliverable: Instagram post + Stories (3-5 Stories), YouTube mention (if applicable), TikTok video
  - Timeline: Post within 2 weeks of agreement
- [ ] Track: Use unique promo codes per influencer (BAKER20, HARVEST20) to measure conversions
- [ ] Goal: 500-2,000 downloads from influencer campaigns

**Week 4-6 (March 9-31): Growth Experiments & Fundraising Decision**

**Growth Experiments:**
- [ ] A/B test pricing:
  - Test $3.99 vs $4.99 vs $5.99 (1 week per variant)
  - Measure: Conversion rate, revenue per user, feedback sentiment
  - Ship winning price permanently
- [ ] Test acquisition channels:
  - Instagram ads: $500 budget, target cookbook collectors, food bloggers
  - TikTok ads: $500 budget, target women 25-45 interested in cooking, nostalgia content
  - Reddit ads: $200 budget, target r/Cooking, r/Old_Recipes
  - Measure: CPA, conversion rate, 30-day retention
  - Scale winning channel, pause losers
- [ ] Content marketing:
  - Launch blog at heirloomapp.com/blog
  - Publish 4 posts: "How to Digitize Your Cookbook Collection", "The Psychology of Recipe Nostalgia", "5 Recipes Worth Passing Down", "How Heirloom Saves 2 Hours Per Week"
  - Promote on social media, Reddit, email list
  - Goal: 1,000+ blog visitors, 50+ email signups

**Community Building:**
- [ ] Launch Discord server:
  - Channels: #introductions, #recipe-sharing, #feature-requests, #support, #beta-testers
  - Invite Phase 1-2 testers, Product Hunt supporters, engaged users
  - Goal: 100+ members, 10+ daily active
- [ ] Reddit: Create r/HeirloomApp
  - Seed with 10 posts (tips, showcases, AMAs)
  - Cross-promote in r/Cooking, r/Old_Recipes
  - Goal: 200+ subscribers
- [ ] Instagram: User-generated content campaign
  - Hashtag: #HeirloomRecipes
  - Prompt: "Share your styled recipe card, tag @heirloomapp, get featured!"
  - Goal: 20+ user posts, 500+ followers

**Fundraising Decision (March 25-31):**
- [ ] Compile metrics (see "Phase 4 Decision Framework" below)
- [ ] Calculate: Are we on track for baseline scenario (100K downloads, 12% conversion by EOY)?
- [ ] Evaluate: Bootstrap (slow growth, 100% equity) vs Raise (fast growth, 90% equity)?
- [ ] Decision: GO with bootstrap, GO with raise, or DEFER (wait 3 months, re-evaluate)

### Success Criteria (Phase 4 Evaluation)

**Baseline Success (Continue Current Strategy):**
- ☑️ 5,000+ downloads (low end of target)
- ☑️ 10%+ conversion rate (500+ premium users)
- ☑️ $2,500+ revenue (Month 1)
- ☑️ $3.00 CAC or lower (paid channels profitable)
- ☑️ 50%+ 30-day retention
- ☑️ 4.5+ star App Store rating (50+ reviews)

**Raise-Worthy Success (Strong Product-Market Fit):**
- ✅ 15,000+ downloads (high end of target)
- ✅ 12%+ conversion rate (1,800+ premium users)
- ✅ $7,500+ revenue (Month 1)
- ✅ $2.50 CAC or lower (paid channels highly profitable)
- ✅ 60%+ 30-day retention
- ✅ 4.7+ star App Store rating (100+ reviews)
- ✅ 5+ press mentions (TechCrunch, MacStories, 9to5Mac, etc.)
- ✅ 5,000+ waitlist/email subscribers

**Below Expectations (Re-Evaluate or Pivot):**
- ❌ < 3,000 downloads
- ❌ < 8% conversion rate
- ❌ < $1,500 revenue (Month 1)
- ❌ > $5.00 CAC (paid channels unprofitable)
- ❌ < 40% 30-day retention
- ❌ < 4.0 star App Store rating

### Phase 4 Decision Framework: Bootstrap vs Raise

**If "Raise-Worthy Success" Achieved:**
- **Recommendation:** Raise $150K at $1.5M valuation (or better terms if strong traction)
- **Rationale:** Proven product-market fit, strong unit economics, scalable channels
- **Use of funds:** Hire team (developer, marketer), scale Apple Search Ads to $5K/month, influencer campaigns, PR agency
- **Expected outcome:** Reach 1M downloads, $500K+ revenue by EOY 2026

**If "Baseline Success" Achieved:**
- **Recommendation:** Bootstrap for 6 months, re-evaluate in Q3 2026
- **Rationale:** Solid traction but not explosive, can scale organically with profits
- **Strategy:** Reinvest revenue into contractors, content marketing, small influencer campaigns
- **Expected outcome:** Reach 200K downloads, $100K revenue by EOY 2026, raise at higher valuation

**If "Below Expectations":**
- **Recommendation:** Pause paid acquisition, focus on product improvements, re-launch in 3 months
- **Rationale:** Product-market fit not yet proven, need to fix conversion/retention issues
- **Strategy:** User interviews to identify friction, optimize onboarding, add must-have features
- **Expected outcome:** Iterate to baseline success, then re-evaluate bootstrap vs raise

### Key Metrics to Track (Daily/Weekly)

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Total Downloads | 5,000-15,000 | App Store Connect |
| Downloads per Day | 100-300 (avg over 6 weeks) | App Store Connect |
| Premium Conversions | 600-1,800 (10-12%) | App Store Connect |
| Revenue (6 weeks) | $3,000-$9,000 | App Store Connect |
| CAC (Paid Channels) | $2.50-$3.00 | Apple Search Ads, ad platforms |
| 30-Day Retention | 60%+ | Mixpanel cohort analysis |
| App Store Rating | 4.5+ stars (50+ reviews) | App Store Connect |
| Press Mentions | 3-5 major outlets | Google Alerts, manual tracking |
| Community Size | 100+ Discord, 200+ Reddit | Discord analytics, Reddit stats |
| Email List Growth | 1,000+ subscribers | Email platform (Customer.io) |
| NPS Score | 50+ | In-app survey (after 14 days active) |

### Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Product Hunt flop (< #10)** | Miss 1,000+ downloads | Medium | Rally more supporters (50+ committed), post at optimal time (Sunday-Tuesday), engage aggressively |
| **Zero press coverage** | Miss 1,000-3,000 downloads | Low | Follow up persistently, offer exclusive angles, pitch tier-2 outlets, leverage Product Hunt traction |
| **High CAC (> $5)** | Unprofitable paid acquisition | Medium | Pause campaigns immediately, optimize targeting, test new channels (Instagram, TikTok) |
| **Low conversion (< 8%)** | Revenue 20-40% below target | Low | A/B test pricing ($3.99), optimize paywall copy, improve onboarding, add urgency (limited-time discount) |
| **Negative press/reviews** | Reputation damage | Low | Monitor mentions 24/7, respond professionally, fix issues immediately, reach out to critics privately |
| **Competitor launches similar feature** | Differentiation weakened | Low | Double down on technical moat (iOS Reminders), accelerate roadmap, emphasize brand story |

### Deliverables

- [ ] Product Hunt launch executed (#1-3 Product of the Day)
- [ ] Press coverage secured (3-5 major outlets)
- [ ] 5,000-15,000 downloads achieved
- [ ] 600-1,800 premium conversions ($3,000-$9,000 revenue)
- [ ] Apple Search Ads campaigns optimized (CAC < $3)
- [ ] 10 influencer partnerships executed (500-2,000 downloads)
- [ ] Community launched (Discord, Reddit, Instagram)
- [ ] Blog published (4 posts, 1,000+ visitors)
- [ ] Fundraising decision document (bootstrap vs raise recommendation)

---

## Phase 5: Growth & Scale - Sustainable Expansion
**Timeline:** April 1 - December 31, 2026
**Duration:** 9 months
**Goal:** Sustainable growth, profitability, community building, feature expansion

### User Targets (EOY 2026)

**Conservative Scenario (Bootstrap Path):**
| Metric | Target | Notes |
|--------|--------|-------|
| Total Downloads | 50,000 | Organic + small paid budget |
| Premium Conversions | 4,000 (8%) | Lower conversion, focus on retention |
| Revenue | $20,000 | Profitable, sustainable |
| Monthly Active Users | 30,000 | 60% of total downloads |

**Baseline Scenario (Bootstrap or Small Raise):**
| Metric | Target | Notes |
|--------|--------|-------|
| Total Downloads | 100,000 | Organic + $2K/month paid |
| Premium Conversions | 12,000 (12%) | Baseline conversion maintained |
| Revenue | $60,000 | Reinvest in contractors, marketing |
| Monthly Active Users | 60,000 | 60% of total downloads |

**Optimistic Scenario (Raised $150K):**
| Metric | Target | Notes |
|--------|--------|-------|
| Total Downloads | 200,000 | Aggressive paid + influencer campaigns |
| Premium Conversions | 30,000 (15%) | Optimized conversion funnel |
| Revenue | $150,000 | Profitable, scale hiring |
| Monthly Active Users | 120,000 | 60% of total downloads |

### Primary Objectives

**Q2 2026 (April-June):**

1. **Optimize Paid Acquisition**
   - Scale Apple Search Ads: $1K → $5K/month (if CAC < $3)
   - Test new channels: Instagram ads ($1K/month), TikTok ads ($1K/month)
   - Measure: CPA, LTV, payback period, 30-day retention by channel
   - Goal: Find 2-3 profitable channels (CAC < $3, 60%+ retention)

2. **Build Content Marketing Engine**
   - Publish 12 blog posts (weekly): Recipe digitization tips, family history preservation, cooking tutorials
   - Launch YouTube channel: 8 videos (biweekly) - App tutorials, cookbook scanning demos, recipe showcases
   - SEO: Rank for "recipe manager app", "cookbook digitizer", "iOS recipe app" (top 10)
   - Goal: 5,000+ monthly blog visitors, 500+ YouTube subscribers, 1,000+ email signups

3. **Expand Influencer Partnerships**
   - Partner with 20 micro-influencers (10K-50K followers) at $100-500 each
   - Launch affiliate program: 20% commission on sales via unique promo codes
   - User-generated content campaign: "Share your heirloom recipe story" (branded hashtag #MyHeirloomStory)
   - Goal: 2,000-5,000 downloads from influencer campaigns, 50+ UGC posts

**Q3 2026 (July-September):**

1. **Feature Expansion (Post-Launch Roadmap)**
   - Semantic search: "Find all pasta recipes with garlic" (AI-powered, Anthropic Claude)
   - Cooking assistant: "What can I make with chicken, tomatoes, basil?" (ingredient-based search)
   - Ingredient substitutions: "Out of butter? Try these alternatives" (AI suggestions)
   - Nutrition data: USDA API integration, automatic nutrition facts per recipe
   - Goal: Increase premium value, drive upgrades from free tier

2. **Launch Sticker Packs (IAP)**
   - Design 3 sticker packs: Seasonal (Fall), Holiday (Christmas), Retro Kitchen
   - Price: $0.99-$1.99 per pack
   - Launch: September (Fall pack), November (Holiday pack)
   - Goal: 30% of premium users buy ≥1 pack = +$5K-$15K revenue

3. **Community Maturity**
   - Discord: Grow to 500+ members, host monthly "Recipe of the Month" contest
   - Reddit: r/HeirloomApp reaches 1,000+ subscribers
   - Instagram: 2,000+ followers, 100+ UGC posts
   - Goal: Self-sustaining community, word-of-mouth growth, brand advocates

**Q4 2026 (October-December):**

1. **Partnership Strategy**
   - Cookbook publishers: Partner with 2-3 publishers (Penguin Random House, Ten Speed Press) for co-marketing
   - Kitchen retailers: Partner with Williams-Sonoma, Sur La Table for in-store promotions
   - Food brands: Partner with King Arthur Baking, Bob's Red Mill for sponsored recipe collections
   - Goal: 5,000-10,000 downloads from partnerships, brand credibility boost

2. **App Store Featuring Push**
   - Pitch to Apple for "App of the Day" or holiday feature (Thanksgiving, Christmas)
   - Angle: "Preserve family recipes this holiday season"
   - Materials: Updated press kit, new features (nutrition, sticker packs), user testimonials
   - Goal: 10K-50K downloads if featured (Apple featuring can drive 5-10x baseline downloads)

3. **Evaluate Year 2 Strategy**
   - Review Year 1 results: Downloads, revenue, conversion, retention, CAC, LTV
   - Plan Year 2 roadmap: New features, hiring, fundraising (if not raised yet), international expansion
   - Decision: Continue bootstrap vs raise seed round ($500K-1M at higher valuation)

### Tactics & Actions (Quarterly Breakdown)

**Q2 2026 (April-June):**

**Month 1 (April):**
- [ ] Scale Apple Search Ads: $1K → $2K/month (monitor CAC daily)
- [ ] Launch blog: Publish 4 posts (weekly), promote on social media, Reddit
- [ ] Influencer outreach: Contact 20 micro-influencers, negotiate terms ($100-500 each)
- [ ] Community engagement: Host Discord AMA, Reddit "Ask Me Anything" in r/Cooking
- [ ] Feature development: Start semantic search implementation (Anthropic Claude API)

**Month 2 (May):**
- [ ] Test Instagram ads: $1K budget, target women 25-45 interested in cooking, nostalgia
- [ ] YouTube channel launch: Publish 4 videos (biweekly) - "How to Digitize Grandma's Cookbook", "Heirloom Tutorial", "Recipe Card Styling Tips", "Shopping List Magic"
- [ ] Influencer campaigns: 10 partnerships executed, track downloads via promo codes
- [ ] SEO: Optimize blog posts for "recipe manager app", "cookbook digitizer" (backlinks, guest posts)
- [ ] Feature development: Complete semantic search, release as beta feature

**Month 3 (June):**
- [ ] Scale profitable channels: If Instagram ads CAC < $3, scale to $2K/month
- [ ] Content marketing: 4 more blog posts, 4 more YouTube videos (total: 8 posts, 8 videos)
- [ ] Influencer expansion: 10 more partnerships, launch affiliate program (20% commission)
- [ ] User-generated content: Launch #MyHeirloomStory campaign, feature 10 best stories on Instagram
- [ ] Feature release: Ship semantic search to all users, promote in App Store update notes

**Q3 2026 (July-September):**

**Month 4 (July):**
- [ ] Feature development: Start cooking assistant ("What can I make with...?") and substitutions
- [ ] Sticker pack design: Commission Fall sticker pack (20 stickers) from illustrator ($500-1K)
- [ ] Community contests: Host "Recipe of the Month" on Discord, winner gets free sticker pack
- [ ] Partnership outreach: Contact 5 cookbook publishers for co-marketing discussions
- [ ] Content marketing: 4 blog posts, 4 YouTube videos (focus: new features, user stories)

**Month 5 (August):**
- [ ] Feature development: Complete cooking assistant and substitutions, release as beta
- [ ] Sticker pack prep: Upload Fall pack to App Store Connect, set price ($1.99), prepare marketing
- [ ] Partnership negotiations: Finalize 1-2 cookbook publisher partnerships (terms: co-branded content, newsletter mentions, social media posts)
- [ ] Content marketing: 4 blog posts, 4 YouTube videos (SEO focus: rank for "best recipe app")

**Month 6 (September):**
- [ ] Feature release: Ship cooking assistant and substitutions to all users
- [ ] Sticker pack launch: Release Fall pack ($1.99), promote in app, blog, social media, email list
- [ ] Partnership execution: Publish co-branded content with cookbook publishers, cross-promote
- [ ] Community milestone: Discord 500+ members, Reddit 1,000+ subscribers, Instagram 2,000+ followers
- [ ] Evaluation: Review Q2-Q3 results, plan Q4 strategy

**Q4 2026 (October-December):**

**Month 7 (October):**
- [ ] Partnership expansion: Contact kitchen retailers (Williams-Sonoma, Sur La Table) for holiday promotions
- [ ] Sticker pack design: Commission Holiday sticker pack (20 stickers) for Christmas ($500-1K)
- [ ] App Store featuring: Pitch to Apple for Thanksgiving/Christmas feature (deadline: early October)
- [ ] Content marketing: 4 blog posts (Thanksgiving recipes, holiday meal planning), 4 YouTube videos

**Month 8 (November):**
- [ ] Sticker pack launch: Release Holiday pack ($1.99), promote heavily (email, social, blog)
- [ ] Partnership execution: Williams-Sonoma in-store promotion (QR codes, flyers), Sur La Table newsletter mention
- [ ] Black Friday promo: Limited-time 30% off premium ($3.49 instead of $4.99) for 4 days
- [ ] Community: Host Thanksgiving recipe exchange on Discord, feature 20+ user recipes on Instagram

**Month 9 (December):**
- [ ] App Store featuring: If featured, scale marketing (Apple Search Ads $10K/month, influencers $5K)
- [ ] Holiday push: Email campaigns, social media (focus: "Preserve family recipes this holiday season")
- [ ] Year-end review: Compile 2026 results (downloads, revenue, conversion, retention, CAC, LTV)
- [ ] Year 2 planning: Draft 2027 roadmap, evaluate fundraising (seed round $500K-1M if strong traction)

### Success Criteria (EOY 2026 Evaluation)

**Baseline Success (Sustainable Business):**
- ☑️ 100,000+ total downloads
- ☑️ 12,000+ premium users (12% conversion)
- ☑️ $60,000+ revenue
- ☑️ Break-even or profitable (revenue > costs)
- ☑️ 60%+ 30-day retention
- ☑️ CAC < $3 (paid channels profitable)

**Strong Success (Scale-Ready Business):**
- ✅ 200,000+ total downloads
- ✅ 30,000+ premium users (15% conversion)
- ✅ $150,000+ revenue
- ✅ Profitable with reinvestment buffer ($50K+ net profit)
- ✅ 70%+ 30-day retention
- ✅ CAC < $2.50 (highly profitable paid acquisition)
- ✅ Community: 500+ Discord, 1,000+ Reddit, 2,000+ Instagram
- ✅ NPS 60+ (world-class word-of-mouth)

**Year 2 Strategy Based on EOY 2026 Results:**

**If Baseline Success:**
- Continue bootstrap with revenue reinvestment
- Hire first contractor: Part-time developer (10-20 hrs/week, $4K-8K/month)
- Focus on profitability, organic growth, community building
- Re-evaluate fundraising in Q2 2027 if revenue > $100K

**If Strong Success:**
- Raise seed round: $500K-1M at $5M-10M valuation (10-20% dilution)
- Hire full-time team: iOS developer, designer, growth marketer
- Scale aggressively: Apple Search Ads $10K/month, influencer campaigns $5K/month
- Target: 1M downloads, $500K revenue by EOY 2027

### Key Metrics to Track (Monthly)

| Metric | Q2 Target | Q3 Target | Q4 Target | EOY 2026 |
|--------|-----------|-----------|-----------|----------|
| Total Downloads | 25K-50K | 50K-100K | 75K-150K | 100K-200K |
| Premium Users | 3K-6K | 6K-12K | 9K-18K | 12K-30K |
| Revenue | $15K-$30K | $30K-$60K | $45K-$90K | $60K-$150K |
| Monthly Active Users | 15K-30K | 30K-60K | 45K-90K | 60K-120K |
| CAC (Paid) | $2.50-$3.00 | $2.50-$3.00 | $2.00-$2.50 | $2.00-$2.50 |
| 30-Day Retention | 60%+ | 60%+ | 65%+ | 65%+ |
| NPS Score | 50+ | 50+ | 55+ | 55-60+ |
| Community Size | 200 Discord, 400 Reddit | 350 Discord, 700 Reddit | 500 Discord, 1K Reddit | 500+ Discord, 1K+ Reddit |

### Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Growth stalls (< 50K downloads EOY)** | Miss revenue targets, can't hire | Medium | Double down on profitable channels, launch referral program (unlock sticker pack for 3 referrals), PR push |
| **High churn (< 50% retention)** | LTV declines, unprofitable | Low | User interviews to identify friction, push notifications (re-engage inactive users), new features (cooking assistant) |
| **Competitor launches styled sharing** | Differentiation weakened | Low | Patent application, double down on community, accelerate feature roadmap (AI features, nutrition) |
| **AI API costs increase 2x** | Profitability threatened | Low | Negotiate with Anthropic (volume discount), implement caching, fallback to on-device Vision API |
| **Burn out (solo founder)** | Development slows, momentum lost | Medium | Hire contractor ASAP (Month 3-4), set work boundaries, automate support (Help Scout macros, FAQ) |

### Deliverables (EOY 2026)

- [ ] 100K-200K total downloads achieved
- [ ] 12K-30K premium users ($60K-$150K revenue)
- [ ] Paid acquisition optimized (CAC < $2.50, 2-3 profitable channels)
- [ ] Content marketing engine running (48 blog posts, 24 YouTube videos, 5K+ monthly visitors)
- [ ] 50+ influencer partnerships executed (affiliate program with 20% commission)
- [ ] 3 sticker packs released ($5K-$15K IAP revenue)
- [ ] Advanced features shipped (semantic search, cooking assistant, substitutions, nutrition data)
- [ ] Community matured (500+ Discord, 1K+ Reddit, 2K+ Instagram)
- [ ] 2-3 brand partnerships (cookbook publishers, kitchen retailers)
- [ ] Year 2 roadmap and fundraising decision (bootstrap vs seed round)

---

## Appendices

### Appendix A: Beta Testing Resources

**Existing Documents (Reference):**
- `BETA_TESTING_PLAN.md` - Detailed 4-week beta plan (current Phase 1 source)
- `heirloom-v1.1.0-beta-plan.md` - Current v1.1.0 beta focus (AI features)
- `TESTFLIGHT_TESTING_GUIDE.md` - Tester instructions and scenarios
- `TESTFLIGHT_MANUAL_TESTING_CHECKLIST.md` - P1/P2/P3 test scenarios

**TestFlight Link:** testflight.apple.com/join/gs6EU81Z

### Appendix B: Contact Information

**Support Email:** beta@heirloomapp.com (Help Scout)
**Feedback Form:** [Google Form URL - to be created]
**Discord Server:** [Invite link - to be created in Phase 2]
**Press Contact:** press@heirloomapp.com (forwards to founder)

### Appendix C: Decision Templates

**Phase Go/No-Go Template:**
```
Phase: [1-5]
Date: [YYYY-MM-DD]
Evaluator: [Name]

MUST ACHIEVE Criteria:
- [ ] Criterion 1: [Met / Not Met] - [Evidence]
- [ ] Criterion 2: [Met / Not Met] - [Evidence]
...

SHOULD ACHIEVE Criteria:
- [ ] Criterion 1: [Met / Not Met] - [Evidence]
- [ ] Criterion 2: [Met / Not Met] - [Evidence]
...

SUMMARY:
- MUST ACHIEVE: [X/Y] met
- SHOULD ACHIEVE: [X/Y] met

RECOMMENDATION: [GO / NO-GO / NEEDS WORK]
RATIONALE: [1-2 sentences]

NEXT ACTIONS:
- [ ] Action 1
- [ ] Action 2
...
```

**Fundraising Decision Template (March 31, 2026):**
```
METRICS (Phase 4 Results):
- Total Downloads: [#]
- Premium Conversions: [#] ([%])
- Revenue (Month 1): $[#]
- CAC (Paid): $[#]
- 30-Day Retention: [%]
- App Store Rating: [#] stars ([#] reviews)
- Press Mentions: [#] ([list outlets])
- Community Size: [#] Discord, [#] Reddit, [#] Instagram
- NPS Score: [#]

EVALUATION:
- [ ] Meets "Raise-Worthy Success" (all criteria)
- [ ] Meets "Baseline Success" (most criteria)
- [ ] Below Expectations (< 3K downloads or < 8% conversion)

RECOMMENDATION: [Bootstrap / Raise $150K / Defer]

RATIONALE:
[2-3 paragraphs explaining decision based on metrics, market conditions, personal goals]

NEXT ACTIONS:
- [ ] If Bootstrap: [specific actions]
- [ ] If Raise: [specific actions - pitch deck update, investor outreach, etc.]
- [ ] If Defer: [specific actions - product improvements, re-launch plan]
```

### Appendix D: Metrics Dashboard (Google Sheets Template)

**Tab 1: Weekly Metrics**
| Week | Downloads | Premium | Revenue | CAC | Retention | Rating |
|------|-----------|---------|---------|-----|-----------|--------|
| Week 1 (Feb 16-22) | [#] | [#] | $[#] | $[#] | [%] | [#] stars |
| Week 2 (Feb 23-29) | [#] | [#] | $[#] | $[#] | [%] | [#] stars |
...

**Tab 2: Channel Performance**
| Channel | Spend | Downloads | CPA | Conv Rate | Revenue | ROI |
|---------|-------|-----------|-----|-----------|---------|-----|
| Apple Search Ads | $[#] | [#] | $[#] | [%] | $[#] | [#]x |
| Product Hunt | $0 | [#] | $0 | [%] | $[#] | ∞ |
| TechCrunch | $0 | [#] | $0 | [%] | $[#] | ∞ |
| Influencer (X) | $[#] | [#] | $[#] | [%] | $[#] | [#]x |
...

**Tab 3: Cohort Retention**
| Cohort | Day 1 | Day 7 | Day 14 | Day 30 | Day 60 | Day 90 |
|--------|-------|-------|--------|--------|--------|--------|
| Feb 16-22 | [%] | [%] | [%] | [%] | [%] | [%] |
| Feb 23-29 | [%] | [%] | [%] | [%] | [%] | [%] |
...

---

**Document End**

**Next Review:** January 15, 2026 (Phase 1 completion)
**Owner:** Matt Hanson
**Status:** Living document, update weekly during Phases 1-4, monthly during Phase 5
