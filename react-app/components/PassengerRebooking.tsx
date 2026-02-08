"use client";

import { useState, useEffect } from "react";
import { Users, Plane, Clock, CheckCircle2, AlertTriangle, Crown, Star, ArrowRight, Loader2, RefreshCw } from "lucide-react";

interface RebookingOption {
  BOOKING_ID: string;
  CONFIRMATION_CODE: string;
  FIRST_NAME: string;
  LAST_NAME: string;
  LOYALTY_TIER: string;
  ORIGINAL_FLIGHT_NUMBER: string;
  ORIGIN: string;
  DESTINATION: string;
  ORIGINAL_STATUS: string;
  REBOOK_FLIGHT_NUMBER: string;
  REBOOK_DEPARTURE: string;
  AVAILABLE_SEATS: number;
  MINUTES_AFTER_ORIGINAL: number;
  OPTION_RANK: number;
}

const TIER_CONFIG: Record<string, { color: string; bg: string; icon: React.ReactNode; priority: number }> = {
  DIAMOND: { color: "text-purple-700", bg: "bg-purple-100", icon: <Crown className="h-4 w-4" />, priority: 1 },
  PLATINUM: { color: "text-slate-700", bg: "bg-slate-200", icon: <Star className="h-4 w-4" />, priority: 2 },
  GOLD: { color: "text-amber-700", bg: "bg-amber-100", icon: <Star className="h-4 w-4" />, priority: 3 },
  SILVER: { color: "text-gray-600", bg: "bg-gray-100", icon: null, priority: 4 },
  BLUE: { color: "text-blue-600", bg: "bg-blue-50", icon: null, priority: 5 },
};

const STORAGE_KEY = "phantom_rebooked_passengers";

function formatTime(dateStr: string): string {
  try {
    const date = new Date(dateStr);
    return date.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" });
  } catch {
    return dateStr;
  }
}

function formatMinutes(minutes: number): string {
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
}

function loadRebookedIds(): Set<string> {
  if (typeof window === "undefined") return new Set();
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      const parsed = JSON.parse(stored);
      if (parsed.date === new Date().toDateString()) {
        return new Set(parsed.ids);
      }
    }
  } catch {}
  return new Set();
}

function saveRebookedIds(ids: Set<string>) {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      date: new Date().toDateString(),
      ids: Array.from(ids)
    }));
  } catch {}
}

export default function PassengerRebooking() {
  const [data, setData] = useState<RebookingOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [rebookedIds, setRebookedIds] = useState<Set<string>>(new Set());
  const [rebookingId, setRebookingId] = useState<string | null>(null);
  const [filter, setFilter] = useState<"all" | "elite">("elite");

  useEffect(() => {
    setRebookedIds(loadRebookedIds());
  }, []);

  useEffect(() => {
    fetchRebookingData();
  }, []);

  async function fetchRebookingData() {
    setLoading(true);
    try {
      const res = await fetch("/api/rebooking");
      if (res.ok) {
        const json = await res.json();
        const options = json.data || [];
        setData(options);
      }
    } catch (err) {
      console.error("Failed to fetch rebooking data:", err);
    } finally {
      setLoading(false);
    }
  }

  async function handleRebook(booking: RebookingOption) {
    setRebookingId(booking.BOOKING_ID);
    await new Promise((r) => setTimeout(r, 1500));
    const newIds = new Set(rebookedIds).add(booking.BOOKING_ID);
    setRebookedIds(newIds);
    saveRebookedIds(newIds);
    setRebookingId(null);
  }

  function clearRebookedHistory() {
    setRebookedIds(new Set());
    if (typeof window !== "undefined") {
      localStorage.removeItem(STORAGE_KEY);
    }
  }

  const uniquePassengers = data.filter((r) => r.OPTION_RANK === 1);
  
  const tierCounts = uniquePassengers.reduce((acc, r) => {
    if (!rebookedIds.has(r.BOOKING_ID)) {
      acc[r.LOYALTY_TIER] = (acc[r.LOYALTY_TIER] || 0) + 1;
    }
    return acc;
  }, {} as Record<string, number>);

  const totalPassengers = uniquePassengers.length;
  const elitePassengers = uniquePassengers.filter((r) => 
    r.LOYALTY_TIER === "DIAMOND" || r.LOYALTY_TIER === "PLATINUM"
  ).length;
  const rebookedCount = rebookedIds.size;
  const pendingCount = totalPassengers - rebookedCount;

  const filteredData = uniquePassengers
    .filter((r) => filter === "all" || r.LOYALTY_TIER === "DIAMOND" || r.LOYALTY_TIER === "PLATINUM")
    .filter((r) => !rebookedIds.has(r.BOOKING_ID))
    .sort((a, b) => {
      const aPriority = TIER_CONFIG[a.LOYALTY_TIER]?.priority || 99;
      const bPriority = TIER_CONFIG[b.LOYALTY_TIER]?.priority || 99;
      return aPriority - bPriority;
    });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-3">
            <Users className="h-7 w-7 text-phantom-primary" />
            Passenger Rebooking
          </h1>
          <p className="text-slate-500 mt-1">Priority rebooking for passengers on cancelled flights</p>
        </div>
        <div className="flex gap-2">
          {rebookedIds.size > 0 && (
            <button
              onClick={clearRebookedHistory}
              className="flex items-center gap-2 px-4 py-2 bg-amber-100 hover:bg-amber-200 text-amber-700 rounded-lg transition text-sm"
            >
              Reset Demo
            </button>
          )}
          <button
            onClick={fetchRebookingData}
            className="flex items-center gap-2 px-4 py-2 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </button>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <div className="bg-white rounded-xl p-4 shadow-sm border">
          <p className="text-sm text-slate-500">Passengers Needing Rebooking</p>
          <p className="text-3xl font-bold text-slate-800">{totalPassengers}</p>
        </div>
        <div className="bg-purple-50 rounded-xl p-4 shadow-sm border border-purple-200">
          <p className="text-sm text-purple-600">Elite Members (Priority)</p>
          <p className="text-3xl font-bold text-purple-700">{elitePassengers}</p>
        </div>
        <div className="bg-green-50 rounded-xl p-4 shadow-sm border border-green-200">
          <p className="text-sm text-green-600">Successfully Rebooked</p>
          <p className="text-3xl font-bold text-green-700">{rebookedCount}</p>
        </div>
        <div className="bg-amber-50 rounded-xl p-4 shadow-sm border border-amber-200">
          <p className="text-sm text-amber-600">Pending</p>
          <p className="text-3xl font-bold text-amber-700">{pendingCount}</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border">
        <div className="p-4 border-b flex items-center justify-between">
          <div className="flex items-center gap-4">
            <h2 className="font-semibold text-slate-800">Priority Queue</h2>
            <div className="flex gap-2">
              {["DIAMOND", "PLATINUM", "GOLD", "SILVER", "BLUE"].map((tier) => {
                const config = TIER_CONFIG[tier];
                const count = tierCounts[tier] || 0;
                return (
                  <span
                    key={tier}
                    className={`px-2 py-1 rounded text-xs font-medium ${config?.bg} ${config?.color}`}
                  >
                    {tier}: {count}
                  </span>
                );
              })}
            </div>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setFilter("elite")}
              className={`px-3 py-1.5 rounded text-sm font-medium transition ${
                filter === "elite" ? "bg-purple-600 text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              Elite Only
            </button>
            <button
              onClick={() => setFilter("all")}
              className={`px-3 py-1.5 rounded text-sm font-medium transition ${
                filter === "all" ? "bg-phantom-primary text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              All Passengers
            </button>
          </div>
        </div>

        {loading ? (
          <div className="p-12 text-center">
            <Loader2 className="h-8 w-8 animate-spin text-phantom-primary mx-auto" />
            <p className="text-slate-500 mt-2">Loading rebooking options...</p>
          </div>
        ) : filteredData.length === 0 ? (
          <div className="p-12 text-center">
            <CheckCircle2 className="h-12 w-12 text-green-500 mx-auto" />
            <p className="text-lg font-medium text-slate-700 mt-2">All passengers rebooked!</p>
            <p className="text-slate-500">No pending rebookings in this queue</p>
          </div>
        ) : (
          <div className="divide-y max-h-[500px] overflow-y-auto">
            {filteredData.slice(0, 20).map((booking, idx) => {
              const tierConfig = TIER_CONFIG[booking.LOYALTY_TIER] || TIER_CONFIG.BLUE;
              const isRebooking = rebookingId === booking.BOOKING_ID;
              
              return (
                <div
                  key={booking.BOOKING_ID}
                  className={`p-4 flex items-center justify-between hover:bg-slate-50 transition ${
                    idx === 0 ? "bg-purple-50/50" : ""
                  }`}
                >
                  <div className="flex items-center gap-4">
                    <div className="text-center w-8">
                      <span className="text-lg font-bold text-slate-400">#{idx + 1}</span>
                    </div>
                    <div className={`px-2 py-1 rounded flex items-center gap-1 ${tierConfig.bg} ${tierConfig.color}`}>
                      {tierConfig.icon}
                      <span className="text-xs font-semibold">{booking.LOYALTY_TIER}</span>
                    </div>
                    <div>
                      <p className="font-medium text-slate-800">
                        {booking.FIRST_NAME} {booking.LAST_NAME}
                      </p>
                      <p className="text-sm text-slate-500">{booking.CONFIRMATION_CODE}</p>
                    </div>
                  </div>

                  <div className="flex items-center gap-6">
                    <div className="text-center">
                      <p className="text-xs text-slate-500">Original</p>
                      <p className="font-medium text-red-600 line-through">{booking.ORIGINAL_FLIGHT_NUMBER}</p>
                      <p className="text-xs text-slate-500">{booking.ORIGINAL_STATUS}</p>
                    </div>
                    <ArrowRight className="h-4 w-4 text-slate-400" />
                    <div className="text-center">
                      <p className="text-xs text-slate-500">New Flight</p>
                      <p className="font-medium text-green-600">{booking.REBOOK_FLIGHT_NUMBER}</p>
                      <p className="text-xs text-slate-500">{formatTime(booking.REBOOK_DEPARTURE)}</p>
                    </div>
                    <div className="text-center px-3 py-1 bg-slate-100 rounded">
                      <p className="text-xs text-slate-500">Route</p>
                      <p className="font-medium text-slate-700">{booking.ORIGIN} → {booking.DESTINATION}</p>
                    </div>
                    <div className="text-center">
                      <p className="text-xs text-slate-500">Wait</p>
                      <p className="font-medium text-amber-600">{formatMinutes(booking.MINUTES_AFTER_ORIGINAL)}</p>
                    </div>
                    <div className="text-center">
                      <p className="text-xs text-slate-500">Seats</p>
                      <p className={`font-medium ${booking.AVAILABLE_SEATS < 10 ? "text-red-600" : "text-green-600"}`}>
                        {booking.AVAILABLE_SEATS}
                      </p>
                    </div>
                    <button
                      onClick={() => handleRebook(booking)}
                      disabled={isRebooking}
                      className={`px-4 py-2 rounded-lg font-medium transition flex items-center gap-2 ${
                        isRebooking
                          ? "bg-slate-200 text-slate-500 cursor-not-allowed"
                          : "bg-green-600 text-white hover:bg-green-700"
                      }`}
                    >
                      {isRebooking ? (
                        <>
                          <Loader2 className="h-4 w-4 animate-spin" />
                          Rebooking...
                        </>
                      ) : (
                        <>
                          <CheckCircle2 className="h-4 w-4" />
                          Rebook
                        </>
                      )}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {filteredData.length > 20 && (
          <div className="p-3 bg-slate-50 text-center text-sm text-slate-500 border-t">
            Showing 20 of {filteredData.length} passengers
          </div>
        )}
      </div>

      <div className="bg-gradient-to-r from-purple-600 to-phantom-primary rounded-xl p-6 text-white">
        <h3 className="text-lg font-semibold mb-2">Rebooking Priority Algorithm</h3>
        <div className="grid grid-cols-5 gap-4 mt-4">
          {[
            { tier: "DIAMOND", desc: "First priority, best options" },
            { tier: "PLATINUM", desc: "Second priority" },
            { tier: "GOLD", desc: "Third priority" },
            { tier: "SILVER", desc: "Fourth priority" },
            { tier: "BLUE", desc: "Standard queue" },
          ].map((item, idx) => (
            <div key={item.tier} className="text-center">
              <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center mx-auto text-lg font-bold">
                {idx + 1}
              </div>
              <p className="font-semibold mt-2">{item.tier}</p>
              <p className="text-xs text-white/70">{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
