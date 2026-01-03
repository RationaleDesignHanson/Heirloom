# Heirloom TestFlight & Beta Testing Strategy

## Executive Summary

This document outlines a comprehensive testing strategy for Heirloom's beta phases, including phase-specific instructions, feedback frameworks, and tester segmentation. The goal is to get the **right feedback at the right time** by guiding testers through structured tasks while allowing organic discovery.

**Key Principles:**
1. **Clarity over quantity** - Specific prompts yield actionable feedback
2. **Progressive disclosure** - Test foundational features before advanced ones
3. **Contextual feedback** - Capture insights at the moment of experience
4. **Tester motivation** - Make testers feel valued and heard
5. **Data + stories** - Combine metrics with qualitative insights

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Phase Breakdown](#phase-breakdown)
3. [TestFlight Mechanics](#testflight-mechanics)
4. [Instruction Templates](#instruction-templates)
5. [Feedback Collection Methods](#feedback-collection-methods)
6. [Tester Segmentation](#tester-segmentation)
7. [Analysis Framework](#analysis-framework)

---

## Testing Philosophy

### What Makes Good Beta Testing?

**Bad Beta Testing:**
- "Try the app and let me know what you think" ❌
- No structure, vague feedback
- Testers don't know what to focus on
- Developer gets opinions, not insights

**Good Beta Testing:**
- Clear goals for each testing phase ✅
- Specific tasks to guide exploration
- Contextual prompts at key moments
- Mix of quantitative + qualitative data

### The Feedback Maturity Model

```
Phase 1: Closed Beta → "Does it work?"
   Focus: Crashes, bugs, core functionality

Phase 2: Expanded Beta → "Can people use it?"
   Focus: Usability, edge cases, feature completeness

Phase 3: Soft Launch → "Will they pay for it?"
   Focus: Value perception, conversion, retention
```

---

## Phase Breakdown

### Phase 1: Closed Beta (20-30 Testers)
**Duration:** Now - Jan 15 (4 weeks)
**Goal:** Validate core functionality and catch critical bugs

#### Testing Objectives
1. **Functionality:** Core features work as intended
2. **Stability:** No crashes or data loss
3. **Usability:** Can users complete primary tasks?
4. **Performance:** Acceptable speed and responsiveness

#### What We Need to Learn
- [ ] Can users successfully add a recipe from URL?
- [ ] Can users manually create a recipe?
- [ ] Can users find and search recipes easily?
- [ ] Does AI extraction work accurately?
- [ ] Are there any crash scenarios?
- [ ] Is the app intuitive without instructions?

#### What We DON'T Need Yet
- ❌ Feature requests ("I wish it had...")
- ❌ Design opinions ("I prefer blue instead of...")
- ❌ Edge cases for features not built yet

#### Tester Profile
- **Who:** Close contacts, iOS-savvy, cooking enthusiasts
- **Why:** Forgiving of bugs, willing to give detailed feedback
- **How many:** 20-30 testers
- **Commitment:** 2-3 hours/week for 4 weeks

---

### Phase 2: Expanded Beta (50-100 Testers)
**Duration:** Jan 16 - Feb 1 (2 weeks)
**Goal:** Polish the experience and test edge cases

#### Testing Objectives
1. **Feature completeness:** All promised features work
2. **Edge cases:** Test unusual scenarios and inputs
3. **Onboarding:** New users can get started without help
4. **Performance:** Works on older devices (iPhone 12+)

#### What We Need to Learn
- [ ] Do new users understand the value proposition?
- [ ] Can users complete onboarding without confusion?
- [ ] What features are most/least used?
- [ ] Where do users get stuck?
- [ ] What causes churn (app deletion)?
- [ ] Does premium tier feel valuable?

#### What We DON'T Need Yet
- ❌ Marketing feedback
- ❌ Competitive comparisons
- ❌ Pricing opinions (testing conversion, not price point)

#### Tester Profile
- **Who:** Mix of Phase 1 + new recruits from network
- **Why:** Fresh eyes + experienced testers for comparison
- **How many:** 50-100 testers (including Phase 1 holdovers)
- **Commitment:** 1-2 hours/week for 2 weeks

---

### Phase 3: Soft Launch (Real Users)
**Duration:** Feb 2-15 (2 weeks)
**Goal:** Validate product-market fit and conversion

#### Testing Objectives
1. **Acquisition:** Can we attract organic users?
2. **Activation:** Do users complete key actions?
3. **Conversion:** Do users upgrade to premium?
4. **Retention:** Do users return after Day 1, Day 7?

#### What We Need to Learn
- [ ] What's the free-to-premium conversion rate?
- [ ] Where do users drop off in onboarding?
- [ ] What features drive premium upgrades?
- [ ] What are common objections to upgrading?
- [ ] How does App Store listing convert?
- [ ] What support questions come up?

#### What We DON'T Need Yet
- ❌ Long-term retention data (not enough time)
- ❌ Revenue optimization (focus on validation first)

#### Tester Profile
- **Who:** Cold users from Product Hunt, Reddit, social
- **Why:** Unbiased, real-world usage patterns
- **How many:** 500-1K downloads target
- **Commitment:** None (organic usage)

---

## TestFlight Mechanics

### How TestFlight Works

**Build Distribution:**
1. Upload build to App Store Connect
2. Add to TestFlight with "What's New" notes
3. Testers get push notification
4. Testers download and install update

**Feedback Mechanisms:**
1. **In-app screenshot feedback** - Shake device → annotate screenshot
2. **TestFlight feedback form** - After uninstall or manual submission
3. **Crash logs** - Automatically collected
4. **External tools** - Surveys, analytics, interviews

### Leveraging "What's New" Notes

This is your PRIMARY instruction mechanism. Every build should have:
1. **What's new in this build** (bug fixes, features)
2. **What to focus on** (specific testing goals)
3. **How to give feedback** (link to form or instructions)

**Example:**
```
Build 1.0.12 (Phase 1, Week 2)

NEW IN THIS BUILD:
✅ Fixed crash when adding recipes with video
✅ Improved AI extraction accuracy
✅ Added recipe sharing to Messages

WHAT TO TEST:
🎯 Try adding 5 recipes from different websites
🎯 Test the new sharing feature with a friend
🎯 Look for any crashes or weird behavior

FEEDBACK:
📝 Use in-app feedback (shake device)
💬 Weekly survey: [link]
🐛 Found a bug? Email: beta@heirloom.app
```

---

## Instruction Templates

### Template 1: Welcome Email (Phase 1 - Day 0)

**Subject:** Welcome to Heirloom Beta! Here's what to expect 🏛️

**Body:**
```
Hi [Name],

Thanks for joining the Heirloom beta! You're one of 25 people helping shape the future of recipe management.

WHAT IS HEIRLOOM?
Heirloom turns any recipe from the web into a clean, organized collection. No more ads, no more clutter—just your recipes, beautifully preserved.

YOUR ROLE AS A BETA TESTER:
For the next 4 weeks, we need your help testing core features and catching bugs. This is NOT the final product—expect rough edges!

WEEK 1 FOCUS: RECIPE ADDING
This week, we want to see if our AI can extract recipes from your favorite sites.

YOUR HOMEWORK:
□ Download Heirloom from TestFlight: [link]
□ Add 10 recipes from different websites
□ Note any sites that don't work well
□ Fill out this quick survey: [link] (5 min)

HOW TO GIVE FEEDBACK:
• Shake your device to send annotated screenshots
• Email beta@heirloom.app anytime
• Weekly 15-min Zoom check-ins (optional)

WHAT WE'RE LOOKING FOR:
✅ Bugs and crashes
✅ Confusing UI or unclear features
✅ Sites where AI extraction fails
❌ NOT looking for feature requests yet

THANK YOU:
As a thank you, you'll get:
• Lifetime premium access (worth $39.99/year)
• Early access to all new features
• Your name in the credits (if you want!)

Questions? Reply to this email.

Let's build something great together!
Matt
Founder, Heirloom
```

---

### Template 2: TestFlight "What's New" (Phase 1 - Build 1)

```
Build 1.0.1 — Closed Beta Week 1

🆕 WHAT'S NEW:
• Initial beta release
• Recipe extraction from URLs
• Manual recipe creation
• Basic search and collections

🎯 THIS WEEK'S MISSION:
Add 10 recipes and tell us what breaks!

SPECIFIC TASKS:
1. Add a recipe from AllRecipes.com
2. Add a recipe from NYT Cooking
3. Add a recipe from a food blog
4. Create a manual recipe from a cookbook
5. Try searching for ingredients

📝 FEEDBACK:
• Shake device → Screenshot + comment
• Survey: [bit.ly/heirloom-week1]
• Bugs: beta@heirloom.app

🐛 KNOWN ISSUES:
• Videos don't import (working on it)
• Search is basic (will improve)
• No sharing yet (coming Week 2)

Thanks for testing! 🙏
```

---

### Template 3: Weekly Check-In Survey (Phase 1 - Week 1)

**Survey Questions:**

**Section 1: Usage**
1. How many times did you open Heirloom this week?
   - [ ] 0-1 times
   - [ ] 2-5 times
   - [ ] 6-10 times
   - [ ] 11+ times

2. How many recipes did you add?
   - [ ] 0-2
   - [ ] 3-5
   - [ ] 6-10
   - [ ] 11+

**Section 2: Functionality**
3. Did you experience any crashes? (Yes/No)
   - If yes, please describe when it happened: [text]

4. Which websites worked well for recipe extraction?
   - [text]

5. Which websites failed or had errors?
   - [text]

**Section 3: Usability**
6. On a scale of 1-5, how intuitive was adding your first recipe?
   - 1 (Very confusing) → 5 (Super easy)

7. What was the most confusing part of the app?
   - [text]

**Section 4: Value**
8. Can you see yourself using Heirloom after beta?
   - [ ] Definitely yes
   - [ ] Probably yes
   - [ ] Not sure
   - [ ] Probably not
   - [ ] Definitely not

9. What would make you more likely to use Heirloom long-term?
   - [text]

**Section 5: Open Feedback**
10. Anything else we should know?
    - [text]

---

### Template 4: Phase 2 Expanded Beta Welcome

**Subject:** You're in! Heirloom Expanded Beta starts now

**Body:**
```
Hi [Name],

Welcome to Heirloom's Expanded Beta! You're joining 75 other testers for the final push before launch.

WHAT'S DIFFERENT IN PHASE 2:
✅ All core features are built
✅ We're polishing, not building
✅ Your feedback shapes the launch version

YOUR MISSION:
We need you to stress-test Heirloom like a real user. Add recipes, organize collections, and try to break things.

WEEK 1 TASKS:
□ Complete onboarding flow
□ Add 20+ recipes from various sources
□ Create 3 collections
□ Try the search feature
□ Test recipe sharing
□ Fill out Day 3 survey: [link]

WHAT TO FOCUS ON:
• Does onboarding make sense?
• Can you find your recipes easily?
• Is anything slow or laggy?
• What feels unfinished?

FEEDBACK CHANNELS:
• Shake to screenshot (easiest!)
• Email: beta@heirloom.app
• Weekly survey (every Monday)

YOUR REWARD:
• Lifetime premium access
• First to see new features
• Help shape the final product

Let's make this app amazing!
Matt
```

---

### Template 5: In-App Prompts (Contextual)

**Trigger: After adding first recipe**
```
🎉 Nice! You added your first recipe.

Quick question: Was that easy, or confusing?

[😃 Super easy] [😐 A bit confusing] [😩 Very confusing]

(Optional) Tell us more: [text box]
[Skip]
```

**Trigger: After 10 recipes added**
```
🔥 You're on a roll! 10 recipes saved.

What do you think of Heirloom so far?

[❤️ Love it] [👍 Like it] [😐 It's okay] [👎 Don't like it]

(Optional) Why? [text box]
[Skip]
```

**Trigger: When user searches**
```
🔍 You just used search!

Did you find what you were looking for?

[✅ Yes] [❌ No]

(If No) What were you looking for? [text box]
[Skip]
```

**Trigger: On 3rd app open (Phase 2)**
```
💎 Want to upgrade to Premium?

Premium includes:
• Unlimited recipes (vs 100 free)
• AI-powered meal planning
• Family sharing
• No ads

[Try Premium Free for 7 Days] [Maybe Later]
```

---

### Template 6: Phase 3 Soft Launch Instructions (None!)

**Key Insight:** In soft launch, you DON'T give instructions. You want to see organic behavior.

**Instead, observe:**
- Where do users drop off?
- What features do they discover?
- When do they upgrade (or not)?
- What triggers app deletion?

**Only intervention:** Post-deletion survey
```
Subject: Sorry to see you go! Quick question?

Hi,

We noticed you uninstalled Heirloom. No hard feelings!

Mind telling us why? This helps us improve.

[ ] Didn't need it
[ ] Too buggy
[ ] Missing features I need
[ ] Prefer another app
[ ] Too expensive
[ ] Other: [text]

[Submit] [No thanks]

Thanks for trying Heirloom!
```

---

## Feedback Collection Methods

### Method 1: TestFlight Screenshot Feedback
**Best for:** Quick, contextual bug reports
**How:** Shake device → Annotate screenshot → Submit
**Pros:** Low friction, visual context
**Cons:** Unstructured, hard to analyze at scale

### Method 2: Weekly Surveys (Typeform/Google Forms)
**Best for:** Structured, comparable data
**How:** Email survey link every Monday
**Pros:** Quantitative data, trends over time
**Cons:** Survey fatigue, requires tester effort

### Method 3: In-App Prompts (Custom)
**Best for:** Contextual, moment-of-use feedback
**How:** Trigger prompts after key actions
**Pros:** High response rate, relevant timing
**Cons:** Requires development, can be annoying

### Method 4: Email Feedback
**Best for:** Detailed bug reports and stories
**How:** beta@heirloom.app always open
**Pros:** Rich detail, tester-initiated
**Cons:** Unstructured, time-consuming to process

### Method 5: Weekly Office Hours (Zoom)
**Best for:** Deep dives, feature discussions
**How:** 30-min Zoom slots, 5-10 testers/week
**Pros:** Qualitative insights, relationship building
**Cons:** Time-intensive, doesn't scale

### Method 6: Usage Analytics (Firebase/Mixpanel)
**Best for:** Quantitative behavior data
**How:** Track events, funnels, retention
**Pros:** Objective, no user effort required
**Cons:** Doesn't tell you "why"

### Recommended Mix:
- **Phase 1:** TestFlight feedback + Weekly surveys + Email
- **Phase 2:** All of the above + In-app prompts
- **Phase 3:** Analytics + Post-deletion survey only

---

## Tester Segmentation

### Why Segment?

Different testers give different feedback. Segment to:
1. **Target instructions** - Power users vs. novices need different guidance
2. **Analyze feedback** - Compare cohorts (e.g., iOS experts vs. general users)
3. **Prioritize bugs** - Critical for power users might not matter to casual users

### Segmentation Dimensions

**1. User Type**
- **Power Users** (20%) - Cooking enthusiasts, recipe hoarders
  - Test advanced features, edge cases
  - Expect detailed bug reports
  - Likely to convert to premium

- **Casual Users** (60%) - Occasional cooks, use 1-2x/week
  - Test onboarding, core features
  - Provide high-level feedback
  - May not upgrade

- **Technical Users** (20%) - iOS developers, designers
  - Test performance, edge cases
  - Provide detailed technical feedback
  - Critical but not target persona

**2. iOS Experience**
- **iOS Experts** - Understand conventions, give polish feedback
- **iOS Novices** - Good for usability testing, onboarding

**3. Cooking Habits**
- **Daily cooks** - Will use app frequently, test retention
- **Weekend cooks** - Sporadic usage, test re-engagement
- **Recipe collectors** - High recipe count, test scaling

### Segmentation Strategy by Phase

**Phase 1: Closed Beta**
- Start with Power Users + Technical Users
- Reason: Forgiving, detailed feedback, find bugs fast

**Phase 2: Expanded Beta**
- Add Casual Users + iOS Novices
- Reason: Test onboarding, mainstream usability

**Phase 3: Soft Launch**
- All user types, organically distributed
- Reason: Validate product-market fit across segments

### Variant Instructions by Segment

**Example: Onboarding Feedback**

**For Power Users:**
```
You're a recipe enthusiast—perfect tester!

This week: Add 20+ recipes and stress-test our AI.

Focus on:
• Unusual recipe sites (international, niche blogs)
• Complex recipes (multiple components, unusual ingredients)
• Edge cases (videos, missing ingredients, weird formatting)

We want you to break it. 🔨
```

**For Casual Users:**
```
Welcome! Try using Heirloom like you normally would.

This week: Add 5-10 recipes you'd actually cook.

Focus on:
• Is it easy to get started?
• Can you find your recipes later?
• Does it feel useful for your cooking routine?

Be honest—we want your real experience!
```

**For Technical Users:**
```
Hey dev! We need your technical eye.

This week: Test performance and edge cases.

Focus on:
• Any crashes or memory leaks?
• Slow screens or janky animations?
• Bugs with iOS 17 vs 18?
• Accessibility issues?

Geek out—we speak your language. 🤓
```

---

## Analysis Framework

### How to Process Feedback

**Weekly Ritual:**
1. **Monday:** Send weekly survey + TestFlight build
2. **Tuesday-Friday:** Collect feedback, triage bugs
3. **Saturday:** Analyze survey results, identify trends
4. **Sunday:** Plan next week's focus based on data

### Bug Triage

**Priority Levels:**
- **P0 - Critical:** Crashes, data loss, blocks core features → Fix immediately
- **P1 - High:** Major bugs, broken features → Fix this week
- **P2 - Medium:** Minor bugs, polish issues → Fix before launch
- **P3 - Low:** Nice-to-haves, edge cases → Backlog

**Triage Questions:**
1. Does it prevent core functionality? (P0)
2. Does it affect most users? (P1)
3. Does it hurt the experience? (P2)
4. Is it just annoying? (P3)

### Feature Request Framework

**Not all feedback is equal. Filter requests:**

**"Must Have"** - Critical for launch
- [ ] Requested by >50% of testers
- [ ] Blocks core use case
- [ ] Easy to implement

**"Should Have"** - Nice to have, but not critical
- [ ] Requested by 20-50% of testers
- [ ] Enhances experience
- [ ] Medium effort

**"Could Have"** - Backlog for post-launch
- [ ] Requested by <20% of testers
- [ ] Nice-to-have
- [ ] High effort

**"Won't Have"** - Out of scope
- [ ] Off-brand or mission drift
- [ ] Too complex for v1
- [ ] Only 1-2 requests

### Metrics Dashboard

**Track These KPIs Weekly:**

**Engagement:**
- Daily Active Users (DAU)
- Weekly Active Users (WAU)
- Avg. session length
- Avg. sessions per week

**Core Actions:**
- Recipes added per user
- Recipes searched per user
- Collections created per user
- Shares sent per user

**Retention:**
- Day 1 retention (did they come back?)
- Day 7 retention
- Day 30 retention (Phase 3 only)

**Quality:**
- Crash-free sessions (target: >99%)
- App Store rating (target: >4.5)
- NPS score (target: >40)

**Conversion (Phase 2+):**
- Free-to-Premium conversion rate
- Time to first premium upgrade
- Premium churn rate

---

## Execution Checklist

### Phase 1: Closed Beta - Week 1

**Pre-Launch:**
- [ ] Recruit 25 testers via email/text
- [ ] Create TestFlight group "Closed Beta"
- [ ] Prepare Build 1.0.1 with "What's New" notes
- [ ] Set up beta@heirloom.app email
- [ ] Create Week 1 survey in Typeform
- [ ] Draft welcome email

**Launch Day:**
- [ ] Upload build to TestFlight
- [ ] Invite 25 testers via TestFlight
- [ ] Send welcome email with instructions
- [ ] Post in beta Slack/Discord (if created)

**During Week:**
- [ ] Monitor email for bug reports
- [ ] Triage P0 bugs immediately
- [ ] Send mid-week reminder (Wednesday)
- [ ] Schedule 5 Zoom office hours (optional)

**End of Week:**
- [ ] Send Week 1 survey
- [ ] Analyze survey results
- [ ] Prioritize Week 2 fixes
- [ ] Draft Week 2 build notes

### Phase 1: Closed Beta - Week 2-4

Repeat weekly cycle:
1. **Monday:** New build + survey
2. **Tuesday-Friday:** Collect feedback, fix bugs
3. **Saturday:** Analyze data
4. **Sunday:** Plan next week

### Phase 2: Expanded Beta

**Pre-Launch:**
- [ ] Recruit 50 new testers (75-100 total)
- [ ] Segment testers (power/casual/technical)
- [ ] Create Phase 2 TestFlight group
- [ ] Add in-app feedback prompts
- [ ] Set up analytics (Firebase/Mixpanel)

**Launch:**
- [ ] Invite new testers
- [ ] Send Phase 2 welcome email (segmented)
- [ ] Monitor closely for first 48 hours

**During Phase:**
- [ ] Weekly surveys (all testers)
- [ ] Track analytics daily
- [ ] Weekly office hours with 5-10 testers
- [ ] Iterate based on feedback

### Phase 3: Soft Launch

**Pre-Launch:**
- [ ] Finalize App Store listing
- [ ] Prepare Product Hunt launch
- [ ] Set up post-deletion survey
- [ ] Analytics dashboard ready

**Launch:**
- [ ] Submit to App Store
- [ ] Launch on Product Hunt
- [ ] Monitor reviews and ratings
- [ ] Track conversion funnel

**During Phase:**
- [ ] Daily analytics review
- [ ] Respond to reviews within 24h
- [ ] Weekly cohort analysis
- [ ] Prepare for Full Launch

---

## Templates & Resources

### Email Templates
- Welcome emails (by phase and segment) → Included above
- Weekly check-in reminders
- "Thanks for testing" wrap-up email

### Survey Templates
- Weekly feedback surveys (Typeform)
- Post-task micro-surveys (in-app)
- Post-deletion survey

### TestFlight "What's New" Templates
- By phase and build number → Included above

### Zoom Office Hours Script
- Introduction: Who I am, what we're building
- Tester share: How have you been using Heirloom?
- Deep dive: Walk me through adding a recipe
- Open Q&A: What's confusing or broken?
- Wrap-up: What should we prioritize?

---

## Success Metrics by Phase

### Phase 1: Closed Beta
- [ ] <5% crash rate
- [ ] >80% of testers add 5+ recipes
- [ ] >90% complete Week 1 survey
- [ ] >50% say "easy" or "very easy" to use
- [ ] Identify and fix all P0/P1 bugs

### Phase 2: Expanded Beta
- [ ] <2% crash rate
- [ ] >70% complete onboarding
- [ ] >60% return Day 7
- [ ] >15% try premium features
- [ ] >4.5 internal rating (tester survey)

### Phase 3: Soft Launch
- [ ] <1% crash rate
- [ ] >4.0 App Store rating
- [ ] >40% Day 1 retention
- [ ] >8% free-to-premium conversion
- [ ] 500-1K downloads achieved

---

## Final Thoughts

**The #1 Mistake in Beta Testing:**
Treating all feedback equally. Not all feedback is signal.

**The #1 Success Factor:**
Clear instructions + specific tasks = actionable insights

**Remember:**
- Phase 1: "Does it work?" → Fix crashes and core bugs
- Phase 2: "Can they use it?" → Polish onboarding and UX
- Phase 3: "Will they pay?" → Validate conversion and retention

**You can't test everything at once. Focus.**

---

## Appendix: Sample Feedback

### Good Feedback Examples

**Example 1: Specific Bug Report**
```
Bug: App crashes when adding recipe from AllRecipes.com

Steps to reproduce:
1. Tap + button
2. Paste URL: https://www.allrecipes.com/recipe/123/
3. Tap "Add Recipe"
4. App crashes

Device: iPhone 14 Pro, iOS 17.2
Build: 1.0.3
```

**Example 2: Usability Insight**
```
I got confused during onboarding. The "Add Recipe" button wasn't obvious—I thought I had to create a collection first.

Suggestion: Maybe highlight the + button on first launch?
```

**Example 3: Value Feedback**
```
I love how clean the recipes look! But I'm not sure I'd pay $40/year for this. I already use Paprika ($5 one-time). What makes Heirloom worth 8x more?
```

### Bad Feedback Examples

**Example 1: Too Vague**
```
The app is confusing.
```
*What's confusing? Where? When?*

**Example 2: Out of Scope**
```
You should add grocery delivery integration with Instacart!
```
*Cool idea, but not for v1.*

**Example 3: Opinion, Not Insight**
```
I don't like the color scheme. Make it more colorful.
```
*Design opinions are low signal unless repeated by many testers.*

---

**Questions?** Email matt@heirloom.app

**Last Updated:** December 31, 2025
