# Onboarding Visual Assets Needed

This document describes the visual assets required for the new onboarding flow.

## Assets to Create

### 1. Video Card Mockup (Optional)
**Filename**: `onboarding-video-card.png`
**Location**: `/Users/matthanson/Heirloom/Heirloom/Resources/Assets.xcassets/onboarding-video-card.imageset/`
**Specifications**:
- **Dimensions**: 400x700px @ 2x resolution (vertical video format, 9:16 aspect ratio)
- **Content**: Cooking scene showing pasta or other appealing dish
- **Style**: TikTok-style UI overlay (optional)
- **Format**: PNG with transparency support

**Status**: Optional - The current implementation uses a gradient placeholder with a play button that looks decent. If you want a more realistic mockup, create this asset.

### 2. Share Sheet Mockup (Optional)
**Filename**: `onboarding-share-sheet.png`
**Location**: `/Users/matthanson/Heirloom/Heirloom/Resources/Assets.xcassets/onboarding-share-sheet.imageset/`
**Specifications**:
- **Dimensions**: 600x400px @ 2x resolution
- **Content**: iOS share sheet design with Heirloom icon highlighted in app row
- **Style**: Native iOS share sheet appearance
- **Background**: Semi-transparent or white
- **Format**: PNG with transparency support

**Status**: Optional - The current implementation draws the share sheet programmatically with SwiftUI, which works well and adapts to different screen sizes.

## Implementation Notes

### Current Implementation
Both Screen 1 (Video Hero) and Screen 2 (Share Extension) use programmatic SwiftUI views instead of static images:

1. **Video Card**: Uses a gradient background with SF Symbols for the play button and badges
2. **Share Sheet**: Draws the iOS share sheet using SwiftUI components

### Benefits of Current Approach
- ✅ Adapts to different screen sizes automatically
- ✅ Supports dark mode out of the box
- ✅ No asset management overhead
- ✅ Easier to update and iterate
- ✅ Smaller app bundle size

### When to Create Static Assets
Consider creating static mockup images if:
- You want pixel-perfect control over the appearance
- You have high-quality photography/design assets
- You want to show actual app screenshots
- You need to match exact brand guidelines

### How to Add Assets (If Created)

1. **Open Xcode**: Open `Heirloom.xcodeproj`

2. **Navigate to Assets**:
   - In Xcode, go to `Heirloom/Resources/Assets.xcassets`

3. **Create Image Set**:
   - Right-click → New Image Set
   - Name it `onboarding-video-card` or `onboarding-share-sheet`

4. **Add Images**:
   - Drag your @1x, @2x, and @3x images into the appropriate slots
   - @2x is required, others are optional

5. **Update Code** (if using static images):
   ```swift
   // In OnboardingVideoHeroScreen.swift
   // Replace videoCardMock with:
   Image("onboarding-video-card")
       .resizable()
       .scaledToFit()
       .frame(height: 200)
       .cornerRadius(12)

   // In OnboardingShareExtensionScreen.swift
   // Replace shareSheetMock with:
   Image("onboarding-share-sheet")
       .resizable()
       .scaledToFit()
       .frame(maxWidth: .infinity)
   ```

## Existing Assets

The following assets are already present and used in the onboarding:
- ✅ `onboarding-grilled-cheese.jpg` - Used in Screen 4
- ✅ `onboarding-tomato-soup.jpg` - Used in Screen 4
- ✅ `ceramic-hero-book` - App icon (used throughout)

## Platform Icons

All platform icons use SF Symbols (built into iOS):
- TikTok: `play.square.stack`
- Instagram: `camera`
- YouTube: `play.rectangle`
- Safari: `safari`
- Photos: `photo`

No custom assets needed for these.

## Recommendation

**Keep the current programmatic implementation.** It works well, looks native, and doesn't require additional assets. Only create static mockups if you have specific design requirements or high-quality photography to showcase.

---

**Last Updated**: 2026-01-23
