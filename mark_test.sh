#!/bin/bash

# Manual Testing Progress Tracker
# Usage: ./mark_test.sh <test-id> <pass|fail|skip> "[optional notes]"
#        ./mark_test.sh status
#        ./mark_test.sh reset

PROGRESS_FILE="test_progress.json"

# Initialize progress file if it doesn't exist
init_progress() {
    if [ ! -f "$PROGRESS_FILE" ]; then
        cat > "$PROGRESS_FILE" << 'JSON'
{
  "session_info": {
    "tester": "",
    "date": "",
    "build": "",
    "device": "",
    "ios_version": "",
    "started_at": "",
    "last_updated": ""
  },
  "summary": {
    "total_tests": 45,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "not_run": 45,
    "pass_rate": 0
  },
  "tests": {}
}
JSON
        echo "✅ Initialized $PROGRESS_FILE"
    fi
}

# Update session info
update_session() {
    local field=$1
    local value=$2
    
    jq ".session_info.$field = \"$value\" | .session_info.last_updated = \"$(date)\"" "$PROGRESS_FILE" > tmp.$$.json && mv tmp.$$.json "$PROGRESS_FILE"
}

# Mark a test result
mark_test() {
    local test_id=$1
    local result=$2
    local notes=${3:-""}
    
    if [ -z "$test_id" ] || [ -z "$result" ]; then
        echo "Usage: ./mark_test.sh <test-id> <pass|fail|skip> \"[notes]\""
        exit 1
    fi
    
    # Validate result
    if [[ ! "$result" =~ ^(pass|fail|skip)$ ]]; then
        echo "❌ Error: Result must be 'pass', 'fail', or 'skip'"
        exit 1
    fi
    
    # Update test result
    jq ".tests[\"$test_id\"] = {
        \"result\": \"$result\",
        \"notes\": \"$notes\",
        \"timestamp\": \"$(date)\"
    } | .session_info.last_updated = \"$(date)\"" "$PROGRESS_FILE" > tmp.$$.json && mv tmp.$$.json "$PROGRESS_FILE"
    
    # Recalculate summary
    update_summary
    
    # Print result with emoji
    case $result in
        pass) echo "✅ $test_id: PASSED" ;;
        fail) echo "❌ $test_id: FAILED - $notes" ;;
        skip) echo "⏭️  $test_id: SKIPPED - $notes" ;;
    esac
}

# Update summary statistics
update_summary() {
    local passed=$(jq '[.tests[] | select(.result == "pass")] | length' "$PROGRESS_FILE")
    local failed=$(jq '[.tests[] | select(.result == "fail")] | length' "$PROGRESS_FILE")
    local skipped=$(jq '[.tests[] | select(.result == "skip")] | length' "$PROGRESS_FILE")
    local total=45
    local not_run=$((total - passed - failed - skipped))
    local pass_rate=0
    
    if [ $((passed + failed)) -gt 0 ]; then
        pass_rate=$(awk "BEGIN {printf \"%.1f\", ($passed / ($passed + $failed)) * 100}")
    fi
    
    jq ".summary.passed = $passed |
        .summary.failed = $failed |
        .summary.skipped = $skipped |
        .summary.not_run = $not_run |
        .summary.pass_rate = $pass_rate" "$PROGRESS_FILE" > tmp.$$.json && mv tmp.$$.json "$PROGRESS_FILE"
}

# Show status
show_status() {
    echo ""
    echo "==================================================="
    echo "   PUBLIC RECIPE DISCOVERY - TESTING PROGRESS"
    echo "==================================================="
    echo ""
    
    # Session info
    local tester=$(jq -r '.session_info.tester' "$PROGRESS_FILE")
    local date=$(jq -r '.session_info.date' "$PROGRESS_FILE")
    local device=$(jq -r '.session_info.device' "$PROGRESS_FILE")
    local last_updated=$(jq -r '.session_info.last_updated' "$PROGRESS_FILE")
    
    if [ -n "$tester" ] && [ "$tester" != "" ]; then
        echo "Tester: $tester"
    fi
    if [ -n "$date" ] && [ "$date" != "" ]; then
        echo "Date: $date"
    fi
    if [ -n "$device" ] && [ "$device" != "" ]; then
        echo "Device: $device"
    fi
    if [ -n "$last_updated" ] && [ "$last_updated" != "" ]; then
        echo "Last Updated: $last_updated"
    fi
    echo ""
    
    # Summary
    local passed=$(jq -r '.summary.passed' "$PROGRESS_FILE")
    local failed=$(jq -r '.summary.failed' "$PROGRESS_FILE")
    local skipped=$(jq -r '.summary.skipped' "$PROGRESS_FILE")
    local not_run=$(jq -r '.summary.not_run' "$PROGRESS_FILE")
    local pass_rate=$(jq -r '.summary.pass_rate' "$PROGRESS_FILE")
    
    echo "OVERALL PROGRESS:"
    echo "  ✅ Passed:   $passed"
    echo "  ❌ Failed:   $failed"
    echo "  ⏭️  Skipped:  $skipped"
    echo "  ⚪ Not Run:  $not_run"
    echo "  📊 Pass Rate: ${pass_rate}%"
    echo ""
    
    # P0 Tests
    echo "P0 TESTS (Critical Path - MUST PASS):"
    show_priority_status "P0"
    echo ""
    
    # P1 Tests
    echo "P1 TESTS (Core Functionality):"
    show_priority_status "P1"
    echo ""
    
    # P2 Tests
    echo "P2 TESTS (Polish & Edge Cases):"
    show_priority_status "P2"
    echo ""
    
    # P3 Tests
    echo "P3 TESTS (Accessibility):"
    show_priority_status "P3"
    echo ""
    
    # Failed tests detail
    local failed_count=$(jq '[.tests[] | select(.result == "fail")] | length' "$PROGRESS_FILE")
    if [ "$failed_count" -gt 0 ]; then
        echo "==================================================="
        echo "FAILED TESTS (Need Attention):"
        echo "==================================================="
        jq -r '.tests | to_entries[] | select(.value.result == "fail") | "❌ \(.key): \(.value.notes)"' "$PROGRESS_FILE"
        echo ""
    fi
    
    echo "==================================================="
}

# Show priority-specific status
show_priority_status() {
    local priority=$1
    local total=0
    local passed=0
    local failed=0
    
    case $priority in
        P0) total=12 ;;
        P1) total=18 ;;
        P2) total=10 ;;
        P3) total=5 ;;
    esac
    
    # Count passed/failed for this priority
    for i in $(seq -w 1 20); do
        local test_id="${priority}-${i}"
        local result=$(jq -r ".tests[\"$test_id\"].result // \"not_run\"" "$PROGRESS_FILE")
        
        if [ "$result" = "pass" ]; then
            ((passed++))
        elif [ "$result" = "fail" ]; then
            ((failed++))
        fi
    done
    
    local not_run=$((total - passed - failed))
    local symbol="⚪"
    
    if [ $passed -eq $total ]; then
        symbol="✅"
    elif [ $failed -gt 0 ]; then
        symbol="❌"
    elif [ $passed -gt 0 ]; then
        symbol="🔄"
    fi
    
    echo "  $symbol $passed/$total passed, $failed failed, $not_run not run"
}

# Reset progress
reset_progress() {
    rm -f "$PROGRESS_FILE"
    init_progress
    echo "✅ Progress reset. Ready for new testing session."
}

# Main
init_progress

case ${1:-} in
    status)
        show_status
        ;;
    reset)
        reset_progress
        ;;
    session)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: ./mark_test.sh session <field> <value>"
            echo "Fields: tester, date, build, device, ios_version"
            exit 1
        fi
        update_session "$2" "$3"
        echo "✅ Updated session info: $2 = $3"
        ;;
    "")
        echo "Usage:"
        echo "  ./mark_test.sh <test-id> <pass|fail|skip> \"[notes]\""
        echo "  ./mark_test.sh status"
        echo "  ./mark_test.sh session <field> <value>"
        echo "  ./mark_test.sh reset"
        echo ""
        echo "Examples:"
        echo "  ./mark_test.sh P0-01 pass"
        echo "  ./mark_test.sh P0-02 fail \"Recipe not appearing in discovery\""
        echo "  ./mark_test.sh P0-03 skip \"Blocked by P0-02\""
        echo "  ./mark_test.sh session tester \"John Doe\""
        echo "  ./mark_test.sh status"
        ;;
    *)
        mark_test "$1" "$2" "$3"
        ;;
esac
