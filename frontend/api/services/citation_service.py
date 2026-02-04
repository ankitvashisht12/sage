"""Citation span computation — reuses helpers/validate.py."""

from validate import compute_span  # noqa: E402 (added via sys.path in config)

# Re-export for use in the API
__all__ = ["compute_span"]
