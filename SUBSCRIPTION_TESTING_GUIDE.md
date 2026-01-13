# Subscription Management Testing Guide

## Quick Start: Debug Mode Testing

The easiest way to test subscription flows without real purchases is using the built-in debug tools.

### 1. Enable Debug Mode

1. Launch Heirloom app
2. Go to **Settings** tab
3. Scroll to **Developer Testing** section
4. Toggle **"Force Non-Premium Mode"** to ON (should be ON by default)

This forces the app to treat you as a non-premium user, even if you have a subscription.

### 2. Access Trial Debug Tools

1. In Settings > Developer Testing
2. Tap **"Trial Debug"**
3. This opens the Trial Debug screen where you can:
   - Reset trial to Day 1
   - Skip to Day 7, 13, or 15 (expired)
   - Manually trigger daily heritage unlocks
   - Reset paywall state
   - View current trial status

---

## Testing Scenarios

### Scenario 1: Free User → First Purchase

**Setup:**
- Force Non-Premium Mode: ON
- Reset trial if needed (Trial Debug > Reset Trial)

**Test Flow:**
1. Open app → Navigate to Collections tab
2. Verify trial countdown shows in toolbar (e.g., "14d")
3. Tap sparkles icon → Opens HeritageUnlockView
4. Verify trial countdown badge shows
5. Verify "Unlock Today's Recipes" button shows (if Day 1)
6. Go to Settings
7. Verify trial countdown badge shows above "Upgrade to Premium"
8. Tap "Upgrade to Premium"
9. Verify PaywallView shows all 3 plans:
   - Annual ($29.99/year, 14-day free trial, BEST VALUE badge)
   - Monthly ($4.99/month, 7-day free trial)
   - Lifetime ($99 once, FOUNDING MEMBER badge)
10. Select each plan and verify CTA text changes:
    - Annual: "Start 14-Day Free Trial"
    - Monthly: "Start 7-Day Free Trial"
    - Lifetime: "Buy Lifetime Access"
11. Tap "Maybe later" to dismiss (soft wall)

**Expected Results:**
- ✅ Trial countdown visible in 3 locations
- ✅ All 3 plans shown
- ✅ Correct CTA text for each plan
- ✅ Soft wall dismissible

---

### Scenario 2: Trial Progression (Day 7, 13, 15)

**Setup:**
- Use Trial Debug to skip to different days

**Day 7 Test:**
1. Trial Debug > Skip to Day 7
2. Add a recipe (any method)
3. Verify soft wall paywall triggers after save (Day 7 trigger)
4. Dismiss paywall (counts toward 3-strike rule)

**Day 13 Test:**
1. Trial Debug > Skip to Day 13
2. Open Collections tab
3. Verify "1d" shows in toolbar (1 day remaining)
4. Open HeritageUnlockView
5. Verify urgency messaging shows
6. Soft wall may trigger (Day 13 urgency trigger)

**Day 15 Test (Trial Expired):**
1. Trial Debug > Skip to Day 15
2. Verify no trial countdown shows anywhere
3. Go to Collections tab
4. Verify post-trial banner shows:
   - "You unlocked X heritage recipes"
   - "They're yours forever!"
   - "Upgrade to Premium" button
   - "Buy Individually" button
5. Tap sparkles icon → HeritageUnlockView
6. Verify "Trial Complete!" message shows
7. Tap "See Your Options" → Opens TrialExpiredView
8. Verify 4 options show:
   - Upgrade to Premium (blue gradient card)
   - Buy Recipes Individually
   - Export Your Recipes
   - Continue with Free Version

**Expected Results:**
- ✅ Day 7: Paywall triggers after recipe save
- ✅ Day 13: Urgency messaging visible
- ✅ Day 15: Post-trial UI shows correctly
- ✅ TrialExpiredView accessible and functional

---

### Scenario 3: Video Import Premium Gate

**Setup:**
- Force Non-Premium Mode: ON
- Reset paywall state (Trial Debug > Reset Paywall State)

**Test Flow:**
1. Go to Recipes tab → Tap "+" → Select "Video Import"
2. Verify SoftWallView shows (URL Import trigger)
3. Tap "See Plans" → Opens PaywallView
4. Dismiss without purchasing
5. Repeat import attempt
6. After 3 dismissals, verify 3-strike rule activates:
   - No more paywalls for 48-72 hours
   - Video import should work

**Expected Results:**
- ✅ Soft wall shows on video import
- ✅ 3-strike rule prevents paywall fatigue
- ✅ Feature accessible after 3 dismissals

---

### Scenario 4: ASMR Credit System

**Setup:**
- Force Non-Premium Mode: ON

**Test Flow:**
1. Go to Recipes tab → Tap "+" → Select "ASMR Video Import"
2. Verify ASMRUsageBadge shows at top:
   - "1 / 1 left this month" (or similar)
   - Orange waveform icon
   - Upgrade arrow button
3. Paste a video URL and start extraction
4. Once credits exhausted, verify:
   - "No ASMR Credits Remaining" screen shows
   - PaywallView embedded in sheet
   - Usage summary shows ("You've used X of Y")
5. Tap Cancel to dismiss

**Expected Results:**
- ✅ Usage badge shows credits remaining
- ✅ Paywall shows when credits exhausted
- ✅ Clear messaging about credit limit

---

### Scenario 5: Monthly Subscriber → Upgrade to Annual

**Setup:**
- Simulate Monthly subscription (requires StoreKit testing or real purchase)
- Or: Manually set subscription status for testing

**Manual Simulation (Debug):**
1. Open Xcode
2. Edit `SubscriptionManager.swift`
3. Temporarily add to `init()`:
```swift
// DEBUG: Simulate Monthly subscription
UserDefaults.standard.set("monthly", forKey: Keys.subscriptionStatus)
UserDefaults.standard.set("com.rationalestudio.heirloom.monthly", forKey: Keys.cachedProductID)
status = .monthly
```

**Test Flow:**
1. Go to Settings
2. Verify Subscription section shows:
   - Status: "Premium"
   - Current Plan: "Monthly"
   - "Upgrade to Annual" button with green icon
   - "Save 50%" badge
3. Tap "Upgrade to Annual"
4. Verify PaywallView shows upgrade UI:
   - Header: "Upgrade to Annual" with green up arrow
   - Subheading: "Save over 50% with Annual billing"
   - Only 2 plans shown: Annual and Lifetime (Monthly hidden)
   - Annual badge: "RECOMMENDED"
   - Lifetime badge: "ONE-TIME PAYMENT"
5. Verify Annual is pre-selected
6. Verify CTA: "Upgrade to Annual"

**Expected Results:**
- ✅ Settings shows upgrade option
- ✅ PaywallView optimized for upgraders
- ✅ Only relevant plans shown (no Monthly)
- ✅ Clear messaging about savings

---

### Scenario 6: Annual Subscriber → Downgrade to Monthly

**Manual Simulation (Debug):**
```swift
// DEBUG: Simulate Annual subscription
UserDefaults.standard.set("annual", forKey: Keys.subscriptionStatus)
UserDefaults.standard.set("com.rationalestudio.heirloom.annual", forKey: Keys.cachedProductID)
status = .annual
```

**Test Flow:**
1. Go to Settings
2. Verify Subscription section shows:
   - Status: "Premium"
   - Current Plan: "Annual"
   - "Switch to Monthly" button
3. Tap "Switch to Monthly"
4. Verify alert shows:
   - Title: "Switch to Monthly Plan"
   - Message: Explains iOS Settings process
   - "Cancel" button
   - "Continue" button
5. Tap "Continue"
6. Verify iOS subscription management sheet opens

**Expected Results:**
- ✅ Settings shows downgrade option
- ✅ Clear explanation of iOS process
- ✅ iOS sheet opens correctly

---

### Scenario 7: Manage Subscription (Cancel/View)

**Setup:**
- Active subscription (Monthly or Annual)

**Test Flow:**
1. Go to Settings > Subscription section
2. Tap "Manage Subscription"
3. Verify iOS subscription management sheet opens
4. Verify can see:
   - Subscription details
   - Renewal date
   - Cancel subscription option
   - Billing history
   - Payment method

**Expected Results:**
- ✅ iOS sheet opens
- ✅ All subscription details visible
- ✅ Cancel option available

---

### Scenario 8: Lifetime Purchase

**Test Flow:**
1. Go to Settings > Subscription
2. Tap "Upgrade to Premium"
3. Select Lifetime plan
4. Verify badge: "FOUNDING MEMBER • LIMITED"
5. Verify CTA: "Buy Lifetime Access"
6. After purchase (sandbox), verify:
   - Status: "Premium"
   - Current Plan: "Lifetime"
   - No renewal date shown
   - No "Manage Subscription" button (lifetime has no subscription)

**Expected Results:**
- ✅ Lifetime plan purchasable
- ✅ No subscription management needed
- ✅ Permanent premium access

---

## StoreKit Testing (Xcode Sandbox)

For testing real purchase flows without spending money:

### Setup StoreKit Configuration

1. **Create StoreKit Configuration File:**
   - In Xcode: File > New > File > StoreKit Configuration File
   - Name it "Heirloom.storekit"

2. **Add Products:**
   - Add subscription: `com.rationalestudio.heirloom.monthly`
     - Price: $4.99
     - Duration: 1 Month
     - Introductory Offer: 7 days free trial
   - Add subscription: `com.rationalestudio.heirloom.annual`
     - Price: $29.99
     - Duration: 1 Year
     - Introductory Offer: 14 days free trial
   - Add non-consumable: `com.rationalestudio.heirloom.lifetime`
     - Price: $99.00

3. **Enable StoreKit Testing:**
   - Edit Scheme (Product > Scheme > Edit Scheme)
   - Run > Options > StoreKit Configuration
   - Select "Heirloom.storekit"

4. **Run in Simulator:**
   - Build and run
   - Purchase flows will use sandbox
   - No real money charged
   - Can test subscriptions, cancellations, upgrades

### StoreKit Testing Console

While app is running in debug:
1. Debug > StoreKit > Manage Transactions
2. View all transactions
3. Can manually:
   - Expire subscriptions
   - Refund purchases
   - Interrupt transactions
   - Speed up time (for testing subscription renewals)

---

## TestFlight Testing

For testing on real devices with real App Store Connect integration:

### Setup

1. **Configure App Store Connect:**
   - Create app record
   - Add in-app purchases matching product IDs
   - Set up subscription groups
   - Configure pricing

2. **Create TestFlight Build:**
   - Archive app in Xcode
   - Upload to App Store Connect
   - Add internal/external testers

3. **Test with Sandbox Accounts:**
   - Create sandbox tester accounts in App Store Connect
   - Sign in to sandbox account on device (Settings > App Store)
   - Install app via TestFlight
   - Make purchases (no real charges)

### TestFlight Testing Scenarios

All the scenarios above work in TestFlight, plus:
- Real StoreKit environment
- Actual receipt validation
- Subscription renewal testing
- Grace period testing
- Billing retry testing

---

## RevenueCat Testing (Phase 3)

When RevenueCat is implemented:

### Setup

1. Enable RevenueCat in Settings:
   - Settings > Developer Testing
   - Toggle "Enable RevenueCat (Stub)" to ON
   - Currently shows "Not yet implemented"

2. Once implemented:
   - RevenueCat dashboard for subscription management
   - Webhook testing
   - Cross-platform subscription sync
   - Customer support tools

---

## Debug Tools Reference

### Force Non-Premium Mode
**Location:** Settings > Developer Testing
**Purpose:** Test as non-premium user even with active subscription
**Default:** ON (for testing)

### Trial Debug
**Location:** Settings > Developer Testing > Trial Debug
**Features:**
- View trial period details (start, expiry, days remaining)
- Reset to Day 1
- Skip to Day 7, 13, 15
- View heritage unlock stats
- Trigger manual unlocks
- View paywall trigger stats
- Reset paywall state

### RevenueCat Toggle
**Location:** Settings > Developer Testing
**Purpose:** Enable/disable RevenueCat integration (Phase 3)
**Default:** OFF (disabled until implementation)

---

## Troubleshooting

### "Cannot connect to iTunes Store"
- **Cause:** Not logged into sandbox account
- **Fix:** Settings > App Store > Sign in with sandbox account

### Purchases not showing up
- **Cause:** Subscription status cache not refreshed
- **Fix:** Force quit app and relaunch, or wait 24 hours for cache refresh

### Trial always shows 14 days
- **Cause:** Force Non-Premium Mode is ON
- **Fix:** Toggle off to test real subscription status

### Paywall won't show
- **Cause:** 3-strike rule active from previous dismissals
- **Fix:** Trial Debug > Reset Paywall State

### Heritage recipes not unlocking
- **Cause:** Trial expired or no blind boxes revealed
- **Fix:**
  - Check trial status in Trial Debug
  - Reveal blind boxes in Collections tab first

---

## Testing Checklist

### Phase 2 Complete Testing

- [ ] **Trial Experience**
  - [ ] Trial starts on first launch
  - [ ] 14-day countdown visible in Settings
  - [ ] Countdown visible in Collections toolbar
  - [ ] Countdown visible in HeritageUnlockView
  - [ ] Day 7 paywall trigger works
  - [ ] Day 13 urgency paywall works
  - [ ] Day 15 post-trial experience works

- [ ] **Paywall Triggers**
  - [ ] First recipe soft wall
  - [ ] 5 recipes or Day 7 soft wall
  - [ ] Day 13 urgency soft wall
  - [ ] Heritage unlock soft wall (2.5s delay)
  - [ ] Video import hard wall
  - [ ] ASMR credit exhaustion hard wall
  - [ ] 3-strike rule activates after 3 dismissals

- [ ] **Subscription Management**
  - [ ] Settings shows current plan for subscribers
  - [ ] Monthly can upgrade to Annual
  - [ ] Annual can downgrade (via iOS Settings)
  - [ ] Manage Subscription button opens iOS sheet
  - [ ] Lifetime purchase shows correctly

- [ ] **PaywallView**
  - [ ] All 3 plans show for new users
  - [ ] Only Annual/Lifetime show for upgraders
  - [ ] Upgrade UI shows for Monthly subscribers
  - [ ] CTA text changes correctly
  - [ ] Soft walls dismissible
  - [ ] Hard walls not dismissible

- [ ] **Post-Trial**
  - [ ] Heritage unlocks stop after trial
  - [ ] Post-trial banner shows in Collections
  - [ ] TrialExpiredView shows 4 options
  - [ ] Unlocked recipes remain accessible
  - [ ] Video imports blocked
  - [ ] ASMR blocked

- [ ] **ASMR System**
  - [ ] Usage badge shows credits
  - [ ] "Unlimited" for premium users
  - [ ] Paywall when credits exhausted
  - [ ] Credit count accurate

---

## Next Steps

1. **Test all scenarios above** using debug tools
2. **Configure StoreKit testing** for purchase flows
3. **Create TestFlight build** for device testing
4. **Set up App Store Connect** products
5. **Test with sandbox accounts** on real devices
6. **Phase 3:** Implement RevenueCat for production

---

## Quick Test Command Reference

```swift
// Simulate Monthly subscription
UserDefaults.standard.set("monthly", forKey: "subscription_status")
UserDefaults.standard.set("com.rationalestudio.heirloom.monthly", forKey: "cached_product_id")

// Simulate Annual subscription
UserDefaults.standard.set("annual", forKey: "subscription_status")
UserDefaults.standard.set("com.rationalestudio.heirloom.annual", forKey: "cached_product_id")

// Simulate Lifetime purchase
UserDefaults.standard.set("lifetime", forKey: "subscription_status")
UserDefaults.standard.set("com.rationalestudio.heirloom.lifetime", forKey: "cached_product_id")

// Reset to free user
UserDefaults.standard.set("none", forKey: "subscription_status")
UserDefaults.standard.removeObject(forKey: "cached_product_id")

// Reset paywall state
UserDefaults.standard.set(0, forKey: "soft_wall_dismiss_count")
UserDefaults.standard.removeObject(forKey: "last_soft_wall_timestamp")

// Reset trial
let now = Date()
UserDefaults.standard.set(now, forKey: "first_launch_date")
UserDefaults.standard.set(now.addingTimeInterval(14 * 24 * 60 * 60), forKey: "trial_expiry_date")
```

Add these to TrialDebugView for quick access during testing.
