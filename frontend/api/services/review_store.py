"""In-memory review store backed by review.jsonl."""

import json
import os
import shutil
import tempfile
import threading
from pathlib import Path

from ..config import OUTPUT_JSONL, REVIEW_JSONL


_lock = threading.Lock()
_items: list[dict] = []


def _load_jsonl(path: Path) -> list[dict]:
    data = []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                data.append(json.loads(line))
    return data


def _save_jsonl(path: Path, items: list[dict]):
    """Atomic write: write to temp file then rename."""
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            for item in items:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")
        shutil.move(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def init():
    """Load or create review.jsonl on startup."""
    global _items
    with _lock:
        if REVIEW_JSONL.exists():
            _items = _load_jsonl(REVIEW_JSONL)
        elif OUTPUT_JSONL.exists():
            raw = _load_jsonl(OUTPUT_JSONL)
            _items = []
            for item in raw:
                item.setdefault("accepted", None)
                item.setdefault("reviewer_notes", "")
                item.setdefault("citation_overridden", False)
                _items.append(item)
            _save_jsonl(REVIEW_JSONL, _items)
        else:
            _items = []


def get_all() -> list[dict]:
    return list(_items)


def get(index: int) -> dict | None:
    if 0 <= index < len(_items):
        return _items[index]
    return None


def update(index: int, patch: dict) -> dict | None:
    with _lock:
        if index < 0 or index >= len(_items):
            return None
        for key, value in patch.items():
            if value is not None:
                _items[index][key] = value
        _save_jsonl(REVIEW_JSONL, _items)
        return _items[index]


def count() -> int:
    return len(_items)
