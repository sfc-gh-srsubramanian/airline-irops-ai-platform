"use client";

import { useState, useRef, useEffect } from "react";
import { CheckCircle, XCircle, AlertTriangle, MessageSquare, Book, Send, Loader2, Bot, User, Shield, DollarSign, Clock, Ban } from "lucide-react";
import InfoTooltip from "./InfoTooltip";
import { PAGE_HELP } from "@/lib/pageHelp";

interface ViolationSave {
  id: string;
  crewId: string;
  crewName: string;
  flightId: string;
  violation: string;
  rule: string;
  fineSaved: number;
  timestamp: Date;
}

const DEMO_SAVES: ViolationSave[] = [
  { id: "1", crewId: "CR004567", crewName: "Capt. Karen Wilson", flightId: "PH2847", violation: "Would exceed 9-hour FDP limit", rule: "FAA Part 117.13", fineSaved: 50000, timestamp: new Date(Date.now() - 1000 * 60 * 5) },
  { id: "2", crewId: "CR001234", crewName: "Capt. John Smith", flightId: "PH1923", violation: "Only 8.5 hrs rest (min 10 required)", rule: "FAA Part 117.25", fineSaved: 50000, timestamp: new Date(Date.now() - 1000 * 60 * 23) },
  { id: "3", crewId: "CR002345", crewName: "Capt. Mary Johnson", flightId: "PH3456", violation: "6 consecutive days exceeded", rule: "PWA Section 5.1", fineSaved: 5000, timestamp: new Date(Date.now() - 1000 * 60 * 47) },
  { id: "4", crewId: "CR003456", crewName: "FO Robert Davis", flightId: "PH4521", violation: "Monthly 100-hour limit exceeded", rule: "FAA Part 117.23", fineSaved: 50000, timestamp: new Date(Date.now() - 1000 * 60 * 82) },
  { id: "5", crewId: "CR005678", crewName: "Capt. Lisa Chen", flightId: "PH5678", violation: "Not type-qualified for A350", rule: "PWA Section 7.1", fineSaved: 25000, timestamp: new Date(Date.now() - 1000 * 60 * 95) },
];

interface ValidationResult {
  check: string;
  status: "pass" | "fail" | "warning";
  detail: string;
}

interface Message {
  role: "user" | "assistant";
  content: string;
  timestamp: Date;
}

const crewMembers = [
  { id: "CR001234", name: "Capt. John Smith", base: "ATL", monthlyHours: 78.5, remaining: 21.5, consecutiveDays: 4, lastRest: 12.3, types: ["B737-800", "B737-900", "A320-200"] },
  { id: "CR002345", name: "Capt. Mary Johnson", base: "DTW", monthlyHours: 82.1, remaining: 17.9, consecutiveDays: 5, lastRest: 10.5, types: ["A321-200", "A320-200"] },
  { id: "CR003456", name: "FO Robert Davis", base: "MSP", monthlyHours: 65.2, remaining: 34.8, consecutiveDays: 2, lastRest: 14.2, types: ["B737-800", "B737-900"] },
  { id: "CR004567", name: "Capt. Karen Wilson", base: "JFK", monthlyHours: 91.3, remaining: 8.7, consecutiveDays: 3, lastRest: 11.8, types: ["B757-200", "B767-300"] },
];

const flights = [
  { id: "PH1234", route: "ATL→JFK", aircraft: "B737-800", blockTime: 2.5, departure: "14:30 UTC", report: "13:30 UTC", release: "18:00 UTC" },
  { id: "PH2567", route: "DTW→LAX", aircraft: "A321-200", blockTime: 4.5, departure: "15:00 UTC", report: "14:00 UTC", release: "20:30 UTC" },
  { id: "PH3890", route: "MSP→SEA", aircraft: "B737-900", blockTime: 3.5, departure: "15:30 UTC", report: "14:30 UTC", release: "20:00 UTC" },
  { id: "PH4123", route: "JFK→MIA", aircraft: "B757-200", blockTime: 3.0, departure: "16:00 UTC", report: "15:00 UTC", release: "20:00 UTC" },
];

const contractRules = [
  { id: "FAA-117-1", category: "FAA", name: "Max Flight Duty Period", limit: "9-14 hours" },
  { id: "FAA-117-2", category: "FAA", name: "Minimum Rest", limit: "10 hours" },
  { id: "FAA-117-3", category: "FAA", name: "Monthly Limit", limit: "100 hours" },
  { id: "FAA-117-4", category: "FAA", name: "Annual Limit", limit: "1,000 hours" },
  { id: "PWA-5.1", category: "UNION", name: "Consecutive Days", limit: "6 days" },
  { id: "PWA-5.2", category: "UNION", name: "Reserve Notice", limit: "2 hours" },
  { id: "PWA-6.1", category: "UNION", name: "Deadhead Rules", limit: "14 hours total" },
  { id: "PWA-7.1", category: "UNION", name: "Type Qualification", limit: "Required" },
  { id: "PWA-8.1", category: "UNION", name: "Involuntary Extension", limit: "2 hours max" },
];

const sampleQuestions = [
  "What is the maximum flight duty period for a pilot starting at 6am?",
  "Can a pilot who flew 95 hours this month take a 6-hour trip?",
  "How many consecutive days can a pilot work before required rest?",
  "What are the minimum rest requirements between duty periods?",
];

export default function ContractBot() {
  const [activeTab, setActiveTab] = useState<"validate" | "chat" | "reference" | "saves">("validate");
  const [selectedCrew, setSelectedCrew] = useState(crewMembers[0]);
  const [selectedFlight, setSelectedFlight] = useState(flights[0]);
  const [validationResults, setValidationResults] = useState<ValidationResult[] | null>(null);
  const [validating, setValidating] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [showNewSave, setShowNewSave] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const validateAssignment = () => {
    setValidating(true);
    setValidationResults(null);

    setTimeout(() => {
      const isQualified = selectedCrew.types.includes(selectedFlight.aircraft);
      const hoursOk = selectedCrew.remaining >= selectedFlight.blockTime;
      const daysOk = selectedCrew.consecutiveDays < 6;
      const restOk = selectedCrew.lastRest >= 10;

      const results: ValidationResult[] = [
        { check: "Type Qualification", status: isQualified ? "pass" : "fail", detail: isQualified ? `Qualified for ${selectedFlight.aircraft}` : `Not qualified for ${selectedFlight.aircraft}` },
        { check: "Monthly Hours", status: hoursOk ? "pass" : (selectedCrew.remaining < selectedFlight.blockTime * 1.5 ? "warning" : "fail"), detail: `${selectedCrew.remaining} hrs remaining > ${selectedFlight.blockTime} hrs needed` },
        { check: "Annual Hours", status: "pass", detail: `${(1000 - selectedCrew.monthlyHours * 12).toFixed(0)} hrs < 1000 limit` },
        { check: "Consecutive Days", status: daysOk ? "pass" : "warning", detail: `${selectedCrew.consecutiveDays} days < 6 day limit` },
        { check: "Rest Period", status: restOk ? "pass" : "fail", detail: `${selectedCrew.lastRest} hrs ${restOk ? ">" : "<"} 10 hr minimum` },
        { check: "FDP Limit", status: "pass", detail: `Est. 4.5 hrs < 13 hr limit` },
      ];

      setValidationResults(results);
      setValidating(false);
    }, 1500);
  };

  const sendChatMessage = async (text: string) => {
    if (!text.trim()) return;

    const userMessage: Message = { role: "user", content: text, timestamp: new Date() };
    setMessages((prev) => [...prev, userMessage]);
    setChatInput("");
    setChatLoading(true);

    try {
      const res = await fetch("/api/agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          message: `You are a contract compliance expert for airlines. Answer this question about FAA Part 117 and PWA (Pilot Working Agreement) rules: ${text}`,
          context: "Contract Bot" 
        }),
      });
      const json = await res.json();
      
      setMessages((prev) => [...prev, { 
        role: "assistant", 
        content: json.response || "I couldn't process that question. Please try again.",
        timestamp: new Date() 
      }]);
    } catch {
      setMessages((prev) => [...prev, {
        role: "assistant",
        content: "I encountered an error. Please try again.",
        timestamp: new Date()
      }]);
    } finally {
      setChatLoading(false);
    }
  };

  const allPassed = validationResults?.every((r) => r.status === "pass");
  const hasWarnings = validationResults?.some((r) => r.status === "warning");
  const hasFails = validationResults?.some((r) => r.status === "fail");
  
  const totalSaved = DEMO_SAVES.reduce((sum, s) => sum + s.fineSaved, 0);

  const triggerNewSaveDemo = () => {
    setShowNewSave(true);
    setTimeout(() => setShowNewSave(false), 5000);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2 mb-2">
        <h1 className="text-xl font-bold text-phantom-dark">Contract Bot</h1>
        <InfoTooltip text={PAGE_HELP.contract} />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-slate-500">Assignments Validated Today</span>
            <CheckCircle className="h-4 w-4 text-green-500" />
          </div>
          <p className="text-3xl font-bold text-phantom-dark">847</p>
          <p className="text-sm text-green-600">98.2% legal</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-slate-500">Violations Prevented</span>
            <AlertTriangle className="h-4 w-4 text-amber-500" />
          </div>
          <p className="text-3xl font-bold text-phantom-dark">15</p>
          <p className="text-sm text-amber-600">$180K in grievances saved</p>
        </div>
        <div className="bg-gradient-to-r from-green-500 to-emerald-600 rounded-xl shadow-sm p-5 text-white">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-green-100">FAA Fines Avoided</span>
            <Shield className="h-4 w-4 text-green-200" />
          </div>
          <p className="text-3xl font-bold">${(totalSaved / 1000).toFixed(0)}K</p>
          <p className="text-sm text-green-200">Part 117 violations blocked</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border">
        <div className="flex border-b px-5 py-3">
          {[
            { id: "validate", label: "Validate Assignment", icon: CheckCircle },
            { id: "saves", label: "Live Saves", icon: Shield },
            { id: "chat", label: "Ask Contract Bot", icon: MessageSquare },
            { id: "reference", label: "Rule Reference", icon: Book },
          ].map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as typeof activeTab)}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition ${
                  activeTab === tab.id
                    ? "bg-phantom-primary text-white"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                <Icon className="h-4 w-4" />
                {tab.label}
              </button>
            );
          })}
        </div>

        <div className="p-5">
          {activeTab === "validate" && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Select Crew Member</label>
                  <select
                    value={selectedCrew.id}
                    onChange={(e) => setSelectedCrew(crewMembers.find((c) => c.id === e.target.value) || crewMembers[0])}
                    className="w-full px-4 py-3 border rounded-lg text-sm focus:ring-2 focus:ring-phantom-primary focus:border-transparent"
                  >
                    {crewMembers.map((c) => (
                      <option key={c.id} value={c.id}>{c.id} - {c.name} ({c.base})</option>
                    ))}
                  </select>
                </div>

                <div className="bg-slate-50 p-4 rounded-lg">
                  <h4 className="font-medium text-phantom-dark mb-2">Current Status</h4>
                  <div className="grid grid-cols-2 gap-2 text-sm">
                    <div><span className="text-slate-500">Monthly Hours:</span> {selectedCrew.monthlyHours} hrs</div>
                    <div><span className="text-slate-500">Remaining:</span> {selectedCrew.remaining} hrs</div>
                    <div><span className="text-slate-500">Consecutive Days:</span> {selectedCrew.consecutiveDays}</div>
                    <div><span className="text-slate-500">Last Rest:</span> {selectedCrew.lastRest} hrs</div>
                    <div className="col-span-2"><span className="text-slate-500">Type Ratings:</span> {selectedCrew.types.join(", ")}</div>
                  </div>
                </div>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Select Flight</label>
                  <select
                    value={selectedFlight.id}
                    onChange={(e) => setSelectedFlight(flights.find((f) => f.id === e.target.value) || flights[0])}
                    className="w-full px-4 py-3 border rounded-lg text-sm focus:ring-2 focus:ring-phantom-primary focus:border-transparent"
                  >
                    {flights.map((f) => (
                      <option key={f.id} value={f.id}>{f.id} - {f.route} ({f.aircraft}, {f.blockTime} hrs)</option>
                    ))}
                  </select>
                </div>

                <div className="bg-slate-50 p-4 rounded-lg">
                  <h4 className="font-medium text-phantom-dark mb-2">Flight Details</h4>
                  <div className="grid grid-cols-2 gap-2 text-sm">
                    <div><span className="text-slate-500">Departure:</span> {selectedFlight.departure}</div>
                    <div><span className="text-slate-500">Block Time:</span> {selectedFlight.blockTime} hrs</div>
                    <div><span className="text-slate-500">Aircraft:</span> {selectedFlight.aircraft}</div>
                    <div><span className="text-slate-500">Report:</span> {selectedFlight.report}</div>
                    <div className="col-span-2"><span className="text-slate-500">Est. Release:</span> {selectedFlight.release}</div>
                  </div>
                </div>
              </div>

              <div className="lg:col-span-2">
                <button
                  onClick={validateAssignment}
                  disabled={validating}
                  className="w-full py-3 bg-phantom-primary text-white rounded-lg hover:bg-phantom-dark transition disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {validating ? <Loader2 className="h-5 w-5 animate-spin" /> : <CheckCircle className="h-5 w-5" />}
                  {validating ? "Validating..." : "Validate Assignment"}
                </button>
              </div>

              {validationResults && (
                <div className="lg:col-span-2 space-y-4">
                  <div className={`p-4 rounded-lg border ${
                    hasFails ? "bg-red-50 border-red-200" :
                    hasWarnings ? "bg-amber-50 border-amber-200" :
                    "bg-green-50 border-green-200"
                  }`}>
                    <div className="flex items-center gap-2">
                      {hasFails ? <XCircle className="h-5 w-5 text-red-600" /> :
                       hasWarnings ? <AlertTriangle className="h-5 w-5 text-amber-600" /> :
                       <CheckCircle className="h-5 w-5 text-green-600" />}
                      <span className={`font-semibold ${
                        hasFails ? "text-red-700" : hasWarnings ? "text-amber-700" : "text-green-700"
                      }`}>
                        {hasFails ? "ASSIGNMENT HAS VIOLATIONS" :
                         hasWarnings ? "ASSIGNMENT LEGAL WITH WARNINGS" :
                         "ASSIGNMENT IS LEGAL"}
                      </span>
                    </div>
                  </div>

                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="text-left text-sm text-slate-500 border-b">
                          <th className="pb-3 font-medium">Check</th>
                          <th className="pb-3 font-medium">Status</th>
                          <th className="pb-3 font-medium">Detail</th>
                        </tr>
                      </thead>
                      <tbody>
                        {validationResults.map((r) => (
                          <tr key={r.check} className="border-b last:border-0">
                            <td className="py-3 font-medium">{r.check}</td>
                            <td className="py-3">
                              <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                                r.status === "pass" ? "bg-green-100 text-green-700" :
                                r.status === "warning" ? "bg-amber-100 text-amber-700" :
                                "bg-red-100 text-red-700"
                              }`}>
                                {r.status === "pass" ? "✓ PASS" : r.status === "warning" ? "⚠ WARNING" : "✗ FAIL"}
                              </span>
                            </td>
                            <td className="py-3 text-sm text-slate-600">{r.detail}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === "saves" && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-lg font-semibold text-slate-800">Violations Caught in Real-Time</h3>
                  <p className="text-sm text-slate-500">Contract Bot automatically blocks illegal assignments before they happen</p>
                </div>
                <button
                  onClick={triggerNewSaveDemo}
                  className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition flex items-center gap-2"
                >
                  <Ban className="h-4 w-4" />
                  Simulate Violation Catch
                </button>
              </div>

              {showNewSave && (
                <div className="bg-red-50 border-2 border-red-300 rounded-xl p-4 animate-pulse">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center">
                      <Ban className="h-6 w-6 text-red-600" />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-red-700 text-lg">VIOLATION BLOCKED</p>
                      <p className="text-red-600">Capt. Michael Torres → PH7892 (LAX→JFK)</p>
                      <p className="text-sm text-red-500">Would exceed 14-hour Flight Duty Period</p>
                    </div>
                    <div className="text-right">
                      <p className="text-2xl font-bold text-red-700">$50,000</p>
                      <p className="text-xs text-red-500">FAA Fine Avoided</p>
                    </div>
                  </div>
                </div>
              )}

              <div className="bg-gradient-to-r from-green-600 to-emerald-600 rounded-xl p-6 text-white">
                <div className="grid grid-cols-4 gap-4 text-center">
                  <div>
                    <p className="text-4xl font-bold">{DEMO_SAVES.length}</p>
                    <p className="text-sm text-green-200">Violations Blocked Today</p>
                  </div>
                  <div>
                    <p className="text-4xl font-bold">${(totalSaved / 1000).toFixed(0)}K</p>
                    <p className="text-sm text-green-200">Fines Avoided</p>
                  </div>
                  <div>
                    <p className="text-4xl font-bold">0</p>
                    <p className="text-sm text-green-200">FAA Violations This Month</p>
                  </div>
                  <div>
                    <p className="text-4xl font-bold">100%</p>
                    <p className="text-sm text-green-200">Compliance Rate</p>
                  </div>
                </div>
              </div>

              <div className="space-y-3">
                {DEMO_SAVES.map((save, idx) => {
                  const minutesAgo = Math.round((Date.now() - save.timestamp.getTime()) / 1000 / 60);
                  return (
                    <div
                      key={save.id}
                      className={`bg-white border rounded-xl p-4 flex items-center gap-4 ${
                        idx === 0 ? "border-red-200 bg-red-50/30" : "border-slate-200"
                      }`}
                    >
                      <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                        save.rule.startsWith("FAA") ? "bg-red-100" : "bg-amber-100"
                      }`}>
                        <Shield className={`h-5 w-5 ${
                          save.rule.startsWith("FAA") ? "text-red-600" : "text-amber-600"
                        }`} />
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <p className="font-semibold text-slate-800">{save.crewName}</p>
                          <span className="text-xs text-slate-400">→</span>
                          <p className="text-sm text-slate-600">{save.flightId}</p>
                        </div>
                        <p className="text-sm text-red-600 font-medium">{save.violation}</p>
                        <p className="text-xs text-slate-500">{save.rule}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-lg font-bold text-green-600">${(save.fineSaved / 1000).toFixed(0)}K</p>
                        <p className="text-xs text-slate-400">{minutesAgo} min ago</p>
                      </div>
                    </div>
                  );
                })}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
                  <h4 className="font-semibold text-blue-800 flex items-center gap-2">
                    <AlertTriangle className="h-4 w-4" />
                    FAA Part 117 Violations
                  </h4>
                  <p className="text-sm text-blue-600 mt-1">Up to <span className="font-bold">$50,000</span> per violation</p>
                  <p className="text-xs text-blue-500 mt-2">Includes FDP limits, rest requirements, monthly/annual hours</p>
                </div>
                <div className="bg-purple-50 border border-purple-200 rounded-xl p-4">
                  <h4 className="font-semibold text-purple-800 flex items-center gap-2">
                    <MessageSquare className="h-4 w-4" />
                    PWA Grievances
                  </h4>
                  <p className="text-sm text-purple-600 mt-1">Up to <span className="font-bold">$5,000+</span> per grievance</p>
                  <p className="text-xs text-purple-500 mt-2">Includes consecutive days, reserve notice, involuntary extensions</p>
                </div>
              </div>
            </div>
          )}

          {activeTab === "chat" && (
            <div className="flex flex-col h-[500px]">
              <div className="flex-1 overflow-y-auto space-y-4 mb-4">
                {messages.length === 0 && (
                  <div className="text-center py-8">
                    <Bot className="h-12 w-12 mx-auto mb-4 text-slate-300" />
                    <p className="text-slate-500 mb-4">Ask about PWA rules or FAA Part 117 regulations</p>
                    <div className="flex flex-wrap justify-center gap-2">
                      {sampleQuestions.map((q, idx) => (
                        <button
                          key={idx}
                          onClick={() => sendChatMessage(q)}
                          className="px-3 py-2 bg-slate-100 hover:bg-slate-200 rounded-lg text-sm text-slate-700 transition text-left"
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
                    <div className={`max-w-[70%] px-4 py-3 rounded-2xl ${
                      msg.role === "user"
                        ? "bg-phantom-primary text-white rounded-br-md"
                        : "bg-slate-100 text-slate-800 rounded-bl-md"
                    }`}>
                      <p className="whitespace-pre-wrap">{msg.content}</p>
                    </div>
                    {msg.role === "user" && (
                      <div className="w-8 h-8 rounded-full bg-phantom-primary flex items-center justify-center flex-shrink-0">
                        <User className="h-4 w-4 text-white" />
                      </div>
                    )}
                  </div>
                ))}

                {chatLoading && (
                  <div className="flex gap-3">
                    <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center">
                      <Bot className="h-4 w-4 text-purple-600" />
                    </div>
                    <div className="bg-slate-100 px-4 py-3 rounded-2xl rounded-bl-md">
                      <Loader2 className="h-5 w-5 animate-spin text-purple-500" />
                    </div>
                  </div>
                )}
                <div ref={messagesEndRef} />
              </div>

              <form
                onSubmit={(e) => { e.preventDefault(); sendChatMessage(chatInput); }}
                className="flex gap-3"
              >
                <input
                  type="text"
                  value={chatInput}
                  onChange={(e) => setChatInput(e.target.value)}
                  placeholder="Ask about contract rules..."
                  className="flex-1 px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-phantom-primary"
                  disabled={chatLoading}
                />
                <button
                  type="submit"
                  disabled={chatLoading || !chatInput.trim()}
                  className="px-4 py-3 bg-phantom-primary text-white rounded-xl hover:bg-phantom-dark transition disabled:opacity-50"
                >
                  <Send className="h-5 w-5" />
                </button>
              </form>
            </div>
          )}

          {activeTab === "reference" && (
            <div className="space-y-6">
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="text-left text-sm text-slate-500 border-b">
                      <th className="pb-3 font-medium">Rule ID</th>
                      <th className="pb-3 font-medium">Category</th>
                      <th className="pb-3 font-medium">Name</th>
                      <th className="pb-3 font-medium">Key Limit</th>
                    </tr>
                  </thead>
                  <tbody>
                    {contractRules.map((r) => (
                      <tr key={r.id} className="border-b last:border-0 hover:bg-slate-50">
                        <td className="py-3 font-mono text-sm">{r.id}</td>
                        <td className="py-3">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                            r.category === "FAA" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"
                          }`}>
                            {r.category}
                          </span>
                        </td>
                        <td className="py-3 font-medium">{r.name}</td>
                        <td className="py-3">{r.limit}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <h4 className="font-semibold text-blue-800 mb-2">FAA Part 117 - Flight Duty Period Limits</h4>
                  <div className="text-sm text-blue-700 space-y-1">
                    <p><strong>0500-0659:</strong> 13 hrs (1-2 seg) / 11.5 hrs (5+ seg)</p>
                    <p><strong>0700-1159:</strong> 14 hrs (1-2 seg) / 12.5 hrs (5+ seg)</p>
                    <p><strong>1200-1659:</strong> 12-13 hrs depending on segments</p>
                    <p><strong>1700-2159:</strong> 11 hrs (1-2 seg) / 9.5 hrs (5+ seg)</p>
                  </div>
                </div>

                <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
                  <h4 className="font-semibold text-purple-800 mb-2">PWA Section 5 - Duty Time Provisions</h4>
                  <div className="text-sm text-purple-700 space-y-1">
                    <p><strong>5.1:</strong> Max 6 consecutive duty days</p>
                    <p><strong>5.2:</strong> Short-call reserve: 2 hr notice min</p>
                    <p><strong>5.3:</strong> Involuntary extension: 2 hr max</p>
                    <p><strong>5.4:</strong> Voluntary extension: unlimited</p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
