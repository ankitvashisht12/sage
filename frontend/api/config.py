"""Path configuration for the review API."""

import os
from pathlib import Path

# Project root is two levels up from this file (frontend/api/config.py -> project root)
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
KB_PATH = PROJECT_ROOT / "kb"
HELPERS_PATH = PROJECT_ROOT / "helpers"
OUTPUT_JSONL = PROJECT_ROOT / "output.jsonl"
REVIEW_JSONL = PROJECT_ROOT / "review.jsonl"
ENV_FILE = PROJECT_ROOT / ".env"

# Add helpers to sys.path for imports
import sys
if str(HELPERS_PATH) not in sys.path:
    sys.path.insert(0, str(HELPERS_PATH))
