"use client";

import { useState, useRef, useEffect } from "react";
import { MessageSquare, Send, Loader2, Database, Table, BarChart3 } from "lucide-react";

interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  sql?: string;
  results?: Record<string, unknown>[];
  timestamp: Date;
  thinking?: boolean;
}

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

export default function SnowflakeIntelligence() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [showSql, setShowSql] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function sendMessage(text: string) {
    if (!text.trim() || loading) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      role: "user",
      content: text,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput("");
    setLoading(true);

    const thinkingMessage: Message = {
      id: (Date.now() + 1).toString(),
      role: "assistant",
      content: "",
      timestamp: new Date(),
      thinking: true,
    };
    setMessages((prev) => [...prev, thinkingMessage]);

    try {
      const res = await fetch("/api/intelligence", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: text }),
      });
      const json = await res.json();

      setMessages((prev) => {
        const filtered = prev.filter((m) => !m.thinking);
        return [
          ...filtered,
          {
            id: (Date.now() + 2).toString(),
            role: "assistant",
            content: json.response || "I couldn't generate a response.",
            sql: json.sql,
            results: json.data || json.results,
            timestamp: new Date(),
          },
        ];
      });
    } catch (error) {
      setMessages((prev) => {
        const filtered = prev.filter((m) => !m.thinking);
        return [
          ...filtered,
          {
            id: (Date.now() + 2).toString(),
            role: "assistant",
            content: "Sorry, I encountered an error. Please try again.",
            timestamp: new Date(),
          },
        ];
      });
    } finally {
      setLoading(false);
    }
  }

  function handleSuggestionClick(question: string) {
    sendMessage(question);
  }

  function renderResults(results: Record<string, unknown>[]) {
    if (!results || results.length === 0) return null;
    const columns = Object.keys(results[0]);
    
    return (
      <div className="mt-4">
        <table className="w-full text-sm border-collapse min-w-0">
          <thead>
            <tr className="bg-slate-100">
              {columns.map((col) => (
                <th key={col} className="px-2 py-2 text-left font-medium text-slate-700 border-b text-xs whitespace-nowrap">
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {results.slice(0, 10).map((row, idx) => (
              <tr key={idx} className="hover:bg-slate-50">
                {columns.map((col) => (
                  <td key={col} className="px-2 py-2 border-b border-slate-100 text-xs">
                    {String(row[col] ?? "")}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        {results.length > 10 && (
          <p className="text-xs text-slate-500 mt-2">Showing 10 of {results.length} rows</p>
        )}
      </div>
    );
  }

  const showWelcome = messages.length === 0;

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

          <div className="max-w-2xl w-full">
            <div className="bg-white rounded-2xl shadow-lg border border-slate-200 p-4">
              <div className="flex items-center gap-3">
                <input
                  ref={inputRef}
                  type="text"
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && sendMessage(input)}
                  placeholder="Ask about IROPS data..."
                  className="flex-1 text-lg outline-none text-slate-700 placeholder-slate-400"
                />
                <button
                  onClick={() => sendMessage(input)}
                  disabled={!input.trim() || loading}
                  className="p-2 rounded-full bg-gradient-to-r from-cyan-500 to-blue-500 text-white disabled:opacity-50"
                >
                  <Send className="h-5 w-5" />
                </button>
              </div>
            </div>

            <div className="mt-6 space-y-3">
              {SUGGESTED_QUESTIONS.map((question, idx) => (
                <button
                  key={idx}
                  onClick={() => handleSuggestionClick(question)}
                  className="w-full text-left px-4 py-3 rounded-lg hover:bg-white hover:shadow-sm border border-transparent hover:border-slate-200 transition flex items-center gap-3 group"
                >
                  <MessageSquare className="h-4 w-4 text-slate-400 group-hover:text-cyan-500" />
                  <span className="text-slate-700">{question}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : (
        <>
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
                        ? "bg-gradient-to-r from-cyan-500 to-blue-500 text-white"
                        : "bg-white border border-slate-200 shadow-sm"
                    }`}
                  >
                    {message.thinking ? (
                      <div className="flex items-center gap-2 text-slate-500">
                        <Loader2 className="h-4 w-4 animate-spin" />
                        <span>Analyzing your question...</span>
                      </div>
                    ) : (
                      <>
                        <p className={`whitespace-pre-wrap ${message.role === "user" ? "text-white" : "text-slate-700"}`}>
                          {message.content}
                        </p>
                        
                        {message.sql && (
                          <div className="mt-3">
                            <button
                              onClick={() => setShowSql(showSql === message.id ? null : message.id)}
                              className="text-xs text-cyan-600 hover:text-cyan-700 flex items-center gap-1"
                            >
                              <Database className="h-3 w-3" />
                              {showSql === message.id ? "Hide SQL" : "Show SQL"}
                            </button>
                            {showSql === message.id && (
                              <pre className="mt-2 p-3 bg-slate-900 text-green-400 rounded-lg text-xs overflow-x-auto">
                                {message.sql}
                              </pre>
                            )}
                          </div>
                        )}
                        
                        {message.results && message.results.length > 0 && (
                          <div className="mt-3 p-3 bg-slate-50 rounded-lg overflow-x-auto">
                            <div className="flex items-center gap-2 text-sm text-slate-600 mb-2">
                              <Table className="h-4 w-4" />
                              <span>Query Results</span>
                              <BarChart3 className="h-4 w-4 ml-2" />
                            </div>
                            {renderResults(message.results)}
                          </div>
                        )}
                      </>
                    )}
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
          </div>

          <div className="border-t bg-white px-4 py-4">
            <div className="max-w-5xl mx-auto">
              <div className="bg-slate-50 rounded-2xl border border-slate-200 p-3">
                <div className="flex items-center gap-3">
                  <input
                    ref={inputRef}
                    type="text"
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && sendMessage(input)}
                    placeholder="Ask a follow-up question..."
                    className="flex-1 bg-transparent outline-none text-slate-700 placeholder-slate-400"
                    disabled={loading}
                  />
                  <button
                    onClick={() => sendMessage(input)}
                    disabled={!input.trim() || loading}
                    className="p-2 rounded-full bg-gradient-to-r from-cyan-500 to-blue-500 text-white disabled:opacity-50"
                  >
                    {loading ? <Loader2 className="h-5 w-5 animate-spin" /> : <Send className="h-5 w-5" />}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
