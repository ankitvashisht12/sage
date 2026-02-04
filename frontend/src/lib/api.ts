import type { ReviewItem, ItemPatch, KBContent, ComputeSpanResponse, UploadResponse } from "./types";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`API ${res.status}: ${body}`);
  }
  return res.json();
}

export function fetchItems(): Promise<ReviewItem[]> {
  return request<ReviewItem[]>("/api/items");
}

export function patchItem(index: number, patch: ItemPatch): Promise<ReviewItem> {
  return request<ReviewItem>(`/api/items/${index}`, {
    method: "PATCH",
    body: JSON.stringify(patch),
  });
}

export function fetchKBContent(docId: string): Promise<KBContent> {
  return request<KBContent>(`/api/kb/${encodeURIComponent(docId)}`);
}

export function computeSpan(docId: string, selectedText: string): Promise<ComputeSpanResponse> {
  return request<ComputeSpanResponse>("/api/citation/compute", {
    method: "POST",
    body: JSON.stringify({ doc_id: docId, selected_text: selectedText }),
  });
}

export function uploadToLangSmith(datasetName: string): Promise<UploadResponse> {
  return request<UploadResponse>("/api/upload", {
    method: "POST",
    body: JSON.stringify({ dataset_name: datasetName }),
  });
}
