#!/bin/bash
#
# Synthetic Data Analysis
# Compares synthetic Q&A data against real production queries using Claude CLI
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

# Prompt template
ANALYSIS_PROMPT_FILE="$SCRIPT_DIR/analysis_prompt.md"

# Output report
REPORT_FILE="$SCRIPT_DIR/analysis_report.md"

# Temp directory
TEMP_DIR="$SCRIPT_DIR/.temp_analysis"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Synthetic Data Analyzer                             ║"
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

    # Check for analysis prompt
    if [[ ! -f "$ANALYSIS_PROMPT_FILE" ]]; then
        print_error "Analysis prompt not found: $ANALYSIS_PROMPT_FILE"
        exit 1
    fi

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Ask for synthetic data path
    echo ""
    read -p "Enter path to synthetic data (output.jsonl): " SYNTHETIC_PATH

    # Expand and resolve path
    SYNTHETIC_PATH=$(eval echo "$SYNTHETIC_PATH")
    if [[ ! "$SYNTHETIC_PATH" = /* ]]; then
        SYNTHETIC_PATH="$SCRIPT_DIR/$SYNTHETIC_PATH"
    fi

    if [[ ! -f "$SYNTHETIC_PATH" ]]; then
        print_error "File not found: $SYNTHETIC_PATH"
        exit 1
    fi

    # Ask for real queries path
    echo ""
    read -p "Enter path to real production queries (queries.json): " REAL_QUERIES_PATH

    # Expand and resolve path
    REAL_QUERIES_PATH=$(eval echo "$REAL_QUERIES_PATH")
    if [[ ! "$REAL_QUERIES_PATH" = /* ]]; then
        REAL_QUERIES_PATH="$SCRIPT_DIR/$REAL_QUERIES_PATH"
    fi

    if [[ ! -f "$REAL_QUERIES_PATH" ]]; then
        print_error "File not found: $REAL_QUERIES_PATH"
        exit 1
    fi

    # Load data
    echo ""
    local synthetic_count
    synthetic_count=$(wc -l < "$SYNTHETIC_PATH" | tr -d ' ')
    print_info "Loaded $synthetic_count synthetic Q&A pairs"

    local real_count
    real_count=$(jq '.queries | length' "$REAL_QUERIES_PATH" 2>/dev/null || echo "unknown")
    print_info "Loaded $real_count real production queries"

    # Prepare synthetic queries (extract just questions for comparison)
    local synthetic_questions
    synthetic_questions=$(jq -s '[.[] | {question: .question, category: .category, subcategory: .subcategory}]' "$SYNTHETIC_PATH")

    # Prepare real queries
    local real_queries
    real_queries=$(jq '.queries' "$REAL_QUERIES_PATH")

    # Build the prompt
    print_info "Building analysis prompt..."

    local prompt_template
    prompt_template=$(cat "$ANALYSIS_PROMPT_FILE")

    # Substitute placeholders
    # Write components to temp files to handle large content
    echo "$synthetic_questions" > "$TEMP_DIR/synthetic.json"
    echo "$real_queries" > "$TEMP_DIR/real.json"

    local synthetic_content
    synthetic_content=$(cat "$TEMP_DIR/synthetic.json")
    local real_content
    real_content=$(cat "$TEMP_DIR/real.json")

    prompt_template="${prompt_template//\{\{SYNTHETIC_QUERIES\}\}/$synthetic_content}"
    prompt_template="${prompt_template//\{\{REAL_QUERIES\}\}/$real_content}"

    # Save full prompt to temp file
    local prompt_file="$TEMP_DIR/analysis_prompt_full.md"
    echo "$prompt_template" > "$prompt_file"

    # Call Claude CLI
    echo ""
    print_info "Running analysis with Claude CLI..."
    print_info "This may take a moment..."
    echo ""

    local response=""
    local claude_exit_code=0

    response=$(claude --print -p "$(cat "$prompt_file")" 2>/dev/null) || claude_exit_code=$?

    if [[ $claude_exit_code -ne 0 || -z "$response" ]]; then
        print_error "Failed to get analysis from Claude CLI"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Clean up response (remove code blocks if wrapped)
    local report
    report=$(echo "$response" | sed '/^```markdown$/d; /^```$/d')

    # Save report
    echo "$report" > "$REPORT_FILE"

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    # Display summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Analysis complete!${NC}"
    echo ""
    echo -e "  Report saved to: ${BLUE}$REPORT_FILE${NC}"
    echo ""

    # Try to extract and display the summary table
    local overall_score
    overall_score=$(grep -i "overall score" "$REPORT_FILE" | grep -oE '[0-9]+%' | head -1 || echo "")

    if [[ -n "$overall_score" ]]; then
        echo -e "  Overall similarity score: ${YELLOW}$overall_score${NC}"
        echo ""
    fi

    # Print the summary table if found
    local in_table=false
    while IFS= read -r line; do
        if echo "$line" | grep -q "| Dimension"; then
            in_table=true
        fi
        if [[ "$in_table" == true ]]; then
            echo -e "  $line"
            if echo "$line" | grep -qi "overall"; then
                break
            fi
        fi
    done < "$REPORT_FILE"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run main
main "$@"
