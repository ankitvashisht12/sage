#!/bin/bash
#
# Prompt Improver
# Reads analysis report + current prompt, generates an improved prompt
# Backs up previous version (prompt + output + report) before applying
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
IMPROVE_TEMPLATE="$SCRIPT_DIR/improve_prompt_template.md"
BACKUPS_DIR="$SCRIPT_DIR/backups"
TEMP_DIR="$SCRIPT_DIR/.temp_improve"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Prompt Improver                                     ║"
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
        echo "(diff not available, showing summary)"
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

    if [[ ! -f "$IMPROVE_TEMPLATE" ]]; then
        print_error "Improve template not found: $IMPROVE_TEMPLATE"
        exit 1
    fi

    if [[ ! -f "$REPORT_FILE" ]]; then
        print_error "Analysis report not found: $REPORT_FILE"
        echo ""
        echo "Run analysis.sh first to generate the report."
        exit 1
    fi

    # Ask for real queries path
    echo ""
    read -p "Enter path to real production queries (queries.json): " REAL_QUERIES_PATH

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

    # Sample 15 diverse real queries for the prompt
    local total_queries
    total_queries=$(jq '.queries | length' "$REAL_QUERIES_PATH")

    local sample_queries
    if [[ "$total_queries" -le 15 ]]; then
        sample_queries=$(jq -r '.queries[] | "[\(.topic)] \(.query)"' "$REAL_QUERIES_PATH")
    else
        # Pick 15 evenly spaced queries for diversity
        sample_queries=$(jq -r --argjson step "$(( total_queries / 15 ))" '
            [.queries | to_entries[] | select(.key % $step == 0)] |
            .[0:15][] |
            "[\(.value.topic)] \(.value.query)"
        ' "$REAL_QUERIES_PATH")
    fi

    # Build the improvement prompt
    print_info "Building improvement prompt..."

    local template
    template=$(cat "$IMPROVE_TEMPLATE")

    local current_prompt
    current_prompt=$(cat "$PROMPT_FILE")

    local analysis_report
    analysis_report=$(cat "$REPORT_FILE")

    # Write components to temp files to handle substitution
    echo "$current_prompt" > "$TEMP_DIR/current_prompt.txt"
    echo "$analysis_report" > "$TEMP_DIR/analysis_report.txt"
    echo "$sample_queries" > "$TEMP_DIR/real_samples.txt"

    template="${template//\{\{CURRENT_PROMPT\}\}/$(cat "$TEMP_DIR/current_prompt.txt")}"
    template="${template//\{\{ANALYSIS_REPORT\}\}/$(cat "$TEMP_DIR/analysis_report.txt")}"
    template="${template//\{\{REAL_QUERY_SAMPLES\}\}/$(cat "$TEMP_DIR/real_samples.txt")}"

    local prompt_file="$TEMP_DIR/full_prompt.md"
    echo "$template" > "$prompt_file"

    # Call Claude CLI
    echo ""
    print_info "Generating improved prompt with Claude CLI..."
    print_info "This may take a moment..."
    echo ""

    local response=""
    local claude_exit_code=0

    response=$(claude --print -p "$(cat "$prompt_file")" 2>/dev/null) || claude_exit_code=$?

    if [[ $claude_exit_code -ne 0 || -z "$response" ]]; then
        print_error "Failed to get response from Claude CLI"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Clean response (remove code blocks if wrapped)
    local improved_prompt
    improved_prompt=$(echo "$response" | sed '/^```markdown$/d; /^```$/d')

    # Save improved prompt to temp file for preview
    local improved_file="$TEMP_DIR/prompt_improved.md"
    echo "$improved_prompt" > "$improved_file"

    # Show diff
    print_success "Improved prompt generated!"
    show_diff "$PROMPT_FILE" "$improved_file"

    # Also save preview copy
    cp "$improved_file" "$SCRIPT_DIR/prompt_improved.md"
    print_info "Preview saved to: prompt_improved.md"

    # Ask for approval
    echo ""
    read -p "Apply changes to prompt.md? [y/N]: " apply_choice

    if [[ "$apply_choice" == "y" || "$apply_choice" == "Y" ]]; then
        # Create backup
        echo ""
        print_info "Creating backup (v$current_version)..."
        create_backup "$current_version"

        # Apply improved prompt
        cp "$improved_file" "$PROMPT_FILE"
        echo ""
        print_success "Updated prompt.md with improvements"

        # Clean up preview file
        rm -f "$SCRIPT_DIR/prompt_improved.md"

        # Final summary
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Prompt improved!${NC}"
        echo ""
        echo -e "  Previous version backed up to: ${BLUE}$BACKUPS_DIR/v$current_version/${NC}"
        echo -e "  Previous analysis score:       ${YELLOW}$overall_score${NC}"
        echo ""
        echo -e "  Next steps:"
        echo -e "    1. Run ${CYAN}./generate.sh${NC} to generate new synthetic data"
        echo -e "    2. Run ${CYAN}./analysis.sh${NC} to measure improvement"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    else
        print_warning "Changes not applied. Preview available at: prompt_improved.md"
    fi

    # Clean up temp directory
    rm -rf "$TEMP_DIR"
}

# Run main
main "$@"
