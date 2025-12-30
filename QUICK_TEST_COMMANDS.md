# Heirloom Testing - Quick Command Reference

**Use this in a separate terminal window during device testing**

---

## Setup Commands

```bash
# 1. Navigate to project
cd /Users/matthanson/Heirloom

# 2. List connected devices
xcrun xctrace list devices
# Copy your device UDID

# 3. Set device UDID variable (replace with yours)
export DEVICE_UDID="YOUR_DEVICE_UDID_HERE"
echo "Testing device: $DEVICE_UDID"
```

---

## Build & Deploy

```bash
# Clean build
xcodebuild clean -project Heirloom.xcodeproj -scheme Heirloom

# Build for device (Release configuration)
xcodebuild -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -configuration Release \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  build

# Or use Xcode UI: Product > Run (⌘R)
```

---

## Live Log Monitoring

```bash
# Monitor all Heirloom logs with CloudKit/Sync filtering
xcrun devicectl device info logs --device $DEVICE_UDID 2>&1 | \
  grep -E "(Heirloom|CloudKit|Sync|SwiftData|✅|❌|📤|📥|🔄|Error)" | \
  tee heirloom_live.log

# In separate terminal, tail the log file:
tail -f heirloom_live.log
```

---

## Specific Log Searches

```bash
# Export full logs to file
xcrun devicectl device info logs --device $DEVICE_UDID > heirloom_full.log

# Search for initialization
grep "🚀 \[Heirloom\]" heirloom_full.log

# Search for errors
grep "❌" heirloom_full.log
grep -i "error" heirloom_full.log

# Search for CloudKit sync
grep -E "(📤|📥|🔄)" heirloom_full.log

# Search for share creation
grep "📤 Creating share" heirloom_full.log
grep "✅ Share created" heirloom_full.log

# Search for ingredient sync
grep "ingredients" heirloom_full.log | grep -E "(📤|📥)"

# Search for OCR processing
grep "🔍 Step" heirloom_full.log
grep "recipe(s)" heirloom_full.log
```

---

## CloudKit Verification

```bash
# Open CloudKit Dashboard
open "https://icloud.developer.apple.com/dashboard"

# Check build version
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  Heirloom/Resources/Info.plist

/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  Heirloom/Resources/Info.plist
```

---

## Bug Logging Template

```bash
# Quick bug log (append to TESTFLIGHT_BUGS.md)
cat >> TESTFLIGHT_BUGS.md << 'EOF'

---
## Bug #___: [Title]
**P[0-3]** | [Component] | Open

**Reproduce:**
1.
2.
3.

**Expected:**

**Actual:**

**Device:** iPhone [model], iOS [version]
**Frequency:** Always/Sometimes/Once

**Logs:**
```
[paste relevant log lines]
```

EOF
```

---

## Test Progress Tracking

```bash
# Create a test session log
echo "# Test Session $(date)" > test_session.md
echo "" >> test_session.md

# Log each test result
log_test() {
  local suite=$1
  local test=$2
  local result=$3
  echo "- [$result] $suite - $test" >> test_session.md
}

# Example usage:
log_test "CloudKit Sync" "Test 2.1: Initial Sync" "✅ PASS"
log_test "CloudKit Sync" "Test 2.2: Recipe Upload" "❌ FAIL"
log_test "CloudKit Sync" "Test 2.3: Ingredient Upload" "✅ PASS"

# View progress
cat test_session.md
```

---

## Performance Monitoring

```bash
# Monitor memory usage
xcrun xctrace record --device $DEVICE_UDID \
  --template 'App Memory' \
  --output heirloom_memory.trace

# Stop with Ctrl+C after testing

# Open in Instruments
open heirloom_memory.trace
```

---

## Simulator Testing (if needed)

```bash
# List simulators
xcrun simctl list devices available | grep iPhone

# Boot a simulator
xcrun simctl boot "iPhone 16 Pro"

# Install app to simulator
xcrun simctl install booted path/to/Heirloom.app

# Launch app
xcrun simctl launch booted com.matthanson.heirloom

# Monitor simulator logs
xcrun simctl spawn booted log stream --predicate 'process == "Heirloom"' | \
  grep -E "(CloudKit|Sync|✅|❌|📤|📥|🔄)"
```

---

## Quick Test Checklist

Use during testing to track completion:

```bash
# Copy to clipboard and paste in terminal
cat << 'EOF'
Heirloom Test Checklist:

App Launch:
[ ] First launch completes
[ ] Empty state displays
[ ] Console shows initialization

CloudKit Sync:
[ ] Initial sync runs
[ ] Recipe uploads to CloudKit
[ ] Ingredients upload to CloudKit
[ ] Pull-to-refresh works
[ ] Sync spinner appears

Sharing:
[ ] Share link creates successfully
[ ] iOS share sheet opens (Bug #4)
[ ] Copy link works (Bug #6)
[ ] Retry works (Bug #5)
[ ] Device B accepts share

Camera & OCR:
[ ] Camera fills screen
[ ] OCR processes recipe
[ ] Progress indicator shows
[ ] Multi-recipe detection works

UX Polish:
[ ] Swipe to delete works
[ ] Swipe to favorite works
[ ] Haptics fire correctly
[ ] Touch targets are 44×44pt+

Accessibility:
[ ] VoiceOver navigation works
[ ] Dynamic Type scales text
EOF
```

---

## Emergency Commands

```bash
# Kill all background processes
killall -9 xcrun

# Restart device
xcrun devicectl device reboot --device $DEVICE_UDID

# Uninstall app from device
# (Must do manually from device Settings → General → iPhone Storage)

# Reset CloudKit Development environment
# (Must do manually in CloudKit Dashboard)
open "https://icloud.developer.apple.com/dashboard"
# Settings → Development Environment → Reset

# Clear Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Heirloom-*
```

---

## After Testing

```bash
# Archive test logs
mkdir -p test_results/$(date +%Y%m%d)
cp heirloom_*.log test_results/$(date +%Y%m%d)/
cp test_session.md test_results/$(date +%Y%m%d)/
cp TESTFLIGHT_BUGS.md test_results/$(date +%Y%m%d)/

# Zip for sharing
zip -r test_results_$(date +%Y%m%d).zip test_results/$(date +%Y%m%d)/

# Generate summary
echo "Test Summary - $(date)" > test_summary.md
echo "=====================" >> test_summary.md
echo "" >> test_summary.md
echo "Total Tests: 30" >> test_summary.md
grep -c "✅ PASS" test_session.md >> test_summary.md
grep -c "❌ FAIL" test_session.md >> test_summary.md
echo "" >> test_summary.md
echo "Bugs Found:" >> test_summary.md
grep "^## Bug #" TESTFLIGHT_BUGS.md | tail -5 >> test_summary.md
```

---

## Useful Aliases (Optional)

Add to your `.zshrc` or `.bashrc`:

```bash
alias heirloom-logs='xcrun devicectl device info logs --device $DEVICE_UDID 2>&1 | grep -E "(Heirloom|CloudKit|✅|❌|📤|📥)"'
alias heirloom-errors='xcrun devicectl device info logs --device $DEVICE_UDID 2>&1 | grep "❌"'
alias heirloom-sync='xcrun devicectl device info logs --device $DEVICE_UDID 2>&1 | grep -E "(📤|📥|🔄)"'
alias heirloom-build='cd /Users/matthanson/Heirloom && xcodebuild -project Heirloom.xcodeproj -scheme Heirloom -configuration Release'
```

Then use:
```bash
heirloom-logs      # Monitor logs
heirloom-errors    # Show only errors
heirloom-sync      # Show sync events
heirloom-build     # Build project
```

---

**Last Updated**: 2025-12-29
**For**: Heirloom iOS App Testing
**Guide**: See COMPREHENSIVE_TESTING_GUIDE.md for full procedures
