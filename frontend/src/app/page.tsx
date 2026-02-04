"use client";

import { useEffect } from "react";
import { useReviewStore } from "@/stores/reviewStore";
import Toolbar from "@/components/Toolbar";
import Sidebar from "@/components/Sidebar";
import DetailPanel from "@/components/DetailPanel";
import SourceViewer from "@/components/SourceViewer";
import ResizablePanels from "@/components/ResizablePanels";
import KeyboardHandler from "@/components/KeyboardHandler";

export default function Home() {
  const load = useReviewStore((s) => s.load);
  const loading = useReviewStore((s) => s.loading);
  const error = useReviewStore((s) => s.error);

  useEffect(() => {
    load();
  }, [load]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen" style={{ color: "var(--text-muted)" }}>
        Loading items...
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center h-screen gap-2">
        <div style={{ color: "var(--accent-red)" }}>Failed to load items</div>
        <div className="text-xs" style={{ color: "var(--text-muted)" }}>{error}</div>
        <button
          onClick={load}
          className="mt-2 px-4 py-2 text-xs rounded"
          style={{ background: "var(--bg-tertiary)", color: "var(--text-primary)" }}
        >
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-screen">
      <Toolbar />
      <div className="flex-1 overflow-hidden">
        <ResizablePanels
          left={<Sidebar />}
          center={<DetailPanel />}
          right={<SourceViewer />}
        />
      </div>
      <KeyboardHandler />
    </div>
  );
}
