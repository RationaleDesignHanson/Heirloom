# Public Recipe Moderation System

## Overview

The moderation system allows users to report inappropriate public recipes and provides auto-moderation capabilities.

## Components

### Client-Side (iOS)

1. **ReportReason enum** (`ReportPublicRecipeService.swift`)
   - Inappropriate content
   - Spam or misleading
   - Copyright violation
   - Offensive or hateful
   - Not a recipe
   - Other

2. **ReportPublicRecipeService** (`ReportPublicRecipeService.swift`)
   - `reportRecipe()` - Submit report to Firestore
   - `hasUserReportedRecipe()` - Check if user already reported
   - Increments `reportCount` on public recipe

3. **ReportConfirmationSheet** (`ReportConfirmationSheet.swift`)
   - UI for selecting report reason
   - Optional additional details field
   - Prevents duplicate reports from same user
   - Success/error handling

4. **PublicRecipeDetailView** - Report button integration
   - Menu with "Report Recipe" option
   - Opens ReportConfirmationSheet

### Backend (Cloud Functions)

**monitorPublicRecipeReports** (`firebase/functions/index.js`)
- Triggered when new report created
- Logs report for admin review
- Auto-hides recipe if reportCount >= 10
- Preserves data for admin review (soft delete)

### Firestore Structure

#### publicRecipeReports/{reportId}
```javascript
{
  publicRecipeId: "abc123",
  reporterId: "user-uid",
  reason: "inappropriate",  // ReportReason raw value
  details: "Contains offensive language",  // Optional
  status: "pending",  // pending, reviewed, action_taken, dismissed
  createdAt: Timestamp,
  reviewedAt: Timestamp | null,
  reviewedBy: "admin-uid" | null,
  actionTaken: "removed" | "warned_creator" | null
}
```

#### publicRecipes/{recipeId} - Added fields
```javascript
{
  // ... existing fields ...
  reportCount: 0,
  lastReportedAt: Timestamp | null,
  isHidden: false,
  hiddenReason: "auto_moderation" | "admin_action" | null,
  hiddenAt: Timestamp | null,
  hiddenByReportCount: 10
}
```

## Admin Queries

### View all pending reports
```javascript
db.collection('publicRecipeReports')
  .where('status', '==', 'pending')
  .orderBy('createdAt', 'desc')
  .get()
```

### View reports for specific recipe
```javascript
db.collection('publicRecipeReports')
  .where('publicRecipeId', '==', 'RECIPE_ID')
  .orderBy('createdAt', 'desc')
  .get()
```

### View auto-hidden recipes
```javascript
db.collection('publicRecipes')
  .where('isHidden', '==', true)
  .where('hiddenReason', '==', 'auto_moderation')
  .get()
```

### View most reported recipes
```javascript
db.collection('publicRecipes')
  .orderBy('reportCount', 'desc')
  .limit(20)
  .get()
```

## Auto-Moderation Rules

- **Threshold:** 10 reports
- **Action:** Recipe is soft-deleted (isHidden = true)
- **Preservation:** All recipe data preserved for admin review
- **Reversible:** Admin can unhide recipe by setting isHidden = false

## Future Enhancements

### Admin Dashboard
- Web-based admin panel for reviewing reports
- Approve/dismiss reports
- Ban users for repeated violations
- View report patterns and analytics

### Enhanced Auto-Moderation
- ML-based content filtering
- Different thresholds by report reason
- User reputation scoring
- Rate limiting (prevent report spam)

### Notifications
- Email admins when new reports arrive
- Notify recipe creator when action taken
- Alert for patterns of abuse

### Advanced Features
- Appeal process for creators
- Warning system before hiding
- Community moderation (trusted users)
- Report analytics dashboard

## Testing Checklist

- [ ] User can report a public recipe
- [ ] Report reason is required
- [ ] Additional details are optional
- [ ] Duplicate reports are prevented
- [ ] Report count increments on public recipe
- [ ] Auto-moderation triggers at 10 reports
- [ ] Hidden recipes don't appear in discovery
- [ ] Report data preserved for admin review
- [ ] Analytics tracked for report submissions
