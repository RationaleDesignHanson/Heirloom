# Heirloom Beta Testing Instructions

Thank you for helping test Heirloom! Your feedback is essential for making this the best recipe management app possible.

---

## Getting Started

### 1. Install TestFlight

If you don't already have it:
1. Download TestFlight from the App Store
2. Open the invitation link sent to your email
3. Tap "Accept" in TestFlight
4. Tap "Install" to download Heirloom

### 2. Sign In to iCloud

**Important:** Heirloom requires iCloud for syncing and sharing features.

1. Go to Settings on your iPhone/iPad
2. Tap your name at the top
3. Verify you're signed in to iCloud
4. Make sure "iCloud Drive" is turned ON

---

## What to Test

### Core Features (Everyone)

**1. Recipe Management**
- Add recipes manually
- Edit existing recipes
- Delete recipes
- Mark favorites
- Search for recipes

**2. Web Import (NEW)**
- Tap the "+" button
- Choose "Import from URL"
- Paste a recipe URL (try AllRecipes, NYT Cooking, etc.)
- Verify all recipe details imported correctly
- Check if the recipe image appears

**3. Recipe Card Scanner (NEW - If you have physical recipe cards)**
- Tap the "+" button
- Choose "Scan Recipe Card"
- Point camera at a recipe card
- Follow quality feedback indicators
- Capture image when ready
- Review and edit OCR results
- Save the recipe

**4. Ingredient Scaling**
- Open any recipe
- Tap the serving size
- Adjust servings up or down
- Verify ingredient quantities scale correctly

**5. Shopping List**
- Long-press on a recipe
- Choose "Add to Shopping List"
- Go to Shopping List tab
- Verify ingredients appear correctly
- Check off items as you shop

---

## Advanced Testing (If Time Permits)

### Recipe Sharing (Requires 2 Devices)

If you have access to another iOS device with a different iCloud account:

1. **Device A (Sender):**
   - Open a recipe
   - Tap the Share button
   - Send via Messages, AirDrop, or Copy Link

2. **Device B (Receiver):**
   - Open the share link
   - Accept the recipe
   - Verify it appears in your recipe list
   - Check that it shows "Shared by [Name]"

### CloudKit Sync

1. Add recipes on your iPhone
2. Open Heirloom on your iPad (same iCloud account)
3. Verify recipes appear on both devices
4. Edit a recipe on one device
5. Confirm changes sync to the other device

---

## What We're Looking For

### Critical Issues
- App crashes
- Data loss
- Features that don't work at all
- Login or sync problems

### Usability Issues
- Confusing workflows
- Hard to find features
- Unexpected behavior
- Slow performance

### Feature Feedback
- Missing functionality you expected
- Ideas for improvements
- Workflows that could be simpler

### OCR Quality (If testing scanner)
- How accurate was the text recognition?
- Did it correctly identify ingredients vs instructions?
- Were any words completely wrong?
- Did handwritten text work?

---

## How to Report Issues

### Option 1: TestFlight Feedback (Preferred)

1. Open TestFlight
2. Tap on Heirloom
3. Tap "Send Beta Feedback"
4. Describe the issue
5. Optionally include a screenshot

### Option 2: Direct Email

Send to: [Your email address]

**Please include:**
- What you were trying to do
- What happened (vs. what you expected)
- Steps to reproduce the issue
- Your device model and iOS version
- Screenshots if relevant

---

## Known Issues & Limitations

### Current Limitations

**Web Import:**
- Some recipe sites may not import correctly
- Paywalled content cannot be imported
- Images may fail to download on slow connections

**Recipe Scanner:**
- Requires good lighting for best results
- Handwritten recipes may need more editing
- Very faded or stained cards may not scan well

**Sharing:**
- Both users must be signed in to iCloud
- Requires iOS 18 or later
- Shared recipes don't sync changes (one-time copy)

**General:**
- No Android version yet (iOS only)
- No web version
- Recipe videos not supported
- Metric/Imperial conversion is automatic (not toggle-able yet)

---

## Tips for Best Results

### Web Import
- Use recipe sites with clear structure (AllRecipes, Food Network, etc.)
- Avoid blog posts with long stories before the recipe
- If import fails, try copying the text manually

### Recipe Scanner
- Use good lighting (natural light is best)
- Hold camera steady
- Make sure entire recipe card is visible
- Tap the screen to focus if blurry
- Follow the on-screen quality indicators

### Recipe Sharing
- Make sure both devices have iCloud enabled
- Use Messages or AirDrop for easiest sharing
- If link doesn't work, try copying and pasting it in Safari first

---

## Testing Priorities

### Week 1: Core Functionality
- Add 5-10 recipes (mix of manual, web import, and scan)
- Use the app for actual cooking
- Try searching and filtering
- Add items to shopping list

### Week 2: Advanced Features
- Test recipe sharing if you have 2 devices
- Try editing and organizing your recipes
- Experiment with ingredient scaling
- Test on both iPhone and iPad if you have both

### Week 3: Daily Use
- Use Heirloom as your primary recipe app
- Note any friction points or annoyances
- Compare to other recipe apps you've used
- Share your overall impression

---

## Privacy & Data

**What data is collected:**
- Your recipes (stored in your personal iCloud account)
- Anonymous usage statistics (if you opt in)
- Crash reports (to fix bugs)

**What is NOT collected:**
- Your personal information
- Your location
- Your contacts
- Your browsing history

**Your data:**
- Stored securely in your iCloud account
- Not accessible to us or other users (except recipes you explicitly share)
- Can be deleted at any time

---

## Frequently Asked Questions

**Q: How often will the app update?**
A: We'll push updates weekly during beta testing. TestFlight will notify you.

**Q: Will my beta data carry over to the final version?**
A: Yes, your recipes will remain when you upgrade to the App Store version.

**Q: Can I invite other testers?**
A: Not directly, but you can forward our invitation email to friends who might be interested.

**Q: What if I want to stop testing?**
A: Just delete the app from your device. No need to notify us.

**Q: Is there a group chat for beta testers?**
A: [Include Discord/Slack link if you have one, or say "Not yet"]

---

## Thank You!

Your testing and feedback directly shapes how Heirloom evolves. Every bug you report, suggestion you make, and feature you test helps us build a better product.

We're especially grateful for:
- Detailed bug reports with steps to reproduce
- Honest feedback about what's confusing or broken
- Suggestions for missing features
- Testing edge cases we didn't think of

**Questions?** Email [your email] anytime.

**Found a critical bug?** Email with "URGENT" in subject line.

---

**Version:** Beta 1.1.0
**Build:** [Current build number]
**Last Updated:** December 18, 2024
**Testing Period:** 4-6 weeks
**Expected Launch:** Q1 2025
