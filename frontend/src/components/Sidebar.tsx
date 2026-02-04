"use client";

import { useRef, useEffect } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import { useReviewStore } from "@/stores/reviewStore";
import type { FilterStatus } from "@/lib/types";
import ItemRow from "./ItemRow";

const FILTER_OPTIONS: { value: FilterStatus; label: string }[] = [
  { value: "all", label: "All" },
  { value: "pending", label: "Pending" },
  { value: "accepted", label: "Accepted" },
  { value: "rejected", label: "Rejected" },
];

export default function Sidebar() {
  const items = useReviewStore((s) => s.items);
  const filteredIndices = useReviewStore((s) => s.filteredIndices);
  const selectedIndex = useReviewStore((s) => s.selectedIndex);
  const filterStatus = useReviewStore((s) => s.filterStatus);
  const searchQuery = useReviewStore((s) => s.searchQuery);
  const select = useReviewStore((s) => s.select);
  const setFilter = useReviewStore((s) => s.setFilter);
  const setSearch = useReviewStore((s) => s.setSearch);

  const parentRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  const virtualizer = useVirtualizer({
    count: filteredIndices.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 52,
    overscan: 10,
  });

  // Scroll selected item into view
  useEffect(() => {
    const pos = filteredIndices.indexOf(selectedIndex);
    if (pos >= 0) {
      virtualizer.scrollToIndex(pos, { align: "auto" });
    }
  }, [selectedIndex, filteredIndices, virtualizer]);

  // Expose search ref for keyboard shortcut
  useEffect(() => {
    const el = searchRef.current;
    if (el) el.id = "sidebar-search";
  }, []);

  return (
    <div className="flex flex-col h-full" style={{ background: "var(--bg-secondary)" }}>
      {/* Search */}
      <div className="p-2 border-b" style={{ borderColor: "var(--border)" }}>
        <div className="relative">
          <input
            ref={searchRef}
            type="text"
            placeholder="Search queries..."
            value={searchQuery}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full px-2 py-1.5 text-xs rounded"
            style={{
              background: "var(--bg-primary)",
              color: "var(--text-primary)",
              border: "1px solid var(--border)",
              outline: "none",
            }}
          />
          <kbd className="absolute right-2 top-1/2 -translate-y-1/2">/</kbd>
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-1 p-2 border-b" style={{ borderColor: "var(--border)" }}>
        {FILTER_OPTIONS.map((opt) => (
          <button
            key={opt.value}
            onClick={() => setFilter(opt.value)}
            className="px-2 py-0.5 text-[11px] rounded transition-colors"
            style={{
              background: filterStatus === opt.value ? "var(--accent-blue-bg)" : "transparent",
              color: filterStatus === opt.value ? "var(--accent-blue)" : "var(--text-secondary)",
              border: `1px solid ${filterStatus === opt.value ? "var(--accent-blue)" : "var(--border)"}`,
            }}
          >
            {opt.label}
          </button>
        ))}
      </div>

      {/* Count */}
      <div className="px-3 py-1 text-[10px]" style={{ color: "var(--text-muted)" }}>
        {filteredIndices.length} of {items.length} items
      </div>

      {/* Virtualized list */}
      <div ref={parentRef} className="flex-1 overflow-auto">
        <div
          style={{
            height: `${virtualizer.getTotalSize()}px`,
            width: "100%",
            position: "relative",
          }}
        >
          {virtualizer.getVirtualItems().map((virtualRow) => {
            const itemIndex = filteredIndices[virtualRow.index];
            const item = items[itemIndex];
            return (
              <div
                key={virtualRow.index}
                style={{
                  position: "absolute",
                  top: 0,
                  left: 0,
                  width: "100%",
                  height: `${virtualRow.size}px`,
                  transform: `translateY(${virtualRow.start}px)`,
                }}
              >
                <ItemRow
                  item={item}
                  index={itemIndex}
                  selected={selectedIndex === itemIndex}
                  onClick={() => select(itemIndex)}
                />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
