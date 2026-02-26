"use client";

import { Sparkles, Database, MessageSquare, Cpu } from 'lucide-react'
import type { StreamingPhase } from '../stores/chatStore'

const phaseConfig = {
  thinking: { 
    icon: Sparkles, 
    label: 'Thinking', 
    color: 'text-purple-400', 
    bg: 'bg-purple-500/10', 
    border: 'border-purple-500/30' 
  },
  planning: { 
    icon: Cpu, 
    label: 'Planning', 
    color: 'text-blue-400', 
    bg: 'bg-blue-500/10', 
    border: 'border-blue-500/30' 
  },
  tool_calling: { 
    icon: Database, 
    label: 'Running Query', 
    color: 'text-amber-400', 
    bg: 'bg-amber-500/10', 
    border: 'border-amber-500/30' 
  },
  responding: { 
    icon: MessageSquare, 
    label: 'Responding', 
    color: 'text-emerald-400', 
    bg: 'bg-emerald-500/10', 
    border: 'border-emerald-500/30' 
  }
}

interface Props {
  phase: StreamingPhase
  thinking?: string
}

export default function StreamingPhaseIndicator({ phase, thinking }: Props) {
  if (!phase) return null
  const { icon: Icon, label, color, bg, border } = phaseConfig[phase]
  
  return (
    <div className={`rounded-lg border ${border} ${bg} overflow-hidden transition-all duration-500`}>
      <div className="flex items-center gap-3 px-4 py-3">
        <div className="relative">
          <div className={`absolute inset-0 ${color.replace('text-', 'bg-')} rounded-full opacity-20 animate-ping`} />
          <Icon size={18} className={`${color} relative z-10`} />
        </div>
        <span className={`text-sm font-medium ${color}`}>{label}</span>
        <div className="flex gap-1.5 ml-auto">
          {[0, 150, 300].map(delay => (
            <span 
              key={delay} 
              className={`w-2 h-2 ${color.replace('text-', 'bg-')} rounded-full animate-bounce`} 
              style={{ animationDelay: `${delay}ms`, animationDuration: '600ms' }} 
            />
          ))}
        </div>
      </div>
      {phase === 'thinking' && thinking && (
        <div className="px-4 pb-3 pt-0">
          <div className="text-xs text-slate-400 max-h-32 overflow-y-auto font-mono whitespace-pre-wrap">
            {thinking.split('\n').slice(-8).join('\n')}
            <span className="inline-block w-2 h-4 bg-slate-400 animate-pulse ml-0.5" />
          </div>
        </div>
      )}
    </div>
  )
}
