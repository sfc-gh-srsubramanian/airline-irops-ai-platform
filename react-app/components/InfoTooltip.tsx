"use client";

import { Info } from "lucide-react";
import { useState } from "react";

interface InfoTooltipProps {
  text: string;
  className?: string;
}

export default function InfoTooltip({ text, className = "" }: InfoTooltipProps) {
  const [visible, setVisible] = useState(false);

  return (
    <div className={`relative inline-flex ${className}`}>
      <button
        onMouseEnter={() => setVisible(true)}
        onMouseLeave={() => setVisible(false)}
        onClick={() => setVisible(!visible)}
        className="text-slate-400 hover:text-slate-600 transition p-0.5 rounded-full hover:bg-slate-100"
        aria-label="Help"
      >
        <Info className="h-4 w-4" />
      </button>
      {visible && (
        <div className="absolute z-50 left-6 top-0 w-64 p-2 bg-slate-800 text-white text-xs rounded-lg shadow-lg">
          <div className="absolute -left-1 top-2 w-2 h-2 bg-slate-800 transform rotate-45" />
          {text}
        </div>
      )}
    </div>
  );
}
