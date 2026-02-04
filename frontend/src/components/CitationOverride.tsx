"use client";

import { useEffect, useRef } from "react";

interface Props {
  rect: DOMRect;
  onUse: () => void;
  onDismiss: () => void;
}

export default function CitationOverride({ rect, onUse, onDismiss }: Props) {
  const ref = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        onDismiss();
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [onDismiss]);

  return (
    <button
      ref={ref}
      onClick={onUse}
      className="fixed z-50 flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium shadow-lg transition-colors"
      style={{
        top: rect.top - 36,
        left: rect.left + rect.width / 2 - 80,
        background: "var(--accent-blue)",
        color: "#fff",
      }}
    >
      Use as citation
    </button>
  );
}
