"use client";

import { useEffect, useRef, useState, useCallback, useMemo } from "react";
import type { Components } from "react-markdown";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { useReviewStore } from "@/stores/reviewStore";
import { fetchKBContent, computeSpan } from "@/lib/api";
import CitationOverride from "./CitationOverride";

const mdComponents: Components = {
  img: ({ src, ...props }) => (src ? <img src={src} {...props} /> : null),
};

const mdCitationComponents: Components = {
  ...mdComponents,
  p: ({ children }) => <span>{children}</span>,
};

export default function SourceViewer() {
  const items = useReviewStore((s) => s.items);
  const selectedIndex = useReviewStore((s) => s.selectedIndex);
  const updateItem = useReviewStore((s) => s.updateItem);

  const item = selectedIndex >= 0 ? items[selectedIndex] : null;

  const [content, setContent] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState(false);
  const contentRef = useRef<HTMLPreElement>(null);
  const markRef = useRef<HTMLElement>(null);
  const previewMarkRef = useRef<HTMLElement>(null);

  // Selection state for citation override
  const [selection, setSelection] = useState<{ text: string; rect: DOMRect } | null>(null);

  // Fetch KB content when doc_id changes
  useEffect(() => {
    if (!item?.doc_id) {
      setContent(null);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    fetchKBContent(item.doc_id)
      .then((data) => {
        if (!cancelled) {
          setContent(data.content);
          setLoading(false);
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError((err as Error).message);
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [item?.doc_id]);

  // Scroll to citation highlight
  useEffect(() => {
    const ref = preview ? previewMarkRef.current : markRef.current;
    if (ref) {
      ref.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  }, [content, item?.start_index, item?.end_index, preview]);

  // Handle text selection
  const handleMouseUp = useCallback(() => {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) {
      setSelection(null);
      return;
    }

    const text = sel.toString().trim();
    if (!text) {
      setSelection(null);
      return;
    }

    const range = sel.getRangeAt(0);
    const rect = range.getBoundingClientRect();
    setSelection({ text, rect });
  }, []);

  // Handle citation override
  const handleUseCitation = useCallback(async () => {
    if (!selection || !item || selectedIndex < 0) return;

    try {
      const span = await computeSpan(item.doc_id, selection.text);
      if (span.found) {
        await updateItem(selectedIndex, {
          citation: selection.text,
          start_index: span.start_index,
          end_index: span.end_index,
          citation_overridden: true,
        });
      }
    } catch {
      // Silently fail
    }

    setSelection(null);
    window.getSelection()?.removeAllRanges();
  }, [selection, item, selectedIndex, updateItem]);

  // For preview mode: split markdown around the citation span and inject a <mark>
  const previewMarkdown = useMemo(() => {
    if (!content || !item) return null;
    const start = item.start_index;
    const end = item.end_index;
    const hasValidSpan = start >= 0 && end > start && end <= content.length;
    if (!hasValidSpan) return { before: content, citation: null, after: "" };
    return {
      before: content.slice(0, start),
      citation: content.slice(start, end),
      after: content.slice(end),
    };
  }, [content, item]);

  if (!item) {
    return (
      <div
        className="flex items-center justify-center h-full text-sm"
        style={{ color: "var(--text-muted)", background: "var(--bg-secondary)" }}
      >
        No item selected
      </div>
    );
  }

  if (loading) {
    return (
      <div
        className="flex items-center justify-center h-full text-sm"
        style={{ color: "var(--text-muted)", background: "var(--bg-secondary)" }}
      >
        Loading source...
      </div>
    );
  }

  if (error) {
    return (
      <div
        className="flex items-center justify-center h-full text-sm"
        style={{ color: "var(--accent-red)", background: "var(--bg-secondary)" }}
      >
        {error}
      </div>
    );
  }

  if (!content) {
    return (
      <div
        className="flex items-center justify-center h-full text-sm"
        style={{ color: "var(--text-muted)", background: "var(--bg-secondary)" }}
      >
        No content
      </div>
    );
  }

  const start = item.start_index;
  const end = item.end_index;
  const hasValidSpan = start >= 0 && end > start && end <= content.length;

  return (
    <div className="relative flex flex-col h-full" style={{ background: "var(--bg-secondary)" }}>
      {/* Header */}
      <div
        className="px-4 py-2 border-b text-[10px] flex items-center justify-between"
        style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}
      >
        <div className="flex items-center gap-2">
          <span>{item.doc_id}</span>
          {hasValidSpan && <span>[{start}:{end}]</span>}
        </div>
        <button
          onClick={() => setPreview(!preview)}
          title={preview ? "Show raw markdown" : "Preview markdown"}
          className="flex items-center justify-center w-6 h-6 rounded transition-colors"
          style={{
            background: preview ? "var(--accent-blue-bg)" : "var(--bg-tertiary)",
            color: preview ? "var(--accent-blue)" : "var(--text-secondary)",
            border: `1px solid ${preview ? "var(--accent-blue)" : "var(--border)"}`,
          }}
        >
          {preview ? (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="16 18 22 12 16 6" />
              <polyline points="8 6 2 12 8 18" />
            </svg>
          ) : (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
              <circle cx="12" cy="12" r="3" />
            </svg>
          )}
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto p-4" onMouseUp={handleMouseUp}>
        {preview ? (
          <div className="prose prose-sm max-w-none">
            {previewMarkdown?.citation ? (
              <>
                <ReactMarkdown remarkPlugins={[remarkGfm]} components={mdComponents}>
                  {previewMarkdown.before}
                </ReactMarkdown>
                <mark ref={previewMarkRef} className="citation-highlight">
                  <ReactMarkdown remarkPlugins={[remarkGfm]} components={mdCitationComponents}>
                    {previewMarkdown.citation}
                  </ReactMarkdown>
                </mark>
                <ReactMarkdown remarkPlugins={[remarkGfm]} components={mdComponents}>
                  {previewMarkdown.after}
                </ReactMarkdown>
              </>
            ) : (
              <ReactMarkdown remarkPlugins={[remarkGfm]} components={mdComponents}>
                {content}
              </ReactMarkdown>
            )}
          </div>
        ) : (
          <pre
            ref={contentRef}
            className="text-xs whitespace-pre-wrap break-words"
            style={{ color: "var(--text-primary)", fontFamily: "var(--font-mono), monospace" }}
          >
            {hasValidSpan ? (
              <>
                {content.slice(0, start)}
                <mark ref={markRef} className="citation-highlight">
                  {content.slice(start, end)}
                </mark>
                {content.slice(end)}
              </>
            ) : (
              content
            )}
          </pre>
        )}
      </div>

      {selection && (
        <CitationOverride
          rect={selection.rect}
          onUse={handleUseCitation}
          onDismiss={() => setSelection(null)}
        />
      )}
    </div>
  );
}
