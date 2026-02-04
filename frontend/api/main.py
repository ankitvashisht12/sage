"""FastAPI backend for the review tool."""

from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .config import ENV_FILE
from .models import (
    ComputeSpanRequest,
    ComputeSpanResponse,
    ItemPatch,
    UploadRequest,
    UploadResponse,
)
from .services import review_store, kb_store

# Load .env from project root
load_dotenv(ENV_FILE)

# Import after sys.path is set up by config
from .services.citation_service import compute_span  # noqa: E402


@asynccontextmanager
async def lifespan(app: FastAPI):
    review_store.init()
    yield


app = FastAPI(title="Review Tool API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/items")
def get_items():
    return review_store.get_all()


@app.patch("/api/items/{index}")
def patch_item(index: int, patch: ItemPatch):
    updates = patch.model_dump(exclude_none=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    result = review_store.update(index, updates)
    if result is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return result


@app.get("/api/kb/{doc_id:path}")
def get_kb(doc_id: str):
    content = kb_store.get_kb_content(doc_id)
    if content is None:
        raise HTTPException(status_code=404, detail="KB file not found")
    return {"doc_id": doc_id, "content": content}


@app.post("/api/citation/compute", response_model=ComputeSpanResponse)
def compute_citation_span(req: ComputeSpanRequest):
    content = kb_store.get_kb_content(req.doc_id)
    if content is None:
        raise HTTPException(status_code=404, detail="KB file not found")
    found, start, end = compute_span(req.selected_text, content)
    return ComputeSpanResponse(found=found, start_index=start, end_index=end)


@app.post("/api/upload", response_model=UploadResponse)
def upload(req: UploadRequest):
    items = review_store.get_all()
    accepted = [item for item in items if item.get("accepted") is True]
    if not accepted:
        raise HTTPException(status_code=400, detail="No accepted items to upload")

    from .services.upload_service import upload_to_langsmith

    dataset_url = upload_to_langsmith(accepted, req.dataset_name)
    return UploadResponse(dataset_url=dataset_url, count=len(accepted))
