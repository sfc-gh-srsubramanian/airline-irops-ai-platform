"use client";

import { useState, useEffect, useRef } from "react";
import { Play, Pause, RotateCcw, Clock, Users, Phone, Zap, AlertTriangle, CheckCircle2, TrendingDown, DollarSign } from "lucide-react";

interface TimelineEvent {
  time: string;
  legacy: string;
  platform: string;
  legacyStatus: "pending" | "active" | "complete";
  platformStatus: "pending" | "active" | "complete";
}

const TIMELINE_EVENTS: TimelineEvent[] = [
  { time: "0:00", legacy: "Disruption detected", platform: "Disruption detected", legacyStatus: "complete", platformStatus: "complete" },
  { time: "0:01", legacy: "Manual assessment begins", platform: "AI auto-detects 847 affected flights", legacyStatus: "active", platformStatus: "complete" },
  { time: "0:02", legacy: "Reviewing spreadsheets...", platform: "ML ranks 2,400 crew candidates", legacyStatus: "active", platformStatus: "complete" },
  { time: "0:05", legacy: "Still assessing impact...", platform: "Batch notifications sent to all candidates", legacyStatus: "active", platformStatus: "complete" },
  { time: "0:15", legacy: "First phone call started", platform: "94% of flights have crew assigned", legacyStatus: "active", platformStatus: "complete" },
  { time: "0:27", legacy: "Pilot 1 responded (12 min)", platform: "Recovery complete - all flights covered", legacyStatus: "active", platformStatus: "complete" },
  { time: "0:39", legacy: "Pilot 2 responded", platform: "Passengers rebooked, notifications sent", legacyStatus: "active", platformStatus: "complete" },
  { time: "1:00", legacy: "5 pilots contacted...", platform: "Operations normalized", legacyStatus: "active", platformStatus: "complete" },
  { time: "4:00", legacy: "Still calling pilots sequentially", platform: "—", legacyStatus: "active", platformStatus: "complete" },
  { time: "12:00", legacy: "Recovery 40% complete", platform: "—", legacyStatus: "active", platformStatus: "complete" },
  { time: "48:00", legacy: "Full recovery achieved", platform: "—", legacyStatus: "complete", platformStatus: "complete" },
];

export default function CrowdStrikeScenario() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [showStats, setShowStats] = useState(false);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (isPlaying && currentStep < TIMELINE_EVENTS.length - 1) {
      intervalRef.current = setTimeout(() => {
        setCurrentStep((prev) => prev + 1);
      }, 1500);
    } else if (currentStep >= TIMELINE_EVENTS.length - 1) {
      setIsPlaying(false);
      setShowStats(true);
    }
    return () => {
      if (intervalRef.current) clearTimeout(intervalRef.current);
    };
  }, [isPlaying, currentStep]);

  const reset = () => {
    setIsPlaying(false);
    setCurrentStep(0);
    setShowStats(false);
  };

  const togglePlay = () => {
    if (currentStep >= TIMELINE_EVENTS.length - 1) {
      reset();
      setTimeout(() => setIsPlaying(true), 100);
    } else {
      setIsPlaying(!isPlaying);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-3">
            <AlertTriangle className="h-7 w-7 text-red-500" />
            CrowdStrike-Scale Scenario Simulation
          </h1>
          <p className="text-slate-500 mt-1">
            Compare recovery times: Legacy sequential calling vs. AI-powered platform
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={togglePlay}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition ${
              isPlaying ? "bg-amber-500 text-white" : "bg-green-600 text-white hover:bg-green-700"
            }`}
          >
            {isPlaying ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
            {isPlaying ? "Pause" : currentStep > 0 ? "Resume" : "Start Simulation"}
          </button>
          <button
            onClick={reset}
            className="flex items-center gap-2 px-4 py-2 bg-slate-200 hover:bg-slate-300 rounded-lg transition"
          >
            <RotateCcw className="h-4 w-4" />
            Reset
          </button>
        </div>
      </div>

      <div className="bg-gradient-to-r from-red-600 to-red-800 rounded-xl p-6 text-white">
        <h2 className="text-lg font-semibold mb-2">Scenario: July 2024 CrowdStrike-Scale Event</h2>
        <div className="grid grid-cols-4 gap-4 mt-4">
          <div className="text-center">
            <p className="text-3xl font-bold">5,000+</p>
            <p className="text-sm text-red-200">Flights Disrupted</p>
          </div>
          <div className="text-center">
            <p className="text-3xl font-bold">847</p>
            <p className="text-sm text-red-200">Needing Crew Recovery</p>
          </div>
          <div className="text-center">
            <p className="text-3xl font-bold">2,400</p>
            <p className="text-sm text-red-200">Available Crew</p>
          </div>
          <div className="text-center">
            <p className="text-3xl font-bold">180K</p>
            <p className="text-sm text-red-200">Passengers Affected</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-6">
        <div className="bg-white rounded-xl shadow-sm border overflow-hidden">
          <div className="bg-slate-700 text-white px-4 py-3 flex items-center gap-2">
            <Phone className="h-5 w-5" />
            <span className="font-semibold">Legacy System</span>
            <span className="ml-auto text-sm text-slate-300">Sequential Phone Calls</span>
          </div>
          <div className="p-4">
            <div className="space-y-3">
              {TIMELINE_EVENTS.slice(0, currentStep + 1).map((event, idx) => (
                <div
                  key={idx}
                  className={`flex items-center gap-3 p-2 rounded transition ${
                    idx === currentStep ? "bg-red-50 border border-red-200" : ""
                  }`}
                >
                  <div className="w-16 text-sm font-mono text-slate-500">{event.time}</div>
                  <div
                    className={`w-3 h-3 rounded-full ${
                      idx < currentStep
                        ? "bg-slate-400"
                        : idx === currentStep
                        ? "bg-red-500 animate-pulse"
                        : "bg-slate-200"
                    }`}
                  />
                  <div className={`text-sm ${idx === currentStep ? "font-medium text-red-700" : "text-slate-600"}`}>
                    {event.legacy}
                  </div>
                </div>
              ))}
            </div>
            {showStats && (
              <div className="mt-4 p-4 bg-red-50 rounded-lg border border-red-200">
                <p className="text-2xl font-bold text-red-700">48+ Hours</p>
                <p className="text-sm text-red-600">Total Recovery Time</p>
              </div>
            )}
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm border overflow-hidden">
          <div className="bg-gradient-to-r from-phantom-dark to-phantom-primary text-white px-4 py-3 flex items-center gap-2">
            <Zap className="h-5 w-5" />
            <span className="font-semibold">AI-Powered Platform</span>
            <span className="ml-auto text-sm text-cyan-200">ML Batch Recovery</span>
          </div>
          <div className="p-4">
            <div className="space-y-3">
              {TIMELINE_EVENTS.slice(0, Math.min(currentStep + 1, 8)).map((event, idx) => (
                <div
                  key={idx}
                  className={`flex items-center gap-3 p-2 rounded transition ${
                    idx === Math.min(currentStep, 7) && currentStep < 8 ? "bg-green-50 border border-green-200" : ""
                  }`}
                >
                  <div className="w-16 text-sm font-mono text-slate-500">{event.time}</div>
                  <div
                    className={`w-3 h-3 rounded-full ${
                      idx < Math.min(currentStep, 7) || currentStep >= 7
                        ? "bg-green-500"
                        : idx === currentStep
                        ? "bg-green-500 animate-pulse"
                        : "bg-slate-200"
                    }`}
                  />
                  <div
                    className={`text-sm ${
                      idx === Math.min(currentStep, 7) && currentStep < 8 ? "font-medium text-green-700" : "text-slate-600"
                    }`}
                  >
                    {event.platform !== "—" ? event.platform : ""}
                  </div>
                  {idx < 8 && currentStep >= idx && (
                    <CheckCircle2 className="h-4 w-4 text-green-500 ml-auto" />
                  )}
                </div>
              ))}
            </div>
            {(currentStep >= 7 || showStats) && (
              <div className="mt-4 p-4 bg-green-50 rounded-lg border border-green-200">
                <p className="text-2xl font-bold text-green-700">27 Minutes</p>
                <p className="text-sm text-green-600">Total Recovery Time</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {showStats && (
        <div className="bg-gradient-to-r from-green-600 to-emerald-600 rounded-xl p-6 text-white">
          <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
            <TrendingDown className="h-6 w-6" />
            Impact Summary
          </h3>
          <div className="grid grid-cols-4 gap-6">
            <div className="text-center bg-white/10 rounded-lg p-4">
              <p className="text-4xl font-bold">94%</p>
              <p className="text-sm text-green-200">Faster Recovery</p>
              <p className="text-xs text-green-300 mt-1">48 hrs → 27 min</p>
            </div>
            <div className="text-center bg-white/10 rounded-lg p-4">
              <p className="text-4xl font-bold">$42M</p>
              <p className="text-sm text-green-200">Cost Avoided</p>
              <p className="text-xs text-green-300 mt-1">Passenger compensation</p>
            </div>
            <div className="text-center bg-white/10 rounded-lg p-4">
              <p className="text-4xl font-bold">4,200</p>
              <p className="text-sm text-green-200">Flights Saved</p>
              <p className="text-xs text-green-300 mt-1">From cancellation</p>
            </div>
            <div className="text-center bg-white/10 rounded-lg p-4">
              <p className="text-4xl font-bold">168K</p>
              <p className="text-sm text-green-200">Passengers Protected</p>
              <p className="text-xs text-green-300 mt-1">Reached destinations</p>
            </div>
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl shadow-sm border p-6">
        <h3 className="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2">
          <Clock className="h-5 w-5 text-phantom-primary" />
          The "12-Minute Problem" Explained
        </h3>
        <div className="grid grid-cols-2 gap-8">
          <div>
            <h4 className="font-medium text-red-700 mb-2">Legacy Sequential Calling</h4>
            <ul className="space-y-2 text-sm text-slate-600">
              <li className="flex items-start gap-2">
                <span className="text-red-500 mt-1">●</span>
                Each pilot gets 12 minutes to accept/decline
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-500 mt-1">●</span>
                200 pilots × 12 minutes = 40 hours minimum
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-500 mt-1">●</span>
                No parallel processing possible
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-500 mt-1">●</span>
                First call might be to least qualified pilot
              </li>
            </ul>
          </div>
          <div>
            <h4 className="font-medium text-green-700 mb-2">ML-Powered Batch Recovery</h4>
            <ul className="space-y-2 text-sm text-slate-600">
              <li className="flex items-start gap-2">
                <span className="text-green-500 mt-1">●</span>
                ML ranks all candidates by fit score instantly
              </li>
              <li className="flex items-start gap-2">
                <span className="text-green-500 mt-1">●</span>
                Batch notify top 20 candidates simultaneously
              </li>
              <li className="flex items-start gap-2">
                <span className="text-green-500 mt-1">●</span>
                First responder wins - parallel competition
              </li>
              <li className="flex items-start gap-2">
                <span className="text-green-500 mt-1">●</span>
                Contract validation in milliseconds
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
