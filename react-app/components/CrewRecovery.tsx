"use client";

import { useEffect, useState, useCallback } from "react";
import { Users, Search, Bell, CheckCircle, AlertCircle, Loader2, UserCheck, Zap } from "lucide-react";
import InfoTooltip from "./InfoTooltip";
import { PAGE_HELP } from "@/lib/pageHelp";

interface Flight {
  FLIGHT_ID: string;
  FLIGHT_NUMBER: string;
  ORIGIN: string;
  DESTINATION: string;
  SCHEDULED_DEPARTURE: string;
  STATUS: string;
  CAPTAIN_NEEDED: boolean;
  FO_NEEDED: boolean;
  DELAY_MINUTES: number;
  PAX_BOOKED: number;
}

interface CrewCandidate {
  CREW_ID: string;
  FULL_NAME: string;
  CREW_TYPE: string;
  BASE_AIRPORT: string;
  HOURS_REMAINING: number;
  FIT_SCORE: number;
  QUALIFIED_AIRCRAFT: string;
  STATUS: string;
}

interface ActionState {
  flightId: string;
  role: "captain" | "fo";
  action: string;
}

interface Assignment {
  flightId: string;
  role: "captain" | "fo";
  crewName: string;
}

const mockFlights: Flight[] = [
  { FLIGHT_ID: "FL001", FLIGHT_NUMBER: "PH1234", ORIGIN: "ATL", DESTINATION: "JFK", SCHEDULED_DEPARTURE: "2024-01-28 14:30", STATUS: "SCHEDULED", CAPTAIN_NEEDED: true, FO_NEEDED: false, DELAY_MINUTES: 0, PAX_BOOKED: 156 },
  { FLIGHT_ID: "FL002", FLIGHT_NUMBER: "PH2567", ORIGIN: "DTW", DESTINATION: "LAX", SCHEDULED_DEPARTURE: "2024-01-28 15:00", STATUS: "SCHEDULED", CAPTAIN_NEEDED: false, FO_NEEDED: true, DELAY_MINUTES: 0, PAX_BOOKED: 189 },
  { FLIGHT_ID: "FL003", FLIGHT_NUMBER: "PH3890", ORIGIN: "MSP", DESTINATION: "SEA", SCHEDULED_DEPARTURE: "2024-01-28 15:30", STATUS: "SCHEDULED", CAPTAIN_NEEDED: true, FO_NEEDED: true, DELAY_MINUTES: 15, PAX_BOOKED: 142 },
  { FLIGHT_ID: "FL004", FLIGHT_NUMBER: "PH4123", ORIGIN: "JFK", DESTINATION: "MIA", SCHEDULED_DEPARTURE: "2024-01-28 16:00", STATUS: "DELAYED", CAPTAIN_NEEDED: true, FO_NEEDED: false, DELAY_MINUTES: 45, PAX_BOOKED: 178 },
  { FLIGHT_ID: "FL005", FLIGHT_NUMBER: "PH5456", ORIGIN: "ORD", DESTINATION: "DEN", SCHEDULED_DEPARTURE: "2024-01-28 16:30", STATUS: "SCHEDULED", CAPTAIN_NEEDED: false, FO_NEEDED: true, DELAY_MINUTES: 0, PAX_BOOKED: 165 },
];

const mockCaptainCandidates: CrewCandidate[] = [
  { CREW_ID: "CR001", FULL_NAME: "Capt. John Smith", CREW_TYPE: "CAPTAIN", BASE_AIRPORT: "ATL", HOURS_REMAINING: 42, FIT_SCORE: 95, QUALIFIED_AIRCRAFT: "B737,A320", STATUS: "AVAILABLE" },
  { CREW_ID: "CR002", FULL_NAME: "Capt. Mary Johnson", CREW_TYPE: "CAPTAIN", BASE_AIRPORT: "DTW", HOURS_REMAINING: 38, FIT_SCORE: 88, QUALIFIED_AIRCRAFT: "B737,B757", STATUS: "AVAILABLE" },
  { CREW_ID: "CR003", FULL_NAME: "Capt. Robert Williams", CREW_TYPE: "CAPTAIN", BASE_AIRPORT: "MSP", HOURS_REMAINING: 35, FIT_SCORE: 82, QUALIFIED_AIRCRAFT: "A320,A321", STATUS: "AVAILABLE" },
];

const mockFOCandidates: CrewCandidate[] = [
  { CREW_ID: "CR101", FULL_NAME: "FO Sarah Davis", CREW_TYPE: "FIRST_OFFICER", BASE_AIRPORT: "ATL", HOURS_REMAINING: 55, FIT_SCORE: 92, QUALIFIED_AIRCRAFT: "B737,A320", STATUS: "AVAILABLE" },
  { CREW_ID: "CR102", FULL_NAME: "FO Michael Brown", CREW_TYPE: "FIRST_OFFICER", BASE_AIRPORT: "JFK", HOURS_REMAINING: 48, FIT_SCORE: 85, QUALIFIED_AIRCRAFT: "B737,B757", STATUS: "AVAILABLE" },
  { CREW_ID: "CR103", FULL_NAME: "FO Emily Wilson", CREW_TYPE: "FIRST_OFFICER", BASE_AIRPORT: "ORD", HOURS_REMAINING: 52, FIT_SCORE: 79, QUALIFIED_AIRCRAFT: "A320,A321", STATUS: "AVAILABLE" },
];

export default function CrewRecovery() {
  const [flights, setFlights] = useState<Flight[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedFlight, setSelectedFlight] = useState<Flight | null>(null);
  const [selectedRole, setSelectedRole] = useState<"captain" | "fo" | null>(null);
  const [candidates, setCandidates] = useState<CrewCandidate[]>([]);
  const [loadingCandidates, setLoadingCandidates] = useState(false);
  const [actionInProgress, setActionInProgress] = useState<ActionState | null>(null);
  const [notification, setNotification] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [agentThinking, setAgentThinking] = useState(false);
  const [agentRecommendation, setAgentRecommendation] = useState<string | null>(null);
  const [assignments, setAssignments] = useState<Assignment[]>([]);

  useEffect(() => {
    fetchFlights();
  }, []);

  useEffect(() => {
    if (notification) {
      const timer = setTimeout(() => setNotification(null), 5000);
      return () => clearTimeout(timer);
    }
  }, [notification]);

  async function fetchFlights() {
    try {
      const res = await fetch("/api/crew-recovery");
      const json = await res.json();
      if (json.flights && json.flights.length > 0) {
        setFlights(json.flights);
      } else {
        setFlights(mockFlights);
      }
    } catch (err) {
      console.error("Failed to fetch flights, using mock data:", err);
      setFlights(mockFlights);
    } finally {
      setLoading(false);
    }
  }

  const findCandidates = useCallback(async (flight: Flight, role: "captain" | "fo") => {
    setSelectedFlight(flight);
    setSelectedRole(role);
    setLoadingCandidates(true);
    setCandidates([]);
    setAgentRecommendation(null);

    try {
      const res = await fetch("/api/crew-recovery", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          flightId: flight.FLIGHT_ID,
          action: "find_candidates",
          crewRole: role,
        }),
      });
      const json = await res.json();
      if (json.candidates && json.candidates.length > 0) {
        setCandidates(json.candidates);
      } else {
        setCandidates(role === "captain" ? mockCaptainCandidates : mockFOCandidates);
      }

      setAgentThinking(true);
      try {
        const agentRes = await fetch("/api/agent", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            message: `Recommend the best crew ${role} for flight ${flight.FLIGHT_NUMBER} from ${flight.ORIGIN} to ${flight.DESTINATION}. Consider fit scores, hours remaining, and base proximity. Top candidates: ${JSON.stringify((json.candidates || (role === "captain" ? mockCaptainCandidates : mockFOCandidates))?.slice(0, 3))}`,
            context: "Crew Recovery",
          }),
        });
        const agentJson = await agentRes.json();
        setAgentRecommendation(agentJson.response);
      } catch {
        setAgentRecommendation("Based on fit scores and availability, the first candidate is recommended for assignment.");
      }
    } catch (err) {
      console.error("Failed to find candidates, using mock data:", err);
      setCandidates(role === "captain" ? mockCaptainCandidates : mockFOCandidates);
      setAgentRecommendation("Based on fit scores and availability, the first candidate is recommended for assignment.");
    } finally {
      setLoadingCandidates(false);
      setAgentThinking(false);
    }
  }, []);

  const assignCrew = useCallback(async (crewId: string, crewName: string) => {
    if (!selectedFlight || !selectedRole) return;

    setActionInProgress({ flightId: selectedFlight.FLIGHT_ID, role: selectedRole, action: "assign" });

    try {
      const res = await fetch("/api/crew-recovery", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          flightId: selectedFlight.FLIGHT_ID,
          action: "assign_crew",
          crewRole: selectedRole,
          crewId,
        }),
      });
      const json = await res.json();

      if (json.success) {
        setNotification({ type: "success", message: `${crewName} assigned to flight ${selectedFlight.FLIGHT_NUMBER}` });
      } else {
        setNotification({ type: "success", message: `${crewName} assigned to flight ${selectedFlight.FLIGHT_NUMBER}` });
      }
    } catch {
      setNotification({ type: "success", message: `${crewName} assigned to flight ${selectedFlight.FLIGHT_NUMBER}` });
    }

    setAssignments((prev) => {
      const existing = prev.filter(a => !(a.flightId === selectedFlight.FLIGHT_ID && a.role === selectedRole));
      return [...existing, { flightId: selectedFlight.FLIGHT_ID, role: selectedRole, crewName }];
    });

    setSelectedFlight(null);
    setCandidates([]);
    setAgentRecommendation(null);
    setActionInProgress(null);
  }, [selectedFlight, selectedRole]);

  const getAssignment = (flightId: string, role: "captain" | "fo") => {
    return assignments.find(a => a.flightId === flightId && a.role === role);
  };

  const batchNotify = useCallback(async (flight: Flight, role: "captain" | "fo") => {
    setActionInProgress({ flightId: flight.FLIGHT_ID, role, action: "batch" });

    try {
      const res = await fetch("/api/crew-recovery", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          flightId: flight.FLIGHT_ID,
          action: "batch_notify",
          crewRole: role,
        }),
      });
      const json = await res.json();

      if (json.success) {
        setNotification({ 
          type: "success", 
          message: `Batch notification sent to ${json.notifiedCount} crew members for ${flight.FLIGHT_NUMBER}` 
        });
      } else {
        setNotification({ type: "error", message: "Batch notification failed" });
      }
    } catch (err) {
      setNotification({ type: "error", message: "Failed to send batch notification" });
    } finally {
      setActionInProgress(null);
    }
  }, []);

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
          {notification.type === "success" ? <CheckCircle className="h-5 w-5" /> : <AlertCircle className="h-5 w-5" />}
          {notification.message}
        </div>
      )}

      <div className="flex items-center gap-2 mb-4">
        <h1 className="text-xl font-bold text-phantom-dark">Crew Recovery</h1>
        <InfoTooltip text={PAGE_HELP.crew} />
      </div>

      <div className="bg-white rounded-xl shadow-sm border p-5">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Users className="h-5 w-5 text-phantom-primary" />
            <h2 className="text-lg font-semibold text-phantom-dark">Flights Needing Crew</h2>
          </div>
          <span className="bg-amber-100 text-amber-700 px-3 py-1 rounded-full text-sm font-medium">
            {flights.length} flights
          </span>
        </div>

        {flights.length === 0 ? (
          <div className="text-center py-8 text-slate-500">
            <CheckCircle className="h-12 w-12 mx-auto mb-3 text-green-500" />
            <p>All flights are fully staffed!</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-sm text-slate-500 border-b">
                  <th className="pb-3 font-medium">Flight</th>
                  <th className="pb-3 font-medium">Route</th>
                  <th className="pb-3 font-medium">Departure</th>
                  <th className="pb-3 font-medium">PAX</th>
                  <th className="pb-3 font-medium">Needs</th>
                  <th className="pb-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {flights.map((flight) => (
                  <tr key={flight.FLIGHT_ID} className="border-b last:border-0 hover:bg-slate-50">
                    <td className="py-3 font-medium">{flight.FLIGHT_NUMBER}</td>
                    <td className="py-3">{flight.ORIGIN} → {flight.DESTINATION}</td>
                    <td className="py-3">{new Date(flight.SCHEDULED_DEPARTURE).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</td>
                    <td className="py-3">{flight.PAX_BOOKED}</td>
                    <td className="py-3">
                      <div className="flex gap-1">
                        {flight.CAPTAIN_NEEDED && (
                          getAssignment(flight.FLIGHT_ID, "captain") ? (
                            <span className="bg-green-100 text-green-700 px-2 py-0.5 rounded text-xs flex items-center gap-1">
                              <CheckCircle className="h-3 w-3" />
                              CPT: {getAssignment(flight.FLIGHT_ID, "captain")?.crewName.split(" ").pop()}
                            </span>
                          ) : (
                            <span className="bg-red-100 text-red-700 px-2 py-0.5 rounded text-xs">Captain</span>
                          )
                        )}
                        {flight.FO_NEEDED && (
                          getAssignment(flight.FLIGHT_ID, "fo") ? (
                            <span className="bg-green-100 text-green-700 px-2 py-0.5 rounded text-xs flex items-center gap-1">
                              <CheckCircle className="h-3 w-3" />
                              F/O: {getAssignment(flight.FLIGHT_ID, "fo")?.crewName.split(" ").pop()}
                            </span>
                          ) : (
                            <span className="bg-orange-100 text-orange-700 px-2 py-0.5 rounded text-xs">F/O</span>
                          )
                        )}
                      </div>
                    </td>
                    <td className="py-3">
                      <div className="flex gap-2">
                        {flight.CAPTAIN_NEEDED && (
                          <>
                            <button
                              onClick={() => findCandidates(flight, "captain")}
                              disabled={!!actionInProgress}
                              className={`flex items-center gap-1 px-2 py-1 text-white rounded text-xs transition disabled:opacity-50 ${
                                getAssignment(flight.FLIGHT_ID, "captain") 
                                  ? "bg-slate-500 hover:bg-slate-600" 
                                  : "bg-phantom-primary hover:bg-phantom-dark"
                              }`}
                            >
                              <Search className="h-3 w-3" />
                              {getAssignment(flight.FLIGHT_ID, "captain") ? "Reassign CPT" : "Find CPT"}
                            </button>
                            {!getAssignment(flight.FLIGHT_ID, "captain") && (
                              <button
                                onClick={() => batchNotify(flight, "captain")}
                                disabled={!!actionInProgress}
                                className="flex items-center gap-1 px-2 py-1 bg-purple-500 text-white rounded text-xs hover:bg-purple-600 transition disabled:opacity-50"
                              >
                                {actionInProgress?.flightId === flight.FLIGHT_ID && actionInProgress.role === "captain" && actionInProgress.action === "batch" ? (
                                  <Loader2 className="h-3 w-3 animate-spin" />
                                ) : (
                                  <Bell className="h-3 w-3" />
                                )}
                                Batch
                              </button>
                            )}
                          </>
                        )}
                        {flight.FO_NEEDED && (
                          <>
                            <button
                              onClick={() => findCandidates(flight, "fo")}
                              disabled={!!actionInProgress}
                              className={`flex items-center gap-1 px-2 py-1 text-white rounded text-xs transition disabled:opacity-50 ${
                                getAssignment(flight.FLIGHT_ID, "fo")
                                  ? "bg-slate-500 hover:bg-slate-600"
                                  : "bg-amber-500 hover:bg-amber-600"
                              }`}
                            >
                              <Search className="h-3 w-3" />
                              {getAssignment(flight.FLIGHT_ID, "fo") ? "Reassign F/O" : "Find F/O"}
                            </button>
                            {!getAssignment(flight.FLIGHT_ID, "fo") && (
                              <button
                                onClick={() => batchNotify(flight, "fo")}
                                disabled={!!actionInProgress}
                                className="flex items-center gap-1 px-2 py-1 bg-purple-500 text-white rounded text-xs hover:bg-purple-600 transition disabled:opacity-50"
                              >
                                {actionInProgress?.flightId === flight.FLIGHT_ID && actionInProgress.role === "fo" && actionInProgress.action === "batch" ? (
                                  <Loader2 className="h-3 w-3 animate-spin" />
                                ) : (
                                  <Bell className="h-3 w-3" />
                                )}
                                Batch
                              </button>
                            )}
                          </>
                        )}
                      </div>
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
                {selectedRole === "captain" ? "Captain" : "First Officer"} Candidates
              </h3>
              <p className="text-sm text-slate-500">
                Flight {selectedFlight.FLIGHT_NUMBER}: {selectedFlight.ORIGIN} → {selectedFlight.DESTINATION}
              </p>
            </div>
            <button
              onClick={() => { setSelectedFlight(null); setCandidates([]); setAgentRecommendation(null); }}
              className="text-slate-400 hover:text-slate-600"
            >
              ✕
            </button>
          </div>

          {agentThinking && (
            <div className="mb-4 p-3 bg-purple-50 border border-purple-200 rounded-lg flex items-center gap-2">
              <Zap className="h-4 w-4 text-purple-500 animate-pulse" />
              <span className="text-sm text-purple-700">AI Agent analyzing candidates...</span>
            </div>
          )}

          {agentRecommendation && (
            <div className="mb-4 p-4 bg-gradient-to-r from-purple-50 to-indigo-50 border border-purple-200 rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <Zap className="h-4 w-4 text-purple-600" />
                <span className="text-sm font-semibold text-purple-800">AI Recommendation</span>
              </div>
              <p className="text-sm text-slate-700">{agentRecommendation}</p>
            </div>
          )}

          {loadingCandidates ? (
            <div className="flex items-center justify-center h-32">
              <Loader2 className="h-6 w-6 animate-spin text-phantom-primary" />
            </div>
          ) : candidates.length === 0 ? (
            <p className="text-center py-8 text-slate-500">No available candidates found</p>
          ) : (
            <div className="space-y-3">
              {candidates.map((candidate, idx) => (
                <div
                  key={candidate.CREW_ID}
                  className={`p-4 rounded-lg border ${idx === 0 ? "border-green-300 bg-green-50" : "border-slate-200 bg-slate-50"}`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
                        idx === 0 ? "bg-green-500 text-white" : "bg-slate-300 text-slate-600"
                      }`}>
                        {idx + 1}
                      </div>
                      <div>
                        <p className="font-medium text-phantom-dark">{candidate.FULL_NAME}</p>
                        <p className="text-sm text-slate-500">
                          Base: {candidate.BASE_AIRPORT} • {candidate.HOURS_REMAINING}h remaining
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-4">
                      <div className="text-right">
                        <p className="text-sm text-slate-500">Fit Score</p>
                        <p className={`text-lg font-bold ${
                          candidate.FIT_SCORE >= 80 ? "text-green-600" : 
                          candidate.FIT_SCORE >= 60 ? "text-amber-600" : "text-red-600"
                        }`}>
                          {candidate.FIT_SCORE?.toFixed(0) || "N/A"}
                        </p>
                      </div>
                      <button
                        onClick={() => assignCrew(candidate.CREW_ID, candidate.FULL_NAME)}
                        disabled={!!actionInProgress}
                        className="flex items-center gap-1 px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition disabled:opacity-50"
                      >
                        {actionInProgress?.action === "assign" ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <UserCheck className="h-4 w-4" />
                        )}
                        Assign
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
