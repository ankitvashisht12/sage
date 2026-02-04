"use client";

import { useState } from "react";
import { useReviewStore } from "@/stores/reviewStore";
import UploadModal from "./UploadModal";

export default function Toolbar() {
  const items = useReviewStore((s) => s.items);
  const [showUpload, setShowUpload] = useState(false);

  const total = items.length;
  const accepted = items.filter((i) => i.accepted === true).length;
  const rejected = items.filter((i) => i.accepted === false).length;
  const reviewed = accepted + rejected;

  return (
    <>
      <div
        className="flex items-center justify-between px-4 py-2 border-b"
        style={{ background: "var(--bg-secondary)", borderColor: "var(--border)" }}
      >
        <div className="flex items-center gap-4">
          <span className="text-sm font-medium" style={{ color: "var(--text-primary)" }}>
            Sage Review Tool
          </span>
          <div className="flex items-center gap-3 text-xs" style={{ color: "var(--text-secondary)" }}>
            <span>
              {reviewed}/{total} reviewed
            </span>
            <span style={{ color: "var(--accent-green)" }}>{accepted} accepted</span>
            <span style={{ color: "var(--accent-red)" }}>{rejected} rejected</span>
          </div>
          {total > 0 && (
            <div className="w-32 h-1.5 rounded-full overflow-hidden" style={{ background: "var(--bg-tertiary)" }}>
              <div
                className="h-full rounded-full transition-all"
                style={{
                  width: `${(reviewed / total) * 100}%`,
                  background: "var(--accent-blue)",
                }}
              />
            </div>
          )}
        </div>

        <button
          onClick={() => setShowUpload(true)}
          disabled={accepted === 0}
          className="px-3 py-1.5 text-xs font-medium rounded transition-colors disabled:opacity-40"
          style={{
            background: "var(--accent-blue-bg)",
            color: "var(--accent-blue)",
            border: "1px solid var(--accent-blue)",
          }}
        >
          Upload to LangSmith ({accepted})
        </button>
      </div>

      {showUpload && <UploadModal onClose={() => setShowUpload(false)} />}
    </>
  );
}
