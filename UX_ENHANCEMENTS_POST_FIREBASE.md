# UX Enhancements - Post Firebase Migration

Priority features to implement after Firebase migration is complete and stable.

## High Priority

### 1. Instruction Step Reordering
**Location:** RecipeEditorView.swift - Instructions Section
**Current:** Instructions cannot be reordered after authoring
**Desired:** Drag-and-drop reordering of instruction steps in case they're authored out of sequence
**Implementation:** Add `.onMove` modifier to instructions ForEach
**Effort:** Small (1-2 hours)

### 2. Ingredient Spelling Suggestions
**Location:** RecipeEditorView.swift / AIIngredientParser.swift
**Current:** AI parser accepts abbreviations but doesn't suggest corrections
**Desired:**
- Detect ambiguous abbreviations (e.g., "tbs" vs "tbsp")
- Detect potential misspellings
- Show inline suggestions/warnings to user
**Examples:**
- "tbs" → "Did you mean 'tbsp' (tablespoon)?"
- "fower" → "Did you mean 'flour'?"
**Implementation:**
- Enhance AI parsing prompt to return warnings
- Add UI feedback in ingredient input fields
**Effort:** Medium (4-6 hours)

### 3. Recipe Photo Preview in List
**Status:** Photo shows on recipe card but not in preview card
**Location:** RecipeCardView / AsyncRecipeImage
**Current:** Thumbnail not loading in preview card
**Desired:** Consistent image display across all views
**Effort:** Small (1-2 hours)

### 4. Add/Edit Photo After Recipe Creation
**Location:** RecipeEditorView.swift - init method
**Current:** When editing an existing recipe, the photo picker doesn't show or allow changing the existing image
**Desired:** Load existing recipe image on edit, allow changing/adding photos after creation
**Implementation:** In init, load recipe.loadImage() when editing existing recipe
**Effort:** Small (1-2 hours)

## Medium Priority

### 5. Ingredient Categorization Improvements
**Current:** Rule-based keyword matching
**Improvements Needed:**
- Add more common ingredients (currently missing some)
- Consider ML-based categorization for better accuracy
- User feedback when categorization seems wrong
**Effort:** Medium-Large (depends on ML approach)

## Status
- Created: 2025-12-30
- Last Updated: 2025-12-30
- Firebase Migration Status: In Progress (Phase 6 - Testing)

## Notes
- These enhancements should NOT block Firebase migration
- Prioritize Firebase stability and testing first
- Revisit this list after Firebase is production-ready
