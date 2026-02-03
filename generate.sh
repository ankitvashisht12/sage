#!/bin/bash
#
# Synthetic Data Generator
# Generates Q&A pairs from a knowledge base using Claude CLI
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

# Output files
OUTPUT_FILE="$SCRIPT_DIR/output.jsonl"
REJECTED_FILE="$SCRIPT_DIR/rejected.jsonl"
STATE_FILE="$SCRIPT_DIR/.generation_state.json"
TEMP_DIR="$SCRIPT_DIR/.temp"
EXISTING_QUESTIONS_FILE="$TEMP_DIR/existing_questions.json"

# Prompt template
PROMPT_FILE="$SCRIPT_DIR/prompt.md"

# Helper scripts
VALIDATE_SCRIPT="$SCRIPT_DIR/helpers/validate.py"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Synthetic Data Generator                            ║"
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

print_progress() {
    local current=$1
    local total=$2
    local filename=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    printf "\r${CYAN}[%d/%d]${NC} %s " "$current" "$total" "$filename"
    printf "${GREEN}"
    printf '█%.0s' $(seq 1 $filled 2>/dev/null) || true
    printf "${NC}"
    printf '░%.0s' $(seq 1 $empty 2>/dev/null) || true
    printf " ${percent}%%"
}

# Extract YAML frontmatter from markdown file
extract_frontmatter() {
    local file=$1
    awk '/^---$/{p=!p; if(p) next; else exit} p' "$file"
}

# Extract content (after frontmatter) from markdown file
extract_content() {
    local file=$1
    # Check if file has frontmatter
    if head -1 "$file" | grep -q "^---$"; then
        awk '/^---$/{p++; next} p>=2' "$file"
    else
        cat "$file"
    fi
}

# Extract URL from frontmatter
extract_url_from_frontmatter() {
    local frontmatter=$1
    echo "$frontmatter" | grep -E "^url:" | sed 's/^url:[[:space:]]*//' | tr -d '"' || echo ""
}

# Get existing questions from output.jsonl
load_existing_questions() {
    if [[ -f "$OUTPUT_FILE" ]]; then
        jq -s '[.[].question]' "$OUTPUT_FILE" > "$EXISTING_QUESTIONS_FILE"
    else
        echo "[]" > "$EXISTING_QUESTIONS_FILE"
    fi
}

# Append questions to existing questions file
append_to_existing_questions() {
    local new_questions=$1
    local current
    current=$(cat "$EXISTING_QUESTIONS_FILE")
    echo "$current" | jq ". + $new_questions" > "$EXISTING_QUESTIONS_FILE"
}

# Save state for resume capability
save_state() {
    local kb_path=$1
    local queries_path=$2
    local processed_files=$3
    local total_questions=$4

    jq -n \
        --arg kb "$kb_path" \
        --arg queries "$queries_path" \
        --argjson processed "$processed_files" \
        --arg total "$total_questions" \
        --arg updated "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            kb_path: $kb,
            queries_path: $queries,
            processed_files: $processed,
            total_questions: ($total | tonumber),
            last_updated: $updated
        }' > "$STATE_FILE"
}

# Load state for resume
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}

# Check if file was already processed
is_file_processed() {
    local filename=$1
    local state=$2
    echo "$state" | jq -e --arg f "$filename" '.processed_files | index($f) != null' > /dev/null 2>&1
}

# Build the full prompt with substitutions
build_prompt() {
    local kb_content=$1
    local source_metadata=$2
    local user_queries=$3

    local prompt_template
    prompt_template=$(cat "$PROMPT_FILE")

    # Substitute placeholders
    prompt_template="${prompt_template//\{\{KB_CONTENT\}\}/$kb_content}"
    prompt_template="${prompt_template//\{\{SOURCE_METADATA\}\}/$source_metadata}"
    prompt_template="${prompt_template//\{\{USER_QUERIES\}\}/$user_queries}"

    echo "$prompt_template"
}

# ------------------------------------------------------------------------------
# Main Script
# ------------------------------------------------------------------------------

main() {
    print_header

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Check for required tools
    if ! command -v claude &> /dev/null; then
        print_error "Claude CLI not found. Please install it first."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq not found. Please install it: brew install jq"
        exit 1
    fi

    if ! command -v uv &> /dev/null; then
        print_error "uv not found. Please install it: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi

    # Check for prompt file
    if [[ ! -f "$PROMPT_FILE" ]]; then
        print_error "Prompt file not found: $PROMPT_FILE"
        exit 1
    fi

    # Check for resume state
    local state
    state=$(load_state)
    local resume=false
    local processed_files="[]"
    local total_questions=0

    if [[ $(echo "$state" | jq -e '.kb_path' 2>/dev/null) ]]; then
        local prev_kb
        prev_kb=$(echo "$state" | jq -r '.kb_path')
        local prev_count
        prev_count=$(echo "$state" | jq -r '.processed_files | length')
        local prev_questions
        prev_questions=$(echo "$state" | jq -r '.total_questions')

        echo ""
        print_warning "Found previous session:"
        echo "  KB Path: $prev_kb"
        echo "  Files processed: $prev_count"
        echo "  Questions generated: $prev_questions"
        echo ""

        read -p "Resume previous session? [Y/n]: " resume_choice
        if [[ "$resume_choice" != "n" && "$resume_choice" != "N" ]]; then
            resume=true
            processed_files=$(echo "$state" | jq '.processed_files')
            total_questions=$(echo "$state" | jq -r '.total_questions')
            KB_PATH=$(echo "$state" | jq -r '.kb_path')
            QUERIES_PATH=$(echo "$state" | jq -r '.queries_path')
            print_success "Resuming previous session..."
        fi
    fi

    # Interactive prompts (if not resuming)
    if [[ "$resume" == false ]]; then
        echo ""
        read -p "Enter path to knowledge base (KB) directory: " KB_PATH

        # Expand path
        KB_PATH=$(eval echo "$KB_PATH")

        # Convert to absolute path if relative
        if [[ ! "$KB_PATH" = /* ]]; then
            KB_PATH="$SCRIPT_DIR/$KB_PATH"
        fi

        if [[ ! -d "$KB_PATH" ]]; then
            print_error "Directory not found: $KB_PATH"
            exit 1
        fi

        echo ""
        read -p "Enter path to queries.json (optional, press Enter to skip): " QUERIES_PATH

        if [[ -n "$QUERIES_PATH" ]]; then
            QUERIES_PATH=$(eval echo "$QUERIES_PATH")
            if [[ ! "$QUERIES_PATH" = /* ]]; then
                QUERIES_PATH="$SCRIPT_DIR/$QUERIES_PATH"
            fi
            if [[ ! -f "$QUERIES_PATH" ]]; then
                print_error "File not found: $QUERIES_PATH"
                exit 1
            fi
        fi

        # Clear previous output files for fresh start
        rm -f "$OUTPUT_FILE" "$REJECTED_FILE"
    fi

    # Load user queries if provided
    local user_queries=""
    if [[ -n "$QUERIES_PATH" && -f "$QUERIES_PATH" ]]; then
        user_queries=$(jq -r '.queries[] | "- [\(.topic)] \(.query)"' "$QUERIES_PATH" 2>/dev/null | head -50)
        print_success "Loaded user queries from: $QUERIES_PATH"
    fi

    # Find all markdown files
    local md_files=()
    while IFS= read -r -d '' file; do
        md_files+=("$file")
    done < <(find "$KB_PATH" -name "*.md" -type f -print0 | sort -z)

    local total_files=${#md_files[@]}

    if [[ $total_files -eq 0 ]]; then
        print_error "No markdown files found in: $KB_PATH"
        exit 1
    fi

    echo ""
    print_info "Found $total_files markdown files in $KB_PATH"
    echo ""

    # Load existing questions for deduplication
    load_existing_questions

    # Process each file
    local current=0
    local validated_count=0
    local rejected_count=0

    echo "Starting generation..."
    echo ""

    for md_file in "${md_files[@]}"; do
        current=$((current + 1))
        local filename
        filename=$(basename "$md_file")

        # Skip if already processed (resume mode)
        if is_file_processed "$filename" "$state" && [[ "$resume" == true ]]; then
            print_progress $current $total_files "$filename (skipped)"
            echo ""
            continue
        fi

        print_progress $current $total_files "$filename"

        # Extract content and metadata
        local frontmatter
        frontmatter=$(extract_frontmatter "$md_file")
        local content
        content=$(extract_content "$md_file")
        local source_url
        source_url=$(extract_url_from_frontmatter "$frontmatter")

        if [[ -z "$source_url" ]]; then
            source_url="$filename"
        fi

        local source_metadata
        source_metadata=$(cat <<EOF
url: $source_url
filename: $filename
EOF
)

        # Build the full prompt
        local full_prompt
        full_prompt=$(build_prompt "$content" "$source_metadata" "$user_queries")

        # Save prompt to temp file (for large prompts)
        local prompt_temp_file="$TEMP_DIR/current_prompt.md"
        echo "$full_prompt" > "$prompt_temp_file"

        # Call Claude CLI
        local response=""
        local claude_exit_code=0

        response=$(claude --print -p "$(cat "$prompt_temp_file")" 2>/dev/null) || claude_exit_code=$?

        if [[ $claude_exit_code -ne 0 || -z "$response" ]]; then
            echo ""
            print_error "Failed to get response for: $filename"
            echo "{\"error\": \"claude_failed\", \"file\": \"$filename\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" >> "$REJECTED_FILE"
            continue
        fi

        # Try to extract JSON from response (handle markdown code blocks)
        local json_response
        json_response=$(echo "$response" | sed -n '/^```json/,/^```$/p' | sed '1d;$d')

        if [[ -z "$json_response" ]]; then
            # Try without code blocks
            json_response=$(echo "$response" | jq '.' 2>/dev/null) || json_response=""
        fi

        if [[ -z "$json_response" ]]; then
            echo ""
            print_error "Invalid JSON response for: $filename"
            echo "{\"error\": \"invalid_json\", \"file\": \"$filename\", \"response\": $(echo "$response" | jq -Rs '.'), \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" >> "$REJECTED_FILE"
            continue
        fi

        # Extract pairs from response
        local pairs
        pairs=$(echo "$json_response" | jq -c '.pairs // []')

        if [[ "$pairs" == "[]" || -z "$pairs" ]]; then
            echo ""
            print_warning "No pairs generated for: $filename"
            continue
        fi

        # Save content to temp file for validation
        local content_temp_file="$TEMP_DIR/current_content.txt"
        echo "$content" > "$content_temp_file"

        # Validate pairs using Python helper (via uv for isolated env)
        local validation_result
        validation_result=$(uv run --project "$SCRIPT_DIR" python "$VALIDATE_SCRIPT" validate "$pairs" "$content_temp_file" "$EXISTING_QUESTIONS_FILE" 2>/dev/null) || validation_result=""

        if [[ -z "$validation_result" ]]; then
            echo ""
            print_error "Validation failed for: $filename"
            continue
        fi

        local valid_pairs
        valid_pairs=$(echo "$validation_result" | jq -c '.valid')
        local rejected_pairs
        rejected_pairs=$(echo "$validation_result" | jq -c '.rejected')

        local valid_count
        valid_count=$(echo "$valid_pairs" | jq 'length')
        local reject_count
        reject_count=$(echo "$rejected_pairs" | jq 'length')

        # Append valid pairs to output
        if [[ "$valid_count" -gt 0 ]]; then
            # Add source to each pair and append to output
            echo "$valid_pairs" | jq -c --arg src "$source_url" '.[] | .source = [$src]' >> "$OUTPUT_FILE"

            # Update existing questions
            local new_questions
            new_questions=$(echo "$valid_pairs" | jq '[.[].question]')
            append_to_existing_questions "$new_questions"

            validated_count=$((validated_count + valid_count))
        fi

        # Append rejected pairs to rejected file
        if [[ "$reject_count" -gt 0 ]]; then
            echo "$rejected_pairs" | jq -c --arg src "$filename" '.[] | .source_file = $src | .timestamp = (now | todate)' >> "$REJECTED_FILE"
            rejected_count=$((rejected_count + reject_count))
        fi

        # Update progress display
        echo ""
        echo -e "       Generated: $valid_count | Validated: $valid_count | Rejected: $reject_count"

        # Update state
        processed_files=$(echo "$processed_files" | jq --arg f "$filename" '. + [$f]')
        total_questions=$((total_questions + valid_count))
        save_state "$KB_PATH" "$QUERIES_PATH" "$processed_files" "$total_questions"
    done

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    # Remove state file on successful completion
    rm -f "$STATE_FILE"

    # Final summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Generation complete!${NC}"
    echo ""
    echo -e "  Total questions: ${GREEN}$validated_count${NC}"
    echo -e "  Rejected:        ${YELLOW}$rejected_count${NC}"
    echo ""
    echo -e "  Output:   ${BLUE}$OUTPUT_FILE${NC}"
    if [[ -f "$REJECTED_FILE" ]]; then
        echo -e "  Rejected: ${YELLOW}$REJECTED_FILE${NC}"
    fi
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run main
main "$@"
