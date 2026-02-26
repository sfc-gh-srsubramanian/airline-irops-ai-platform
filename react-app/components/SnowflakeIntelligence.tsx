"use client";

import { useRef, useEffect } from "react";
import { MessageSquare, Send, Database, Table, BarChart3, Trash2 } from "lucide-react";
import { useChatStore, type StreamingPhase, type TableData } from "../stores/chatStore";
import StreamingPhaseIndicator from "./StreamingPhaseIndicator";
import SmartChart from "./SmartChart";

const SUGGESTED_QUESTIONS = [
  "How many flights are currently delayed?",
  "What is the on-time performance by hub?",
  "Show me the top 10 airports by delay count",
  "Which crew members are available for reassignment?",
  "What is the average delay time today?",
  "How many passengers are affected by cancellations?",
];

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 17) return "Good afternoon";
  return "Good evening";
}

function shouldShowChart(content: string): boolean {
  if (!content) return false;
  const keywords = ['chart', 'graph', 'visualization', 'visualize', 'plot', 
    'bar chart', 'line chart', 'pie chart', 'trend', 'comparison', 'breakdown'];
  return keywords.some(k => content.toLowerCase().includes(k));
}

export default function SnowflakeIntelligence() {
  const { messages, threadId, addMessage, updateLastMessage, clearMessages, setThreadId } = useChatStore();
  const inputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function submitQuestion(question: string) {
    if (!question.trim()) return;

    addMessage({ role: 'user', content: question });
    addMessage({ role: 'assistant', content: '', status: 'streaming', phase: 'thinking' });

    try {
      const response = await fetch('/api/agent/stream', {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json', 
          'Accept': 'text/event-stream' 
        },
        body: JSON.stringify({ query: question, thread_id: threadId })
      });

      if (!response.ok) {
        const errorData = await response.json();
        updateLastMessage({ 
          content: `Error: ${errorData.error || 'Failed to get response'}`, 
          status: 'error', 
          phase: null 
        });
        return;
      }

      const reader = response.body?.getReader();
      if (!reader) {
        updateLastMessage({ content: 'No response stream', status: 'error', phase: null });
        return;
      }

      const decoder = new TextDecoder();
      let buffer = '';
      let currentContent = '';
      let currentThinking = '';
      let currentSql = '';
      let currentTable: TableData | undefined;
      let currentPhase: StreamingPhase = 'thinking';
      let currentEvent = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.startsWith('event: ')) {
            currentEvent = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            try {
              const data = JSON.parse(line.substring(6));

              switch (currentEvent) {
                case 'response.thinking.delta':
                  currentPhase = 'thinking';
                  currentThinking += data.delta?.text || data.text || '';
                  updateLastMessage({ thinking: currentThinking, phase: currentPhase });
                  break;

                case 'response.tool_calls.delta':
                case 'response.tool_start':
                  currentPhase = 'tool_calling';
                  updateLastMessage({ phase: currentPhase });
                  break;

                case 'response.tool_result':
                  currentPhase = 'tool_calling';
                  if (data.content) {
                    for (const item of data.content) {
                      if (item.type === 'json' && item.json) {
                        if (item.json.sql) {
                          currentSql = item.json.sql;
                        }
                        if (item.json.result_set) {
                          const rs = item.json.result_set;
                          currentTable = {
                            columns: rs.columns || Object.keys(rs.data?.[0] || {}),
                            rows: rs.data?.map((row: Record<string, unknown>) => 
                              (rs.columns || Object.keys(row)).map((col: string) => row[col])
                            ) || []
                          };
                        }
                      }
                    }
                  }
                  updateLastMessage({ sql: currentSql, table: currentTable, phase: currentPhase });
                  break;

                case 'response.text.delta':
                  currentPhase = 'responding';
                  currentContent += data.delta?.text || data.text || '';
                  updateLastMessage({ content: currentContent, phase: currentPhase });
                  break;

                case 'metadata':
                  if (data.thread_id && !threadId) {
                    setThreadId(data.thread_id);
                  }
                  break;

                case 'response':
                case 'response.done':
                  updateLastMessage({ status: 'complete', phase: null });
                  break;
              }
            } catch {
            }
          }
        }
      }

      updateLastMessage({ status: 'complete', phase: null });
    } catch (error) {
      updateLastMessage({ 
        content: `Error: ${(error as Error).message}`, 
        status: 'error', 
        phase: null 
      });
    }
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const value = inputRef.current?.value || '';
    if (inputRef.current) inputRef.current.value = '';
    submitQuestion(value);
  }

  function renderTable(table: TableData) {
    if (!table.rows.length) return null;
    
    return (
      <div className="overflow-x-auto">
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="bg-slate-100">
              {table.columns.map((col) => (
                <th key={col} className="px-3 py-2 text-left font-medium text-slate-700 border-b text-xs">
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {table.rows.slice(0, 10).map((row, idx) => (
              <tr key={idx} className="hover:bg-slate-50">
                {row.map((val, colIdx) => (
                  <td key={colIdx} className="px-3 py-2 border-b border-slate-100 text-xs">
                    {String(val ?? "")}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        {table.rows.length > 10 && (
          <p className="text-xs text-slate-500 mt-2">Showing 10 of {table.rows.length} rows</p>
        )}
      </div>
    );
  }

  const showWelcome = messages.length === 0;
  const isStreaming = messages.some(m => m.status === 'streaming');

  return (
    <div className="flex flex-col h-[calc(100vh-120px)]">
      {showWelcome ? (
        <div className="flex-1 flex flex-col items-center justify-center px-4">
          <div className="max-w-2xl w-full text-center mb-8">
            <h1 className="text-4xl font-light text-slate-800 mb-2">
              {getGreeting()}, Ops Team
            </h1>
            <h2 className="text-3xl font-light text-transparent bg-clip-text bg-gradient-to-r from-cyan-500 to-blue-500">
              What insights can I help with?
            </h2>
          </div>

          <form onSubmit={handleSubmit} className="max-w-2xl w-full">
            <div className="bg-white rounded-2xl shadow-lg border border-slate-200 p-4">
              <div className="flex items-center gap-3">
                <input
                  ref={inputRef}
                  type="text"
                  placeholder="Ask about IROPS data..."
                  className="flex-1 text-lg outline-none text-slate-700 placeholder-slate-400"
                />
                <button
                  type="submit"
                  className="p-2 rounded-full bg-gradient-to-r from-cyan-500 to-blue-500 text-white hover:opacity-90 transition"
                >
                  <Send className="h-5 w-5" />
                </button>
              </div>
            </div>
          </form>

          <div className="mt-6 space-y-3 max-w-2xl w-full">
            {SUGGESTED_QUESTIONS.map((question, idx) => (
              <button
                key={idx}
                onClick={() => submitQuestion(question)}
                className="w-full text-left px-4 py-3 rounded-lg hover:bg-white hover:shadow-sm border border-transparent hover:border-slate-200 transition flex items-center gap-3 group"
              >
                <MessageSquare className="h-4 w-4 text-slate-400 group-hover:text-cyan-500" />
                <span className="text-slate-700">{question}</span>
              </button>
            ))}
          </div>
        </div>
      ) : (
        <>
          <div className="flex items-center justify-between px-4 py-2 border-b bg-slate-50">
            <span className="text-sm text-slate-500">
              {threadId ? `Thread: ${threadId.slice(0, 8)}...` : 'New Conversation'}
            </span>
            <button
              onClick={clearMessages}
              className="text-slate-400 hover:text-red-500 transition p-1"
              title="Clear conversation"
            >
              <Trash2 className="h-4 w-4" />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto px-4 py-6">
            <div className="max-w-5xl mx-auto space-y-6">
              {messages.map((message) => (
                <div
                  key={message.id}
                  className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}
                >
                  <div
                    className={`max-w-full w-full rounded-2xl px-4 py-3 ${
                      message.role === "user"
                        ? "bg-gradient-to-r from-cyan-500 to-blue-500 text-white max-w-[80%]"
                        : "bg-white border border-slate-200 shadow-sm"
                    }`}
                  >
                    {message.role === 'assistant' && message.status === 'streaming' && message.phase ? (
                      <StreamingPhaseIndicator phase={message.phase} thinking={message.thinking} />
                    ) : null}

                    {message.content && (
                      <p className={`whitespace-pre-wrap ${message.role === "user" ? "text-white" : "text-slate-700"}`}>
                        {message.content}
                      </p>
                    )}

                    {message.sql && message.status === 'complete' && (
                      <details className="mt-3">
                        <summary className="text-xs text-cyan-600 hover:text-cyan-700 cursor-pointer flex items-center gap-1">
                          <Database className="h-3 w-3" />
                          View SQL Query
                        </summary>
                        <pre className="mt-2 p-3 bg-slate-900 text-green-400 rounded-lg text-xs overflow-x-auto">
                          {message.sql}
                        </pre>
                      </details>
                    )}

                    {message.table && message.status === 'complete' && (
                      <div className="mt-3 p-3 bg-slate-50 rounded-lg">
                        <div className="flex items-center gap-2 text-sm text-slate-600 mb-2">
                          {shouldShowChart(message.content) ? (
                            <>
                              <BarChart3 className="h-4 w-4" />
                              <span>Visualization</span>
                            </>
                          ) : (
                            <>
                              <Table className="h-4 w-4" />
                              <span>Query Results</span>
                            </>
                          )}
                        </div>
                        {shouldShowChart(message.content) ? (
                          <SmartChart table={message.table} />
                        ) : (
                          renderTable(message.table)
                        )}
                      </div>
                    )}
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
          </div>

          <div className="border-t bg-white px-4 py-4">
            <form onSubmit={handleSubmit} className="max-w-5xl mx-auto">
              <div className="bg-slate-50 rounded-2xl border border-slate-200 p-3">
                <div className="flex items-center gap-3">
                  <input
                    ref={inputRef}
                    type="text"
                    placeholder="Ask a follow-up question..."
                    className="flex-1 bg-transparent outline-none text-slate-700 placeholder-slate-400"
                    disabled={isStreaming}
                  />
                  <button
                    type="submit"
                    disabled={isStreaming}
                    className="p-2 rounded-full bg-gradient-to-r from-cyan-500 to-blue-500 text-white disabled:opacity-50 hover:opacity-90 transition"
                  >
                    <Send className="h-5 w-5" />
                  </button>
                </div>
              </div>
            </form>
          </div>
        </>
      )}
    </div>
  );
}
