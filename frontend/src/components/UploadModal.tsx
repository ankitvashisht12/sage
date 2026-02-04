"use client";

import { useState, useCallback, useEffect } from "react";
import { uploadToLangSmith } from "@/lib/api";

interface Props {
  onClose: () => void;
}

export default function UploadModal({ onClose }: Props) {
  const [datasetName, setDatasetName] = useState("rag-eval-dataset");
  const [uploading, setUploading] = useState(false);
  const [result, setResult] = useState<{ url: string; count: number } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleUpload = useCallback(async () => {
    if (!datasetName.trim()) return;
    setUploading(true);
    setError(null);
    try {
      const res = await uploadToLangSmith(datasetName.trim());
      setResult({ url: res.dataset_url, count: res.count });
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setUploading(false);
    }
  }, [datasetName]);

  // Close on Escape
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" style={{ background: "rgba(0,0,0,0.6)" }}>
      <div
        className="w-full max-w-md rounded-lg p-6"
        style={{ background: "var(--bg-secondary)", border: "1px solid var(--border)" }}
      >
        <h2 className="text-sm font-semibold mb-4" style={{ color: "var(--text-primary)" }}>
          Upload to LangSmith
        </h2>

        {result ? (
          <div className="space-y-3">
            <div className="text-xs" style={{ color: "var(--accent-green)" }}>
              Uploaded {result.count} items
            </div>
            <a
              href={result.url}
              target="_blank"
              rel="noopener noreferrer"
              className="block text-xs truncate hover:underline"
              style={{ color: "var(--accent-blue)" }}
            >
              {result.url}
            </a>
            <button
              onClick={onClose}
              className="w-full px-4 py-2 text-xs rounded"
              style={{ background: "var(--bg-tertiary)", color: "var(--text-primary)" }}
            >
              Close
            </button>
          </div>
        ) : (
          <div className="space-y-3">
            <div>
              <label className="block text-[10px] mb-1" style={{ color: "var(--text-muted)" }}>
                Dataset Name
              </label>
              <input
                type="text"
                value={datasetName}
                onChange={(e) => setDatasetName(e.target.value)}
                className="w-full px-3 py-2 text-xs rounded"
                style={{
                  background: "var(--bg-primary)",
                  color: "var(--text-primary)",
                  border: "1px solid var(--border)",
                  outline: "none",
                }}
                autoFocus
              />
            </div>

            {error && (
              <div className="text-xs p-2 rounded" style={{ background: "var(--accent-red-bg)", color: "var(--accent-red)" }}>
                {error}
              </div>
            )}

            <div className="flex gap-2">
              <button
                onClick={onClose}
                className="flex-1 px-4 py-2 text-xs rounded"
                style={{ background: "var(--bg-tertiary)", color: "var(--text-secondary)" }}
              >
                Cancel
              </button>
              <button
                onClick={handleUpload}
                disabled={uploading || !datasetName.trim()}
                className="flex-1 px-4 py-2 text-xs rounded font-medium disabled:opacity-40"
                style={{ background: "var(--accent-blue)", color: "#fff" }}
              >
                {uploading ? "Uploading..." : "Upload"}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
