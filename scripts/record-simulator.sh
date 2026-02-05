#!/bin/bash
#
# record-simulator.sh
# Records iOS Simulator screen while running a test or for a set duration
#
# Usage:
#   ./scripts/record-simulator.sh [options]
#
# Options:
#   -o, --output <file>     Output filename (default: recording-{timestamp}.mp4)
#   -d, --duration <secs>   Recording duration in seconds (default: 30)
#   -t, --test <test>       Run specific UI test (e.g., HeirloomUITests/RecipeImportUITests)
#   -s, --simulator <id>    Simulator ID or name (default: booted, or boots iPhone 16 Pro)
#   -l, --launch-only       Just launch the app, don't run tests
#   --no-boot               Don't boot simulator (assume already running)
#   -h, --help              Show this help message
#
# Examples:
#   ./scripts/record-simulator.sh -d 15 -l                    # Record app launch for 15s
#   ./scripts/record-simulator.sh -t HeirloomUITests -d 60    # Record while running all UI tests
#   ./scripts/record-simulator.sh -o onboarding.mp4 -d 20 -l  # Record to specific file
#

set -e

# Default values
OUTPUT=""
DURATION=30
TEST=""
SIMULATOR_ID=""
LAUNCH_ONLY=false
NO_BOOT=false
SCHEME="Heirloom"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_help() {
    head -30 "$0" | tail -27 | sed 's/^# //' | sed 's/^#//'
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -t|--test)
            TEST="$2"
            shift 2
            ;;
        -s|--simulator)
            SIMULATOR_ID="$2"
            shift 2
            ;;
        -l|--launch-only)
            LAUNCH_ONLY=true
            shift
            ;;
        --no-boot)
            NO_BOOT=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Set default output filename with timestamp
if [[ -z "$OUTPUT" ]]; then
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    OUTPUT="$PROJECT_DIR/recordings/recording-$TIMESTAMP.mp4"
fi

# Ensure output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT")
mkdir -p "$OUTPUT_DIR"

# Find or boot simulator
get_simulator() {
    if [[ -n "$SIMULATOR_ID" ]]; then
        echo "$SIMULATOR_ID"
        return
    fi

    # Check if any simulator is booted
    BOOTED=$(xcrun simctl list devices | grep -i "booted" | head -1 | grep -oE '[A-F0-9-]{36}' || true)

    if [[ -n "$BOOTED" ]]; then
        echo "$BOOTED"
    else
        # Find iPhone 16 Pro simulator
        FOUND=$(xcrun simctl list devices available | grep "iPhone 16 Pro" | grep -v "Max" | head -1 | grep -oE '[A-F0-9-]{36}' || true)
        if [[ -z "$FOUND" ]]; then
            # Fallback to any iPhone
            FOUND=$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -oE '[A-F0-9-]{36}' || true)
        fi
        echo "$FOUND"
    fi
}

boot_simulator() {
    local sim_id=$1

    # Check if already booted
    STATE=$(xcrun simctl list devices | grep "$sim_id" | grep -o "Booted" || true)

    if [[ "$STATE" != "Booted" ]]; then
        log_info "Booting simulator..."
        xcrun simctl boot "$sim_id" 2>/dev/null || true

        # Wait for boot
        sleep 3

        # Open Simulator app
        open -a Simulator
        sleep 2
    fi
}

cleanup() {
    log_info "Cleaning up..."

    # Stop recording if still running
    if [[ -n "$RECORD_PID" ]] && kill -0 "$RECORD_PID" 2>/dev/null; then
        kill -INT "$RECORD_PID" 2>/dev/null || true
        wait "$RECORD_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Main execution
log_info "Heirloom Simulator Recorder"
echo ""

# Get simulator
SIM_ID=$(get_simulator)

if [[ -z "$SIM_ID" ]]; then
    log_error "No simulator found. Please install a simulator or specify one with -s"
    exit 1
fi

SIM_NAME=$(xcrun simctl list devices | grep "$SIM_ID" | sed 's/(.*//' | xargs)
log_info "Using simulator: $SIM_NAME"

# Boot if needed
if [[ "$NO_BOOT" != true ]]; then
    boot_simulator "$SIM_ID"
    log_success "Simulator ready"
fi

# Start recording
log_info "Starting recording: $OUTPUT"
log_info "Duration: ${DURATION}s"
echo ""

xcrun simctl io "$SIM_ID" recordVideo --codec=h264 --force "$OUTPUT" &
RECORD_PID=$!

sleep 1  # Give recording time to start

# Run test or launch app
if [[ -n "$TEST" ]]; then
    log_info "Running test: $TEST"

    # Run test with timeout
    timeout "${DURATION}s" xcodebuild test \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$SIM_ID" \
        -only-testing:"$TEST" \
        -quiet \
        2>&1 | while read line; do echo "  $line"; done || true

elif [[ "$LAUNCH_ONLY" == true ]]; then
    log_info "Launching app..."

    # Get bundle ID
    BUNDLE_ID="com.rationaledesign.heirloom"

    # Terminate if running
    xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
    sleep 0.5

    # Launch app
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"
    log_success "App launched"

    # Wait for duration
    log_info "Recording for ${DURATION}s..."
    sleep "$DURATION"
else
    # Just record for duration
    log_info "Recording for ${DURATION}s (no app action)..."
    sleep "$DURATION"
fi

# Stop recording
log_info "Stopping recording..."
kill -INT "$RECORD_PID" 2>/dev/null || true
wait "$RECORD_PID" 2>/dev/null || true
RECORD_PID=""

sleep 1

# Verify output
if [[ -f "$OUTPUT" ]]; then
    SIZE=$(du -h "$OUTPUT" | cut -f1)
    log_success "Recording saved: $OUTPUT ($SIZE)"

    # Open in Finder
    echo ""
    read -p "Open in Finder? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open -R "$OUTPUT"
    fi
else
    log_error "Recording failed - no output file created"
    exit 1
fi
