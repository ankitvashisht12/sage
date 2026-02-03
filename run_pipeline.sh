#!/usr/bin/env bash
#
# Pipeline Orchestration Script
# Automates the feedback loop: generate -> analyze -> (improve -> generate -> analyze)
# until the target score is reached or max iterations are exhausted.
#

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
OUTPUT_FILE="$SCRIPT_DIR/output.jsonl"
REJECTED_FILE="$SCRIPT_DIR/rejected.jsonl"
STATE_FILE="$SCRIPT_DIR/.generation_state.json"
REPORT_FILE="$SCRIPT_DIR/analysis_report.md"

# Score history for summary table
declare -a SCORE_HISTORY=()

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Synthetic Data Pipeline                             ║"
    echo "║           Automated Feedback Loop                             ║"
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

print_summary() {
    echo ""
    echo -e "${CYAN}═════════════════ Pipeline Summary ═════════════════${NC}"
    echo ""
    printf "  %-12s|  %-8s|  %s\n" "Iteration" "Score" "Delta"
    printf "  -----------+---------+--------\n"

    local prev_score=""
    for i in "${!SCORE_HISTORY[@]}"; do
        local iter=$((i + 1))
        local score="${SCORE_HISTORY[$i]}"
        local delta="-"

        if [[ -n "$prev_score" && "$score" =~ ^[0-9]+$ && "$prev_score" =~ ^[0-9]+$ ]]; then
            local diff=$((score - prev_score))
            if [[ $diff -ge 0 ]]; then
                delta="+${diff}%"
            else
                delta="${diff}%"
            fi
        fi

        printf "  %5d      |  %4s%%   |  %s\n" "$iter" "$score" "$delta"
        prev_score="$score"
    done

    echo ""
}

extract_score() {
    local report_file=$1
    grep -i "overall score" "$report_file" | grep -oE '[0-9]+' | head -1
}

# ------------------------------------------------------------------------------
# Trap: print partial summary on Ctrl+C
# ------------------------------------------------------------------------------

cleanup() {
    echo ""
    echo ""
    print_warning "Pipeline interrupted!"

    if [[ ${#SCORE_HISTORY[@]} -gt 0 ]]; then
        print_summary

        local first="${SCORE_HISTORY[0]}"
        local last="${SCORE_HISTORY[-1]}"
        if [[ "$first" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]]; then
            local total_improvement=$((last - first))
            echo -e "  Result: ${YELLOW}INTERRUPTED${NC}"
            echo -e "  Iterations completed: ${#SCORE_HISTORY[@]}"
            echo -e "  Total improvement: ${GREEN}+${total_improvement}%${NC}"
        fi
    else
        echo "  No iterations completed."
    fi

    echo ""
    exit 130
}

trap cleanup INT

# ------------------------------------------------------------------------------
# Main Script
# ------------------------------------------------------------------------------

main() {
    # Parse CLI arguments
    local ARG_KB_PATH=""
    local ARG_QUERIES_PATH=""
    local ARG_MAX_ITERATIONS=""
    local ARG_TARGET_SCORE=""

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
            --max-iterations)
                ARG_MAX_ITERATIONS="$2"
                shift 2
                ;;
            --target-score)
                ARG_TARGET_SCORE="$2"
                shift 2
                ;;
            *)
                print_error "Unknown argument: $1"
                echo "Usage: run_pipeline.sh [--kb-path <dir>] [--queries-path <file>] [--max-iterations <n>] [--target-score <n>]"
                exit 1
                ;;
        esac
    done

    print_header

    # Collect inputs
    local KB_PATH=""
    local QUERIES_PATH=""
    local MAX_ITERATIONS=""
    local TARGET_SCORE=""

    # KB path
    if [[ -n "$ARG_KB_PATH" ]]; then
        KB_PATH="$ARG_KB_PATH"
    else
        read -p "Enter path to knowledge base (KB) directory: " KB_PATH
    fi

    KB_PATH=$(eval echo "$KB_PATH")
    if [[ ! "$KB_PATH" = /* ]]; then
        KB_PATH="$SCRIPT_DIR/$KB_PATH"
    fi

    if [[ ! -d "$KB_PATH" ]]; then
        print_error "Directory not found: $KB_PATH"
        exit 1
    fi

    # Queries path
    if [[ -n "$ARG_QUERIES_PATH" ]]; then
        QUERIES_PATH="$ARG_QUERIES_PATH"
    else
        read -p "Enter path to real production queries (queries.json): " QUERIES_PATH
    fi

    QUERIES_PATH=$(eval echo "$QUERIES_PATH")
    if [[ ! "$QUERIES_PATH" = /* ]]; then
        QUERIES_PATH="$SCRIPT_DIR/$QUERIES_PATH"
    fi

    if [[ ! -f "$QUERIES_PATH" ]]; then
        print_error "File not found: $QUERIES_PATH"
        exit 1
    fi

    # Max iterations
    if [[ -n "$ARG_MAX_ITERATIONS" ]]; then
        MAX_ITERATIONS="$ARG_MAX_ITERATIONS"
    else
        read -p "Max iterations [10]: " MAX_ITERATIONS
        MAX_ITERATIONS="${MAX_ITERATIONS:-10}"
    fi

    # Target score
    if [[ -n "$ARG_TARGET_SCORE" ]]; then
        TARGET_SCORE="$ARG_TARGET_SCORE"
    else
        read -p "Target score (0-100) [85]: " TARGET_SCORE
        TARGET_SCORE="${TARGET_SCORE:-85}"
    fi

    # Display configuration
    echo ""
    print_info "Configuration:"
    echo "  KB Path:        $KB_PATH"
    echo "  Queries Path:   $QUERIES_PATH"
    echo "  Max Iterations: $MAX_ITERATIONS"
    echo "  Target Score:   ${TARGET_SCORE}%"
    echo ""

    # Main loop
    local consecutive_improve_failures=0

    for ((iteration = 1; iteration <= MAX_ITERATIONS; iteration++)); do
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${CYAN}ITERATION ${iteration}/${MAX_ITERATIONS}${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo ""

        # Step 1: Clean slate and generate
        rm -f "$STATE_FILE" "$OUTPUT_FILE" "$REJECTED_FILE"

        print_info "Step 1/3: Generating synthetic data..."
        echo ""

        local gen_exit=0
        "$SCRIPT_DIR/generate.sh" --kb-path "$KB_PATH" --queries-path "$QUERIES_PATH" --no-resume || gen_exit=$?

        if [[ $gen_exit -ne 0 ]]; then
            echo ""
            print_error "Generation failed (exit code: $gen_exit). Stopping pipeline."
            if [[ ${#SCORE_HISTORY[@]} -gt 0 ]]; then
                print_summary
            fi
            exit 1
        fi

        print_success "Generation complete"
        echo ""

        # Step 2: Analyze
        print_info "Step 2/3: Analyzing quality..."
        echo ""

        local analysis_exit=0
        "$SCRIPT_DIR/analysis.sh" --synthetic-path "$OUTPUT_FILE" --queries-path "$QUERIES_PATH" || analysis_exit=$?

        if [[ $analysis_exit -ne 0 ]]; then
            echo ""
            print_error "Analysis failed (exit code: $analysis_exit). Stopping pipeline."
            if [[ ${#SCORE_HISTORY[@]} -gt 0 ]]; then
                print_summary
            fi
            exit 1
        fi

        print_success "Analysis complete"
        echo ""

        # Extract score
        local score
        score=$(extract_score "$REPORT_FILE")

        if [[ -z "$score" ]]; then
            print_warning "Could not extract score from analysis report."
            score="?"
        fi

        SCORE_HISTORY+=("$score")

        # Display score with delta
        local delta_msg=""
        if [[ ${#SCORE_HISTORY[@]} -gt 1 && "$score" =~ ^[0-9]+$ ]]; then
            local prev_score="${SCORE_HISTORY[-2]}"
            if [[ "$prev_score" =~ ^[0-9]+$ ]]; then
                local diff=$((score - prev_score))
                if [[ $diff -ge 0 ]]; then
                    delta_msg="  (+${diff}% from previous)"
                else
                    delta_msg="  (${diff}% from previous)"
                fi
            fi
        fi

        echo -e "  Score: ${YELLOW}${score}%${NC}  (target: ${TARGET_SCORE}%)${delta_msg}"
        echo ""

        # Check if target reached
        if [[ "$score" =~ ^[0-9]+$ && "$score" -ge "$TARGET_SCORE" ]]; then
            print_summary

            local first="${SCORE_HISTORY[0]}"
            local total_improvement=0
            if [[ "$first" =~ ^[0-9]+$ ]]; then
                total_improvement=$((score - first))
            fi

            echo -e "  Result: ${GREEN}TARGET REACHED${NC} (${score}% >= ${TARGET_SCORE}%)"
            echo -e "  Total iterations: $iteration"
            echo -e "  Total improvement: ${GREEN}+${total_improvement}%${NC}"
            echo ""
            exit 0
        fi

        # Check if last iteration (no improvement step needed)
        if [[ $iteration -eq $MAX_ITERATIONS ]]; then
            break
        fi

        # Step 3: Improve prompt
        print_info "Step 3/3: Improving prompt..."
        echo ""

        local improve_exit=0
        "$SCRIPT_DIR/improve_prompt.sh" --queries-path "$QUERIES_PATH" || improve_exit=$?

        if [[ $improve_exit -ne 0 ]]; then
            consecutive_improve_failures=$((consecutive_improve_failures + 1))
            echo ""
            print_warning "Prompt improvement failed (attempt $consecutive_improve_failures). Prompt unchanged."

            if [[ $consecutive_improve_failures -ge 2 ]]; then
                echo ""
                print_error "2 consecutive improve failures. Stopping pipeline."
                print_summary

                local first="${SCORE_HISTORY[0]}"
                local last="${SCORE_HISTORY[-1]}"
                local total_improvement=0
                if [[ "$first" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]]; then
                    total_improvement=$((last - first))
                fi

                echo -e "  Result: ${RED}STOPPED (consecutive improve failures)${NC}"
                echo -e "  Total iterations: $iteration"
                echo -e "  Total improvement: +${total_improvement}%"
                echo ""
                exit 1
            fi
        else
            consecutive_improve_failures=0
            print_success "Prompt improved"
        fi

        echo ""
    done

    # Max iterations exhausted
    print_summary

    local first="${SCORE_HISTORY[0]}"
    local last="${SCORE_HISTORY[-1]}"
    local total_improvement=0
    if [[ "$first" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]]; then
        total_improvement=$((last - first))
    fi

    echo -e "  Result: ${YELLOW}MAX ITERATIONS REACHED${NC} (${last}% < ${TARGET_SCORE}%)"
    echo -e "  Total iterations: $MAX_ITERATIONS"
    echo -e "  Total improvement: +${total_improvement}%"
    echo ""
}

# Run main
main "$@"
