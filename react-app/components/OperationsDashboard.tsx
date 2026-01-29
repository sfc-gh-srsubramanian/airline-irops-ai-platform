"use client";

import { useEffect, useState, useCallback } from "react";
import { Plane, Clock, Users, AlertTriangle, TrendingUp, Filter, Loader2, PlayCircle } from "lucide-react";
import InfoTooltip from "./InfoTooltip";
import { PAGE_HELP } from "@/lib/pageHelp";
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from "recharts";

interface OperationsData {
  summary: {
    TOTAL_FLIGHTS: number;
    DELAYED_FLIGHTS: number;
    CANCELLED_FLIGHTS: number;
    ON_TIME_FLIGHTS: number;
    IN_PROGRESS_FLIGHTS: number;
    TOTAL_PASSENGERS_AFFECTED: number;
    AVG_DELAY_MINUTES: number;
  };
  hubStats: Array<{
    ORIGIN: string;
    FLIGHT_COUNT: number;
    DELAYED_COUNT: number;
    AVG_DELAY: number;
  }>;
  otpTrend: Array<{
    DATE_LABEL: string;
    OTP: number;
    FLIGHTS: number;
  }>;
  timeRange: string;
}

interface SidebarFilters {
  hub: string;
  status: string;
  timeRange: string;
}

const CHART_COLORS = ["#29B5E8", "#1E3A5F", "#0D47A1", "#4CAF50", "#FF9800", "#E91E63"];

const mockOtpTrendToday = [
  { DATE_LABEL: "06:00", OTP: 94, FLIGHTS: 45 },
  { DATE_LABEL: "08:00", OTP: 89, FLIGHTS: 78 },
  { DATE_LABEL: "10:00", OTP: 85, FLIGHTS: 92 },
  { DATE_LABEL: "12:00", OTP: 78, FLIGHTS: 105 },
  { DATE_LABEL: "14:00", OTP: 72, FLIGHTS: 98 },
  { DATE_LABEL: "16:00", OTP: 68, FLIGHTS: 87 },
  { DATE_LABEL: "18:00", OTP: 71, FLIGHTS: 75 },
  { DATE_LABEL: "20:00", OTP: 82, FLIGHTS: 52 },
];

const mockOtpTrend7Days = [
  { DATE_LABEL: "01/21", OTP: 84.2, FLIGHTS: 1423 },
  { DATE_LABEL: "01/22", OTP: 82.1, FLIGHTS: 1456 },
  { DATE_LABEL: "01/23", OTP: 79.8, FLIGHTS: 1389 },
  { DATE_LABEL: "01/24", OTP: 81.5, FLIGHTS: 1412 },
  { DATE_LABEL: "01/25", OTP: 83.2, FLIGHTS: 1478 },
  { DATE_LABEL: "01/26", OTP: 85.6, FLIGHTS: 1501 },
  { DATE_LABEL: "01/27", OTP: 82.4, FLIGHTS: 1445 },
];

const delayDistribution = [
  { reason: "Weather", count: 45, percentage: 35 },
  { reason: "ATC", count: 28, percentage: 22 },
  { reason: "Mechanical", count: 22, percentage: 17 },
  { reason: "Crew", count: 18, percentage: 14 },
  { reason: "Ground Ops", count: 15, percentage: 12 },
];

const TIME_RANGE_OPTIONS = [
  { value: "next2hours", label: "Next 2 Hours" },
  { value: "next6hours", label: "Next 6 Hours" },
  { value: "today", label: "Today" },
  { value: "tomorrow", label: "Tomorrow" },
  { value: "last7days", label: "Last 7 Days" },
];

interface OperationsDashboardProps {
  sidebarFilters?: SidebarFilters;
  onFiltersChange?: (filters: SidebarFilters) => void;
}

export default function OperationsDashboard({ sidebarFilters, onFiltersChange }: OperationsDashboardProps) {
  const [data, setData] = useState<OperationsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  
  const filters = sidebarFilters || { hub: "ALL", status: "ALL", timeRange: "today" };

  const fetchData = useCallback(async (timeRange: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/data?timeRange=${timeRange}`);
      if (!res.ok) throw new Error("Failed to fetch");
      const json = await res.json();
      if (json.error) throw new Error(json.error);
      setData(json);
    } catch (err) {
      console.warn("API fetch failed, using mock data:", err);
      setData({
        summary: {
          TOTAL_FLIGHTS: 1423,
          DELAYED_FLIGHTS: 156,
          CANCELLED_FLIGHTS: 34,
          ON_TIME_FLIGHTS: 1172,
          IN_PROGRESS_FLIGHTS: 61,
          TOTAL_PASSENGERS_AFFECTED: 4500,
          AVG_DELAY_MINUTES: 34,
        },
        hubStats: [
          { ORIGIN: "ATL", FLIGHT_COUNT: 342, DELAYED_COUNT: 45, AVG_DELAY: 28 },
          { ORIGIN: "DTW", FLIGHT_COUNT: 156, DELAYED_COUNT: 23, AVG_DELAY: 22 },
          { ORIGIN: "MSP", FLIGHT_COUNT: 134, DELAYED_COUNT: 28, AVG_DELAY: 35 },
          { ORIGIN: "JFK", FLIGHT_COUNT: 203, DELAYED_COUNT: 32, AVG_DELAY: 31 },
          { ORIGIN: "LAX", FLIGHT_COUNT: 187, DELAYED_COUNT: 18, AVG_DELAY: 19 },
          { ORIGIN: "SLC", FLIGHT_COUNT: 98, DELAYED_COUNT: 5, AVG_DELAY: 12 },
          { ORIGIN: "SEA", FLIGHT_COUNT: 112, DELAYED_COUNT: 8, AVG_DELAY: 15 },
          { ORIGIN: "BOS", FLIGHT_COUNT: 89, DELAYED_COUNT: 4, AVG_DELAY: 11 },
        ],
        otpTrend: timeRange === "last7days" ? mockOtpTrend7Days : mockOtpTrendToday,
        timeRange,
      });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData(filters.timeRange);
  }, [filters.timeRange, fetchData]);

  const handleFilterChange = (key: keyof SidebarFilters, value: string) => {
    const newFilters = { ...filters, [key]: value };
    onFiltersChange?.(newFilters);
  };

  if (loading) {
    return (
      <div className="animate-pulse space-y-6">
        <div className="grid grid-cols-5 gap-4">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="h-32 bg-slate-200 rounded-xl" />
          ))}
        </div>
        <div className="h-64 bg-slate-200 rounded-xl" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-red-700">
        <AlertTriangle className="h-6 w-6 mb-2" />
        <p>Error loading operations data: {error}</p>
      </div>
    );
  }

  const { summary, hubStats, otpTrend } = data!;
  const operatedFlights = summary.ON_TIME_FLIGHTS + summary.DELAYED_FLIGHTS;
  const onTimeRate = operatedFlights > 0 
    ? ((summary.ON_TIME_FLIGHTS / operatedFlights) * 100).toFixed(1)
    : "N/A";

  const otpChartData = (otpTrend && otpTrend.length > 0) 
    ? otpTrend 
    : (filters.timeRange === "last7days" ? mockOtpTrend7Days : mockOtpTrendToday);

  const metrics = [
    { label: "Total Flights", value: summary.TOTAL_FLIGHTS, icon: Plane, color: "bg-phantom-primary" },
    { label: "On Time", value: summary.ON_TIME_FLIGHTS, icon: TrendingUp, color: "bg-green-500" },
    { label: "In Flight", value: summary.IN_PROGRESS_FLIGHTS || 0, icon: PlayCircle, color: "bg-blue-500" },
    { label: "Delayed", value: summary.DELAYED_FLIGHTS, icon: Clock, color: "bg-amber-500" },
    { label: "Cancelled", value: summary.CANCELLED_FLIGHTS, icon: AlertTriangle, color: "bg-red-500" },
  ];

  const filteredHubs = hubStats.filter((hub) => {
    if (filters.hub !== "ALL" && hub.ORIGIN !== filters.hub) return false;
    if (filters.status !== "ALL") {
      const rate = hub.DELAYED_COUNT / hub.FLIGHT_COUNT;
      if (filters.status === "CRITICAL" && rate <= 0.3) return false;
      if (filters.status === "WARNING" && (rate <= 0.15 || rate > 0.3)) return false;
      if (filters.status === "NORMAL" && rate > 0.15) return false;
    }
    return true;
  });

  const otpChartTitle = filters.timeRange === "last7days" 
    ? "OTP Trend (Last 7 Days)" 
    : filters.timeRange === "tomorrow"
    ? "OTP Trend (Tomorrow - Projected)"
    : "OTP Trend (Today)";

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2 mb-2">
        <h1 className="text-xl font-bold text-phantom-dark">Operations Dashboard</h1>
        <InfoTooltip text={PAGE_HELP.dashboard} />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
        {metrics.map((metric) => {
          const Icon = metric.icon;
          return (
            <div key={metric.label} className="bg-white rounded-xl shadow-sm border p-5">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm text-slate-500 font-medium">{metric.label}</span>
                <div className={`${metric.color} p-2 rounded-lg`}>
                  <Icon className="h-4 w-4 text-white" />
                </div>
              </div>
              <p className="text-3xl font-bold text-phantom-dark">{metric.value.toLocaleString()}</p>
            </div>
          );
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="h-5 w-5 text-phantom-primary" />
            <h3 className="font-semibold text-phantom-dark">On-Time Performance</h3>
          </div>
          <div className="flex items-end gap-2">
            <span className={`text-4xl font-bold ${onTimeRate === "N/A" ? "text-slate-400" : "text-green-600"}`}>
              {onTimeRate === "N/A" ? "N/A" : `${onTimeRate}%`}
            </span>
            <span className="text-slate-500 text-sm mb-1">OTP</span>
          </div>
          {onTimeRate === "N/A" ? (
            <div className="mt-3 text-xs text-slate-400">No operated flights in this time range</div>
          ) : (
            <div className="mt-3 h-2 bg-slate-100 rounded-full overflow-hidden">
              <div 
                className="h-full bg-green-500 rounded-full transition-all duration-500"
                style={{ width: `${onTimeRate}%` }}
              />
            </div>
          )}
        </div>

        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center gap-2 mb-4">
            <Clock className="h-5 w-5 text-amber-500" />
            <h3 className="font-semibold text-phantom-dark">Average Delay</h3>
          </div>
          <div className="flex items-end gap-2">
            <span className="text-4xl font-bold text-amber-600">
              {Math.round(summary.AVG_DELAY_MINUTES || 0)}
            </span>
            <span className="text-slate-500 text-sm mb-1">minutes</span>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center gap-2 mb-4">
            <Users className="h-5 w-5 text-purple-500" />
            <h3 className="font-semibold text-phantom-dark">Passengers Affected</h3>
          </div>
          <div className="flex items-end gap-2">
            <span className="text-4xl font-bold text-purple-600">
              {(summary.TOTAL_PASSENGERS_AFFECTED || 0).toLocaleString()}
            </span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-phantom-dark">{otpChartTitle}</h3>
            <select
              value={filters.timeRange}
              onChange={(e) => handleFilterChange("timeRange", e.target.value)}
              className="px-3 py-1.5 border rounded-lg text-sm bg-slate-50 focus:ring-2 focus:ring-phantom-primary"
            >
              {TIME_RANGE_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </div>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={otpChartData}>
              <XAxis dataKey="DATE_LABEL" tick={{ fontSize: 12 }} />
              <YAxis domain={[50, 100]} tick={{ fontSize: 12 }} tickFormatter={(v) => `${v}%`} />
              <Tooltip formatter={(value: number, name: string) => [name === "OTP" ? `${value}%` : value, name === "OTP" ? "OTP" : "Flights"]} />
              <Line type="monotone" dataKey="OTP" stroke="#29B5E8" strokeWidth={2} dot={{ fill: "#29B5E8" }} name="OTP" />
            </LineChart>
          </ResponsiveContainer>
          <div className="mt-2 text-xs text-slate-500 text-center">
            Target: 85% OTP
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm border p-5">
          <h3 className="font-semibold text-phantom-dark mb-4">Delay Distribution by Cause</h3>
          <div className="flex items-center">
            <ResponsiveContainer width="50%" height={200}>
              <PieChart>
                <Pie
                  data={delayDistribution}
                  cx="50%"
                  cy="50%"
                  innerRadius={40}
                  outerRadius={70}
                  dataKey="count"
                >
                  {delayDistribution.map((_, idx) => (
                    <Cell key={idx} fill={CHART_COLORS[idx % CHART_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value: number) => [value, "Flights"]} />
              </PieChart>
            </ResponsiveContainer>
            <div className="w-1/2 space-y-2">
              {delayDistribution.map((item, idx) => (
                <div key={item.reason} className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-full" style={{ backgroundColor: CHART_COLORS[idx] }} />
                    <span>{item.reason}</span>
                  </div>
                  <span className="font-medium">{item.percentage}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border p-5">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-phantom-dark">Hub Performance</h3>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition ${
              showFilters ? "bg-phantom-primary text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
            }`}
          >
            <Filter className="h-4 w-4" />
            Filters
          </button>
        </div>

        {showFilters && (
          <div className="flex gap-4 p-4 bg-slate-50 rounded-lg mb-4">
            <div>
              <label className="block text-xs text-slate-500 mb-1">Hub</label>
              <select
                value={filters.hub}
                onChange={(e) => handleFilterChange("hub", e.target.value)}
                className="px-3 py-2 border rounded-lg text-sm"
              >
                <option value="ALL">All Hubs</option>
                {hubStats.map((h) => (
                  <option key={h.ORIGIN} value={h.ORIGIN}>{h.ORIGIN}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs text-slate-500 mb-1">Status</label>
              <select
                value={filters.status}
                onChange={(e) => handleFilterChange("status", e.target.value)}
                className="px-3 py-2 border rounded-lg text-sm"
              >
                <option value="ALL">All</option>
                <option value="CRITICAL">Critical</option>
                <option value="WARNING">Warning</option>
                <option value="NORMAL">Normal</option>
              </select>
            </div>
          </div>
        )}
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-left text-sm text-slate-500 border-b">
                <th className="pb-3 font-medium">Airport</th>
                <th className="pb-3 font-medium">Flights</th>
                <th className="pb-3 font-medium">Delayed</th>
                <th className="pb-3 font-medium">Avg Delay</th>
                <th className="pb-3 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {filteredHubs.map((hub) => (
                <tr key={hub.ORIGIN} className="border-b last:border-0">
                  <td className="py-3 font-medium">{hub.ORIGIN}</td>
                  <td className="py-3">{hub.FLIGHT_COUNT}</td>
                  <td className="py-3">{hub.DELAYED_COUNT}</td>
                  <td className="py-3">{Math.round(hub.AVG_DELAY || 0)} min</td>
                  <td className="py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      hub.DELAYED_COUNT / hub.FLIGHT_COUNT > 0.3
                        ? "bg-red-100 text-red-700"
                        : hub.DELAYED_COUNT / hub.FLIGHT_COUNT > 0.15
                        ? "bg-amber-100 text-amber-700"
                        : "bg-green-100 text-green-700"
                    }`}>
                      {hub.DELAYED_COUNT / hub.FLIGHT_COUNT > 0.3
                        ? "Critical"
                        : hub.DELAYED_COUNT / hub.FLIGHT_COUNT > 0.15
                        ? "Warning"
                        : "Normal"}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border p-5">
        <h3 className="font-semibold text-phantom-dark mb-4">Delays by Hub</h3>
        <ResponsiveContainer width="100%" height={250}>
          <BarChart data={hubStats}>
            <XAxis dataKey="ORIGIN" tick={{ fontSize: 12 }} />
            <YAxis tick={{ fontSize: 12 }} />
            <Tooltip />
            <Bar dataKey="FLIGHT_COUNT" name="Total Flights" fill="#29B5E8" />
            <Bar dataKey="DELAYED_COUNT" name="Delayed" fill="#FF9800" />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
