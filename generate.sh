#!/usr/bin/env bash
#
# Synthetic Data Generator — Two-Call Pipeline
# Phase 1: Generate diverse questions (Sonnet)
# Phase 2: Extract verbatim citations (Haiku)
# Phase 3: Validate and merge
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

# Prompt templates
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
CITATION_PROMPT_FILE="$SCRIPT_DIR/citation_prompt.md"

# Helper scripts
VALIDATE_SCRIPT="$SCRIPT_DIR/helpers/validate.py"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Synthetic Data Generator                            ║"
    echo "║           Two-Call Pipeline (Sonnet → Haiku)                  ║"
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
        if ! jq -s '[.[].query]' "$OUTPUT_FILE" > "$EXISTING_QUESTIONS_FILE" 2>/dev/null; then
            print_warning "output.jsonl is corrupt — starting with empty question list"
            echo "[]" > "$EXISTING_QUESTIONS_FILE"
        fi
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

# Build the question generation prompt (Call 1)
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

# Build the citation extraction prompt (Call 2)
build_citation_prompt() {
    local kb_content=$1
    local questions=$2

    local prompt_template
    prompt_template=$(cat "$CITATION_PROMPT_FILE")

    # Substitute placeholders
    prompt_template="${prompt_template//\{\{KB_CONTENT\}\}/$kb_content}"
    prompt_template="${prompt_template//\{\{QUESTIONS\}\}/$questions}"

    echo "$prompt_template"
}

# Monitor background jobs with live progress
# Usage: monitor_jobs file_slugs_array_name temp_dir phase_label
monitor_jobs() {
    local -n slugs_ref=$1
    local temp_dir=$2
    local suffix=$3
    local phase_label=$4
    local launch_start=$5

    local total_jobs=${#slugs_ref[@]}
    local prev_completed=0

    while true; do
        local completed=0
        local succeeded=0
        local failed=0
        local in_progress_files=()

        for slug in "${slugs_ref[@]}"; do
            if [[ -f "$temp_dir/jobs/${slug}.${suffix}.exit" ]]; then
                completed=$((completed + 1))
                local code
                code=$(cat "$temp_dir/jobs/${slug}.${suffix}.exit")
                if [[ "$code" -eq 0 ]]; then
                    succeeded=$((succeeded + 1))
                else
                    failed=$((failed + 1))
                fi
            else
                in_progress_files+=("$slug")
            fi
        done

        # Print update only when something changed
        if [[ $completed -ne $prev_completed ]]; then
            local elapsed=$(( SECONDS - launch_start ))
            local mins=$(( elapsed / 60 ))
            local secs=$(( elapsed % 60 ))

            # Build progress bar
            local pct=$(( completed * 100 / total_jobs ))
            local filled=$(( pct / 5 ))
            local empty=$(( 20 - filled ))
            local bar=""
            for ((i=0; i<filled; i++)); do bar+="█"; done
            for ((i=0; i<empty; i++)); do bar+="░"; done

            echo -e "  ${CYAN}${phase_label}:${NC} ${GREEN}${bar}${NC} ${completed}/${total_jobs} (${pct}%) — ${GREEN}${succeeded} ok${NC}, ${RED}${failed} err${NC} — ${mins}m${secs}s"

            # Show which files just completed
            for slug in "${slugs_ref[@]}"; do
                if [[ -f "$temp_dir/jobs/${slug}.${suffix}.exit" ]]; then
                    local code
                    code=$(cat "$temp_dir/jobs/${slug}.${suffix}.exit")
                    if [[ ! -f "$temp_dir/jobs/${slug}.${suffix}.announced" ]]; then
                        touch "$temp_dir/jobs/${slug}.${suffix}.announced"
                        if [[ "$code" -eq 0 ]]; then
                            echo -e "    ${GREEN}✓${NC} Done: ${slug}.md"
                        else
                            echo -e "    ${RED}✗${NC} Failed: ${slug}.md"
                        fi
                    fi
                fi
            done

            # Show still running
            if [[ ${#in_progress_files[@]} -gt 0 && $completed -lt $total_jobs ]]; then
                local running_list=""
                local show_max=5
                local shown=0
                for slug in "${in_progress_files[@]}"; do
                    if [[ $shown -lt $show_max ]]; then
                        if [[ -n "$running_list" ]]; then running_list+=", "; fi
                        running_list+="${slug}.md"
                        shown=$((shown + 1))
                    fi
                done
                local remaining=${#in_progress_files[@]}
                if [[ $remaining -gt $show_max ]]; then
                    running_list+=" (+$((remaining - show_max)) more)"
                fi
                echo -e "    ${YELLOW}⏳${NC} Running: $running_list"
            fi

            prev_completed=$completed
        fi

        # All done?
        if [[ $completed -ge $total_jobs ]]; then
            break
        fi

        sleep 2
    done
}

# Extract JSON from a Claude response (handles markdown code blocks)
extract_json_from_response() {
    local response=$1

    # Try to extract from markdown code block first
    local json_response
    json_response=$(echo "$response" | sed -n '/^```json/,/^```$/p' | sed '1d;$d')

    if [[ -z "$json_response" ]]; then
        # Try raw JSON
        json_response=$(echo "$response" | jq '.' 2>/dev/null) || json_response=""
    fi

    echo "$json_response"
}

# ------------------------------------------------------------------------------
# Main Script
# ------------------------------------------------------------------------------

main() {
    # Parse CLI arguments
    local ARG_KB_PATH=""
    local ARG_QUERIES_PATH=""
    local ARG_NO_RESUME=false
    local ARG_SAMPLE=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --kb-path)
                ARG_KB_PATH="$2"
                shift 2
                ;;
            --queries-path)
                ARG_QUERIES_PATH="$2"
                shift 2
                ;;
            --no-resume)
                ARG_NO_RESUME=true
                shift
                ;;
            --sample)
                ARG_SAMPLE="$2"
                shift 2
                ;;
            *)
                print_error "Unknown argument: $1"
                echo "Usage: generate.sh [--kb-path <dir>] [--queries-path <file>] [--no-resume] [--sample N]"
                exit 1
                ;;
        esac
    done

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

    # Check for prompt files
    if [[ ! -f "$PROMPT_FILE" ]]; then
        print_error "Prompt file not found: $PROMPT_FILE"
        exit 1
    fi

    if [[ ! -f "$CITATION_PROMPT_FILE" ]]; then
        print_error "Citation prompt file not found: $CITATION_PROMPT_FILE"
        exit 1
    fi

    # Handle --no-resume: delete state file before checking
    if [[ "$ARG_NO_RESUME" == true ]]; then
        rm -f "$STATE_FILE"
    fi

    # Check for resume state
    local state
    state=$(load_state)
    local resume=false
    local processed_files="[]"
    local total_questions=0

    if echo "$state" | jq -e '.kb_path // empty' > /dev/null 2>&1; then
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
        # KB path: use CLI arg or prompt
        if [[ -n "$ARG_KB_PATH" ]]; then
            KB_PATH="$ARG_KB_PATH"
        else
            echo ""
            read -p "Enter path to knowledge base (KB) directory: " KB_PATH
        fi

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

        # Queries path: use CLI arg or prompt
        if [[ -n "$ARG_QUERIES_PATH" ]]; then
            QUERIES_PATH="$ARG_QUERIES_PATH"
        else
            echo ""
            read -p "Enter path to queries.json (optional, press Enter to skip): " QUERIES_PATH
        fi

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

    # Apply --sample if set
    if [[ -n "$ARG_SAMPLE" && "$ARG_SAMPLE" -gt 0 ]]; then
        mapfile -t md_files < <(printf '%s\n' "${md_files[@]}" | awk 'BEGIN{srand()}{print rand()"\t"$0}' | sort -n | cut -f2- | head -n "$ARG_SAMPLE")
        print_info "Sampling $ARG_SAMPLE files from $total_files total"
        total_files=${#md_files[@]}
    fi

    echo ""

    # Load existing questions for deduplication
    load_existing_questions

    # Concurrency limit for parallel generation
    local MAX_PARALLEL=${MAX_PARALLEL:-20}

    # ══════════════════════════════════════════════════════════════════════
    # Phase 1: Generate Questions (Sonnet, parallel)
    # ══════════════════════════════════════════════════════════════════════

    local files_to_process=()
    local pids=()

    echo -e "${CYAN}═══ Phase 1: Generate Questions (Sonnet) ═══${NC}"
    echo ""

    # Build per-file prompt files and content files; collect list to process
    local current=0
    for md_file in "${md_files[@]}"; do
        current=$((current + 1))
        local filename
        filename=$(basename "$md_file")

        # Skip if already processed (resume mode)
        if is_file_processed "$filename" "$state" && [[ "$resume" == true ]]; then
            print_info "Skipping (already processed): $filename"
            continue
        fi

        files_to_process+=("$md_file")

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

        # Build the question generation prompt and save per-file temp files
        local full_prompt
        full_prompt=$(build_prompt "$content" "$source_metadata" "$user_queries")

        local file_slug="${filename%.md}"
        mkdir -p "$TEMP_DIR/jobs"
        echo "$full_prompt" > "$TEMP_DIR/jobs/${file_slug}.prompt.md"
        echo "$content"     > "$TEMP_DIR/jobs/${file_slug}.content.txt"
        echo "$source_url"  > "$TEMP_DIR/jobs/${file_slug}.source_url.txt"
        echo "$filename"    > "$TEMP_DIR/jobs/${file_slug}.doc_id.txt"
    done

    local total_to_process=${#files_to_process[@]}
    if [[ $total_to_process -eq 0 ]]; then
        print_info "All files already processed."
    else
        print_info "Launching $total_to_process Sonnet calls (max $MAX_PARALLEL parallel)..."
        print_info "Tip: Set MAX_PARALLEL=N to change concurrency (e.g., MAX_PARALLEL=10 ./generate.sh)"
        echo ""

        # Fan-out: launch background jobs with concurrency throttle
        local running=0
        local file_slugs=()
        local phase1_start=$SECONDS

        for md_file in "${files_to_process[@]}"; do
            local filename
            filename=$(basename "$md_file")
            local file_slug="${filename%.md}"
            local prompt_file="$TEMP_DIR/jobs/${file_slug}.prompt.md"
            local response_file="$TEMP_DIR/jobs/${file_slug}.questions.txt"
            local exit_file="$TEMP_DIR/jobs/${file_slug}.questions.exit"

            file_slugs+=("$file_slug")

            # Launch Call 1 with Sonnet
            (
                claude --print --model sonnet -p "$(cat "$prompt_file")" > "$response_file" 2>/dev/null
                echo $? > "$exit_file"
            ) &
            pids+=($!)
            running=$((running + 1))

            echo -e "  ${BLUE}▸${NC} Launched (Sonnet): $filename (pid $!)"

            # Throttle: wait for a slot if at capacity
            if [[ $running -ge $MAX_PARALLEL ]]; then
                wait -n 2>/dev/null || true
                running=$((running - 1))
            fi
        done

        echo ""

        # Monitor Phase 1
        monitor_jobs file_slugs "$TEMP_DIR" "questions" "Phase 1" "$phase1_start"

        # Reap all background processes
        for pid in "${pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done

        echo ""
        local phase1_elapsed=$(( SECONDS - phase1_start ))
        local phase1_mins=$(( phase1_elapsed / 60 ))
        local phase1_secs=$(( phase1_elapsed % 60 ))
        print_success "Phase 1 complete in ${phase1_mins}m${phase1_secs}s"
        echo ""

        # ══════════════════════════════════════════════════════════════════
        # Phase 2: Extract Citations (Haiku, parallel)
        # ══════════════════════════════════════════════════════════════════

        echo -e "${CYAN}═══ Phase 2: Extract Citations (Haiku) ═══${NC}"
        echo ""

        local citation_slugs=()
        local citation_pids=()
        local citation_running=0
        local phase2_start=$SECONDS

        for file_slug in "${file_slugs[@]}"; do
            local questions_file="$TEMP_DIR/jobs/${file_slug}.questions.txt"
            local questions_exit="$TEMP_DIR/jobs/${file_slug}.questions.exit"
            local content_file="$TEMP_DIR/jobs/${file_slug}.content.txt"

            # Check if Call 1 succeeded
            if [[ ! -f "$questions_exit" ]]; then
                continue
            fi
            local exit_code
            exit_code=$(cat "$questions_exit")
            if [[ "$exit_code" -ne 0 ]]; then
                print_warning "Skipping citation for ${file_slug}.md (Call 1 failed)"
                continue
            fi

            local response=""
            if [[ -f "$questions_file" ]]; then
                response=$(cat "$questions_file")
            fi
            if [[ -z "$response" ]]; then
                print_warning "Skipping citation for ${file_slug}.md (empty response)"
                continue
            fi

            # Extract JSON from Call 1 response
            local json_response
            json_response=$(extract_json_from_response "$response")

            if [[ -z "$json_response" ]]; then
                print_warning "Skipping citation for ${file_slug}.md (invalid JSON in Call 1)"
                echo "{\"error\": \"invalid_json_phase1\", \"file\": \"${file_slug}.md\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" >> "$REJECTED_FILE"
                continue
            fi

            # Extract query list from pairs
            local queries_list
            queries_list=$(echo "$json_response" | jq -r '.pairs // [] | to_entries[] | "\(.key + 1). \(.value.query)"' 2>/dev/null)

            if [[ -z "$queries_list" ]]; then
                print_warning "Skipping citation for ${file_slug}.md (no queries generated)"
                continue
            fi

            # Save the questions JSON for later merge
            echo "$json_response" > "$TEMP_DIR/jobs/${file_slug}.questions.json"

            # Build citation prompt
            local kb_content
            kb_content=$(cat "$content_file")
            local citation_prompt
            citation_prompt=$(build_citation_prompt "$kb_content" "$queries_list")

            local citation_prompt_file="$TEMP_DIR/jobs/${file_slug}.citation_prompt.md"
            local citation_response_file="$TEMP_DIR/jobs/${file_slug}.citations.txt"
            local citation_exit_file="$TEMP_DIR/jobs/${file_slug}.citations.exit"

            echo "$citation_prompt" > "$citation_prompt_file"

            citation_slugs+=("$file_slug")

            # Launch Call 2 with Haiku
            (
                claude --print --model haiku -p "$(cat "$citation_prompt_file")" > "$citation_response_file" 2>/dev/null
                echo $? > "$citation_exit_file"
            ) &
            citation_pids+=($!)
            citation_running=$((citation_running + 1))

            echo -e "  ${BLUE}▸${NC} Launched (Haiku): ${file_slug}.md (pid $!)"

            # Throttle
            if [[ $citation_running -ge $MAX_PARALLEL ]]; then
                wait -n 2>/dev/null || true
                citation_running=$((citation_running - 1))
            fi
        done

        if [[ ${#citation_slugs[@]} -eq 0 ]]; then
            print_warning "No files to process in Phase 2"
        else
            print_info "Launched ${#citation_slugs[@]} Haiku calls..."
            echo ""

            # Monitor Phase 2
            monitor_jobs citation_slugs "$TEMP_DIR" "citations" "Phase 2" "$phase2_start"

            # Reap all
            for pid in "${citation_pids[@]}"; do
                wait "$pid" 2>/dev/null || true
            done

            echo ""
            local phase2_elapsed=$(( SECONDS - phase2_start ))
            local phase2_mins=$(( phase2_elapsed / 60 ))
            local phase2_secs=$(( phase2_elapsed % 60 ))
            print_success "Phase 2 complete in ${phase2_mins}m${phase2_secs}s"
        fi

        echo ""

        # ══════════════════════════════════════════════════════════════════
        # Phase 3: Merge + Validate
        # ══════════════════════════════════════════════════════════════════

        echo -e "${CYAN}═══ Phase 3: Merge & Validate ═══${NC}"
        echo ""

        local validated_count=0
        local rejected_count=0
        local validate_current=0

        for file_slug in "${citation_slugs[@]}"; do
            validate_current=$((validate_current + 1))
            local questions_json_file="$TEMP_DIR/jobs/${file_slug}.questions.json"
            local citations_file="$TEMP_DIR/jobs/${file_slug}.citations.txt"
            local citations_exit="$TEMP_DIR/jobs/${file_slug}.citations.exit"
            local content_file="$TEMP_DIR/jobs/${file_slug}.content.txt"
            local source_url_file="$TEMP_DIR/jobs/${file_slug}.source_url.txt"
            local doc_id_file="$TEMP_DIR/jobs/${file_slug}.doc_id.txt"

            local source_url
            source_url=$(cat "$source_url_file")
            local doc_id
            doc_id=$(cat "$doc_id_file")

            # Check Call 2 exit code
            local citation_exit_code=0
            if [[ -f "$citations_exit" ]]; then
                citation_exit_code=$(cat "$citations_exit")
            else
                citation_exit_code=1
            fi

            local citation_response=""
            if [[ -f "$citations_file" ]]; then
                citation_response=$(cat "$citations_file")
            fi

            if [[ "$citation_exit_code" -ne 0 || -z "$citation_response" ]]; then
                print_error "Failed to get citations for: ${file_slug}.md"
                echo "{\"error\": \"claude_failed_phase2\", \"file\": \"${file_slug}.md\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" >> "$REJECTED_FILE"
                continue
            fi

            # Extract JSON from citation response
            local citation_json
            citation_json=$(extract_json_from_response "$citation_response")

            if [[ -z "$citation_json" ]]; then
                print_error "Invalid JSON in citation response for: ${file_slug}.md"
                echo "{\"error\": \"invalid_json_phase2\", \"file\": \"${file_slug}.md\", \"response\": $(echo "$citation_response" | jq -Rs '.'), \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" >> "$REJECTED_FILE"
                continue
            fi

            # Load the Call 1 questions metadata
            local questions_json
            questions_json=$(cat "$questions_json_file")

            # Merge: combine Call 1 metadata + Call 2 citations
            # Build merged pairs array using jq
            local merged_pairs
            merged_pairs=$(jq -n \
                --argjson q "$questions_json" \
                --argjson c "$citation_json" \
                --arg doc_id "$doc_id" \
                --arg source_url "$source_url" \
                '
                ($q.pairs // []) as $questions |
                ($c.citations // []) as $citations |
                [range(0; $questions | length) |
                    . as $i |
                    $questions[$i] as $q_item |
                    # Find matching citation by query text
                    ($citations | map(select(.query == $q_item.query)) | first // null) as $c_item |
                    {
                        query: $q_item.query,
                        doc_id: $doc_id,
                        citation: (if $c_item then $c_item.citation else null end),
                        category: $q_item.category,
                        subcategory: $q_item.subcategory,
                        chunks: (if $c_item then ($c_item.chunks // []) else [] end),
                        source: [$source_url],
                        query_metadata: ($q_item.query_metadata // {})
                    }
                ]
                ') || merged_pairs="[]"

            if [[ "$merged_pairs" == "[]" || -z "$merged_pairs" ]]; then
                print_warning "No merged pairs for: ${file_slug}.md"
                continue
            fi

            # Validate using Python helper
            local validation_result
            validation_result=$(uv run --project "$SCRIPT_DIR" python "$VALIDATE_SCRIPT" validate_citations "$merged_pairs" "$content_file" "$EXISTING_QUESTIONS_FILE" 2>/dev/null) || validation_result=""

            if [[ -z "$validation_result" ]]; then
                print_error "Validation failed for: ${file_slug}.md"
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
                echo "$valid_pairs" | jq -c '.[]' >> "$OUTPUT_FILE"

                # Update existing questions for cross-file deduplication
                local new_questions
                new_questions=$(echo "$valid_pairs" | jq '[.[].query]')
                append_to_existing_questions "$new_questions"

                validated_count=$((validated_count + valid_count))
            fi

            # Append rejected pairs to rejected file
            if [[ "$reject_count" -gt 0 ]]; then
                echo "$rejected_pairs" | jq -c --arg src "${file_slug}.md" '.[] | .source_file = $src | .timestamp = (now | todate)' >> "$REJECTED_FILE"
                rejected_count=$((rejected_count + reject_count))
            fi

            echo -e "  ${GREEN}✓${NC} [${validate_current}/${#citation_slugs[@]}] ${file_slug}.md — valid: $valid_count, rejected: $reject_count"

            # Update state
            processed_files=$(echo "$processed_files" | jq --arg f "${file_slug}.md" '. + [$f]')
            total_questions=$((total_questions + valid_count))
            save_state "$KB_PATH" "$QUERIES_PATH" "$processed_files" "$total_questions"
        done
    fi

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    # Remove state file on successful completion
    rm -f "$STATE_FILE"

    # Final summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Generation complete!${NC}"
    echo ""
    echo -e "  Total questions: ${GREEN}${validated_count:-0}${NC}"
    echo -e "  Rejected:        ${YELLOW}${rejected_count:-0}${NC}"
    echo ""
    echo -e "  Output:   ${BLUE}$OUTPUT_FILE${NC}"
    if [[ -f "$REJECTED_FILE" ]]; then
        echo -e "  Rejected: ${YELLOW}$REJECTED_FILE${NC}"
    fi
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run main
main "$@"
