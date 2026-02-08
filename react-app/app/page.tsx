"use client";

import { useState, useEffect, useCallback } from "react";
import { Plane, Users, Ghost, AlertTriangle, Activity, MessageSquare, FileWarning, FileText, Menu, X, Zap, UserCheck } from "lucide-react";
import OperationsDashboard from "@/components/OperationsDashboard";
import CrewRecovery from "@/components/CrewRecovery";
import GhostPlanes from "@/components/GhostPlanes";
import AgentChat from "@/components/AgentChat";
import DisruptionAnalysis from "@/components/DisruptionAnalysis";
import ContractBot from "@/components/ContractBot";
import Sidebar from "@/components/Sidebar";
import SnowflakeIntelligence from "@/components/SnowflakeIntelligence";
import PassengerRebooking from "@/components/PassengerRebooking";
import CrowdStrikeScenario from "@/components/CrowdStrikeScenario";
import { NotificationToast, useNotifications, NotificationDemo } from "@/components/NotificationSystem";

type TabId = "dashboard" | "crew" | "ghost" | "disruptions" | "contract" | "assistant" | "intelligence" | "rebooking" | "scenario";

interface SidebarFilters {
  hub: string;
  status: string;
  timeRange: string;
}

const tabs = [
  { id: "dashboard" as TabId, label: "Operations", icon: Activity },
  { id: "crew" as TabId, label: "Crew Recovery", icon: Users },
  { id: "rebooking" as TabId, label: "Rebooking", icon: UserCheck },
  { id: "ghost" as TabId, label: "Ghost Planes", icon: Ghost },
  { id: "disruptions" as TabId, label: "Disruptions", icon: FileWarning },
  { id: "contract" as TabId, label: "Contract Bot", icon: FileText },
  { id: "scenario" as TabId, label: "Scenario", icon: Zap },
  { id: "assistant" as TabId, label: "AI Assistant", icon: MessageSquare },
];

export default function Home() {
  const [activeTab, setActiveTab] = useState<TabId>("dashboard");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [filters, setFilters] = useState<SidebarFilters>({
    hub: "ALL",
    status: "ALL",
    timeRange: "today",
  });
  const [quickStats, setQuickStats] = useState<{ flights: number; otp: number | null; crew: number } | undefined>();
  const [hubStats, setHubStats] = useState<Array<{ ORIGIN: string; FLIGHT_COUNT: number; DELAYED_COUNT: number; AVG_DELAY: number }> | undefined>();
  const { notifications, addNotification, dismissNotification } = useNotifications();

  const fetchQuickStats = useCallback(async (timeRange: string) => {
    try {
      const res = await fetch(`/api/data?timeRange=${timeRange}`);
      if (res.ok) {
        const json = await res.json();
        if (json.summary) {
          const operatedFlights = json.summary.ON_TIME_FLIGHTS + json.summary.DELAYED_FLIGHTS;
          const otp = operatedFlights > 0
            ? (json.summary.ON_TIME_FLIGHTS / operatedFlights) * 100
            : null;
          setQuickStats({
            flights: json.summary.TOTAL_FLIGHTS,
            otp,
            crew: 847,
          });
        }
        if (json.hubStats) {
          setHubStats(json.hubStats);
        }
      }
    } catch {}
  }, []);

  useEffect(() => {
    fetchQuickStats(filters.timeRange);
  }, [filters.timeRange, fetchQuickStats]);

  return (
    <div className="min-h-screen flex">
      {sidebarOpen && (
        <Sidebar
          activeTab={activeTab}
          onTabChange={(tab) => setActiveTab(tab as TabId)}
          filters={filters}
          onFiltersChange={setFilters}
          quickStats={quickStats}
          hubStats={hubStats}
        />
      )}

      <div className="flex-1 flex flex-col">
        <header className="bg-phantom-dark text-white px-6 py-4 shadow-lg">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <button
                onClick={() => setSidebarOpen(!sidebarOpen)}
                className="p-2 hover:bg-white/10 rounded-lg transition"
              >
                {sidebarOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
              </button>
              {!sidebarOpen && (
                <div className="flex items-center gap-3">
                  <Plane className="h-8 w-8 text-phantom-primary" />
                  <div>
                    <h1 className="text-xl font-bold">Phantom Airlines</h1>
                    <p className="text-sm text-slate-300">IROPS Command Center</p>
                  </div>
                </div>
              )}
              <div className="text-sm text-slate-300">
                <span className="font-medium text-white">{tabs.find(t => t.id === activeTab)?.label}</span>
                {filters.timeRange !== "today" && (
                  <span className="ml-2 px-2 py-0.5 bg-phantom-primary/30 rounded text-xs">
                    {filters.timeRange === "last7days" ? "Last 7 Days" : 
                     filters.timeRange === "next2hours" ? "Next 2 Hours" :
                     filters.timeRange === "next6hours" ? "Next 6 Hours" : "Tomorrow"}
                  </span>
                )}
              </div>
            </div>
            <button
              onClick={() => setActiveTab("disruptions")}
              className="flex items-center gap-2 bg-red-500/20 px-4 py-2 rounded-lg hover:bg-red-500/30 transition cursor-pointer"
            >
              <AlertTriangle className="h-5 w-5 text-red-400" />
              <span className="text-sm font-medium">Active Disruptions</span>
            </button>
          </div>
        </header>

        {!sidebarOpen && (
          <nav className="bg-white border-b shadow-sm sticky top-0 z-10">
            <div className="px-6">
              <div className="flex gap-1">
                {tabs.map((tab) => {
                  const Icon = tab.icon;
                  return (
                    <button
                      key={tab.id}
                      onClick={() => setActiveTab(tab.id)}
                      className={`flex items-center gap-2 px-4 py-3 text-sm font-medium transition-colors border-b-2 ${
                        activeTab === tab.id
                          ? "border-phantom-primary text-phantom-primary bg-phantom-light/50"
                          : "border-transparent text-slate-600 hover:text-phantom-dark hover:bg-slate-50"
                      }`}
                    >
                      <Icon className="h-4 w-4" />
                      {tab.label}
                    </button>
                  );
                })}
              </div>
            </div>
          </nav>
        )}

        <main className="flex-1 px-6 py-6 bg-slate-50 overflow-y-auto">
          {activeTab === "dashboard" && (
            <OperationsDashboard 
              sidebarFilters={filters}
              onFiltersChange={setFilters}
            />
          )}
          {activeTab === "crew" && <CrewRecovery />}
          {activeTab === "ghost" && <GhostPlanes />}
          {activeTab === "disruptions" && <DisruptionAnalysis />}
          {activeTab === "contract" && <ContractBot />}
          {activeTab === "assistant" && <AgentChat />}
          {activeTab === "intelligence" && <SnowflakeIntelligence />}
          {activeTab === "rebooking" && <PassengerRebooking />}
          {activeTab === "scenario" && <CrowdStrikeScenario />}
          
          {activeTab === "dashboard" && (
            <div className="mt-6">
              <NotificationDemo onNotify={addNotification} />
            </div>
          )}
        </main>
      </div>
      
      <NotificationToast notifications={notifications} onDismiss={dismissNotification} />
    </div>
  );
}
