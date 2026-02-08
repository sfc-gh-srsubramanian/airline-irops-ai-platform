"use client";

import { useEffect, useState, useCallback } from "react";
import { Ghost, AlertTriangle, Loader2, CheckCircle, XCircle, Clock, Plane, Users, Zap, ArrowRight } from "lucide-react";
import InfoTooltip from "./InfoTooltip";
import { PAGE_HELP } from "@/lib/pageHelp";

interface GhostFlight {
  FLIGHT_ID: string;
  FLIGHT_NUMBER: string;
  ORIGIN: string;
  DESTINATION: string;
  SCHEDULED_DEPARTURE: string;
  STATUS: string;
  IS_GHOST_FLIGHT: boolean;
  GHOST_FLIGHT_REASON: string;
  RECOVERY_PRIORITY_SCORE: number;
  PAX_BOOKED: number;
  AIRCRAFT_REGISTRATION: string;
  CAPTAIN_NAME: string;
  FO_NAME: string;
}

interface Summary {
  totalGhostFlights: number;
  missingCrew: number;
  missingAircraft: number;
  missingBoth: number;
  avgPriority: number;
  totalPaxAffected: number;
}

interface Recommendation {
  type: string;
  title: string;
  description: string;
  options?: Array<{
    CREW_ID?: string;
    AIRCRAFT_ID?: string;
    FULL_NAME?: string;
    REGISTRATION?: string;
    CREW_TYPE?: string;
    AIRCRAFT_TYPE?: string;
    BASE_AIRPORT?: string;
    CURRENT_LOCATION?: string;
    HOURS_REMAINING?: number;
    STATUS?: string;
  }>;
  priority: string;
}

interface AnalysisResult {
  flight: GhostFlight;
  recommendations: Recommendation[];
  agentAnalysis: string;
}

export default function GhostPlanes() {
  const [ghostFlights, setGhostFlights] = useState<GhostFlight[]>([]);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedFlight, setSelectedFlight] = useState<GhostFlight | null>(null);
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [resolving, setResolving] = useState<string | null>(null);
  const [notification, setNotification] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [agentThinking, setAgentThinking] = useState(false);
  const [agentPlan, setAgentPlan] = useState<string | null>(null);

  useEffect(() => {
    fetchGhostFlights();
  }, []);

  useEffect(() => {
    if (notification) {
      const timer = setTimeout(() => setNotification(null), 5000);
      return () => clearTimeout(timer);
    }
  }, [notification]);

  async function fetchGhostFlights() {
    try {
      const res = await fetch("/api/ghost-planes");
      const json = await res.json();
      setGhostFlights(json.ghostFlights || []);
      setSummary(json.summary);
    } catch (err) {
      console.error("Failed to fetch ghost flights:", err);
    } finally {
      setLoading(false);
    }
  }

  const analyzeFlightWithAgent = useCallback(async (flight: GhostFlight) => {
    setSelectedFlight(flight);
    setAnalyzing(true);
    setAnalysis(null);
    setAgentPlan(null);

    try {
      const res = await fetch("/api/ghost-planes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ flightId: flight.FLIGHT_ID, action: "analyze" }),
      });
      const json = await res.json();
      setAnalysis(json);

      setAgentThinking(true);
      const agentRes = await fetch("/api/agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: `Create a step-by-step resolution plan for ghost flight ${flight.FLIGHT_NUMBER} from ${flight.ORIGIN} to ${flight.DESTINATION}. Issue: ${flight.GHOST_FLIGHT_REASON}. ${flight.PAX_BOOKED} passengers affected. Priority score: ${flight.RECOVERY_PRIORITY_SCORE}. Available options: ${JSON.stringify(json.recommendations)}`,
          context: "Ghost Flight Resolution",
        }),
      });
      const agentJson = await agentRes.json();
      setAgentPlan(agentJson.response);
    } catch (err) {
      console.error("Failed to analyze flight:", err);
    } finally {
      setAnalyzing(false);
      setAgentThinking(false);
    }
  }, []);

  const executeResolution = useCallback(async (resolutionType: string) => {
    if (!selectedFlight) return;

    setResolving(resolutionType);

    try {
      const res = await fetch("/api/ghost-planes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          flightId: selectedFlight.FLIGHT_ID,
          action: "resolve",
          resolutionType,
        }),
      });
      const json = await res.json();

      if (json.success) {
        setNotification({ type: "success", message: json.message });
        setSelectedFlight(null);
        setAnalysis(null);
        setAgentPlan(null);
        fetchGhostFlights();
      } else {
        setNotification({ type: "error", message: json.message || "Resolution failed" });
      }
    } catch (err) {
      setNotification({ type: "error", message: "Failed to execute resolution" });
    } finally {
      setResolving(null);
    }
  }, [selectedFlight]);

  const getReasonIcon = (reason: string) => {
    if (reason?.includes("CREW")) return <Users className="h-4 w-4" />;
    if (reason?.includes("AIRCRAFT")) return <Plane className="h-4 w-4" />;
    return <Ghost className="h-4 w-4" />;
  };

  const getReasonColor = (reason: string) => {
    if (reason?.includes("BOTH")) return "bg-red-100 text-red-700";
    if (reason?.includes("CREW")) return "bg-orange-100 text-orange-700";
    if (reason?.includes("AIRCRAFT")) return "bg-purple-100 text-purple-700";
    return "bg-slate-100 text-slate-700";
  };

  const getPriorityColor = (score: number) => {
    if (score >= 80) return "text-red-600";
    if (score >= 60) return "text-orange-600";
    if (score >= 40) return "text-amber-600";
    return "text-green-600";
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-phantom-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {notification && (
        <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-lg shadow-lg flex items-center gap-2 ${
          notification.type === "success" ? "bg-green-500 text-white" : "bg-red-500 text-white"
        }`}>
          {notification.type === "success" ? <CheckCircle className="h-5 w-5" /> : <XCircle className="h-5 w-5" />}
          {notification.message}
        </div>
      )}

      {summary && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-xl shadow-sm border p-4">
            <div className="flex items-center gap-2 mb-2">
              <Ghost className="h-5 w-5 text-purple-500" />
              <span className="text-sm text-slate-500">Ghost Flights</span>
            </div>
            <p className="text-2xl font-bold text-phantom-dark">{summary.totalGhostFlights}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border p-4">
            <div className="flex items-center gap-2 mb-2">
              <Users className="h-5 w-5 text-orange-500" />
              <span className="text-sm text-slate-500">Missing Crew</span>
            </div>
            <p className="text-2xl font-bold text-orange-600">{summary.missingCrew}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border p-4">
            <div className="flex items-center gap-2 mb-2">
              <Plane className="h-5 w-5 text-purple-500" />
              <span className="text-sm text-slate-500">Missing Aircraft</span>
            </div>
            <p className="text-2xl font-bold text-purple-600">{summary.missingAircraft}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border p-4">
            <div className="flex items-center gap-2 mb-2">
              <AlertTriangle className="h-5 w-5 text-red-500" />
              <span className="text-sm text-slate-500">PAX Affected</span>
            </div>
            <p className="text-2xl font-bold text-red-600">{summary.totalPaxAffected?.toLocaleString()}</p>
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl shadow-sm border p-5">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Ghost className="h-5 w-5 text-purple-500" />
            <h2 className="text-lg font-semibold text-phantom-dark">Ghost Flights</h2>
            <InfoTooltip text={PAGE_HELP.ghost} />
          </div>
        </div>

        {ghostFlights.length === 0 ? (
          <div className="text-center py-8 text-slate-500">
            <CheckCircle className="h-12 w-12 mx-auto mb-3 text-green-500" />
            <p>No ghost flights detected! All flights have proper resources assigned.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-sm text-slate-500 border-b">
                  <th className="pb-3 font-medium">Flight</th>
                  <th className="pb-3 font-medium">Route</th>
                  <th className="pb-3 font-medium">Issue</th>
                  <th className="pb-3 font-medium">
                    <span className="flex items-center gap-1">
                      Priority
                      <InfoTooltip text="Recovery Priority Score (0-100). Higher = more urgent. 100 = aircraft location mismatch, 95 = missing crew, 90 = critical disruption, 85 = ground stop." />
                    </span>
                  </th>
                  <th className="pb-3 font-medium">PAX</th>
                  <th className="pb-3 font-medium">Action</th>
                </tr>
              </thead>
              <tbody>
                {ghostFlights.map((flight) => (
                  <tr key={flight.FLIGHT_ID} className="border-b last:border-0 hover:bg-slate-50">
                    <td className="py-3 font-medium">{flight.FLIGHT_NUMBER}</td>
                    <td className="py-3">{flight.ORIGIN} → {flight.DESTINATION}</td>
                    <td className="py-3">
                      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium ${getReasonColor(flight.GHOST_FLIGHT_REASON)}`}>
                        {getReasonIcon(flight.GHOST_FLIGHT_REASON)}
                        {flight.GHOST_FLIGHT_REASON || "UNKNOWN"}
                      </span>
                    </td>
                    <td className="py-3">
                      <span className={`font-bold ${getPriorityColor(flight.RECOVERY_PRIORITY_SCORE)}`}>
                        {flight.RECOVERY_PRIORITY_SCORE?.toFixed(0) || "N/A"}
                      </span>
                    </td>
                    <td className="py-3">{flight.PAX_BOOKED}</td>
                    <td className="py-3">
                      <button
                        onClick={() => analyzeFlightWithAgent(flight)}
                        disabled={analyzing}
                        className="flex items-center gap-1 px-3 py-1.5 bg-purple-500 text-white rounded text-sm hover:bg-purple-600 transition disabled:opacity-50"
                      >
                        <Zap className="h-3 w-3" />
                        Resolve
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {selectedFlight && (
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-lg font-semibold text-phantom-dark">
                Resolution Options for {selectedFlight.FLIGHT_NUMBER}
              </h3>
              <p className="text-sm text-slate-500">
                {selectedFlight.ORIGIN} → {selectedFlight.DESTINATION} • {selectedFlight.PAX_BOOKED} passengers
              </p>
            </div>
            <button
              onClick={() => { setSelectedFlight(null); setAnalysis(null); setAgentPlan(null); }}
              className="text-slate-400 hover:text-slate-600"
            >
              ✕
            </button>
          </div>

          {analyzing && (
            <div className="flex items-center justify-center h-32">
              <Loader2 className="h-6 w-6 animate-spin text-purple-500" />
            </div>
          )}

          {agentThinking && (
            <div className="mb-4 p-3 bg-purple-50 border border-purple-200 rounded-lg flex items-center gap-2">
              <Zap className="h-4 w-4 text-purple-500 animate-pulse" />
              <span className="text-sm text-purple-700">AI Agent creating resolution plan...</span>
            </div>
          )}

          {agentPlan && (
            <div className="mb-6 p-4 bg-gradient-to-r from-purple-50 to-indigo-50 border border-purple-200 rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <Zap className="h-4 w-4 text-purple-600" />
                <span className="text-sm font-semibold text-purple-800">AI Resolution Plan</span>
              </div>
              <p className="text-sm text-slate-700 whitespace-pre-wrap">{agentPlan}</p>
            </div>
          )}

          {analysis && (
            <div className="space-y-4">
              {analysis.recommendations.map((rec) => (
                <div
                  key={rec.type}
                  className={`p-4 rounded-lg border ${
                    rec.priority === "HIGH" ? "border-red-200 bg-red-50" :
                    rec.priority === "MEDIUM" ? "border-amber-200 bg-amber-50" :
                    "border-slate-200 bg-slate-50"
                  }`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      {rec.type === "CREW_ASSIGNMENT" && <Users className="h-5 w-5 text-orange-500" />}
                      {rec.type === "AIRCRAFT_SWAP" && <Plane className="h-5 w-5 text-purple-500" />}
                      {rec.type === "CANCEL_FLIGHT" && <XCircle className="h-5 w-5 text-red-500" />}
                      {rec.type === "DELAY_FLIGHT" && <Clock className="h-5 w-5 text-amber-500" />}
                      <h4 className="font-semibold">{rec.title}</h4>
                    </div>
                    <span className={`text-xs font-medium px-2 py-1 rounded ${
                      rec.priority === "HIGH" ? "bg-red-200 text-red-800" :
                      rec.priority === "MEDIUM" ? "bg-amber-200 text-amber-800" :
                      "bg-slate-200 text-slate-800"
                    }`}>
                      {rec.priority}
                    </span>
                  </div>
                  <p className="text-sm text-slate-600 mb-3">{rec.description}</p>

                  {rec.options && rec.options.length > 0 && (
                    <div className="mb-3 space-y-2">
                      {rec.options.slice(0, 3).map((opt, idx) => (
                        <div key={idx} className="text-sm p-2 bg-white rounded border flex items-center justify-between">
                          <span>
                            {opt.FULL_NAME || opt.REGISTRATION} 
                            {opt.BASE_AIRPORT && ` (${opt.BASE_AIRPORT})`}
                            {opt.CURRENT_LOCATION && ` @ ${opt.CURRENT_LOCATION}`}
                          </span>
                          {opt.HOURS_REMAINING && <span className="text-slate-500">{opt.HOURS_REMAINING}h remaining</span>}
                        </div>
                      ))}
                    </div>
                  )}

                  <button
                    onClick={() => executeResolution(rec.type)}
                    disabled={!!resolving}
                    className={`flex items-center gap-2 px-4 py-2 rounded-lg text-white transition ${
                      rec.type === "CANCEL_FLIGHT" ? "bg-red-500 hover:bg-red-600" :
                      rec.type === "DELAY_FLIGHT" ? "bg-amber-500 hover:bg-amber-600" :
                      "bg-green-500 hover:bg-green-600"
                    } disabled:opacity-50`}
                  >
                    {resolving === rec.type ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <ArrowRight className="h-4 w-4" />
                    )}
                    Execute {rec.title}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
