export interface QueryMetadata {
  language: string;
  has_typos: boolean;
  tone: string;
  style: string;
}

export interface ReviewItem {
  query: string;
  doc_id: string;
  citation: string;
  start_index: number;
  end_index: number;
  category: string;
  subcategory: string;
  chunks: string[];
  source: string[];
  query_metadata: QueryMetadata | null;
  accepted: boolean | null;
  reviewer_notes: string;
  citation_overridden: boolean;
}

export interface ItemPatch {
  accepted?: boolean | null;
  reviewer_notes?: string;
  citation?: string;
  start_index?: number;
  end_index?: number;
  citation_overridden?: boolean;
}

export interface KBContent {
  doc_id: string;
  content: string;
}

export interface ComputeSpanResponse {
  found: boolean;
  start_index: number;
  end_index: number;
}

export interface UploadResponse {
  dataset_url: string;
  count: number;
}

export type FilterStatus = "all" | "pending" | "accepted" | "rejected";
