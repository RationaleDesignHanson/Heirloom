# Known Issues - Heritage On-Demand System

## UI State Issues

### Blind Boxes Show as Unrevealed on Second Device
**Severity**: Low (cosmetic)
**Status**: Deferred

**Issue**: When signing in on a second device after revealing blind boxes on the first device, the blind boxes still appear visually unrevealed (show as blind boxes in UI) even though the auto-reveal logic runs successfully in the background.

**User Impact**:
- User must tap the blind box once to "reveal" it
- Correct recipes download and appear (sync works perfectly)
- Just requires one extra tap - not blocking

**Expected Behavior**:
Blind boxes should appear pre-revealed on second device, showing the collections immediately without requiring a tap.

**Root Cause**:
The auto-reveal logic in `HeirloomApp.seedHeritageRecipesAfterAuth()` runs asynchronously after sign-in. By the time it marks blind boxes as `isRevealed = true`, the CollectionsListView has already rendered with the unrevealed state. SwiftUI's @Query doesn't detect the state change or the view hasn't refreshed.

**Potential Fixes** (for later):
1. Add explicit UI refresh after auto-reveal completes
2. Move auto-reveal earlier in the auth flow (before views load)
3. Add `@Published` property or notification to trigger view update
4. Show loading state until auto-reveal check completes

**Workaround**:
Tap the blind box once - recipes will appear immediately since they were already downloaded by auto-reveal.

**Files Involved**:
- `/Users/matthanson/Heirloom/Heirloom/App/HeirloomApp.swift` (lines 954-1012)
- `/Users/matthanson/Heirloom/Heirloom/Features/Collections/CollectionsListView.swift`

---

## Future Enhancements

### Loading Indicator for Auto-Reveal
When auto-revealing on second device, show a brief loading indicator instead of displaying unrevealed blind boxes.

### Sync Status Badge
Add visual indicator in Collections tab showing "Synced from [Device Name]" for cross-device clarity.
