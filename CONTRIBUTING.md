# Contributing to Heirloom

Thank you for your interest in contributing to Heirloom! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

### Prerequisites

- **Xcode 15.2+** (for iOS 17+ support)
- **macOS 14+** (Sonoma or later)
- **Swift 5.9+**
- **Firebase account** (for backend services)

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/RationaleDesignHanson/Heirloom.git
   cd Heirloom
   ```

2. **Configure Firebase**
   - Create a Firebase project at https://console.firebase.google.com
   - Download `GoogleService-Info.plist` and add to `Heirloom/Resources/`
   - Enable Firebase Authentication (Apple, Google)
   - Enable Firestore Database
   - Enable Cloud Storage

3. **Configure API Keys**
   - Copy `Config.xcconfig.template` to `Config.xcconfig` (if template exists)
   - Or create `Config.xcconfig` with required keys:
     ```
     DEFAULT_ANTHROPIC_KEY = your_anthropic_api_key
     REVERSED_CLIENT_ID = com.googleusercontent.apps.YOUR_CLIENT_ID
     ```
   - **DO NOT commit `Config.xcconfig`** - it's in `.gitignore`

4. **Open in Xcode**
   ```bash
   open Heirloom.xcodeproj
   ```

5. **Build and Run**
   - Select a simulator (iPhone 15 recommended)
   - Press `Cmd + R` to build and run
   - Tests: `Cmd + U`

## 📋 Development Workflow

### Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/your-feature-name` - Feature branches
- `fix/issue-description` - Bug fixes
- `hotfix/critical-fix` - Emergency production fixes

### Before Starting Work

1. Create an issue describing the feature/bug
2. Fork the repository (external contributors)
3. Create a feature branch from `develop`
4. Keep commits focused and atomic

### Making Changes

1. **Write Tests**
   - Add unit tests for new functionality
   - Update existing tests if behavior changes
   - Ensure all tests pass: `xcodebuild test -project Heirloom.xcodeproj -scheme Heirloom -destination 'platform=iOS Simulator,name=iPhone 15'`

2. **Follow Code Style**
   - Use SwiftLint (configuration in `.swiftlint.yml`)
   - Follow Apple's Swift naming conventions
   - Add doc comments for public APIs
   - Keep functions small and focused

3. **Update Documentation**
   - Update README.md if adding user-facing features
   - Add/update doc comments for code changes
   - Update relevant docs in `/docs/` if applicable

4. **Commit Guidelines**
   - Use clear, descriptive commit messages
   - Format: `Type: Brief description`
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
   - Example: `feat: Add recipe scaling with precision math`
   - Include `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>` if AI-assisted

### Pull Requests

1. **Before Opening PR**
   - Ensure all tests pass
   - Run SwiftLint: `swiftlint lint`
   - Update CHANGELOG.md (if exists)
   - Rebase on latest `develop`

2. **PR Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix (non-breaking change)
   - [ ] New feature (non-breaking change)
   - [ ] Breaking change (fix or feature)
   - [ ] Documentation update

   ## Testing
   - [ ] Unit tests added/updated
   - [ ] Manual testing performed
   - [ ] All tests pass locally

   ## Screenshots (if applicable)
   Add screenshots for UI changes

   ## Checklist
   - [ ] Code follows project style guidelines
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] No console warnings
   - [ ] Tested on iPhone 15 simulator
   ```

3. **PR Review Process**
   - CI must pass (GitHub Actions tests)
   - At least one approval required
   - Address review comments
   - Squash commits before merge (if requested)

## 🧪 Testing

### Running Tests

**All Tests**:
```bash
xcodebuild test \
  -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Specific Test**:
```bash
xcodebuild test \
  -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:HeirloomTestsV2/YourTestClass/testMethod
```

**Code Coverage**:
```bash
xcodebuild test \
  -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES
```

### Testing Guidelines

- **Unit Tests**: Test business logic, models, services
- **UI Tests**: Test critical user flows (import, share, edit)
- **Integration Tests**: Test Firebase interactions with emulator
- **Mock External Dependencies**: Use mocks for Firebase, AI services
- **Test Edge Cases**: Empty states, errors, network failures
- **Test Performance**: Large recipe collections, image loading

### Firebase Emulator Testing

```bash
# Start Firebase emulators
firebase emulators:start

# Run tests against emulator
# (Configure app to use localhost:8080 for Firestore)
```

## 🛠️ Code Guidelines

### Swift Style

- **Naming**: Use clear, descriptive names
- **Functions**: Keep under 50 lines, single responsibility
- **Comments**: Explain "why", not "what"
- **SwiftUI**: Prefer small, reusable view components
- **Async/Await**: Use structured concurrency, avoid closures

### Architecture

- **MVVM Pattern**: Views, ViewModels, Models
- **Dependency Injection**: Use `ServiceContainer` for services
- **Feature Flags**: Use `FeatureRegistry` for experimental features
- **SwiftData**: Models in `Core/Models/`, use `@Model` macro
- **Firebase**: Services in `Core/Services/Firebase/`

### Security

- **No Hardcoded Secrets**: Use `Config.xcconfig`
- **Validate User Input**: Sanitize before Firebase writes
- **Test Security Rules**: Use Firebase emulator
- **PII Handling**: Don't log sensitive user data
- **Auth Checks**: Verify auth state before Firebase operations

## 📚 Documentation

### Code Documentation

Use doc comments for public APIs:
```swift
/// Imports a recipe from a URL
/// - Parameter url: The URL of the recipe page
/// - Returns: The imported Recipe object
/// - Throws: ImportError if URL is invalid or import fails
func importRecipe(from url: URL) async throws -> Recipe {
    // Implementation
}
```

### Project Documentation

- **Architecture decisions**: Document in `/docs/architecture/`
- **API changes**: Update relevant doc files
- **Breaking changes**: Add migration guide
- **New features**: Update feature documentation

## 🐛 Reporting Bugs

### Bug Report Template

```markdown
## Description
Clear description of the bug

## Steps to Reproduce
1. Step 1
2. Step 2
3. Expected vs Actual behavior

## Environment
- iOS Version:
- Device/Simulator:
- App Version:

## Logs/Screenshots
Attach relevant logs or screenshots
```

### Critical Bugs

For security vulnerabilities or data loss bugs:
- **DO NOT** open a public issue
- Email security@[domain].com (replace with actual)
- Provide detailed reproduction steps
- Wait for acknowledgment before disclosure

## 💡 Feature Requests

- Check existing issues first
- Describe the problem it solves
- Provide use cases and examples
- Consider implementation complexity
- Tag with `enhancement` label

## 📝 Commit Messages

### Format

```
<type>: <subject>

<body (optional)>

<footer (optional)>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactor (no behavior change)
- `test`: Adding/updating tests
- `chore`: Build process, tooling, dependencies

### Examples

```
feat: Add recipe scaling with precision math

Implements intelligent recipe scaling that avoids decimal ranges.
Uses ingredient parsing to determine scalable quantities.

Closes #123
```

```
fix: Prevent duplicate recipe imports

Fixed issue where importing same URL twice created duplicates.
Now checks for existing recipes before import.

Fixes #456
```

## 🔄 Release Process

### Version Numbering

- `MAJOR.MINOR.PATCH` (e.g., 1.2.3)
- `MAJOR`: Breaking changes
- `MINOR`: New features (backward compatible)
- `PATCH`: Bug fixes

### Release Checklist

- [ ] All tests passing
- [ ] Update version in Xcode
- [ ] Update CHANGELOG.md
- [ ] Create release notes
- [ ] Tag release: `git tag v1.2.3`
- [ ] Build TestFlight release
- [ ] Submit to App Store Review

## 📞 Communication

### Questions?

- Open a GitHub Discussion
- Tag with `question` label
- Check existing discussions first

### Stay Updated

- Watch the repository for updates
- Follow release notes
- Join community discussions

## 📄 License

By contributing to Heirloom, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to Heirloom!** 🎉

For questions or assistance, open an issue or discussion on GitHub.
