# Heirloom Dashboard Setup Guide

## Overview

This guide walks you through setting up the interactive components of your Heirloom business dashboard. You'll connect Notion for project tracking and Google Sheets + Looker Studio for financial modeling.

**Time Required:** 2-3 hours
**Difficulty:** Beginner-friendly (step-by-step instructions provided)

---

## Prerequisites

- [x] Heirloom dashboard deployed to rationale.studio/heirloom
- [ ] Notion account (free tier is fine)
- [ ] Google account for Sheets and Looker Studio
- [ ] Access to business strategy documents in `/Users/matthanson/Heirloom/`

---

## Part 1: Notion Launch Tracker (60 min)

### Step 1: Create Notion Workspace

1. Go to [notion.so](https://notion.so)
2. Click **+ New page** in sidebar
3. Name it: **"Heirloom Strategy"**
4. Select icon: 🏛️ (or choose your own)

### Step 2: Create Launch Tracker Database

1. Inside "Heirloom Strategy" page, type `/database` and select **"Database - Full page"**
2. Name the database: **"Launch Tracker"**
3. Add these properties (click **+** next to properties):
   - **Phase** (Select) - Options: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5
   - **Milestone** (Title) - Default property, already exists
   - **Status** (Select) - Options: Not Started, In Progress, Complete, Blocked
   - **Due Date** (Date)
   - **Owner** (Person)
   - **Category** (Select) - Options: Product, Marketing, Testing, Infrastructure
   - **Priority** (Select) - Options: Critical, High, Medium, Low
   - **Notes** (Text)

### Step 3: Import Milestones from USER_MILESTONE_ROADMAP.md

Open `/Users/matthanson/Heirloom/USER_MILESTONE_ROADMAP.md` and copy tasks into Notion:

**Phase 1: Closed Beta (Now - Jan 15)**
- Finalize core features and bug fixes
- Recruit 20-30 beta testers from network
- Set up TestFlight distribution
- Create feedback collection system
- Weekly check-ins with testers
- Track app usage and feature adoption
- Document all bugs and feedback

**Phase 2: Expanded Beta (Jan 16 - Feb 1)**
- Expand to 50-100 beta testers
- Fix critical bugs from Phase 1
- Add requested features from feedback
- Prepare App Store listing materials
- Create marketing website
- Build email automation for onboarding

**Phase 3: Soft Launch (Feb 2-15)**
- Submit to App Store for review
- Soft launch to Product Hunt
- Monitor reviews and ratings closely
- Quick iteration based on public feedback
- Target: 500-1K downloads

**Phase 4: Full Launch (Feb 16 - Mar 31)**
- Press outreach to tech blogs
- Influencer partnerships with cooking creators
- Community engagement (Reddit, Facebook groups)
- ASO optimization
- Target: 5K-15K downloads

**Phase 5: Growth & Scale (Apr 1 - Dec 31)**
- Conversion optimization experiments
- Feature expansion based on user requests
- Premium tier marketing
- Retention campaigns
- Target: 100K-200K downloads

### Step 4: Create Views

1. **Kanban View (Default)**
   - Click **+ New view** → **Board**
   - Group by: **Status**
   - Sort by: **Priority** (descending)

2. **Timeline View**
   - Click **+ New view** → **Timeline**
   - Start date: **Due Date**
   - Color by: **Phase**

3. **Table View**
   - Click **+ New view** → **Table**
   - Show all properties
   - Sort by: **Due Date** (ascending)

### Step 5: Publish and Get Embed URL

1. Click **Share** button (top right)
2. Toggle **"Publish to web"**
3. Copy the URL (should look like: `https://notion.so/your-workspace/Launch-Tracker-abc123`)
4. Add `?embed=true` to the end
5. Final URL: `https://notion.so/your-workspace/Launch-Tracker-abc123?embed=true`

### Step 6: Update Dashboard Code

Open `/Users/matthanson/rationale-public/app/heirloom/roadmap/page.tsx`:

```typescript
// Line 14: Replace empty string with your Notion URL
const notionUrl = 'https://notion.so/your-workspace/Launch-Tracker-abc123?embed=true';
```

---

## Part 2: Notion GTM Planner (45 min)

### Step 1: Create GTM Planner Database

1. In "Heirloom Strategy" page, create another database
2. Name it: **"GTM Planner"**
3. Add these properties:
   - **Task** (Title)
   - **Week** (Select) - Options: Week 1, Week 2, ..., Week 8
   - **Channel** (Select) - Options: Product Hunt, Press, Influencer, Community, ASO, Paid Ads
   - **Budget** (Number) - Format: Currency (USD)
   - **Status** (Select) - Options: Not Started, In Progress, Complete, Cancelled
   - **Owner** (Person)
   - **Due Date** (Date)
   - **Deliverables** (Text)

### Step 2: Import Tasks from GO_TO_MARKET_PLAYBOOK.md

Open `/Users/matthanson/Heirloom/GO_TO_MARKET_PLAYBOOK.md` and copy weekly tasks:

**Week 1: Soft Launch**
- Create landing page with waitlist
- Set up TestFlight public link
- Write launch blog post
- Prepare Product Hunt assets
- Budget: $500

**Week 2: Product Hunt**
- Launch on Product Hunt
- Monitor comments and engage
- Share on Twitter and LinkedIn
- Email beta testers for support
- Budget: $1,000

**Week 3: Launch Week**
- Submit to App Store
- Press release to tech blogs
- Pitch to TechCrunch, MacStories
- Monitor reviews and respond
- Budget: $2,000

**Week 4: Press & Media**
- Follow up with journalists
- Podcast outreach
- Case study creation
- Budget: $1,500

**Week 5: Influencer Push**
- Partner with cooking influencers
- Sponsored content creation
- YouTube video sponsorships
- Budget: $2,500

**Week 6: Community**
- Reddit posts (r/Cooking, r/iOS)
- Facebook group engagement
- Slack community participation
- Budget: $500

**Week 7: ASO Optimization**
- Keyword research and optimization
- A/B test screenshots
- Update app description
- Budget: $1,000

**Week 8: Retention Focus**
- In-app messaging setup
- Email drip campaigns
- Feature announcement
- Budget: $500

### Step 3: Create Views

1. **Calendar View**
   - Group by: **Week**
   - Show: **Due Date**

2. **Kanban by Status**
   - Group by: **Status**
   - Sort by: **Due Date**

3. **Budget Tracker Table**
   - Show: Week, Channel, Budget, Status
   - Sort by: **Week**
   - Sum: **Budget** column

### Step 4: Publish and Get Embed URL

1. Click **Share** → **Publish to web**
2. Copy URL and add `?embed=true`
3. Final URL: `https://notion.so/your-workspace/GTM-Planner-xyz789?embed=true`

### Step 5: Update Dashboard Code

Open `/Users/matthanson/rationale-public/app/heirloom/gtm/page.tsx`:

```typescript
// Line 11: Replace empty string with your Notion URL
const notionUrl = 'https://notion.so/your-workspace/GTM-Planner-xyz789?embed=true';
```

---

## Part 3: Google Sheets Financial Model (60 min)

### Step 1: Create New Google Sheet

1. Go to [sheets.google.com](https://sheets.google.com)
2. Create new sheet: **"Heirloom Financial Model"**
3. Create 4 sheets (tabs):
   - **Dashboard** (summary view)
   - **Revenue Model**
   - **Cost Structure**
   - **Cash Flow**

### Step 2: Set Up Revenue Model Sheet

**Column Headers:**
- Month (Jan - Dec)
- Total Downloads
- MAU (60% of downloads)
- Free-to-Premium Rate (8%, 12%, 15%)
- Premium Users
- Monthly Subscriptions ($4.99)
- Annual Subscriptions ($39.99)
- Total Revenue

**Formulas:**
```
MAU = Downloads * 0.60
Premium Users = MAU * Conversion_Rate
Monthly Rev = Premium Users * 0.60 * $4.99
Annual Rev = Premium Users * 0.40 * $39.99 / 12
Total Revenue = Monthly Rev + Annual Rev
```

**Create 3 Scenarios (use columns or separate sheets):**
1. Conservative: 100K downloads, 8% conversion
2. Baseline: 150K downloads, 12% conversion
3. Optimistic: 200K downloads, 15% conversion

### Step 3: Set Up Cost Structure Sheet

**Fixed Monthly Costs:**
- Development: $1,000/mo
- Infrastructure (Firebase, Netlify): $100/mo
- AI APIs (OpenAI): $500/mo
- Legal/Admin: $333/mo
- Marketing: Variable (see GTM budget)

**Variable Costs:**
- App Store Fee: 30% of revenue
- AI API costs scale with users

### Step 4: Set Up Cash Flow Sheet

**Columns:**
- Month
- Revenue (link from Revenue Model)
- Fixed Costs
- Variable Costs
- Net Income
- Cumulative Cash Flow

**Break-Even Analysis:**
- Add conditional formatting when Cumulative Cash Flow > 0

### Step 5: Create Dashboard Sheet

**Summary Metrics:**
1. **Year 1 Totals** (all 3 scenarios)
   - Total Downloads
   - Total Revenue
   - Total Costs
   - Net Profit/Loss
   - Break-Even Month

2. **Monthly Trend Chart**
   - Line chart: Revenue vs. Costs over 12 months

3. **Scenario Comparison**
   - Bar chart: Revenue by scenario
   - Break-even comparison

### Step 6: Import Data from FINANCIAL_MODEL_DETAILED.md

Open `/Users/matthanson/Heirloom/FINANCIAL_MODEL_DETAILED.md` and reference:
- Pricing tiers and conversion assumptions
- Cost breakdown details
- Download projections by phase

---

## Part 4: Looker Studio Dashboard (30 min)

### Step 1: Connect Google Sheets to Looker Studio

1. Go to [lookerstudio.google.com](https://lookerstudio.google.com)
2. Click **Create** → **Report**
3. Add data source: **Google Sheets**
4. Select your "Heirloom Financial Model" sheet
5. Choose **Dashboard** sheet

### Step 2: Create Visualizations

**Page 1: Overview**
- Scorecard: Total Revenue (all scenarios)
- Scorecard: Break-Even Month
- Line chart: Monthly revenue trend
- Bar chart: Scenario comparison

**Page 2: Revenue Breakdown**
- Pie chart: Monthly vs. Annual subscriptions
- Line chart: Premium user growth
- Table: Month-by-month revenue detail

**Page 3: Cost Analysis**
- Stacked bar chart: Fixed vs. Variable costs
- Line chart: Cost trend over time
- Table: Cost category breakdown

**Page 4: Cash Flow**
- Area chart: Cumulative cash flow
- Waterfall chart: Monthly net income
- Gauge chart: Runway remaining

### Step 3: Share and Get Embed URL

1. Click **Share** (top right)
2. Click **Manage access**
3. Change to **"Anyone with the link can view"**
4. Click **Embed** button
5. Copy the embed URL
6. Final URL: `https://lookerstudio.google.com/embed/reporting/abc-def-ghi`

### Step 4: Update Dashboard Code

Open `/Users/matthanson/rationale-public/app/heirloom/financials/page.tsx`:

```typescript
// Line 22: Replace empty string with Looker Studio URL
const lookerStudioUrl = 'https://lookerstudio.google.com/embed/reporting/abc-def-ghi';
```

---

## Part 5: Deploy Updates

After updating all URLs in the dashboard code:

```bash
cd /Users/matthanson/rationale-public

# Add and commit changes
git add app/heirloom/roadmap/page.tsx app/heirloom/gtm/page.tsx app/heirloom/financials/page.tsx
git commit -m "Add Notion and Looker Studio embed URLs for Heirloom dashboard"
git push

# Netlify will automatically deploy
# Check status at: https://app.netlify.com/sites/rationale-studio/deploys
```

---

## Part 6: Test and Verify

1. **Test Login**
   - Go to https://rationale.studio/login
   - Sign in with `hanson@rationale.work`
   - Should redirect to `/owner` or `/heirloom`

2. **Test Dashboard Access**
   - Navigate to https://rationale.studio/heirloom
   - Verify all pages load:
     - Dashboard (KPI cards)
     - Launch Tracker (Notion embed)
     - GTM Planner (Notion embed)
     - Financials (Looker Studio embed)

3. **Test Embeds**
   - Verify Notion databases display correctly
   - Check that Looker Studio charts are interactive
   - Ensure you can edit directly in Notion (should open in new tab)

---

## Troubleshooting

### Notion Embed Not Loading
- Check that "Publish to web" is enabled
- Verify `?embed=true` is added to URL
- Try opening embed URL directly in browser

### Looker Studio Embed Not Loading
- Check sharing permissions ("Anyone with link")
- Verify you copied the **embed** URL, not view URL
- Check browser console for CSP errors (may need to update CSP in netlify.toml)

### Dashboard Not Accessible
- Verify Firebase authentication is working
- Check that your user has `owner` role in Firestore
- Test middleware.ts protection by visiting /heirloom while logged out

### Metrics API Returning 0
- This is expected - using mock data until App Store Connect integration
- Real metrics will populate after Phase 3 (Soft Launch)

---

## Next Steps

Once setup is complete:

1. **Weekly Reviews** - Update Notion databases every Monday
2. **Financial Updates** - Refresh Google Sheets monthly with actual data
3. **Metrics Integration** - Connect App Store Connect API after launch
4. **Team Access** - Add team members to Notion for collaboration
5. **Investor Sharing** - Create read-only links for investor updates

---

## Resources

- **Notion Help:** [notion.so/help](https://notion.so/help)
- **Looker Studio Docs:** [support.google.com/looker-studio](https://support.google.com/looker-studio)
- **Firebase Console:** [console.firebase.google.com](https://console.firebase.google.com)
- **Netlify Dashboard:** [app.netlify.com/sites/rationale-studio](https://app.netlify.com/sites/rationale-studio)

---

## Support

Questions or issues? Check:
1. Netlify build logs for deployment errors
2. Browser console for frontend errors
3. Firebase logs for authentication issues

**Need help?** Reference the business strategy documents in `/Users/matthanson/Heirloom/` for detailed context.
