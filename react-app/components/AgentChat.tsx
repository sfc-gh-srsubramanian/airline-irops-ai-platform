"use client";

import { useState, useRef, useEffect } from "react";
import { Send, Loader2, Bot, User, Zap, Database, ChevronDown, ChevronRight, Lightbulb } from "lucide-react";
import InfoTooltip from "./InfoTooltip";
import { PAGE_HELP } from "@/lib/pageHelp";

interface Message {
  role: "user" | "assistant";
  content: string;
  timestamp: Date;
  sql?: string;
  results?: Record<string, unknown>[];
  suggestions?: string[];
}

const sampleQuestions = [
  "How many flights are delayed today?",
  "What is the on-time performance by hub?",
  "Show me diamond tier passengers affected by delays",
  "Which flights have the longest delays?",
  "How many crew members are available?",
];

export default function AgentChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [expandedSql, setExpandedSql] = useState<number | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function sendMessage(text: string) {
    if (!text.trim()) return;

    const userMessage: Message = {
      role: "user",
      content: text,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput("");
    setLoading(true);

    try {
      const res = await fetch("/api/agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: text }),
      });
      const json = await res.json();

      const assistantMessage: Message = {
        role: "assistant",
        content: json.response || "I processed your request.",
        timestamp: new Date(),
        sql: json.sql,
        results: json.results,
        suggestions: json.suggestions,
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (err) {
      const errorMessage: Message = {
        role: "assistant",
        content: "I encountered an error processing your request. Please try again.",
        timestamp: new Date(),
      };
      setMessages((prev) => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  }

  function formatValue(value: unknown): string {
    if (value === null || value === undefined) return "-";
    if (typeof value === "number") {
      if (Number.isInteger(value)) return value.toLocaleString();
      return value.toFixed(2);
    }
    return String(value);
  }

  return (
    <div className="flex flex-col h-[calc(100vh-200px)] bg-white rounded-xl shadow-sm border">
      <div className="px-5 py-4 border-b bg-gradient-to-r from-purple-50 to-indigo-50">
        <div className="flex items-center gap-2">
          <Zap className="h-5 w-5 text-purple-600" />
          <h2 className="text-lg font-semibold text-phantom-dark">IROPS AI Assistant</h2>
          <InfoTooltip text={PAGE_HELP.assistant} />
        </div>
        <p className="text-sm text-slate-500">Powered by Snowflake Cortex Analyst</p>
      </div>

      <div className="flex-1 overflow-y-auto p-5 space-y-4">
        {messages.length === 0 && (
          <div className="text-center py-8">
            <Bot className="h-12 w-12 mx-auto mb-4 text-slate-300" />
            <p className="text-slate-500 mb-6">Ask me anything about IROPS operations - I can query your live data!</p>
            <div className="flex flex-wrap justify-center gap-2">
              {sampleQuestions.map((q, idx) => (
                <button
                  key={idx}
                  onClick={() => sendMessage(q)}
                  className="px-3 py-2 bg-slate-100 hover:bg-slate-200 rounded-lg text-sm text-slate-700 transition"
                >
                  {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg, idx) => (
          <div key={idx} className={`flex gap-3 ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
            {msg.role === "assistant" && (
              <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center flex-shrink-0">
                <Bot className="h-4 w-4 text-purple-600" />
              </div>
            )}
            <div className={`max-w-[80%] ${msg.role === "user" ? "" : ""}`}>
              <div
                className={`px-4 py-3 rounded-2xl ${
                  msg.role === "user"
                    ? "bg-phantom-primary text-white rounded-br-md"
                    : "bg-slate-100 text-slate-800 rounded-bl-md"
                }`}
              >
                <p className="whitespace-pre-wrap">{msg.content}</p>
                <p className={`text-xs mt-1 ${msg.role === "user" ? "text-white/70" : "text-slate-400"}`}>
                  {msg.timestamp.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                </p>
              </div>

              {msg.sql && (
                <div className="mt-2">
                  <button
                    onClick={() => setExpandedSql(expandedSql === idx ? null : idx)}
                    className="flex items-center gap-1 text-xs text-slate-500 hover:text-slate-700"
                  >
                    {expandedSql === idx ? <ChevronDown className="h-3 w-3" /> : <ChevronRight className="h-3 w-3" />}
                    <Database className="h-3 w-3" />
                    View SQL Query
                  </button>
                  {expandedSql === idx && (
                    <pre className="mt-2 p-3 bg-slate-900 text-green-400 rounded-lg text-xs overflow-x-auto">
                      {msg.sql}
                    </pre>
                  )}
                </div>
              )}

              {msg.results && msg.results.length > 0 && (
                <div className="mt-3 overflow-x-auto">
                  <table className="min-w-full text-sm border rounded-lg overflow-hidden">
                    <thead className="bg-slate-100">
                      <tr>
                        {Object.keys(msg.results[0]).map((col) => (
                          <th key={col} className="px-3 py-2 text-left text-xs font-medium text-slate-600 uppercase">
                            {col.replace(/_/g, " ")}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-slate-100">
                      {msg.results.slice(0, 10).map((row, rowIdx) => (
                        <tr key={rowIdx} className="hover:bg-slate-50">
                          {Object.values(row).map((val, colIdx) => (
                            <td key={colIdx} className="px-3 py-2 text-slate-700 whitespace-nowrap">
                              {formatValue(val)}
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {msg.results.length > 10 && (
                    <p className="text-xs text-slate-400 mt-1">Showing 10 of {msg.results.length} rows</p>
                  )}
                </div>
              )}

              {msg.suggestions && msg.suggestions.length > 0 && (
                <div className="mt-3">
                  <div className="flex items-center gap-1 text-xs text-slate-500 mb-2">
                    <Lightbulb className="h-3 w-3" />
                    Follow-up questions:
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {msg.suggestions.map((s, sIdx) => (
                      <button
                        key={sIdx}
                        onClick={() => sendMessage(s)}
                        className="px-2 py-1 bg-purple-50 hover:bg-purple-100 text-purple-700 rounded text-xs transition"
                      >
                        {s}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
            {msg.role === "user" && (
              <div className="w-8 h-8 rounded-full bg-phantom-primary flex items-center justify-center flex-shrink-0">
                <User className="h-4 w-4 text-white" />
              </div>
            )}
          </div>
        ))}

        {loading && (
          <div className="flex gap-3">
            <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center">
              <Bot className="h-4 w-4 text-purple-600" />
            </div>
            <div className="bg-slate-100 px-4 py-3 rounded-2xl rounded-bl-md">
              <div className="flex items-center gap-2">
                <Loader2 className="h-5 w-5 animate-spin text-purple-500" />
                <span className="text-sm text-slate-500">Analyzing your data...</span>
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      <div className="px-5 py-4 border-t">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            sendMessage(input);
          }}
          className="flex gap-3"
        >
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Ask about flights, crew, disruptions..."
            className="flex-1 px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-phantom-primary focus:border-transparent"
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading || !input.trim()}
            className="px-4 py-3 bg-phantom-primary text-white rounded-xl hover:bg-phantom-dark transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Send className="h-5 w-5" />
          </button>
        </form>
      </div>
    </div>
  );
}
