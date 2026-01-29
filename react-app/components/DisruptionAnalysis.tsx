"use client";

import { useEffect, useState } from "react";
import { AlertTriangle, DollarSign, TrendingUp, Clock, Filter, Loader2 } from "lucide-react";
import InfoTooltip from "./InfoTooltip";
import { PAGE_HELP } from "@/lib/pageHelp";
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from "recharts";

interface Disruption {
  DISRUPTION_ID: string;
  DISRUPTION_TYPE: string;
  SEVERITY: string;
  HUB: string;
  DESCRIPTION: string;
  FLIGHTS_AFFECTED: number;
  PASSENGERS_AFFECTED: number;
  ESTIMATED_COST: number;
  STATUS: string;
  STARTED_AT: string;
}

interface CostBreakdown {
  TYPE: string;
  DIRECT_COST: number;
  PASSENGER_COST: number;
  CREW_COST: number;
}

const SEVERITY_COLORS: Record<string, string> = {
  CRITICAL: "bg-red-100 text-red-700",
  SEVERE: "bg-orange-100 text-orange-700",
  MODERATE: "bg-yellow-100 text-yellow-700",
  MINOR: "bg-green-100 text-green-700",
};

const CHART_COLORS = ["#29B5E8", "#1E3A5F", "#0D47A1", "#4CAF50", "#FF9800"];

const mockDisruptions: Disruption[] = [
  { DISRUPTION_ID: "DIS001", DISRUPTION_TYPE: "WEATHER", SEVERITY: "CRITICAL", HUB: "ATL", DESCRIPTION: "Severe thunderstorms causing ground stop", FLIGHTS_AFFECTED: 45, PASSENGERS_AFFECTED: 4500, ESTIMATED_COST: 850000, STATUS: "IN_PROGRESS", STARTED_AT: "2 hrs ago" },
  { DISRUPTION_ID: "DIS002", DISRUPTION_TYPE: "MECHANICAL", SEVERITY: "SEVERE", HUB: "DTW", DESCRIPTION: "Engine issue on N3102PH", FLIGHTS_AFFECTED: 1, PASSENGERS_AFFECTED: 180, ESTIMATED_COST: 125000, STATUS: "IN_PROGRESS", STARTED_AT: "45 min ago" },
  { DISRUPTION_ID: "DIS003", DISRUPTION_TYPE: "CREW", SEVERITY: "SEVERE", HUB: "MSP", DESCRIPTION: "Captain sick call - 3 flights affected", FLIGHTS_AFFECTED: 3, PASSENGERS_AFFECTED: 450, ESTIMATED_COST: 95000, STATUS: "PENDING", STARTED_AT: "30 min ago" },
  { DISRUPTION_ID: "DIS004", DISRUPTION_TYPE: "ATC", SEVERITY: "MODERATE", HUB: "JFK", DESCRIPTION: "ATC staffing shortage", FLIGHTS_AFFECTED: 12, PASSENGERS_AFFECTED: 1200, ESTIMATED_COST: 180000, STATUS: "RESOLVED", STARTED_AT: "4 hrs ago" },
  { DISRUPTION_ID: "DIS005", DISRUPTION_TYPE: "WEATHER", SEVERITY: "CRITICAL", HUB: "ATL", DESCRIPTION: "Tornado warning - diversions", FLIGHTS_AFFECTED: 23, PASSENGERS_AFFECTED: 2100, ESTIMATED_COST: 420000, STATUS: "IN_PROGRESS", STARTED_AT: "1.5 hrs ago" },
  { DISRUPTION_ID: "DIS006", DISRUPTION_TYPE: "GROUND_OPS", SEVERITY: "MODERATE", HUB: "LAX", DESCRIPTION: "Fueling equipment failure", FLIGHTS_AFFECTED: 5, PASSENGERS_AFFECTED: 750, ESTIMATED_COST: 65000, STATUS: "PENDING", STARTED_AT: "20 min ago" },
];

const costByType: CostBreakdown[] = [
  { TYPE: "WEATHER", DIRECT_COST: 1250000, PASSENGER_COST: 450000, CREW_COST: 180000 },
  { TYPE: "MECHANICAL", DIRECT_COST: 450000, PASSENGER_COST: 125000, CREW_COST: 45000 },
  { TYPE: "CREW", DIRECT_COST: 320000, PASSENGER_COST: 95000, CREW_COST: 85000 },
  { TYPE: "ATC", DIRECT_COST: 280000, PASSENGER_COST: 180000, CREW_COST: 65000 },
  { TYPE: "GROUND_OPS", DIRECT_COST: 120000, PASSENGER_COST: 65000, CREW_COST: 25000 },
];

const cascadeFlights = [
  { flight: "PH1235", route: "JFK → LAX", type: "Aircraft Rotation", delay: "45 min", passengers: 180, cost: 18000 },
  { flight: "PH1456", route: "JFK → MIA", type: "Crew Rotation", delay: "60 min", passengers: 150, cost: 22000 },
  { flight: "PH1678", route: "ATL → ORD", type: "Aircraft Rotation", delay: "90 min", passengers: 165, cost: 35000 },
  { flight: "PH1890", route: "ORD → DEN", type: "Crew Rotation", delay: "120 min", passengers: 145, cost: 48000 },
  { flight: "PH2012", route: "LAX → SEA", type: "Aircraft Rotation", delay: "75 min", passengers: 170, cost: 28000 },
];

const historicalEvents = [
  { date: "2024-07-19", event: "CrowdStrike Outage", type: "SYSTEM_OUTAGE", duration: "120 hrs", cancelled: "4,000", cost: "$85M", learning: "Need backup crew tracking" },
  { date: "2022-12-22", event: "Winter Storm Elliott", type: "WEATHER", duration: "96 hrs", cancelled: "2,500", cost: "$45M", learning: "Pre-position crews 48hrs ahead" },
  { date: "2023-08-15", event: "B737 Fleet AD", type: "MECHANICAL", duration: "72 hrs", cancelled: "1,200", cost: "$25M", learning: "Cross-train mechanics" },
];

export default function DisruptionAnalysis() {
  const [activeTab, setActiveTab] = useState<"events" | "cost" | "cascade" | "historical">("events");
  const [disruptions, setDisruptions] = useState<Disruption[]>(mockDisruptions);
  const [loading, setLoading] = useState(false);
  const [filters, setFilters] = useState({ type: "ALL", severity: "ALL", hub: "ALL" });
  const [showFilters, setShowFilters] = useState(false);

  const filteredDisruptions = disruptions.filter((d) => {
    if (filters.type !== "ALL" && d.DISRUPTION_TYPE !== filters.type) return false;
    if (filters.severity !== "ALL" && d.SEVERITY !== filters.severity) return false;
    if (filters.hub !== "ALL" && d.HUB !== filters.hub) return false;
    return true;
  });

  const totalCost = disruptions.reduce((sum, d) => sum + d.ESTIMATED_COST, 0);
  const totalPassengers = disruptions.reduce((sum, d) => sum + d.PASSENGERS_AFFECTED, 0);
  const criticalCount = disruptions.filter((d) => d.SEVERITY === "CRITICAL").length;
  const severeCount = disruptions.filter((d) => d.SEVERITY === "SEVERE").length;

  const pieData = Object.entries(
    disruptions.reduce((acc, d) => {
      acc[d.DISRUPTION_TYPE] = (acc[d.DISRUPTION_TYPE] || 0) + 1;
      return acc;
    }, {} as Record<string, number>)
  ).map(([name, value]) => ({ name, value }));

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2 mb-2">
        <h1 className="text-xl font-bold text-phantom-dark">Disruption Analysis</h1>
        <InfoTooltip text={PAGE_HELP.disruptions} />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-slate-500">Active Disruptions</span>
            <AlertTriangle className="h-4 w-4 text-amber-500" />
          </div>
          <p className="text-3xl font-bold text-phantom-dark">{disruptions.length}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-slate-500">Critical</span>
            <span className="w-3 h-3 rounded-full bg-red-500" />
          </div>
          <p className="text-3xl font-bold text-red-600">{criticalCount}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-slate-500">Severe</span>
            <span className="w-3 h-3 rounded-full bg-orange-500" />
          </div>
          <p className="text-3xl font-bold text-orange-600">{severeCount}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-slate-500">Passengers Affected</span>
          </div>
          <p className="text-3xl font-bold text-phantom-dark">{totalPassengers.toLocaleString()}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-slate-500">Est. Cost Today</span>
            <DollarSign className="h-4 w-4 text-green-500" />
          </div>
          <p className="text-3xl font-bold text-phantom-dark">${(totalCost / 1000000).toFixed(1)}M</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border">
        <div className="flex items-center justify-between border-b px-5 py-3">
          <div className="flex gap-1">
            {[
              { id: "events", label: "Active Events", icon: AlertTriangle },
              { id: "cost", label: "Cost Analysis", icon: DollarSign },
              { id: "cascade", label: "Cascading Impact", icon: TrendingUp },
              { id: "historical", label: "Historical", icon: Clock },
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
          {activeTab === "events" && (
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition ${
                showFilters ? "bg-phantom-primary text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              <Filter className="h-4 w-4" />
              Filters
            </button>
          )}
        </div>

        <div className="p-5">
          {activeTab === "events" && (
            <div className="space-y-4">
              {showFilters && (
                <div className="flex gap-4 p-4 bg-slate-50 rounded-lg">
                  <div>
                    <label className="block text-xs text-slate-500 mb-1">Type</label>
                    <select
                      value={filters.type}
                      onChange={(e) => setFilters({ ...filters, type: e.target.value })}
                      className="px-3 py-2 border rounded-lg text-sm"
                    >
                      <option value="ALL">All Types</option>
                      <option value="WEATHER">Weather</option>
                      <option value="MECHANICAL">Mechanical</option>
                      <option value="CREW">Crew</option>
                      <option value="ATC">ATC</option>
                      <option value="GROUND_OPS">Ground Ops</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs text-slate-500 mb-1">Severity</label>
                    <select
                      value={filters.severity}
                      onChange={(e) => setFilters({ ...filters, severity: e.target.value })}
                      className="px-3 py-2 border rounded-lg text-sm"
                    >
                      <option value="ALL">All Severities</option>
                      <option value="CRITICAL">Critical</option>
                      <option value="SEVERE">Severe</option>
                      <option value="MODERATE">Moderate</option>
                      <option value="MINOR">Minor</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs text-slate-500 mb-1">Hub</label>
                    <select
                      value={filters.hub}
                      onChange={(e) => setFilters({ ...filters, hub: e.target.value })}
                      className="px-3 py-2 border rounded-lg text-sm"
                    >
                      <option value="ALL">All Hubs</option>
                      <option value="ATL">ATL</option>
                      <option value="DTW">DTW</option>
                      <option value="MSP">MSP</option>
                      <option value="JFK">JFK</option>
                      <option value="LAX">LAX</option>
                    </select>
                  </div>
                </div>
              )}

              <p className="text-sm text-slate-500">
                Showing {filteredDisruptions.length} of {disruptions.length} disruptions
              </p>

              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="text-left text-sm text-slate-500 border-b">
                      <th className="pb-3 font-medium">ID</th>
                      <th className="pb-3 font-medium">Type</th>
                      <th className="pb-3 font-medium">Severity</th>
                      <th className="pb-3 font-medium">Hub</th>
                      <th className="pb-3 font-medium">Description</th>
                      <th className="pb-3 font-medium">Flights</th>
                      <th className="pb-3 font-medium">PAX</th>
                      <th className="pb-3 font-medium">Est. Cost</th>
                      <th className="pb-3 font-medium">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredDisruptions.map((d) => (
                      <tr key={d.DISRUPTION_ID} className="border-b last:border-0 hover:bg-slate-50">
                        <td className="py-3 font-mono text-sm">{d.DISRUPTION_ID}</td>
                        <td className="py-3">{d.DISRUPTION_TYPE}</td>
                        <td className="py-3">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${SEVERITY_COLORS[d.SEVERITY]}`}>
                            {d.SEVERITY}
                          </span>
                        </td>
                        <td className="py-3 font-medium">{d.HUB}</td>
                        <td className="py-3 text-sm text-slate-600 max-w-xs truncate">{d.DESCRIPTION}</td>
                        <td className="py-3">{d.FLIGHTS_AFFECTED}</td>
                        <td className="py-3">{d.PASSENGERS_AFFECTED.toLocaleString()}</td>
                        <td className="py-3">${(d.ESTIMATED_COST / 1000).toFixed(0)}K</td>
                        <td className="py-3">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                            d.STATUS === "IN_PROGRESS" ? "bg-blue-100 text-blue-700" :
                            d.STATUS === "RESOLVED" ? "bg-green-100 text-green-700" :
                            "bg-yellow-100 text-yellow-700"
                          }`}>
                            {d.STATUS}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {activeTab === "cost" && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div>
                <h3 className="text-lg font-semibold text-phantom-dark mb-4">Cost by Disruption Type</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={costByType}>
                    <XAxis dataKey="TYPE" tick={{ fontSize: 12 }} />
                    <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `$${(v / 1000000).toFixed(1)}M`} />
                    <Tooltip formatter={(v: number) => `$${(v / 1000).toFixed(0)}K`} />
                    <Bar dataKey="DIRECT_COST" name="Direct" fill="#29B5E8" stackId="a" />
                    <Bar dataKey="PASSENGER_COST" name="Passenger" fill="#1E3A5F" stackId="a" />
                    <Bar dataKey="CREW_COST" name="Crew" fill="#0D47A1" stackId="a" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
              <div>
                <h3 className="text-lg font-semibold text-phantom-dark mb-4">Disruptions by Type</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={pieData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={100}
                      dataKey="value"
                      label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                    >
                      {pieData.map((_, idx) => (
                        <Cell key={idx} fill={CHART_COLORS[idx % CHART_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
                <div className="mt-4 p-4 bg-slate-50 rounded-lg">
                  <h4 className="font-medium text-phantom-dark mb-2">Cost Categories</h4>
                  <div className="grid grid-cols-3 gap-2 text-sm">
                    <div><span className="font-medium">Direct:</span> Repositioning, fuel, fees</div>
                    <div><span className="font-medium">Passenger:</span> Hotels, vouchers, DOT comp</div>
                    <div><span className="font-medium">Crew:</span> OT, deadhead, reserves</div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === "cascade" && (
            <div className="space-y-4">
              <div className="grid grid-cols-3 gap-4 mb-6">
                <div className="p-4 bg-amber-50 border border-amber-200 rounded-lg text-center">
                  <p className="text-2xl font-bold text-amber-700">23</p>
                  <p className="text-sm text-amber-600">Downstream Flights</p>
                </div>
                <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-center">
                  <p className="text-2xl font-bold text-red-700">3,200</p>
                  <p className="text-sm text-red-600">Additional PAX Affected</p>
                </div>
                <div className="p-4 bg-purple-50 border border-purple-200 rounded-lg text-center">
                  <p className="text-2xl font-bold text-purple-700">$420K</p>
                  <p className="text-sm text-purple-600">Cascade Cost</p>
                </div>
              </div>

              <h3 className="text-lg font-semibold text-phantom-dark">Cascade Impact - ATL Thunderstorms</h3>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="text-left text-sm text-slate-500 border-b">
                      <th className="pb-3 font-medium">Flight</th>
                      <th className="pb-3 font-medium">Route</th>
                      <th className="pb-3 font-medium">Cascade Type</th>
                      <th className="pb-3 font-medium">Est. Delay</th>
                      <th className="pb-3 font-medium">PAX</th>
                      <th className="pb-3 font-medium">Cost Impact</th>
                    </tr>
                  </thead>
                  <tbody>
                    {cascadeFlights.map((f) => (
                      <tr key={f.flight} className="border-b last:border-0 hover:bg-slate-50">
                        <td className="py-3 font-medium">{f.flight}</td>
                        <td className="py-3">{f.route}</td>
                        <td className="py-3">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                            f.type === "Aircraft Rotation" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"
                          }`}>
                            {f.type}
                          </span>
                        </td>
                        <td className="py-3 text-amber-600 font-medium">{f.delay}</td>
                        <td className="py-3">{f.passengers}</td>
                        <td className="py-3">${(f.cost / 1000).toFixed(0)}K</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {activeTab === "historical" && (
            <div className="space-y-6">
              <h3 className="text-lg font-semibold text-phantom-dark">Similar Past Events</h3>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="text-left text-sm text-slate-500 border-b">
                      <th className="pb-3 font-medium">Date</th>
                      <th className="pb-3 font-medium">Event</th>
                      <th className="pb-3 font-medium">Type</th>
                      <th className="pb-3 font-medium">Duration</th>
                      <th className="pb-3 font-medium">Flights Cancelled</th>
                      <th className="pb-3 font-medium">Total Cost</th>
                      <th className="pb-3 font-medium">Key Learning</th>
                    </tr>
                  </thead>
                  <tbody>
                    {historicalEvents.map((e) => (
                      <tr key={e.date} className="border-b last:border-0 hover:bg-slate-50">
                        <td className="py-3">{e.date}</td>
                        <td className="py-3 font-medium">{e.event}</td>
                        <td className="py-3">
                          <span className="px-2 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700">
                            {e.type}
                          </span>
                        </td>
                        <td className="py-3">{e.duration}</td>
                        <td className="py-3 text-red-600 font-medium">{e.cancelled}</td>
                        <td className="py-3 font-medium">{e.cost}</td>
                        <td className="py-3 text-sm text-slate-600">{e.learning}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <button className="w-full py-3 bg-phantom-primary text-white rounded-lg hover:bg-phantom-dark transition flex items-center justify-center gap-2">
                <TrendingUp className="h-4 w-4" />
                Find Similar Incidents for Current Disruption
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
