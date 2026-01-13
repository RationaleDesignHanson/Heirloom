# Version Management

## Problem

Xcode projects with app extensions (like share extensions) require that the `CFBundleVersion` of the extension matches the main app. If these get out of sync, Xcode will show a warning:

```
warning: The CFBundleVersion of an app extension ('X') must match that of its containing parent app ('Y').
```

Additionally, Xcode uses build settings in `project.pbxproj` that can override values in `Info.plist` files:
- `MARKETING_VERSION` → `CFBundleShortVersionString` (e.g., "1.6.0")
- `CURRENT_PROJECT_VERSION` → `CFBundleVersion` (e.g., "7")

## Solution

Use the provided `update-version.sh` script to update version numbers consistently across all files.

### Usage

```bash
./update-version.sh <version> <build>
```

### Examples

```bash
# Update to version 1.7.0, build 8
./update-version.sh 1.7.0 8

# Update to version 2.0.0, build 1
./update-version.sh 2.0.0 1
```

### What It Does

The script updates version numbers in three locations:

1. **Main App Info.plist** (`Heirloom/Resources/Info.plist`)
   - Sets `CFBundleShortVersionString`
   - Sets `CFBundleVersion`

2. **Share Extension Info.plist** (`HeirloomShareExtension/Info.plist`)
   - Sets `CFBundleShortVersionString`
   - Sets `CFBundleVersion`

3. **Xcode Project File** (`Heirloom.xcodeproj/project.pbxproj`)
   - Updates all `MARKETING_VERSION` settings
   - Updates all `CURRENT_PROJECT_VERSION` settings
   - Creates a backup file before making changes

### After Running

The script will tell you what to commit:

```bash
git add Heirloom/Resources/Info.plist HeirloomShareExtension/Info.plist Heirloom.xcodeproj/project.pbxproj
git commit -m "Bump version to 1.7.0 (8)"
```

## Manual Updates (Not Recommended)

If you need to manually update versions, you must update **all three files**:

1. Edit `Heirloom/Resources/Info.plist`
2. Edit `HeirloomShareExtension/Info.plist`
3. Edit `Heirloom.xcodeproj/project.pbxproj` (search for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`)

**Always use the script to avoid version mismatches.**

## Version History

Current version: **1.6.0 (build 7)**

When incrementing versions:
- **Major version** (X.0.0): Breaking changes or major new features
- **Minor version** (1.X.0): New features, backwards compatible
- **Patch version** (1.0.X): Bug fixes only
- **Build number**: Increment for every build submitted to App Store Connect

## Troubleshooting

### Build Warning Still Appears

If you still see the CFBundleVersion warning after running the script:

1. Clean build folder: Product → Clean Build Folder (⇧⌘K)
2. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Heirloom-*
   ```
3. Rebuild the project

### Script Fails

- Ensure you're in the project root directory (where `update-version.sh` is located)
- Check that all three files exist at their expected paths
- Verify the script has execute permissions: `chmod +x update-version.sh`
