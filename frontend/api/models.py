"""Pydantic models for the review API."""

from pydantic import BaseModel
from typing import Optional


class QueryMetadata(BaseModel):
    language: str = "en"
    has_typos: bool = False
    tone: str = "neutral"
    style: str = "question"


class ReviewItem(BaseModel):
    query: str
    doc_id: str
    citation: str
    start_index: int = 0
    end_index: int = 0
    category: str = ""
    subcategory: str = ""
    chunks: list[str] = []
    source: list[str] = []
    query_metadata: Optional[QueryMetadata] = None
    accepted: Optional[bool] = None
    reviewer_notes: str = ""
    citation_overridden: bool = False


class ItemPatch(BaseModel):
    accepted: Optional[bool] = None
    reviewer_notes: Optional[str] = None
    citation: Optional[str] = None
    start_index: Optional[int] = None
    end_index: Optional[int] = None
    citation_overridden: Optional[bool] = None


class ComputeSpanRequest(BaseModel):
    doc_id: str
    selected_text: str


class ComputeSpanResponse(BaseModel):
    found: bool
    start_index: int
    end_index: int


class UploadRequest(BaseModel):
    dataset_name: str


class UploadResponse(BaseModel):
    dataset_url: str
    count: int
