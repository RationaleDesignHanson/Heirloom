#!/bin/bash

# Firebase Migration Progress Tracker
# Usage:
#   ./migration-tracker.sh status              - Show current progress
#   ./migration-tracker.sh start <phase>       - Start a phase
#   ./migration-tracker.sh complete <phase>    - Complete a phase
#   ./migration-tracker.sh step <phase> <step> - Mark a step complete
#   ./migration-tracker.sh note <phase> "msg"  - Add a note to phase
#   ./migration-tracker.sh log "message"       - Add timestamped log entry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROGRESS_FILE="$PROJECT_ROOT/.migration-progress.json"
LOG_FILE="$PROJECT_ROOT/.migration-log.txt"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required. Install with: brew install jq${NC}"
    exit 1
fi

# Ensure files exist
if [ ! -f "$PROGRESS_FILE" ]; then
    echo -e "${RED}Error: Progress file not found at $PROGRESS_FILE${NC}"
    exit 1
fi

# Add log entry
log_entry() {
    local message="$1"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $message" >> "$LOG_FILE"
}

# Show current status
show_status() {
    echo -e "${BLUE}=== Firebase Migration Progress ===${NC}\n"

    local current_phase=$(jq -r '.currentPhase' "$PROGRESS_FILE")
    local start_date=$(jq -r '.startDate' "$PROGRESS_FILE")

    echo -e "Migration started: ${GREEN}$start_date${NC}"
    echo -e "Current phase: ${YELLOW}Phase $current_phase${NC}\n"

    # Show all phases
    for phase in {0..10}; do
        local phase_name=$(jq -r ".phases[\"$phase\"].name" "$PROGRESS_FILE")
        local phase_status=$(jq -r ".phases[\"$phase\"].status" "$PROGRESS_FILE")
        local estimated_hours=$(jq -r ".phases[\"$phase\"].estimatedHours" "$PROGRESS_FILE")

        case $phase_status in
            "completed")
                echo -e "${GREEN}✓${NC} Phase $phase: $phase_name ($estimated_hours hrs)"
                ;;
            "in_progress")
                echo -e "${YELLOW}▶${NC} Phase $phase: $phase_name ($estimated_hours hrs) ${YELLOW}[IN PROGRESS]${NC}"

                # Show steps for current phase
                local steps=$(jq -r ".phases[\"$phase\"].steps[] | \"  \" + (if .completed then \"✓\" else \"○\" end) + \" \" + .step" "$PROGRESS_FILE")
                if [ -n "$steps" ]; then
                    echo "$steps"
                fi
                ;;
            "pending")
                echo -e "  Phase $phase: $phase_name ($estimated_hours hrs)"
                ;;
        esac
    done

    echo ""

    # Show total hours
    local total_hours=67
    local completed_hours=$(jq '[.phases[] | select(.status == "completed") | .estimatedHours] | add' "$PROGRESS_FILE")
    echo -e "Progress: ${GREEN}$completed_hours${NC} / $total_hours hours completed\n"
}

# Start a phase
start_phase() {
    local phase="$1"

    if [ -z "$phase" ]; then
        echo -e "${RED}Error: Phase number required${NC}"
        exit 1
    fi

    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq ".currentPhase = $phase | .phases[\"$phase\"].status = \"in_progress\" | .phases[\"$phase\"].startDate = \"$current_date\"" "$PROGRESS_FILE" > "$PROGRESS_FILE.tmp"
    mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

    local phase_name=$(jq -r ".phases[\"$phase\"].name" "$PROGRESS_FILE")
    echo -e "${GREEN}Started Phase $phase: $phase_name${NC}"
    log_entry "Started Phase $phase: $phase_name"
}

# Complete a phase
complete_phase() {
    local phase="$1"

    if [ -z "$phase" ]; then
        echo -e "${RED}Error: Phase number required${NC}"
        exit 1
    fi

    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq ".phases[\"$phase\"].status = \"completed\" | .phases[\"$phase\"].completedDate = \"$current_date\"" "$PROGRESS_FILE" > "$PROGRESS_FILE.tmp"
    mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

    local phase_name=$(jq -r ".phases[\"$phase\"].name" "$PROGRESS_FILE")
    echo -e "${GREEN}✓ Completed Phase $phase: $phase_name${NC}"
    log_entry "Completed Phase $phase: $phase_name"
}

# Mark a step complete
complete_step() {
    local phase="$1"
    local step_index="$2"

    if [ -z "$phase" ] || [ -z "$step_index" ]; then
        echo -e "${RED}Error: Phase and step index required${NC}"
        exit 1
    fi

    jq ".phases[\"$phase\"].steps[$step_index].completed = true" "$PROGRESS_FILE" > "$PROGRESS_FILE.tmp"
    mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

    local step_name=$(jq -r ".phases[\"$phase\"].steps[$step_index].step" "$PROGRESS_FILE")
    echo -e "${GREEN}✓ Completed step: $step_name${NC}"
    log_entry "Phase $phase - Completed step: $step_name"
}

# Add note to phase
add_note() {
    local phase="$1"
    local note="$2"

    if [ -z "$phase" ] || [ -z "$note" ]; then
        echo -e "${RED}Error: Phase and note required${NC}"
        exit 1
    fi

    jq ".phases[\"$phase\"].notes = \"$note\"" "$PROGRESS_FILE" > "$PROGRESS_FILE.tmp"
    mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

    echo -e "${GREEN}Note added to Phase $phase${NC}"
    log_entry "Phase $phase - Note: $note"
}

# Add log entry only
add_log() {
    local message="$1"

    if [ -z "$message" ]; then
        echo -e "${RED}Error: Message required${NC}"
        exit 1
    fi

    log_entry "$message"
    echo -e "${GREEN}Log entry added${NC}"
}

# Main command dispatcher
case "$1" in
    status)
        show_status
        ;;
    start)
        start_phase "$2"
        ;;
    complete)
        complete_phase "$2"
        ;;
    step)
        complete_step "$2" "$3"
        ;;
    note)
        add_note "$2" "$3"
        ;;
    log)
        add_log "$2"
        ;;
    *)
        echo "Firebase Migration Progress Tracker"
        echo ""
        echo "Usage:"
        echo "  $0 status              - Show current progress"
        echo "  $0 start <phase>       - Start a phase"
        echo "  $0 complete <phase>    - Complete a phase"
        echo "  $0 step <phase> <step> - Mark a step complete (by index)"
        echo "  $0 note <phase> \"msg\"  - Add a note to phase"
        echo "  $0 log \"message\"       - Add timestamped log entry"
        echo ""
        echo "Example:"
        echo "  $0 status"
        echo "  $0 start 1"
        echo "  $0 step 1 0"
        echo "  $0 complete 1"
        exit 1
        ;;
esac
