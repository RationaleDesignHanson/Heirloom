# Unit Tests TODO

## Priority: High
**Created:** 2026-01-13
**Status:** Pending for next major command

## Subscription System Unit Tests

The subscription and paywall system needs comprehensive unit tests covering:

### 1. SubscriptionManager Tests

**Core Functionality:**
- [ ] Trial initialization (first launch, blind box reveal)
- [ ] Trial expiry calculation
- [ ] Days remaining calculation
- [ ] `isPremium` property (various states)
- [ ] `isInTrial` property (active, expired, never started)
- [ ] `canUpgrade` / `canDowngrade` logic
- [ ] Product ID tracking

**Trial Management:**
- [ ] `initializeTrialOnBlindBoxReveal()` - starts 14-day trial
- [ ] `initializeTrialIfNeeded()` - respects debug flag
- [ ] `adjustTrialForPlan()` - changes from annual to monthly
- [ ] Trial doesn't initialize twice
- [ ] Trial respects debug_force_non_premium flag

**Status Updates:**
- [ ] `refreshStatus()` - cache TTL behavior
- [ ] `handleActiveSubscription()` - monthly, annual, lifetime
- [ ] `handleTrialStatus()` - active, expired, none
- [ ] `updateStatus()` - persistence and analytics

### 2. PaywallManager Tests

**Trigger Logic:**
- [ ] Soft wall triggers (firstRecipeAdded, fiveRecipesOrDay7, day13Urgency)
- [ ] Hard wall triggers (urlImport, cookbookScan, cloudSync)
- [ ] `shouldShow()` - respects 3-strike rule
- [ ] `shouldShow()` - respects cooldown periods (48hr, 72hr)

**State Management:**
- [ ] `show()` / `dismiss()` - increments dismiss count
- [ ] 3-strike rule activation (after 3 dismissals)
- [ ] Cooldown period calculation
- [ ] Persistence across app launches

### 3. HeritageUnlockTracker Tests

**Unlock Logic:**
- [ ] `unlockDailyBatch()` - requires trial/premium
- [ ] `unlockDailyBatch()` - requires revealed blind boxes
- [ ] `unlockDailyBatch()` - respects daily quota (~7/day)
- [ ] `unlockDailyBatch()` - stops after trial expires
- [ ] `selectBalancedRecipes()` - 5 Literary Kitchen, 2 other

**State Tracking:**
- [ ] `hasUnlocksAvailableToday` - daily check
- [ ] `recipesToUnlockToday` - catch-up logic
- [ ] `totalUnlockedCount` / `totalRecipesRemaining`
- [ ] `isUnlocked()` - per-recipe check
- [ ] `startTrialPeriod()` - only starts once

**Migration:**
- [ ] `migrateExistingUsers()` - grandfather old users
- [ ] `resetTrialTracking()` - clears all state

### 4. PaywallView Tests

**Display Logic:**
- [ ] Shows all 3 plans for new users
- [ ] Shows only Annual+Lifetime for Monthly upgraders
- [ ] Hides upgrade options for Annual/Lifetime users
- [ ] CTA text changes correctly per plan
- [ ] Soft wall shows "Maybe later" button
- [ ] Hard wall hides dismiss button

**Upgrade Flow:**
- [ ] Header changes for upgraders
- [ ] Plan badges change for upgraders
- [ ] Default selection is Annual for upgraders

### 5. Integration Tests

**Blind Box Reveal Flow:**
- [ ] Blind boxes seed correctly after onboarding
- [ ] Reveal marks all boxes as revealed
- [ ] Trial starts on reveal (SubscriptionManager)
- [ ] Heritage trial starts on reveal (HeritageUnlockTracker)
- [ ] First batch unlocks immediately after reveal
- [ ] Correct number of recipes unlocked (7 total: 5+2)

**Trial Progression:**
- [ ] Day 1: Trial active, 14 days remaining, daily unlock works
- [ ] Day 7: Soft wall triggers after recipe save
- [ ] Day 13: Urgency soft wall triggers
- [ ] Day 15: Trial expired, no more unlocks, post-trial UI shows

**Premium Gates:**
- [ ] Video import blocked for non-premium (with 3-strike)
- [ ] ASMR blocked when credits exhausted
- [ ] Heritage recipes locked after trial expires
- [ ] Premium users bypass all gates

### 6. Edge Cases

**Race Conditions:**
- [ ] Blind box reveal + immediate unlock batch
- [ ] Multiple simultaneous trial checks
- [ ] Rapid paywall dismissals

**Data Consistency:**
- [ ] Trial dates sync between managers
- [ ] UnlockedRecipeIds persist correctly
- [ ] Paywall state survives app restart

**Boundary Conditions:**
- [ ] Day 0 trial (just started)
- [ ] Day 14 trial (last day)
- [ ] Day 15 trial (expired)
- [ ] 100 recipes unlocked (quota met)
- [ ] 3 paywall dismissals (strike rule activates)

## Test Infrastructure Needed

### Mocking
- [ ] Mock StoreKit transactions
- [ ] Mock UserDefaults for clean state
- [ ] Mock ModelContext for SwiftData
- [ ] Mock Date/Calendar for time manipulation

### Helpers
- [ ] Trial state builder (set to any day)
- [ ] Unlock state builder (set any unlock count)
- [ ] Paywall state builder (set dismiss count)
- [ ] Recipe factory (create test recipes)

### Test Utilities
```swift
// Example utilities needed
func setTrialDay(_ day: Int)
func setUnlockedCount(_ count: Int)
func setPaywallDismissCount(_ count: Int)
func createMockRecipe(heritageCollectionId: String) -> Recipe
func simulateBlindBoxReveal()
```

## Testing Strategy

### Unit Tests (XCTest)
- Fast, isolated tests for each class
- Mock all external dependencies
- Focus on business logic

### Integration Tests
- Test interactions between components
- Use in-memory SwiftData container
- Verify end-to-end flows

### UI Tests (optional, lower priority)
- Test actual paywall display
- Test blind box reveal animation
- Test trial countdown UI updates

## Estimated Effort
- **SubscriptionManager tests**: 4-6 hours
- **PaywallManager tests**: 2-3 hours
- **HeritageUnlockTracker tests**: 3-4 hours
- **PaywallView tests**: 2-3 hours
- **Integration tests**: 3-4 hours
- **Test infrastructure**: 2-3 hours

**Total**: 16-23 hours for comprehensive coverage

## Priority Order
1. **Critical**: SubscriptionManager (trial logic is core)
2. **High**: HeritageUnlockTracker (unlock logic is complex)
3. **High**: PaywallManager (3-strike rule is subtle)
4. **Medium**: Integration tests (catch regressions)
5. **Low**: PaywallView (mostly UI, manual testing OK)

## References
- XCTest documentation
- SwiftData testing guide
- StoreKit Configuration Files (for sandbox testing)

---

**Note**: This list was created as a reminder for future work. The subscription system is complete and working, but unit tests will provide confidence for future changes and catch regressions.
