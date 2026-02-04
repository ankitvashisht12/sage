"use client";

import { useCallback, useRef, useState } from "react";

interface Props {
  left: React.ReactNode;
  center: React.ReactNode;
  right: React.ReactNode;
}

export default function ResizablePanels({ left, center, right }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [leftWidth, setLeftWidth] = useState(280);
  const [rightWidth, setRightWidth] = useState<number | null>(null);
  const draggingRef = useRef<"left" | "right" | null>(null);

  const onMouseDown = useCallback((handle: "left" | "right") => {
    draggingRef.current = handle;

    const onMouseMove = (e: MouseEvent) => {
      if (!containerRef.current || !draggingRef.current) return;
      const rect = containerRef.current.getBoundingClientRect();

      if (draggingRef.current === "left") {
        const newLeft = Math.max(200, Math.min(500, e.clientX - rect.left));
        setLeftWidth(newLeft);
      } else {
        const newRight = Math.max(250, Math.min(rect.width * 0.6, rect.right - e.clientX));
        setRightWidth(newRight);
      }
    };

    const onMouseUp = () => {
      draggingRef.current = null;
      document.removeEventListener("mousemove", onMouseMove);
      document.removeEventListener("mouseup", onMouseUp);
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };

    document.addEventListener("mousemove", onMouseMove);
    document.addEventListener("mouseup", onMouseUp);
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }, []);

  return (
    <div ref={containerRef} className="flex h-full overflow-hidden">
      <div style={{ width: leftWidth, minWidth: 200 }} className="flex-shrink-0 overflow-hidden">
        {left}
      </div>
      <div
        className="resize-handle"
        onMouseDown={() => onMouseDown("left")}
      />
      <div className="flex-1 min-w-[200px] overflow-hidden">
        {center}
      </div>
      <div
        className="resize-handle"
        onMouseDown={() => onMouseDown("right")}
      />
      <div
        style={{ width: rightWidth ?? "50%" }}
        className="flex-shrink-0 overflow-hidden"
      >
        {right}
      </div>
    </div>
  );
}
