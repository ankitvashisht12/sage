"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { useReviewStore } from "@/stores/reviewStore";
import MetadataSection from "./MetadataSection";

export default function DetailPanel() {
  const items = useReviewStore((s) => s.items);
  const selectedIndex = useReviewStore((s) => s.selectedIndex);
  const updateItem = useReviewStore((s) => s.updateItem);
  const selectNextPending = useReviewStore((s) => s.selectNextPending);

  const item = selectedIndex >= 0 ? items[selectedIndex] : null;
  const [notes, setNotes] = useState("");
  const notesRef = useRef<HTMLTextAreaElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  // Sync notes with selected item
  useEffect(() => {
    setNotes(item?.reviewer_notes ?? "");
  }, [item?.reviewer_notes, selectedIndex]);

  const saveNotes = useCallback(
    (value: string) => {
      if (selectedIndex < 0) return;
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => {
        updateItem(selectedIndex, { reviewer_notes: value });
      }, 500);
    },
    [selectedIndex, updateItem]
  );

  const handleAccept = useCallback(async () => {
    if (selectedIndex < 0) return;
    await updateItem(selectedIndex, { accepted: true });
    selectNextPending();
  }, [selectedIndex, updateItem, selectNextPending]);

  const handleReject = useCallback(async () => {
    if (selectedIndex < 0) return;
    await updateItem(selectedIndex, { accepted: false });
    selectNextPending();
  }, [selectedIndex, updateItem, selectNextPending]);

  // Expose refs for keyboard shortcuts
  useEffect(() => {
    if (notesRef.current) notesRef.current.id = "reviewer-notes";
  }, []);

  if (!item) {
    return (
      <div
        className="flex items-center justify-center h-full text-sm"
        style={{ color: "var(--text-muted)", background: "var(--bg-primary)" }}
      >
        Select an item to review
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full overflow-auto" style={{ background: "var(--bg-primary)" }}>
      {/* Query */}
      <div className="p-4 border-b" style={{ borderColor: "var(--border)" }}>
        <div className="text-[10px] uppercase tracking-wider mb-1" style={{ color: "var(--text-muted)" }}>
          Query
        </div>
        <div className="text-sm" style={{ color: "var(--text-primary)" }}>
          {item.query}
        </div>
      </div>

      {/* Citation */}
      <div className="p-4 border-b" style={{ borderColor: "var(--border)" }}>
        <div className="flex items-center gap-2 mb-1">
          <span className="text-[10px] uppercase tracking-wider" style={{ color: "var(--text-muted)" }}>
            Citation
          </span>
          {item.citation_overridden && (
            <span
              className="text-[10px] px-1.5 rounded"
              style={{ background: "var(--accent-yellow-bg)", color: "var(--accent-yellow)" }}
            >
              overridden
            </span>
          )}
        </div>
        <div
          className="text-xs p-3 rounded whitespace-pre-wrap"
          style={{ background: "var(--bg-secondary)", color: "var(--text-primary)", border: "1px solid var(--border)" }}
        >
          {item.citation}
        </div>
        <div className="mt-1 text-[10px]" style={{ color: "var(--text-muted)" }}>
          {item.doc_id} [{item.start_index}:{item.end_index}]
        </div>
      </div>

      {/* Metadata */}
      <MetadataSection label="Classification">
        <div className="grid grid-cols-2 gap-2">
          <div>
            <span style={{ color: "var(--text-muted)" }}>Category: </span>
            {item.category}
          </div>
          <div>
            <span style={{ color: "var(--text-muted)" }}>Subcategory: </span>
            {item.subcategory}
          </div>
        </div>
      </MetadataSection>

      <MetadataSection label="Query Metadata">
        {item.query_metadata ? (
          <div className="grid grid-cols-2 gap-2">
            <div>
              <span style={{ color: "var(--text-muted)" }}>Language: </span>
              {item.query_metadata.language}
            </div>
            <div>
              <span style={{ color: "var(--text-muted)" }}>Tone: </span>
              {item.query_metadata.tone}
            </div>
            <div>
              <span style={{ color: "var(--text-muted)" }}>Style: </span>
              {item.query_metadata.style}
            </div>
            <div>
              <span style={{ color: "var(--text-muted)" }}>Typos: </span>
              {item.query_metadata.has_typos ? "yes" : "no"}
            </div>
          </div>
        ) : (
          <span style={{ color: "var(--text-muted)" }}>No metadata</span>
        )}
      </MetadataSection>

      <MetadataSection label="Sources">
        <div className="space-y-1">
          {item.source.map((s, i) => (
            <a
              key={i}
              href={s}
              target="_blank"
              rel="noopener noreferrer"
              className="block truncate hover:underline"
              style={{ color: "var(--accent-blue)" }}
            >
              {s}
            </a>
          ))}
          {item.source.length === 0 && (
            <span style={{ color: "var(--text-muted)" }}>No sources</span>
          )}
        </div>
      </MetadataSection>

      <MetadataSection label="Chunks">
        <div className="space-y-2">
          {item.chunks.map((chunk, i) => (
            <div
              key={i}
              className="p-2 rounded text-[11px] whitespace-pre-wrap"
              style={{ background: "var(--bg-secondary)", border: "1px solid var(--border)" }}
            >
              {chunk}
            </div>
          ))}
          {item.chunks.length === 0 && (
            <span style={{ color: "var(--text-muted)" }}>No chunks</span>
          )}
        </div>
      </MetadataSection>

      {/* Reviewer Notes */}
      <div className="p-4 border-b" style={{ borderColor: "var(--border)" }}>
        <div className="flex items-center gap-2 mb-1">
          <span className="text-[10px] uppercase tracking-wider" style={{ color: "var(--text-muted)" }}>
            Reviewer Notes
          </span>
          <kbd>n</kbd>
        </div>
        <textarea
          ref={notesRef}
          value={notes}
          onChange={(e) => {
            setNotes(e.target.value);
            saveNotes(e.target.value);
          }}
          onBlur={() => {
            if (debounceRef.current) clearTimeout(debounceRef.current);
            if (selectedIndex >= 0) updateItem(selectedIndex, { reviewer_notes: notes });
          }}
          placeholder="Add notes about this item..."
          rows={3}
          className="w-full px-3 py-2 text-xs rounded resize-none"
          style={{
            background: "var(--bg-secondary)",
            color: "var(--text-primary)",
            border: "1px solid var(--border)",
            outline: "none",
          }}
        />
      </div>

      {/* Actions */}
      <div className="p-4 flex gap-3">
        <button
          onClick={handleAccept}
          className="flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded text-xs font-medium transition-colors"
          style={{
            background: item.accepted === true ? "var(--accent-green)" : "var(--accent-green-bg)",
            color: item.accepted === true ? "#fff" : "var(--accent-green)",
            border: `1px solid ${item.accepted === true ? "var(--accent-green)" : "transparent"}`,
          }}
        >
          Accept <kbd>a</kbd>
        </button>
        <button
          onClick={handleReject}
          className="flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded text-xs font-medium transition-colors"
          style={{
            background: item.accepted === false ? "var(--accent-red)" : "var(--accent-red-bg)",
            color: item.accepted === false ? "#fff" : "var(--accent-red)",
            border: `1px solid ${item.accepted === false ? "var(--accent-red)" : "transparent"}`,
          }}
        >
          Reject <kbd>r</kbd>
        </button>
      </div>
    </div>
  );
}
