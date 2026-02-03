# Polish Items - Low Priority

## Generated Recipe Images Not Working
**Priority**: P3 (Polish)
**Description**: Generated recipes appear before images are ready
- Recipe shows up immediately after generation
- Image generation may be failing silently or taking too long
- Not blocking core functionality

**Investigation Needed**:
- Check if RecipeImageGeneratorProtocol is configured
- Check logs for image generation errors
- May need to add loading state for image
- Consider showing placeholder until image ready

**Location**: RecipeGenerationService.swift:145-153

---

## Collection Cards Missing "NEW" Badge for Daily Unlocks
**Priority**: P2 (UX)
**Description**: When new recipes are unlocked daily, collection cards don't show any badge
- Daily unlocks add recipes to collections
- Users have to open each collection to discover new content
- No visual indicator on collection card that new recipes were added

**Expected Behavior**:
- Collection card should show "NEW" badge or count when it contains newly unlocked recipes
- Badge should clear after user views the collection
- Similar to how individual recipe cards show "NEW" badges

**Testing**:
- Discovered during Daily Unlocks testing (Day 1→2 progression)
- 2 new recipes added to Victory Kitchen collection
- Collection card showed no indication of new content

**Location**: Collection card UI - RecipeCollectionCard component

---

*Created: 2026-02-03*
*Deferred from: API Gateway Migration testing*
