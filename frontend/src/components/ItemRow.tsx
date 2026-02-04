"use client";

import type { ReviewItem } from "@/lib/types";

interface Props {
  item: ReviewItem;
  index: number;
  selected: boolean;
  onClick: () => void;
}

export default function ItemRow({ item, index, selected, onClick }: Props) {
  const statusClass = item.accepted === true ? "accepted" : item.accepted === false ? "rejected" : "pending";

  return (
    <button
      onClick={onClick}
      className={`w-full text-left px-3 py-2 flex items-start gap-2 border-b transition-colors ${
        selected
          ? "bg-[var(--accent-blue-bg)] border-[var(--accent-blue)]"
          : "border-[var(--border)] hover:bg-[var(--bg-hover)]"
      }`}
    >
      <span className={`status-dot ${statusClass} mt-1.5`} />
      <div className="min-w-0 flex-1">
        <div className="text-xs truncate" style={{ color: "var(--text-primary)" }}>
          {item.query}
        </div>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-[10px]" style={{ color: "var(--text-muted)" }}>
            #{index}
          </span>
          {item.category && (
            <span
              className="text-[10px] px-1.5 py-0 rounded"
              style={{ background: "var(--bg-tertiary)", color: "var(--text-secondary)" }}
            >
              {item.category}
            </span>
          )}
          {item.citation_overridden && (
            <span
              className="text-[10px] px-1.5 py-0 rounded"
              style={{ background: "var(--accent-yellow-bg)", color: "var(--accent-yellow)" }}
            >
              edited
            </span>
          )}
        </div>
      </div>
    </button>
  );
}
