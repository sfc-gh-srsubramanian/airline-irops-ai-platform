"use client";

import { Plane, BarChart2, Users, Ghost, AlertTriangle, FileText, Bot, Activity, ChevronRight, Sparkles, UserCheck, Zap } from "lucide-react";

interface SidebarFilters {
  hub: string;
  status: string;
  timeRange: string;
}

interface HubStat {
  ORIGIN: string;
  FLIGHT_COUNT: number;
  DELAYED_COUNT: number;
  AVG_DELAY: number;
}

interface SidebarProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
  filters: SidebarFilters;
  onFiltersChange: (filters: SidebarFilters) => void;
  quickStats?: {
    flights: number;
    otp: number | null;
    crew: number;
  };
  hubStats?: HubStat[];
}

const NAV_ITEMS = [
  { id: "dashboard", label: "Operations Dashboard", icon: BarChart2 },
  { id: "intelligence", label: "AI Assistant", icon: Sparkles },
  { id: "crew", label: "Crew Recovery", icon: Users },
  { id: "rebooking", label: "Passenger Rebooking", icon: UserCheck },
  { id: "ghost", label: "Ghost Planes", icon: Ghost },
  { id: "disruptions", label: "Disruption Analysis", icon: AlertTriangle },
  { id: "contract", label: "Contract Bot", icon: FileText },
  { id: "scenario", label: "CrowdStrike Scenario", icon: Zap },
];

const DEFAULT_HUBS = ["ATL", "DTW", "MSP", "SLC", "SEA", "LAX", "JFK", "BOS"];

function getHubStatus(delayedCount: number, flightCount: number): "normal" | "warning" | "critical" {
  if (flightCount === 0) return "normal";
  const rate = delayedCount / flightCount;
  if (rate > 0.3) return "critical";
  if (rate > 0.15) return "warning";
  return "normal";
}

const TIME_RANGE_OPTIONS = [
  { value: "next2hours", label: "Next 2 Hours" },
  { value: "next6hours", label: "Next 6 Hours" },
  { value: "today", label: "Today" },
  { value: "tomorrow", label: "Tomorrow" },
  { value: "last7days", label: "Last 7 Days" },
];

export default function Sidebar({ activeTab, onTabChange, filters, onFiltersChange, quickStats, hubStats }: SidebarProps) {
  const hubStatusData = DEFAULT_HUBS.map(code => {
    const stat = hubStats?.find(h => h.ORIGIN === code);
    return {
      code,
      status: stat ? getHubStatus(stat.DELAYED_COUNT, stat.FLIGHT_COUNT) : "normal"
    };
  });
  return (
    <aside className="w-64 bg-white border-r min-h-screen">
      <div className="p-4 border-b">
        <div className="flex items-center gap-2">
          <div className="bg-gradient-to-r from-phantom-dark to-phantom-primary p-2 rounded-lg">
            <Plane className="h-5 w-5 text-white" />
          </div>
          <div>
            <h1 className="font-bold text-phantom-dark text-sm">Phantom Airlines</h1>
            <p className="text-xs text-slate-500">IROPS Platform</p>
          </div>
        </div>
      </div>

      <nav className="p-3">
        <div className="space-y-1">
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => onTabChange(item.id)}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition ${
                  isActive
                    ? "bg-gradient-to-r from-phantom-dark to-phantom-primary text-white"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                <Icon className="h-4 w-4" />
                {item.label}
                {isActive && <ChevronRight className="h-4 w-4 ml-auto" />}
              </button>
            );
          })}
        </div>
      </nav>

      <div className="p-4 border-t">
        <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Quick Stats</h3>
        <div className="grid grid-cols-3 gap-2">
          <div className="text-center">
            <p className="text-lg font-bold text-phantom-dark">{quickStats?.flights?.toLocaleString() || "1,423"}</p>
            <p className="text-xs text-slate-500">Flights</p>
          </div>
          <div className="text-center">
            <p className={`text-lg font-bold ${quickStats?.otp === null ? "text-slate-400" : "text-green-600"}`}>
              {quickStats?.otp === null ? "N/A" : `${(quickStats?.otp ?? 82.4).toFixed(1)}%`}
            </p>
            <p className="text-xs text-slate-500">OTP</p>
          </div>
          <div className="text-center">
            <p className="text-lg font-bold text-phantom-dark">{quickStats?.crew || "847"}</p>
            <p className="text-xs text-slate-500">Crew</p>
          </div>
        </div>
      </div>

      <div className="p-4 border-t">
        <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Filters</h3>
        <div className="space-y-3">
          <div>
            <label className="block text-xs text-slate-500 mb-1">Time Range</label>
            <select
              value={filters.timeRange}
              onChange={(e) => onFiltersChange({ ...filters, timeRange: e.target.value })}
              className="w-full px-2 py-1.5 border rounded text-sm bg-slate-50"
            >
              {TIME_RANGE_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-xs text-slate-500 mb-1">Hub</label>
            <select
              value={filters.hub}
              onChange={(e) => onFiltersChange({ ...filters, hub: e.target.value })}
              className="w-full px-2 py-1.5 border rounded text-sm bg-slate-50"
            >
              <option value="ALL">All Hubs</option>
              {hubStatusData.map((h) => (
                <option key={h.code} value={h.code}>{h.code}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-xs text-slate-500 mb-1">Status</label>
            <select
              value={filters.status}
              onChange={(e) => onFiltersChange({ ...filters, status: e.target.value })}
              className="w-full px-2 py-1.5 border rounded text-sm bg-slate-50"
            >
              <option value="ALL">All Statuses</option>
              <option value="CRITICAL">Critical</option>
              <option value="WARNING">Warning</option>
              <option value="NORMAL">Normal</option>
            </select>
          </div>
        </div>
      </div>

      <div className="p-4 border-t">
        <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Hub Status</h3>
        <div className="grid grid-cols-4 gap-1">
          {hubStatusData.map((hub) => (
            <div
              key={hub.code}
              className={`text-center py-1 px-1.5 rounded text-xs font-medium ${
                hub.status === "critical"
                  ? "bg-red-100 text-red-700"
                  : hub.status === "warning"
                  ? "bg-amber-100 text-amber-700"
                  : "bg-green-100 text-green-700"
              }`}
            >
              {hub.status === "critical" ? "🔴" : hub.status === "warning" ? "🟡" : "🟢"} {hub.code}
            </div>
          ))}
        </div>
      </div>
    </aside>
  );
}
