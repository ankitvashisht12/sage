"use client";

import { useState } from "react";

interface Props {
  label: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}

export default function MetadataSection({ label, children, defaultOpen = false }: Props) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className="border-b" style={{ borderColor: "var(--border)" }}>
      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center justify-between px-4 py-2 text-xs hover:bg-[var(--bg-hover)] transition-colors"
        style={{ color: "var(--text-secondary)" }}
      >
        <span>{label}</span>
        <span className="text-[10px]">{open ? "▾" : "▸"}</span>
      </button>
      {open && (
        <div className="px-4 pb-3 text-xs" style={{ color: "var(--text-primary)" }}>
          {children}
        </div>
      )}
    </div>
  );
}
