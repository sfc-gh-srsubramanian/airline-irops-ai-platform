'use client';

import { useState, useEffect, useCallback } from 'react';
import { Radio, Activity, Database, Clock, TrendingUp, Zap, RefreshCw, DollarSign, Gauge, Server } from 'lucide-react';
import LiveEventFeed from './LiveEventFeed';
import InfoTooltip from './InfoTooltip';

interface StreamingStats {
  totalEvents: number;
  eventsLast5Min: number;
  avgLatencyMs: number;
  taskLastRun: string | null;
  streamHasData: boolean;
}

interface CostMetrics {
  totalRows: number;
  dataGb: number;
  durationMinutes: number;
  rowsPerSecond: number;
  gbPerHour: number;
  estimatedCredits: number;
  estimatedCostUsd: number;
  costPerMillionRows: number;
  costPerGb: number;
  warehouseEquivalentCost: number;
  savingsPercent: number;
}

export default function StreamingDashboard() {
  const [stats, setStats] = useState<StreamingStats>({
    totalEvents: 0,
    eventsLast5Min: 0,
    avgLatencyMs: 0,
    taskLastRun: null,
    streamHasData: false,
  });
  const [costMetrics, setCostMetrics] = useState<CostMetrics | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchStats = useCallback(async () => {
    try {
      const [statsRes, costRes] = await Promise.all([
        fetch('/api/streaming-stats'),
        fetch('/api/streaming-cost')
      ]);
      
      if (statsRes.ok) {
        const data = await statsRes.json();
        setStats(data);
      }
      if (costRes.ok) {
        const costData = await costRes.json();
        setCostMetrics(costData);
      }
    } catch (err) {
      console.error('Failed to fetch streaming stats:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 10000);
    return () => clearInterval(interval);
  }, [fetchStats]);

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2 mb-2">
        <h1 className="text-xl font-bold text-phantom-dark">Real-Time Streaming</h1>
        <InfoTooltip text="Monitor Snowpipe Streaming ingestion with sub-second latency from Kafka. Events flow: Simulator → Kafka → Snowflake → Dashboard." />
        <span className="ml-2 px-2 py-1 bg-cyan-100 text-cyan-700 text-xs font-medium rounded-full flex items-center gap-1">
          <Zap className="w-3 h-3" />
          Snowpipe Streaming
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm text-slate-500 font-medium">Total Events</span>
            <div className="bg-cyan-500 p-2 rounded-lg">
              <Database className="h-4 w-4 text-white" />
            </div>
          </div>
          <p className="text-3xl font-bold text-phantom-dark">
            {loading ? '...' : stats.totalEvents.toLocaleString()}
          </p>
          <p className="text-xs text-slate-400 mt-1">In FLIGHT_EVENTS_STREAMING</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm text-slate-500 font-medium">Last 5 Minutes</span>
            <div className="bg-green-500 p-2 rounded-lg">
              <Activity className="h-4 w-4 text-white" />
            </div>
          </div>
          <p className="text-3xl font-bold text-green-600">
            {loading ? '...' : stats.eventsLast5Min.toLocaleString()}
          </p>
          <p className="text-xs text-slate-400 mt-1">Events ingested</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm text-slate-500 font-medium">Avg Latency</span>
            <div className="bg-purple-500 p-2 rounded-lg">
              <Clock className="h-4 w-4 text-white" />
            </div>
          </div>
          <p className="text-3xl font-bold text-purple-600">
            {loading ? '...' : `${stats.avgLatencyMs}ms`}
          </p>
          <p className="text-xs text-slate-400 mt-1">Kafka → Snowflake</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm border p-5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm text-slate-500 font-medium">Throughput</span>
            <div className="bg-amber-500 p-2 rounded-lg">
              <Gauge className="h-4 w-4 text-white" />
            </div>
          </div>
          <p className="text-2xl font-bold text-amber-600">
            {loading || !costMetrics ? '...' : `${costMetrics.rowsPerSecond.toLocaleString()}/s`}
          </p>
          <p className="text-xs text-slate-400 mt-1">{costMetrics ? `${costMetrics.gbPerHour} GB/hour` : 'Events per second'}</p>
        </div>
      </div>

      {/* Cost Metrics Panel */}
      {costMetrics && (
        <div className="bg-gradient-to-r from-emerald-500 to-teal-600 rounded-xl p-6 text-white">
          <div className="flex items-center gap-2 mb-4">
            <DollarSign className="h-6 w-6" />
            <h2 className="text-lg font-bold">Snowpipe Streaming Cost Analysis</h2>
            <span className="ml-auto text-xs bg-white/20 px-2 py-1 rounded">Serverless • No warehouse needed</span>
          </div>
          
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
            <div className="bg-white/10 rounded-lg p-3">
              <p className="text-xs text-emerald-100 mb-1">Data Ingested</p>
              <p className="text-2xl font-bold">{costMetrics.dataGb} GB</p>
              <p className="text-xs text-emerald-200">{costMetrics.totalRows.toLocaleString()} rows</p>
            </div>
            
            <div className="bg-white/10 rounded-lg p-3">
              <p className="text-xs text-emerald-100 mb-1">Duration</p>
              <p className="text-2xl font-bold">{costMetrics.durationMinutes} min</p>
              <p className="text-xs text-emerald-200">Streaming time</p>
            </div>
            
            <div className="bg-white/10 rounded-lg p-3">
              <p className="text-xs text-emerald-100 mb-1">Credits Used</p>
              <p className="text-2xl font-bold">{costMetrics.estimatedCredits}</p>
              <p className="text-xs text-emerald-200">Snowflake credits</p>
            </div>
            
            <div className="bg-white/10 rounded-lg p-3">
              <p className="text-xs text-emerald-100 mb-1">Total Cost</p>
              <p className="text-2xl font-bold">${costMetrics.estimatedCostUsd}</p>
              <p className="text-xs text-emerald-200">@ $3/credit</p>
            </div>
            
            <div className="bg-white/10 rounded-lg p-3">
              <p className="text-xs text-emerald-100 mb-1">Cost per Million</p>
              <p className="text-2xl font-bold">${costMetrics.costPerMillionRows}</p>
              <p className="text-xs text-emerald-200">Per 1M rows</p>
            </div>
            
            <div className="bg-white/10 rounded-lg p-3">
              <p className="text-xs text-emerald-100 mb-1">Cost per GB</p>
              <p className="text-2xl font-bold">${costMetrics.costPerGb}</p>
              <p className="text-xs text-emerald-200">Per GB ingested</p>
            </div>
          </div>
          
          <div className="mt-4 pt-4 border-t border-white/20 flex items-center justify-between">
            <div className="flex items-center gap-6">
              <div>
                <p className="text-xs text-emerald-100">Warehouse Equivalent</p>
                <p className="text-lg font-semibold">${costMetrics.warehouseEquivalentCost} <span className="text-xs font-normal">(XS warehouse)</span></p>
              </div>
              <div className="text-3xl font-bold text-yellow-300">
                {costMetrics.savingsPercent}% savings
              </div>
            </div>
            <div className="text-right text-xs text-emerald-100">
              <p>✓ No warehouse to manage</p>
              <p>✓ Pay only for data ingested</p>
              <p>✓ Sub-second latency</p>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <LiveEventFeed maxEvents={20} pollIntervalMs={2000} />
        </div>

        <div className="space-y-4">
          <div className="bg-white rounded-xl shadow-sm border p-5">
            <h3 className="font-semibold text-phantom-dark mb-4 flex items-center gap-2">
              <Radio className="h-5 w-5 text-cyan-500" />
              Pipeline Status
            </h3>
            <div className="space-y-3">
              <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                <span className="text-sm text-slate-600">Kafka Topic</span>
                <span className="text-sm font-medium text-green-600 flex items-center gap-1">
                  <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>
                  flight-status-events
                </span>
              </div>
              <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                <span className="text-sm text-slate-600">Connector</span>
                <span className="text-sm font-medium text-cyan-600">Snowpipe Streaming</span>
              </div>
              <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                <span className="text-sm text-slate-600">Ingestion Method</span>
                <span className="text-sm font-medium text-emerald-600">SNOWPIPE_STREAMING</span>
              </div>
              <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                <span className="text-sm text-slate-600">Target Table</span>
                <span className="text-sm font-medium text-slate-700">FLIGHT_EVENTS_STREAMING</span>
              </div>
            </div>
          </div>

          <div className="bg-gradient-to-br from-cyan-500 to-blue-600 rounded-xl p-5 text-white">
            <h3 className="font-semibold mb-3 flex items-center gap-2">
              <TrendingUp className="h-5 w-5" />
              Architecture
            </h3>
            <div className="text-sm space-y-2 opacity-90">
              <div className="flex items-center gap-2">
                <span className="w-1.5 h-1.5 bg-white rounded-full"></span>
                <span>Python Simulator → Kafka</span>
              </div>
              <div className="flex items-center gap-2 pl-4">
                <span className="text-cyan-200">↓ ~10ms</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-1.5 h-1.5 bg-white rounded-full"></span>
                <span>Kafka → Snowflake (Streaming)</span>
              </div>
              <div className="flex items-center gap-2 pl-4">
                <span className="text-cyan-200">↓ Sub-second latency</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-1.5 h-1.5 bg-white rounded-full"></span>
                <span>Direct table insert (no staging)</span>
              </div>
              <div className="flex items-center gap-2 pl-4">
                <span className="text-cyan-200">↓ Immediate availability</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-1.5 h-1.5 bg-white rounded-full"></span>
                <span>Dashboard auto-refresh</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
