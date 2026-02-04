"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useReviewStore } from "@/stores/reviewStore";
import { fetchKBContent, computeSpan } from "@/lib/api";
import CitationOverride from "./CitationOverride";

export default function SourceViewer() {
  const items = useReviewStore((s) => s.items);
  const selectedIndex = useReviewStore((s) => s.selectedIndex);
  const updateItem = useReviewStore((s) => s.updateItem);

  const item = selectedIndex >= 0 ? items[selectedIndex] : null;

  const [content, setContent] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const contentRef = useRef<HTMLPreElement>(null);
  const markRef = useRef<HTMLElement>(null);

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
    if (markRef.current) {
      markRef.current.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  }, [content, item?.start_index, item?.end_index]);

  // Handle text selection
  const handleMouseUp = useCallback(() => {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed || !contentRef.current) {
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

  // Render content with citation highlight
  const start = item.start_index;
  const end = item.end_index;
  const hasValidSpan = start >= 0 && end > start && end <= content.length;

  return (
    <div className="relative flex flex-col h-full" style={{ background: "var(--bg-secondary)" }}>
      <div
        className="px-4 py-2 border-b text-[10px] flex items-center gap-2"
        style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}
      >
        <span>{item.doc_id}</span>
        {hasValidSpan && <span>[{start}:{end}]</span>}
      </div>
      <div className="flex-1 overflow-auto p-4" onMouseUp={handleMouseUp}>
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
