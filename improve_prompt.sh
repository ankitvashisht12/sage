#!/bin/bash
#
# Prompt Improver (Two-Step Approach)
#
# Step 1: Claude analyzes gaps and produces a structured change plan
# Step 2: Claude applies the change plan to the prompt and outputs the complete file
#
# Backs up previous version before applying changes automatically.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
OUTPUT_FILE="$SCRIPT_DIR/output.jsonl"
REPORT_FILE="$SCRIPT_DIR/analysis_report.md"
STEP1_TEMPLATE="$SCRIPT_DIR/improve_prompt_template_step1.md"
STEP2_TEMPLATE="$SCRIPT_DIR/improve_prompt_template_step2.md"
BACKUPS_DIR="$SCRIPT_DIR/backups"
TEMP_DIR="$SCRIPT_DIR/.temp_improve"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Prompt Improver (Two-Step)                          ║"
    echo "║           Using Claude CLI                                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Get the next version number
get_next_version() {
    local max_version=0
    if [[ -d "$BACKUPS_DIR" ]]; then
        for dir in "$BACKUPS_DIR"/v*/; do
            if [[ -d "$dir" ]]; then
                local version_num
                version_num=$(basename "$dir" | sed 's/v//')
                if [[ "$version_num" -gt "$max_version" ]]; then
                    max_version=$version_num
                fi
            fi
        done
    fi
    echo $((max_version + 1))
}

# Create backup of current version
create_backup() {
    local version=$1
    local backup_dir="$BACKUPS_DIR/v$version"

    mkdir -p "$backup_dir"

    # Backup prompt
    if [[ -f "$PROMPT_FILE" ]]; then
        cp "$PROMPT_FILE" "$backup_dir/prompt.md"
        print_success "Backed up prompt.md"
    fi

    # Backup output
    if [[ -f "$OUTPUT_FILE" ]]; then
        cp "$OUTPUT_FILE" "$backup_dir/output.jsonl"
        print_success "Backed up output.jsonl"
    fi

    # Backup analysis report
    if [[ -f "$REPORT_FILE" ]]; then
        cp "$REPORT_FILE" "$backup_dir/analysis_report.md"
        print_success "Backed up analysis_report.md"
    fi

    # Create metadata
    local total_questions=0
    if [[ -f "$OUTPUT_FILE" ]]; then
        total_questions=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
    fi

    local overall_score=""
    if [[ -f "$REPORT_FILE" ]]; then
        overall_score=$(grep -i "overall score" "$REPORT_FILE" | grep -oE '[0-9]+%' | head -1 || echo "N/A")
    fi

    local metadata
    metadata=$(jq -n \
        --arg version "$version" \
        --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg questions "$total_questions" \
        --arg score "$overall_score" \
        '{
            version: ($version | tonumber),
            created_at: $created,
            total_questions: ($questions | tonumber),
            analysis_overall_score: $score
        }')

    echo "$metadata" > "$backup_dir/metadata.json"
    print_success "Created metadata.json"

    echo ""
    print_info "Backup saved to: $backup_dir"
}

# Validate that the output is a proper prompt file
validate_prompt() {
    local file=$1

    # Check it starts with a markdown heading
    if ! head -1 "$file" | grep -q "^#"; then
        return 1
    fi

    # Check it contains required placeholders
    if ! grep -q "{{KB_CONTENT}}" "$file"; then
        return 1
    fi

    if ! grep -q "{{SOURCE_METADATA}}" "$file"; then
        return 1
    fi

    if ! grep -q "{{USER_QUERIES}}" "$file"; then
        return 1
    fi

    # Check it has reasonable length (at least 50 lines)
    local line_count
    line_count=$(wc -l < "$file" | tr -d ' ')
    if [[ "$line_count" -lt 50 ]]; then
        return 1
    fi

    return 0
}

# Show diff between old and new prompt
show_diff() {
    local old_file=$1
    local new_file=$2

    echo ""
    echo -e "${CYAN}── Changes ──────────────────────────────────────────────────${NC}"
    echo ""

    if command -v diff &> /dev/null; then
        diff --color=auto -u "$old_file" "$new_file" 2>/dev/null || true
    else
        local old_lines
        old_lines=$(wc -l < "$old_file" | tr -d ' ')
        local new_lines
        new_lines=$(wc -l < "$new_file" | tr -d ' ')
        echo "  Old prompt: $old_lines lines"
        echo "  New prompt: $new_lines lines"
    fi

    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
}

# ------------------------------------------------------------------------------
# Main Script
# ------------------------------------------------------------------------------

main() {
    # Parse CLI arguments
    local ARG_QUERIES_PATH=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --queries-path)
                ARG_QUERIES_PATH="$2"
                shift 2
                ;;
            *)
                print_error "Unknown argument: $1"
                echo "Usage: improve_prompt.sh [--queries-path <file>]"
                exit 1
                ;;
        esac
    done

    print_header

    # Check for required tools
    if ! command -v claude &> /dev/null; then
        print_error "Claude CLI not found. Please install it first."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq not found. Please install it: brew install jq"
        exit 1
    fi

    # Check for required files
    if [[ ! -f "$PROMPT_FILE" ]]; then
        print_error "Current prompt not found: $PROMPT_FILE"
        exit 1
    fi

    if [[ ! -f "$STEP1_TEMPLATE" ]]; then
        print_error "Step 1 template not found: $STEP1_TEMPLATE"
        exit 1
    fi

    if [[ ! -f "$STEP2_TEMPLATE" ]]; then
        print_error "Step 2 template not found: $STEP2_TEMPLATE"
        exit 1
    fi

    if [[ ! -f "$REPORT_FILE" ]]; then
        print_error "Analysis report not found: $REPORT_FILE"
        echo ""
        echo "Run analysis.sh first to generate the report."
        exit 1
    fi

    # Real queries path: use CLI arg or prompt
    if [[ -n "$ARG_QUERIES_PATH" ]]; then
        REAL_QUERIES_PATH="$ARG_QUERIES_PATH"
    else
        echo ""
        read -p "Enter path to real production queries (queries.json): " REAL_QUERIES_PATH
    fi

    REAL_QUERIES_PATH=$(eval echo "$REAL_QUERIES_PATH")
    if [[ ! "$REAL_QUERIES_PATH" = /* ]]; then
        REAL_QUERIES_PATH="$SCRIPT_DIR/$REAL_QUERIES_PATH"
    fi

    if [[ ! -f "$REAL_QUERIES_PATH" ]]; then
        print_error "File not found: $REAL_QUERIES_PATH"
        exit 1
    fi

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Show current state
    echo ""
    local current_version
    current_version=$(get_next_version)

    local overall_score
    overall_score=$(grep -i "overall score" "$REPORT_FILE" | grep -oE '[0-9]+%' | head -1 || echo "N/A")

    print_info "Current prompt version: v$current_version"
    print_info "Analysis overall score: $overall_score"

    # Show top gaps from analysis
    echo ""
    echo -e "${YELLOW}Top gaps from analysis:${NC}"
    grep -E "^\| .+ \| [0-9]+%" "$REPORT_FILE" | head -5 | while IFS= read -r line; do
        echo "  $line"
    done
    echo ""

    # Sample 15 diverse real queries
    local total_queries
    total_queries=$(jq '.queries | length' "$REAL_QUERIES_PATH")

    local sample_queries
    if [[ "$total_queries" -le 15 ]]; then
        sample_queries=$(jq -r '.queries[] | "[\(.topic)] \(.query)"' "$REAL_QUERIES_PATH")
    else
        sample_queries=$(jq -r --argjson step "$(( total_queries / 15 ))" '
            [.queries | to_entries[] | select(.key % $step == 0)] |
            .[0:15][] |
            "[\(.value.topic)] \(.value.query)"
        ' "$REAL_QUERIES_PATH")
    fi

    # Load current prompt and report
    local current_prompt
    current_prompt=$(cat "$PROMPT_FILE")

    local analysis_report
    analysis_report=$(cat "$REPORT_FILE")

    # Write components to temp files
    echo "$current_prompt" > "$TEMP_DIR/current_prompt.txt"
    echo "$analysis_report" > "$TEMP_DIR/analysis_report.txt"
    echo "$sample_queries" > "$TEMP_DIR/real_samples.txt"

    # ══════════════════════════════════════════════════════════════════════════
    # STEP 1: Generate change plan
    # ══════════════════════════════════════════════════════════════════════════

    print_info "Step 1/2: Analyzing gaps and generating change plan..."
    echo ""

    local step1_template
    step1_template=$(cat "$STEP1_TEMPLATE")

    step1_template="${step1_template//\{\{CURRENT_PROMPT\}\}/$(cat "$TEMP_DIR/current_prompt.txt")}"
    step1_template="${step1_template//\{\{ANALYSIS_REPORT\}\}/$(cat "$TEMP_DIR/analysis_report.txt")}"
    step1_template="${step1_template//\{\{REAL_QUERY_SAMPLES\}\}/$(cat "$TEMP_DIR/real_samples.txt")}"

    echo "$step1_template" > "$TEMP_DIR/step1_prompt.md"

    local change_plan=""
    local step1_exit=0

    change_plan=$(claude --print -p "$(cat "$TEMP_DIR/step1_prompt.md")" 2>/dev/null) || step1_exit=$?

    if [[ $step1_exit -ne 0 || -z "$change_plan" ]]; then
        print_error "Step 1 failed: Could not generate change plan"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Try to extract JSON from response (handle code blocks)
    local clean_plan
    clean_plan=$(echo "$change_plan" | sed -n '/^```json/,/^```$/p' | sed '1d;$d')

    if [[ -z "$clean_plan" ]]; then
        # Try raw JSON
        clean_plan=$(echo "$change_plan" | jq '.' 2>/dev/null) || clean_plan=""
    fi

    if [[ -z "$clean_plan" ]]; then
        print_error "Step 1 failed: Response was not valid JSON"
        echo "$change_plan" > "$TEMP_DIR/step1_raw_response.txt"
        print_info "Raw response saved to: $TEMP_DIR/step1_raw_response.txt"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Show change plan summary
    local num_changes
    num_changes=$(echo "$clean_plan" | jq '.changes | length')
    local summary
    summary=$(echo "$clean_plan" | jq -r '.summary')

    print_success "Change plan generated: $num_changes changes"
    echo ""
    echo -e "  ${CYAN}Summary:${NC} $summary"
    echo ""

    # Show individual changes
    echo -e "  ${CYAN}Changes:${NC}"
    echo "$clean_plan" | jq -r '.changes[] | "    [\(.action)] \(.target): \(.description)"'
    echo ""

    # Save change plan
    echo "$clean_plan" > "$TEMP_DIR/change_plan.json"

    # ══════════════════════════════════════════════════════════════════════════
    # STEP 2: Apply change plan to prompt
    # ══════════════════════════════════════════════════════════════════════════

    print_info "Step 2/2: Applying changes to prompt..."
    echo ""

    local step2_template
    step2_template=$(cat "$STEP2_TEMPLATE")

    step2_template="${step2_template//\{\{ORIGINAL_PROMPT\}\}/$(cat "$TEMP_DIR/current_prompt.txt")}"
    step2_template="${step2_template//\{\{CHANGE_PLAN\}\}/$(cat "$TEMP_DIR/change_plan.json")}"

    echo "$step2_template" > "$TEMP_DIR/step2_prompt.md"

    local improved_prompt=""
    local step2_exit=0

    improved_prompt=$(claude --print -p "$(cat "$TEMP_DIR/step2_prompt.md")" 2>/dev/null) || step2_exit=$?

    if [[ $step2_exit -ne 0 || -z "$improved_prompt" ]]; then
        print_error "Step 2 failed: Could not generate improved prompt"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Clean response (remove code blocks if wrapped)
    improved_prompt=$(echo "$improved_prompt" | sed '/^```markdown$/d; /^```$/d')

    # Save to temp file for validation
    local improved_file="$TEMP_DIR/prompt_improved.md"
    echo "$improved_prompt" > "$improved_file"

    # Validate the output
    if ! validate_prompt "$improved_file"; then
        print_error "Validation failed: Output is not a valid prompt file"
        echo ""
        print_info "Expected: starts with #, contains {{KB_CONTENT}}, {{SOURCE_METADATA}}, {{USER_QUERIES}}, at least 50 lines"
        echo ""
        print_info "Raw output saved to: $TEMP_DIR/prompt_improved.md"
        echo ""
        print_warning "Prompt was NOT changed. Previous version is intact."
        exit 1
    fi

    print_success "Improved prompt generated and validated!"

    # Show diff
    show_diff "$PROMPT_FILE" "$improved_file"

    # Create backup before applying
    echo ""
    print_info "Creating backup (v$current_version)..."
    create_backup "$current_version"

    # Save change plan to backup too
    cp "$TEMP_DIR/change_plan.json" "$BACKUPS_DIR/v$current_version/change_plan.json"
    print_success "Backed up change_plan.json"

    # Apply improved prompt
    cp "$improved_file" "$PROMPT_FILE"
    echo ""
    print_success "Updated prompt.md with improvements"

    # Clean stale output — prompt changed, old synthetic data is invalid
    rm -f "$OUTPUT_FILE" "$SCRIPT_DIR/rejected.jsonl"
    rm -f "$SCRIPT_DIR/.generation_state.json"
    print_success "Cleaned stale output files (backed up in v$current_version)"

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    # Final summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Prompt improved!${NC}"
    echo ""
    echo -e "  Previous version backed up to: ${BLUE}$BACKUPS_DIR/v$current_version/${NC}"
    echo -e "  Previous analysis score:       ${YELLOW}$overall_score${NC}"
    echo -e "  Changes applied:               ${GREEN}$num_changes${NC}"
    echo ""
    echo -e "  Next steps:"
    echo -e "    1. Run ${CYAN}./generate.sh${NC} to generate new synthetic data"
    echo -e "    2. Run ${CYAN}./analysis.sh${NC} to measure improvement"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run main
main "$@"
