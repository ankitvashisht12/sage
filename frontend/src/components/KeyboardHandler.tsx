"use client";

import { useEffect } from "react";
import { useReviewStore } from "@/stores/reviewStore";

export default function KeyboardHandler() {
  const selectNext = useReviewStore((s) => s.selectNext);
  const selectPrev = useReviewStore((s) => s.selectPrev);
  const selectedIndex = useReviewStore((s) => s.selectedIndex);
  const updateItem = useReviewStore((s) => s.updateItem);
  const selectNextPending = useReviewStore((s) => s.selectNextPending);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      const isInput = target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable;

      // Escape always works
      if (e.key === "Escape") {
        (document.activeElement as HTMLElement)?.blur();
        return;
      }

      // Don't handle shortcuts when typing in inputs
      if (isInput) return;

      switch (e.key) {
        case "j":
        case "ArrowDown":
          e.preventDefault();
          selectNext();
          break;
        case "k":
        case "ArrowUp":
          e.preventDefault();
          selectPrev();
          break;
        case "a":
          if (selectedIndex >= 0) {
            e.preventDefault();
            updateItem(selectedIndex, { accepted: true }).then(selectNextPending);
          }
          break;
        case "r":
          if (selectedIndex >= 0) {
            e.preventDefault();
            updateItem(selectedIndex, { accepted: false }).then(selectNextPending);
          }
          break;
        case "n":
          e.preventDefault();
          document.getElementById("reviewer-notes")?.focus();
          break;
        case "/":
          e.preventDefault();
          document.getElementById("sidebar-search")?.focus();
          break;
      }
    };

    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [selectNext, selectPrev, selectedIndex, updateItem, selectNextPending]);

  return null;
}
