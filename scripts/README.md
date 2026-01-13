# Heirloom Scripts

CLI tools for managing features, coverage, and CI/CD validation.

## Feature Management

### `feature-tool.sh`

Main CLI wrapper for all feature management tasks.

```bash
# List all features
./scripts/feature-tool.sh list

# Show test coverage report
./scripts/feature-tool.sh coverage

# Validate feature lifecycle gates
./scripts/feature-tool.sh gates

# Validate feature dependencies
./scripts/feature-tool.sh validate
```

## Coverage Validation

### `check-coverage.swift`

Validates test coverage against thresholds.

**Usage:**
```bash
swift scripts/check-coverage.swift [coverage.json]
```

**Thresholds:**
- Overall: 60% minimum
- Critical paths:
  - SubscriptionManager: 100% (revenue critical)
  - PaywallManager: 100% (revenue critical)
  - HeritageUnlockTracker: 100% (revenue critical)
  - StoreManager: 80% (payment logic)
  - FirebaseShareService: 80% (data integrity)
  - VideoRecipeProcessor: 80% (complex flow)

**Example:**
```bash
# Run tests with coverage
xcodebuild test -scheme Heirloom -enableCodeCoverage YES -resultBundlePath TestResults

# Generate coverage JSON
xcrun xccov view --report --json TestResults.xcresult > coverage.json

# Check coverage
swift scripts/check-coverage.swift coverage.json
```

**Exit codes:**
- 0: All thresholds met
- 1: One or more thresholds violated

## Feature Lifecycle Gates

### `check-feature-gates.swift`

Validates that features meet test coverage requirements based on their lifecycle state.

**Usage:**
```bash
swift scripts/check-feature-gates.swift
```

**Coverage Requirements by State:**
- Development: 0% (no requirement)
- Alpha: 40%
- Beta: 60%
- Released: 80%
- Deprecated: 80%
- Removed: 0% (no longer applicable)

**Example output:**
```
recipeManagement      [  Released] 85% (req: 80%) ✅ PASS
videoImport           [  Released] 80% (req: 80%) ✅ PASS
asmrProcessing        [      Beta] 75% (req: 60%) ✅ PASS
discovery             [     Alpha] 30% (req: 40%) ❌ FAIL
```

**Exit codes:**
- 0: All gates satisfied
- 1: One or more features violate lifecycle gates

## Feature Listing

### `list-features.swift`

Lists all features with their state, coverage, and category.

**Usage:**
```bash
# List all features
swift scripts/list-features.swift

# List features in specific state
swift scripts/list-features.swift Released
swift scripts/list-features.swift Beta
```

**Example output:**
```
──────────────────────────────────────────────
Core
──────────────────────────────────────────────
  ✅ Recipe Management           [85% ████████░░]   Released
  ✅ Collections                 [100% ██████████]   Released

──────────────────────────────────────────────
Premium
──────────────────────────────────────────────
  ✅ Video Import                [80% ████████░░]   Released 💎
  🚧 ASMR Processing             [75% ███████░░░]       Beta 💎

Summary
──────────────────────────────────────────────
Total features: 19
By State:
  • Released: 13
  • Beta: 2
  • Alpha: 1
  • Development: 3
Average Coverage: 68%
Premium Features: 6
```

## Dependency Validation

### `validate-features.swift`

Validates feature dependencies for consistency and detects circular dependencies.

**Usage:**
```bash
swift scripts/validate-features.swift
```

**Checks:**
- All dependencies exist
- No dependencies on removed features
- No circular dependencies

**Example output:**
```
✅ All dependencies valid!
No circular dependencies detected
No missing or removed dependencies
```

**Exit codes:**
- 0: All dependencies valid
- 1: Dependency errors found

## CI/CD Integration

These scripts are integrated into `.github/workflows/tests.yml`:

```yaml
- name: Check Coverage Threshold
  run: |
    swift scripts/check-coverage.swift coverage.json

- name: Check Feature Lifecycle Gates
  run: |
    swift scripts/check-feature-gates.swift
```

### CI Workflow

1. **Unit Tests**: Run all unit tests with coverage enabled
2. **Generate Coverage**: Export coverage data as JSON
3. **Check Coverage**: Validate against thresholds (60% overall, critical paths)
4. **Check Gates**: Ensure features meet lifecycle requirements
5. **Fail Build**: If any check fails, CI build fails

## Adding a New Feature

When adding a new feature, update these files:

1. **Feature.swift** - Add feature enum case
2. **FeatureRegistryData.swift** - Add metadata
3. **check-feature-gates.swift** - Add to features array
4. **list-features.swift** - Add to features array
5. **validate-features.swift** - Add with dependencies

## Best Practices

### Coverage Thresholds

- **Critical Paths (100%)**: Revenue logic, payments, subscriptions
- **Released Features (80%)**: High confidence for production
- **Beta Features (60%)**: Validated logic before release
- **Alpha Features (40%)**: Early testing, still iterating

### Feature States

- **Development**: Early implementation, no coverage required
- **Alpha**: Internal testing, 40% coverage
- **Beta**: Public beta, 60% coverage
- **Released**: Production, 80% coverage
- **Deprecated**: Marked for removal, maintain 80%
- **Removed**: No longer in codebase

### Adding Tests

When adding tests:
1. Run `./scripts/feature-tool.sh gates` to see coverage gaps
2. Prioritize critical paths first (subscription, payments)
3. Bring beta features to 60% before release
4. Ensure released features maintain 80%

### CI Failures

If CI fails:

**Coverage Below Threshold:**
```bash
# Locally check which files need tests
./scripts/feature-tool.sh coverage

# Focus on critical paths first
```

**Feature Gate Violation:**
```bash
# Check which features need tests
./scripts/feature-tool.sh gates

# Add tests to meet lifecycle requirements
```

**Dependency Error:**
```bash
# Validate dependencies
./scripts/feature-tool.sh validate

# Fix circular dependencies or missing features
```

## Making Scripts Executable

```bash
chmod +x scripts/*.sh
chmod +x scripts/*.swift
```

## Requirements

- macOS with Xcode 15+
- Swift 5.9+
- Bash (for feature-tool.sh)

## Troubleshooting

**"Command not found" error:**
```bash
# Make scripts executable
chmod +x scripts/feature-tool.sh

# Run with explicit path
./scripts/feature-tool.sh list
```

**Coverage file not found:**
```bash
# Ensure tests ran with coverage
xcodebuild test -scheme Heirloom -enableCodeCoverage YES

# Generate coverage.json
xcrun xccov view --report --json TestResults.xcresult > coverage.json
```

**Swift script fails to run:**
```bash
# Check Xcode command line tools
xcode-select --print-path

# Install if missing
xcode-select --install
```
