#!/bin/bash
#
# Upload synthetic Q&A data to LangSmith
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

# Default files
OUTPUT_FILE="$SCRIPT_DIR/output.jsonl"
ENV_FILE="$SCRIPT_DIR/.env"
UPLOAD_SCRIPT="$SCRIPT_DIR/helpers/upload_langsmith.py"

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           LangSmith Dataset Uploader                          ║"
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

main() {
    print_header

    # Check for uv
    if ! command -v uv &> /dev/null; then
        print_error "uv not found. Please install it:"
        echo ""
        echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi

    # Load .env file if exists
    if [[ -f "$ENV_FILE" ]]; then
        print_info "Loading environment from .env"
        set -a
        source "$ENV_FILE"
        set +a
    elif [[ -f "$SCRIPT_DIR/example.env" ]]; then
        print_warning ".env file not found"
        echo ""
        echo "Create it by copying example.env:"
        echo "  cp example.env .env"
        echo ""
        echo "Then edit .env and add your LangSmith API key."
        exit 1
    fi

    # Check for API key
    if [[ -z "$LANGSMITH_API_KEY" ]]; then
        print_error "LANGSMITH_API_KEY not set"
        echo ""
        echo "Set it in your .env file or export it:"
        echo "  export LANGSMITH_API_KEY='your-api-key'"
        echo ""
        echo "Get your API key from: https://smith.langchain.com/settings"
        exit 1
    fi

    # Check for output file
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        print_error "Output file not found: $OUTPUT_FILE"
        echo ""
        echo "Run generate.sh first to create synthetic data."
        exit 1
    fi

    # Count entries
    local count
    count=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
    print_info "Found $count Q&A pairs in output.jsonl"

    # Get dataset name
    local dataset_name="${LANGSMITH_DATASET_NAME:-rag-eval-dataset}"

    echo ""
    read -p "Enter dataset name [$dataset_name]: " input_name
    if [[ -n "$input_name" ]]; then
        dataset_name="$input_name"
    fi

    echo ""
    print_info "Uploading to LangSmith..."
    print_info "(uv will auto-install dependencies on first run)"
    echo ""

    # Run upload script via uv (auto-installs langsmith from pyproject.toml)
    uv run --project "$SCRIPT_DIR" python "$UPLOAD_SCRIPT" "$OUTPUT_FILE" "$dataset_name"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run main
main "$@"
