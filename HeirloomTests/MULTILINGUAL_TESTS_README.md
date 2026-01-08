# Multilingual Recipe Import - Test Suite Documentation

**Status**: Test files created, ready for integration into test suite

**Last Updated**: 2026-01-06

---

## 📋 Overview

This document describes the comprehensive test suite for the multilingual recipe import feature. All test files have been created but are not yet integrated into the Xcode project or test suite.

### Test Coverage Summary

| Test Suite | Test Cases | Coverage Area | Status |
|-----------|------------|---------------|--------|
| `UnitConversionServiceTests.swift` | 20 tests | Regional unit conversions | ✅ Created |
| `MultilingualIngredientParsingTests.swift` | 45 tests | 6-language ingredient parsing | ✅ Created |
| `MultilingualRecipeImportTests.swift` | 25 tests | Integration & regression | ✅ Created |
| **Total** | **90 tests** | **Full multilingual stack** | 📦 Ready |

---

## 🧪 Test Files

### 1. UnitConversionServiceTests.swift

**Location**: `HeirloomTests/Services/UnitConversionServiceTests.swift` (320 lines)

**Purpose**: Validates regional unit conversion logic

**Test Categories**:
- **Japanese Cup Conversions** (200ml → 237ml US)
  - Single cup conversion
  - Multiple cup conversion
  - With original unit (カップ)

- **Korean Cup Conversions** (200ml → 237ml US)
  - Single cup conversion
  - With original unit (컵)

- **Korean Traditional Units**
  - 근 (geun) → grams (600g per 근)
  - 돈 (don) → grams (3.75g per 돈)

- **French Metric Cup** (250ml → 237ml US)
  - Single and multiple conversions

- **English Pass-Through** (No conversion)
  - English measurements unchanged
  - Nil language defaults to no conversion

- **Edge Cases**
  - Zero quantities
  - Nil units
  - Non-convertible units
  - Unsupported languages

- **Conversion Info Generation**
  - Info messages for each conversion type
  - No info for English or non-convertible units

**Key Assertions**:
```swift
// Example: Japanese cup conversion
XCTAssertEqual(result, 0.844, accuracy: 0.001)

// Example: Korean traditional unit
XCTAssertEqual(result, 600.0, accuracy: 0.1)

// Example: English pass-through
XCTAssertEqual(result, 1.0, accuracy: 0.001)
```

---

### 2. MultilingualIngredientParsingTests.swift

**Location**: `HeirloomTests/Services/MultilingualIngredientParsingTests.swift` (450 lines)

**Purpose**: Validates ingredient parsing across 6 languages

**Languages Tested**: French, Spanish, German, Japanese, Chinese, Korean

**Test Pattern (Per Language)**:
- Cup/tasse/taza/Tasse/カップ/杯/컵 parsing
- Tablespoon parsing (cuillère à soupe/cucharada/Esslöffel/大さじ/大勺/큰술)
- Teaspoon parsing (cuillère à café/cucharadita/Teelöffel/小さじ/小勺/작은술)
- Gram/kilogram parsing
- Liter/milliliter parsing
- Traditional units (Korean 근/돈)

**French Examples**:
```swift
"2 tasses de farine" → qty: 2, unit: "cup", name: "farine"
"3 cuillères à soupe d'huile" → qty: 3, unit: "tbsp", name: "huile"
"500 g de sucre" → qty: 500, unit: "g", name: "sucre"
```

**Japanese Examples**:
```swift
"2カップの小麦粉" → qty: 2, unit: "cup", name: "小麦粉"
"大さじ3の油" → qty: 3, unit: "tbsp", name: "油"
"300gの砂糖" → qty: 300, unit: "g", name: "砂糖"
```

**Korean Examples**:
```swift
"2컵 밀가루" → qty: 2, unit: "cup", name: "밀가루"
"1근 쇠고기" → qty: 1, unit: "g", name: "쇠고기" (for conversion)
"5돈 인삼" → qty: 5, unit: "g", name: "인삼" (for conversion)
```

**Zero-Regression Tests**:
- English parsing unchanged
- Default language parameter ("en")
- Identical output to pre-multilingual code

**Edge Cases**:
- Range parsing (2-3 cups, 1〜2カップ)
- No quantity ingredients
- Fractional quantities (1/2)
- Decimal quantities (German comma: 1,5)

---

### 3. MultilingualRecipeImportTests.swift

**Location**: `HeirloomTests/Integration/MultilingualRecipeImportTests.swift` (450 lines)

**Purpose**: End-to-end integration tests for the full import flow

**Test Categories**:

#### A. Ingredient Integration
- Ingredient with conversion metadata storage
- Recipe with multilingual metadata storage
- Ingredient order preservation

#### B. Language Detection Edge Cases
- English recipes have no metadata (nil fields)
- Multilingual fields are optional
- Partial metadata allowed

#### C. Database Persistence
- Save/fetch recipe with multilingual metadata
- Save/fetch ingredient with conversion metadata
- SwiftData persistence validation

#### D. Data Migration
- Legacy recipes without language fields work
- Backward compatibility guaranteed

#### E. Conversion Accuracy
- Japanese cup conversion math validation
- Korean 근 conversion math validation
- French metric cup conversion math validation

#### F. Zero-Regression Validation ⚠️ **CRITICAL**
- English ingredient parsing identical
- Default language parameter behavior
- English quantities never converted
- 5 common ingredient patterns validated

#### G. Performance
- Ingredient parsing performance (30 ingredients)
- Unit conversion performance (30 ingredients)
- Acceptable thresholds measured

**Key Zero-Regression Tests**:
```swift
func testEnglishIngredientParsingUnchanged() {
    // Tests 5 common patterns:
    // - "2 cups flour"
    // - "1 tbsp butter"
    // - "3 tsp salt"
    // - "500 g sugar"
    // - "2 lbs beef"

    // Each must parse identically to before
}
```

---

## 🎯 Critical Test Coverage

### Zero-Regression Guarantee

The following tests **must pass** before shipping:

1. **English ingredient parsing unchanged** (5 patterns)
2. **Default language parameter defaults to "en"**
3. **English quantities never converted** (all units)
4. **Legacy recipes without language fields work**
5. **English recipes have nil language metadata**

### Multilingual Feature Validation

The following tests validate new functionality:

1. **6 languages × 5-7 unit types = 35+ parsing tests**
2. **4 regional conversion types** (Japanese/Korean/French cups, Korean traditional)
3. **Edge cases** (zero, nil, unsupported languages)
4. **Database persistence** (save/fetch with metadata)
5. **Performance** (acceptable speed for 30 ingredients)

---

## 📊 Test Execution Plan

### Phase 1: Unit Tests (No External Dependencies)

These can run immediately:

```bash
# Unit conversion tests (20 tests)
xcodebuild test -only-testing:HeirloomTests/UnitConversionServiceTests

# Ingredient parsing tests (45 tests)
xcodebuild test -only-testing:HeirloomTests/MultilingualIngredientParsingTests

# Integration tests (25 tests)
xcodebuild test -only-testing:HeirloomTests/MultilingualRecipeImportTests
```

**Expected Results**:
- ✅ All unit tests should pass
- ✅ Zero external dependencies
- ✅ Fast execution (~5 seconds total)

### Phase 2: Zero-Regression Validation

Run existing English import tests:

```bash
# Existing regression test suite
xcodebuild test -only-testing:HeirloomTests/EnglishImportRegressionTests
```

**Expected Results**:
- ✅ All existing tests pass (100%)
- ✅ No performance regression
- ✅ No API changes to existing code

### Phase 3: Manual Integration Testing

Test real recipe URLs (requires backend services):

1. **French Recipe**
   - URL: https://www.marmiton.org/recettes/recette_cookies-chocolat_27408.aspx
   - Expected: Language detected as "fr", units converted

2. **Japanese Recipe**
   - URL: https://cookpad.com/recipe/[valid-id]
   - Expected: Language detected as "ja", cups converted (200ml → 237ml)

3. **Korean Recipe**
   - URL: https://www.10000recipe.com/recipe/[valid-id]
   - Expected: Language detected as "ko", 근/돈 converted

4. **Spanish Recipe**
   - URL: https://www.recetasgratis.net/[valid-recipe]
   - Expected: Language detected as "es", metric units handled

---

## 🔧 Integration Strategy

### Option 1: Add to Existing Test Targets

Add test files to `HeirloomTests` target in Xcode:

1. Open `Heirloom.xcodeproj`
2. Right-click `HeirloomTests` folder
3. Add existing files:
   - `UnitConversionServiceTests.swift`
   - `MultilingualIngredientParsingTests.swift`
   - `MultilingualRecipeImportTests.swift`
4. Ensure "Copy items if needed" is **unchecked**
5. Select `HeirloomTests` target

### Option 2: Create New Test Target

Create separate `HeirloomMultilingualTests` target:

```bash
# Benefits:
# - Isolated from existing tests
# - Can run independently
# - Cleaner organization

# Drawbacks:
# - More complex project structure
# - Requires target configuration
```

### Option 3: Integrate Gradually

Add one test suite at a time:

1. Week 1: `UnitConversionServiceTests` (20 tests)
2. Week 2: `MultilingualIngredientParsingTests` (45 tests)
3. Week 3: `MultilingualRecipeImportTests` (25 tests)

### Recommendation

**Start with Option 1** (add to existing target):
- Simplest integration path
- Existing infrastructure works
- Can run with existing CI/CD
- Easy to revert if issues arise

---

## 🚨 Known Limitations

### Not Tested (Out of Scope)

1. **Language Detection Service**
   - Requires mocking Claude API
   - Network-dependent
   - Should be tested separately with integration tests

2. **Translation Service**
   - Requires mocking Claude API
   - Network-dependent
   - Translation quality is subjective

3. **UI Tests**
   - Language badge display
   - Toggle functionality
   - Conversion note rendering
   - Should use UI testing framework

4. **Real Recipe Import**
   - Requires live URLs
   - Recipe websites may change
   - Should be manual QA process

### Test Gaps to Address

1. **Error Handling**
   - What if language detection fails?
   - What if translation API times out?
   - What if recipe has mixed languages?

2. **Concurrent Requests**
   - Multiple recipes importing simultaneously
   - Translation API rate limiting
   - Database concurrency

3. **Large Recipes**
   - 50+ ingredients
   - 30+ instructions
   - Performance at scale

---

## 📈 Success Metrics

### Required for Ship

- ✅ All 90 tests pass
- ✅ Zero-regression tests pass (100%)
- ✅ English recipe behavior unchanged
- ✅ Performance: <100ms for 30 ingredients
- ✅ Database persistence validated

### Optional (Nice to Have)

- ⚪ UI tests added
- ⚪ Integration tests with real URLs
- ⚪ Error handling tests
- ⚪ Concurrent import tests
- ⚪ Translation quality validation

---

## 🎯 Next Steps

1. **Integrate test files into Xcode project**
   - Add to `HeirloomTests` target
   - Verify compilation
   - Run one test suite to validate setup

2. **Run zero-regression validation**
   - Execute `EnglishImportRegressionTests`
   - Verify 100% pass rate
   - Compare performance metrics

3. **Run new test suites**
   - Execute each suite individually
   - Fix any failures
   - Validate all 90 tests pass

4. **Manual testing with real recipes**
   - Test each supported language
   - Verify UI displays correctly
   - Validate conversion accuracy

5. **CI/CD integration**
   - Add tests to build pipeline
   - Set pass threshold (100%)
   - Monitor performance trends

---

## 📝 Test File Locations

```
HeirloomTests/
├── Services/
│   ├── UnitConversionServiceTests.swift        (320 lines, 20 tests)
│   └── MultilingualIngredientParsingTests.swift (450 lines, 45 tests)
├── Integration/
│   └── MultilingualRecipeImportTests.swift     (450 lines, 25 tests)
└── MULTILINGUAL_TESTS_README.md                (this file)
```

**Total**: ~1,220 lines of test code, 90 comprehensive tests

---

## ✅ Validation Checklist

Before integrating tests:

- [ ] All test files compile without errors
- [ ] No external dependencies required
- [ ] Tests use in-memory database (no side effects)
- [ ] Zero-regression tests validate English behavior
- [ ] Performance tests have reasonable thresholds
- [ ] Edge cases covered (nil, zero, invalid)
- [ ] Documentation complete and accurate

After integration:

- [ ] All 90 tests pass
- [ ] CI/CD pipeline includes tests
- [ ] Test coverage report generated
- [ ] Performance baseline established
- [ ] Manual testing completed for all languages

---

## 🤝 Contributing

When adding new tests:

1. Follow existing test naming conventions
2. Group related tests with `// MARK:` comments
3. Use descriptive test names (`testJapaneseCupToUSCup`)
4. Add accuracy parameters for floating-point comparisons
5. Include failure messages in assertions
6. Test both happy path and edge cases

---

**End of Documentation**
