# SwiftLint Quick Start

**Status**: ✅ Configuration created, needs installation

---

## ✅ What's Done

Created `.swiftlint.yml` with sensible rules for Heirloom:
- Permissive for SwiftUI (longer lines, longer functions)
- Warnings instead of errors (don't block builds)
- Excludes test files from strict rules
- Custom rules for async/await and logging

---

## 📦 Installation (Choose One)

### Option 1: Homebrew (Recommended)
```bash
brew install swiftlint
```

### Option 2: Mint
```bash
mint install realm/SwiftLint
```

### Option 3: Download Binary
Download from: https://github.com/realm/SwiftLint/releases

---

## 🔍 Run Initial Audit

```bash
# Navigate to project
cd /Users/matthanson/Heirloom

# Run SwiftLint
swiftlint lint

# Save report
swiftlint lint --reporter markdown > swiftlint-report.md
```

**This will show**:
- Number of violations
- Severity (warning vs error)
- File locations
- Suggested fixes

---

## 🔧 Auto-Fix Issues

SwiftLint can automatically fix many issues:

```bash
# Preview what would be fixed (safe)
swiftlint --fix --dry-run

# Actually fix issues
swiftlint --fix
```

**Fixes**:
- Trailing whitespace
- Extra blank lines
- Unused imports
- Redundant code

---

## 🏗️ Xcode Integration (Optional)

Add SwiftLint to Xcode build process:

### Step 1: Add Build Phase
1. Open `Heirloom.xcodeproj`
2. Select Heirloom target → Build Phases
3. Click "+" → New Run Script Phase
4. Name it "SwiftLint"

### Step 2: Add Script
```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

### Step 3: Configure
- Move phase to be after "Compile Sources"
- Check "Based on dependency analysis" for faster builds

**Result**: SwiftLint runs on every build, shows warnings in Xcode.

---

## 📊 Baseline Report

After installing, run this to document current state:

```bash
cd /Users/matthanson/Heirloom

# Count violations
echo "SwiftLint Baseline Report - $(date)" > docs/quality/swiftlint-baseline.txt
echo "=================================" >> docs/quality/swiftlint-baseline.txt
swiftlint lint --quiet | tail -1 >> docs/quality/swiftlint-baseline.txt

# Full report
swiftlint lint --reporter markdown > docs/quality/swiftlint-report.md
```

---

## 🎯 What to Expect

**Typical findings in a project this size**:
- 50-200 warnings (spacing, naming, etc.)
- 0-10 errors (force unwraps, force casts)
- Many auto-fixable issues

**Priority**:
1. Fix errors (force unwraps in production code)
2. Auto-fix easy issues (swiftlint --fix)
3. Review warnings, fix selectively
4. Update .swiftlint.yml to disable noisy rules

---

## 🚫 Disabling Rules

If a rule is too noisy, disable it in `.swiftlint.yml`:

```yaml
disabled_rules:
  - rule_name_here
```

Or disable for specific lines in code:

```swift
// swiftlint:disable:next force_cast
let value = something as! String
```

---

## ✅ Success Criteria

**SwiftLint is working when**:
- ✅ `swiftlint lint` runs without error
- ✅ Shows violation count
- ✅ (Optional) Runs in Xcode builds
- ✅ Auto-fix resolves simple issues

---

## 📋 Quick Commands

```bash
# Audit
swiftlint lint

# Auto-fix
swiftlint --fix

# Specific files only
swiftlint lint --path Heirloom/Core/Services

# Check specific rule
swiftlint rules | grep rule_name

# Count violations
swiftlint lint --quiet
```

---

**Status**: Configuration ready, awaiting installation
**Time**: 5 minutes to install + 10 minutes to review results
**Next**: Run `brew install swiftlint` then `swiftlint lint`
