# Share Extension - Quick Test Checklist ⚡

**Must-Pass Tests Before Merge** (30 minutes)

---

## Setup (5 min)
- [ ] Build on physical iPhone (iOS 17+)
- [ ] Share Extension enabled in Settings
- [ ] Install: TikTok, Instagram, YouTube

---

## Core Functionality (15 min)

### 1. TikTok Video → Recipe Card
- [ ] Open TikTok → Find recipe video with narration
- [ ] Share → Heirloom
- [ ] Verify: Detects TikTok, shows transcript, "Import" button
- [ ] Tap Import → Main app opens → Recipe created
- [ ] Check recipe has: title, ingredients, steps, TikTok attribution

### 2. Instagram Reel → Recipe Card
- [ ] Open Instagram → Find recipe Reel
- [ ] Share → Heirloom → Import
- [ ] Verify: Creates recipe with Instagram attribution

### 3. YouTube Shorts → Recipe Card
- [ ] Open YouTube → Find recipe Short
- [ ] Share → Heirloom → Import
- [ ] Verify: Creates recipe with YouTube attribution

---

## Edge Cases (10 min)

### 4. Background Music (OCR Fallback)
- [ ] Share TikTok with music only (no speech)
- [ ] Verify: Recommends "On-Screen Text (OCR)" mode
- [ ] Import still works

### 5. Invalid URL
- [ ] Share non-video URL (e.g., google.com)
- [ ] Verify: Shows error, doesn't crash

### 6. No Internet
- [ ] Turn off WiFi/cellular
- [ ] Share video
- [ ] Verify: Shows "No internet" error, doesn't crash

---

## Premium Paywall
- [ ] Select "Visual Analysis" mode as free user
- [ ] Verify: Paywall appears, blocks processing

---

## Performance
- [ ] Share Extension loads in <3 seconds
- [ ] Full import completes in <30 seconds

---

## Pass/Fail
- ✅ All 8 tests pass → **READY TO MERGE**
- ❌ Any test fails → **FIX BEFORE MERGE**

---

**Critical Success Metric:**
> "Can a user share a TikTok recipe video and get a complete recipe card in their Heirloom app within 30 seconds?"

If YES → Ship it! 🚀
