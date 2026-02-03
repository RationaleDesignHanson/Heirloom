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

## Switch Cookbook Imports to Haiku (Cost Optimization)
**Priority**: P2 (Cost)
**Description**: Cookbook PDF imports currently use Claude Sonnet 4.5 (~$6.30 per 200 pages), could use Haiku (~$0.60) for 10x cost savings
- Current: Sonnet 4.5 for all vision tasks including PDFs
- Proposed: Haiku for PDF cookbook imports (still very accurate for printed recipes)
- Estimated savings: ~$5.70 per 200-page cookbook (~90% reduction)

**Cost Comparison**:
- Sonnet 4.5: $3.00 input / $15.00 output per 1M tokens
- Haiku: $0.25 input / $1.25 output per 1M tokens

**Implementation**:
- Update AIConfiguration.swift `model(for:)` function
- Change `.pdfVision` case from Sonnet to Haiku
- Keep Sonnet for video/handwriting (where quality matters more)
- Test accuracy on sample cookbooks before deploying

**Testing Criteria**:
- Test on 20+ cookbook pages of varying quality
- Verify ingredient extraction accuracy (>95%)
- Verify instruction extraction accuracy (>95%)
- Check handling of multi-column layouts
- Ensure recipe title extraction works

**Location**: AIConfiguration.swift:268

**Status**: Deferred until testing complete with Sonnet baseline

---

*Created: 2026-02-03*
*Deferred from: API Gateway Migration testing*
