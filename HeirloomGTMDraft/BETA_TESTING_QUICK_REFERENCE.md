# Beta Testing Quick Reference
**Print this out or keep it open during beta for quick weekly execution.**

---

## Weekly Ritual (Every Phase)

### Monday Morning (30 min)
- [ ] Upload new build to TestFlight with "What's New" notes
- [ ] Send weekly survey via email
- [ ] Post update in beta Slack/Discord (if using)
- [ ] Review last week's analytics dashboard

### Tuesday-Friday (1 hr/day)
- [ ] Check beta@heirloom.app for bug reports
- [ ] Triage bugs (P0/P1/P2/P3)
- [ ] Fix P0 bugs immediately
- [ ] Respond to tester feedback within 24h
- [ ] Track bugs in Linear/Notion

### Saturday (2 hrs)
- [ ] Analyze survey results (export to spreadsheet)
- [ ] Identify top 3 issues to fix
- [ ] Update analytics dashboard
- [ ] Plan next week's build

### Sunday (1 hr)
- [ ] Write next week's "What's New" notes
- [ ] Prepare next week's survey
- [ ] Review testing goals for upcoming week

---

## Phase 1: Closed Beta (Weeks 1-4)

### Week 1: Recipe Adding Basics
**Goal:** Validate core functionality works

**TestFlight "What's New" Focus:**
- Welcome message
- Task: Add 10 recipes from different sources
- Known issues list

**Survey Questions:**
- How many recipes added?
- Any crashes?
- Which sites worked/failed?
- First impression (1-5 scale)

**Success Metrics:**
- [ ] 20+ testers install app
- [ ] 80%+ add at least 5 recipes
- [ ] <10% crash rate
- [ ] Identify P0/P1 bugs

**Don't Forget:**
- Send welcome email with instructions
- Set up beta@heirloom.app forwarding
- Create Week 1 survey in Typeform

---

### Week 2: Collections & Organization
**Goal:** Test organization features

**TestFlight "What's New" Focus:**
- Bug fixes from Week 1
- New features (tags, collections)
- Task: Create 3 collections, tag recipes

**Survey Questions:**
- Did you create collections?
- Are collections useful?
- Did you try search?
- What's most frustrating?

**Success Metrics:**
- [ ] 70%+ create at least 1 collection
- [ ] <5% crash rate
- [ ] Fixed all P0 bugs from Week 1

**Don't Forget:**
- Thank testers for Week 1 feedback
- Share progress stats (e.g., "234 recipes tested!")

---

### Week 3: Sharing & Collaboration
**Goal:** Test social features

**TestFlight "What's New" Focus:**
- Sharing features (Messages, Email, public links)
- Task: Share recipe with a friend, get feedback

**Survey Questions:**
- Did sharing work?
- Did your friend receive it OK?
- Would you share recipes regularly?
- What would make sharing better?

**Success Metrics:**
- [ ] 50%+ test sharing feature
- [ ] <5% crash rate
- [ ] Sharing links work cross-platform

**Don't Forget:**
- Ask testers to share with non-beta users
- Collect feedback from recipients too

---

### Week 4: Premium Features Preview
**Goal:** Test premium tier, gauge willingness to pay

**TestFlight "What's New" Focus:**
- Premium features (free for beta)
- Unlimited recipes, AI meal planning, scaling
- Task: Try premium features, give pricing feedback

**Survey Questions:**
- Would you pay $4.99/month?
- Would you pay $39.99/year?
- Which premium features are most valuable?
- What's missing from premium?

**Success Metrics:**
- [ ] 60%+ try premium features
- [ ] <2% crash rate
- [ ] 50%+ say "probably yes" to paying
- [ ] All P1 bugs fixed

**Don't Forget:**
- Final Phase 1 survey (15 min, important!)
- Invite testers to continue into Phase 2
- Send thank-you email with stats

---

## Phase 2: Expanded Beta (Weeks 5-6)

### Week 5: Onboarding & First Impressions
**Goal:** Test with fresh eyes, validate onboarding

**TestFlight "What's New" Focus:**
- New onboarding flow
- Task: Complete onboarding (delete/reinstall if continuing tester)
- Focus on first 3 days experience

**Survey Questions (Day 3):**
- Would you keep this app? (Yes/No)
- How easy was onboarding? (1-5)
- What was most confusing?
- Compared to other apps? (Better/Same/Worse)

**Success Metrics:**
- [ ] 50+ new testers onboard
- [ ] 70%+ complete onboarding
- [ ] 60%+ Day 3 retention
- [ ] <2% crash rate

**Don't Forget:**
- Send different welcome emails for new vs. continuing testers
- Segment testers (power/casual/technical)
- Set up analytics dashboard (Firebase/Mixpanel)

---

### Week 6: Polish & Edge Cases
**Goal:** Find weird bugs, test on edge cases

**TestFlight "What's New" Focus:**
- Bug fixes and polish
- Task: Try unusual scenarios, test on iPad

**Survey Questions:**
- Did you find any edge cases?
- iPad experience (if tested)?
- Is anything still confusing?
- Ready for launch? (Yes/No)

**Success Metrics:**
- [ ] <1% crash rate
- [ ] 40%+ Day 7 retention
- [ ] All P0/P1 bugs fixed
- [ ] 4.5+ internal rating

**Don't Forget:**
- Thank testers, Phase 2 wrap-up email
- Prep for App Store submission
- Finalize App Store listing copy

---

## Phase 3: Soft Launch (Weeks 7-8)

### Week 7: App Store Launch
**Goal:** Real-world validation, conversion testing

**TestFlight "What's New" Focus:**
- We're live! Download from App Store
- Thank beta testers
- Ask for App Store reviews

**Monitoring:**
- [ ] Daily analytics review
- [ ] Monitor App Store reviews (respond within 24h)
- [ ] Track conversion funnel
- [ ] Watch crash-free rate

**Success Metrics:**
- [ ] 500-1K downloads
- [ ] 40%+ Day 1 retention
- [ ] 8%+ free-to-premium conversion
- [ ] 4.0+ App Store rating

**Don't Forget:**
- Launch on Product Hunt (Week 2 plan)
- Monitor social media mentions
- Respond to support requests quickly

---

### Week 8: Iteration & Growth
**Goal:** Quick iteration based on soft launch data

**Focus:**
- Fix critical issues from reviews
- Optimize conversion funnel
- Prep for full launch

**Monitoring:**
- [ ] Cohort analysis (which users convert?)
- [ ] Drop-off points in onboarding
- [ ] Support ticket themes
- [ ] Competitor app updates

**Success Metrics:**
- [ ] <1% crash rate
- [ ] Improved Day 7 retention from Week 7
- [ ] Growing organic downloads
- [ ] Ready for full launch

---

## Emergency Protocols

### P0 Bug Discovered (Critical)
**Within 1 hour:**
1. Reproduce bug
2. Fix if possible
3. Upload emergency build to TestFlight
4. Send email to all testers: "Critical update available"
5. Update "What's New" with apology + fix

**Example:**
```
🚨 URGENT UPDATE

We found a bug causing data loss.
Update immediately.

✅ Fixed: [bug description]
⚠️ If affected: Email beta@heirloom.app

Sorry! This is why we beta test.
```

---

### Tester Feedback Drops Off
**Signs:**
- <40% survey completion
- No TestFlight feedback in 3+ days
- No email reports

**Response:**
1. Send re-engagement email
2. Reduce survey frequency
3. Offer alternatives (Zoom call, quick shake feedback)
4. Remind them of their reward (lifetime premium)

**Example Email:**
```
Subject: Too many surveys? 😅

Hey [Name],

Noticed you've been quiet. Surveys too much?

No pressure! Alternative ways to help:
• Shake device for quick feedback (10 sec)
• Email anytime
• Skip surveys

We're grateful you're here!
```

---

### Negative Feedback Spike
**Signs:**
- Multiple testers report same issue
- "Most frustrating" survey answers align

**Response:**
1. Acknowledge the issue publicly (email to all)
2. Explain what you're doing about it
3. Set expectations (timeline to fix)
4. Follow up when fixed

**Example Email:**
```
Subject: We hear you on [issue]

Hey everyone,

We've heard from 8 of you that [issue] is frustrating.

We agree—it's annoying! Here's what we're doing:
• [Fix description]
• [Timeline]
• Next build: Monday

Thanks for the honest feedback. Keep it coming!
```

---

## Quick Copy/Paste Responses

### Tester Reports Bug
```
Thanks for reporting this! 🐛

I've added it to our bug tracker:
Priority: [P0/P1/P2/P3]
Status: [Investigating/Fixing/Fixed in next build]

Expected fix: [Timeline]

Really appreciate you finding this!
```

---

### Tester Suggests Feature
```
Great idea! 💡

We've heard similar requests from [X] other testers.

For now, we're focused on [current priority], but I've added this to our backlog for post-launch.

Keep the ideas coming!
```

---

### Tester Loves Something
```
So glad you love [feature]! ❤️

This is exactly why we built Heirloom.

Mind sharing more about how you use it? Helps us understand what's working.

[Optional: Ask permission to use as testimonial]
```

---

### Tester Asks About Launch Date
```
Great question!

Timeline:
• Phase 1 (Closed Beta): [Dates]
• Phase 2 (Expanded Beta): [Dates]
• Phase 3 (Soft Launch): [Dates]
• Full Launch: [Date range]

We're on track! You'll be the first to know.
```

---

## Tools Checklist

### Before Phase 1 Starts
- [ ] TestFlight set up with first build
- [ ] beta@heirloom.app email configured
- [ ] Typeform account for surveys
- [ ] Bug tracking system (Linear/Notion)
- [ ] Analytics dashboard (Firebase/Mixpanel)
- [ ] Welcome email drafted
- [ ] Week 1 survey created

### Optional but Helpful
- [ ] Slack/Discord for beta community
- [ ] Calendly for office hours
- [ ] Loom for video responses
- [ ] Spreadsheet for bug tracking

---

## Red Flags to Watch For

🚩 **High churn** (>50% don't return after Day 1)
→ Onboarding is broken or value prop unclear

🚩 **Low usage** (testers add <5 recipes)
→ App isn't sticky or valuable enough

🚩 **Survey fatigue** (<50% completion)
→ Too many surveys or questions

🚩 **No feature usage** (e.g., nobody uses collections)
→ Feature not valuable or too hidden

🚩 **Consistent crash reports** (>5% crash rate)
→ Critical stability issues

🚩 **"Wouldn't pay" feedback** (>60% say no to premium)
→ Value prop or pricing needs work

---

## Success Indicators

✅ **High engagement** (70%+ return Day 7)
✅ **Feature adoption** (50%+ use new features)
✅ **Positive sentiment** ("love it" > "hate it")
✅ **Low crashes** (<2% crash rate)
✅ **Strong surveys** (60%+ completion)
✅ **Organic referrals** (testers tell friends)

---

## Final Checklist Before Launch

- [ ] <1% crash rate for 2+ weeks
- [ ] All P0 and P1 bugs fixed
- [ ] Onboarding tested with 20+ fresh users
- [ ] 4.5+ internal rating average
- [ ] App Store listing finalized
- [ ] Support email ready (support@heirloom.app)
- [ ] Privacy policy and terms live
- [ ] Pricing confirmed
- [ ] Marketing assets ready
- [ ] Press list prepared
- [ ] Product Hunt launch scheduled

---

**You've got this! 🚀**

Questions? Reference:
- `TESTFLIGHT_STRATEGY.md` for strategic context
- `TESTFLIGHT_INSTRUCTIONS_LIBRARY.md` for copy/paste templates
