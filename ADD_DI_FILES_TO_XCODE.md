# Adding DI Files to Xcode Project

## Quick Steps

1. **Open Xcode project:**
   ```bash
   open Heirloom.xcodeproj
   ```

2. **Add DI folder to project:**
   - In Project Navigator, right-click on `Heirloom/Core` folder
   - Select "Add Files to 'Heirloom'..."
   - Navigate to `Heirloom/Core/DI/`
   - Select the `DI` folder
   - Check "Create groups"
   - Check "Add to targets: Heirloom"
   - Click "Add"

## Files to Add

- `ServiceContainer.swift` - Main DI container
- `ServiceEnvironment.swift` - SwiftUI environment integration
- `ServiceProtocols.swift` - Service protocol definitions
- `ServiceRegistration.swift` - Service registration configuration

## Verify Addition

After adding, you should see:
```
Heirloom/
  Core/
    DI/
      ServiceContainer.swift
      ServiceEnvironment.swift
      ServiceProtocols.swift
      ServiceRegistration.swift
```

## Build Test

Run a build to ensure files compile:
```bash
xcodebuild -project Heirloom.xcodeproj -scheme Heirloom \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Expected: Build should succeed (or show missing protocol conformances that we'll fix next)
