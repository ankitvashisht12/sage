"""KB file reader with LRU cache."""

import re
from functools import lru_cache
from pathlib import Path

from ..config import KB_PATH


def _strip_frontmatter(content: str) -> str:
    """Remove YAML frontmatter if present."""
    if content.startswith("---"):
        match = re.match(r"^---\s*\n.*?\n---\s*\n?", content, re.DOTALL)
        if match:
            return content[match.end():]
    return content


@lru_cache(maxsize=256)
def get_kb_content(doc_id: str) -> str | None:
    """Read KB file content, stripping frontmatter. Returns None if not found."""
    path = KB_PATH / doc_id
    # Validate no path traversal
    try:
        resolved = path.resolve()
        if not str(resolved).startswith(str(KB_PATH.resolve())):
            return None
    except (OSError, ValueError):
        return None

    if not path.exists():
        return None

    content = path.read_text(encoding="utf-8")
    return _strip_frontmatter(content)


def get_kb_raw(doc_id: str) -> str | None:
    """Read full KB file content including frontmatter."""
    path = KB_PATH / doc_id
    try:
        resolved = path.resolve()
        if not str(resolved).startswith(str(KB_PATH.resolve())):
            return None
    except (OSError, ValueError):
        return None

    if not path.exists():
        return None

    return path.read_text(encoding="utf-8")
