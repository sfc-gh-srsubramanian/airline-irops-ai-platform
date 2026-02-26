import { create } from 'zustand'

export type StreamingPhase = 'thinking' | 'planning' | 'tool_calling' | 'responding' | null

export interface TableData {
  columns: string[]
  rows: (string | number | null)[][]
}

export interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  thinking?: string
  sql?: string
  table?: TableData
  requestId?: string
  status?: 'streaming' | 'complete' | 'error'
  phase?: StreamingPhase
  timestamp: number
}

interface ChatState {
  messages: Message[]
  threadId: string | null
  setThreadId: (id: string | null) => void
  addMessage: (message: Omit<Message, 'id' | 'timestamp'>) => void
  updateLastMessage: (updates: Partial<Message>) => void
  clearMessages: () => void
}

export const useChatStore = create<ChatState>((set) => ({
  messages: [],
  threadId: null,
  setThreadId: (id) => set({ threadId: id }),
  addMessage: (message) => set((state) => ({ 
    messages: [...state.messages, { 
      ...message, 
      id: Math.random().toString(36).substr(2, 9),
      timestamp: Date.now() 
    }] 
  })),
  updateLastMessage: (updates) => set((state) => {
    const newMessages = [...state.messages]
    if (newMessages.length > 0 && newMessages[newMessages.length - 1].role === 'assistant') {
      newMessages[newMessages.length - 1] = {
        ...newMessages[newMessages.length - 1],
        ...updates
      }
    }
    return { messages: newMessages }
  }),
  clearMessages: () => set({ messages: [], threadId: null })
}))
