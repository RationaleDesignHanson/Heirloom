# Setup: Add Seasoning Defaults to Project

## Issue
The file `SeasoningDefaults.swift` exists but isn't yet added to the Xcode project, causing a build error:
```
error: cannot find 'SeasoningDefaults' in scope
```

## Solution

### Method 1: Add via Xcode (Recommended)
1. Open `Heirloom.xcodeproj` in Xcode
2. Navigate to `Heirloom/Features/Scaling/Services/` in the Project Navigator
3. Right-click on the `Services` folder → "Add Files to Heirloom..."
4. Select `SeasoningDefaults.swift`
5. Ensure "Add to targets: Heirloom" is checked
6. Click "Add"
7. Build (⌘B) - should now compile successfully

### Method 2: Command Line (Alternative)
```bash
cd /Users/matthanson/Heirloom

# Use ruby script to add file to Xcode project
ruby << 'EOF'
require 'xcodeproj'

project_path = 'Heirloom.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Services group
services_group = project.main_group['Heirloom']['Features']['Scaling']['Services']

# Add the file
file_ref = services_group.new_reference('SeasoningDefaults.swift')

# Add to target
target = project.targets.first
target.add_file_references([file_ref])

project.save
EOF

# Rebuild
xcodebuild -scheme Heirloom -sdk iphonesimulator build
```

Note: Requires xcodeproj gem (`gem install xcodeproj`)

## Verification

After adding the file, verify it compiles:
```bash
xcodebuild -scheme Heirloom -sdk iphonesimulator -quiet build 2>&1 | grep -E "(error:|BUILD SUCCEEDED)"
```

Should see: `BUILD SUCCEEDED` or `** BUILD SUCCEEDED **`

## Files Created

- ✅ `Heirloom/Features/Scaling/Services/SeasoningDefaults.swift`
- ⏳ Needs to be added to Xcode project

## Next Steps

After adding the file:
1. Run the app
2. Test scaling a recipe with "salt to taste"
3. Verify it shows suggested amounts like: "Suggested: ¾-1¼ tsp (adjust to taste)"
4. Run pending tests from `docs/pending_tests.md`
