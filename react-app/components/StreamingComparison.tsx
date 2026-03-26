'use client';

import { useState, useEffect, useCallback } from 'react';
import { Activity, Database, Zap, DollarSign, Gauge, ArrowRight, Trophy, Server, Layers } from 'lucide-react';
import InfoTooltip from './InfoTooltip';

interface ArchitectureStats {
  name: string;
  totalRows: number;
  dataGb: number;
  durationMinutes: number;
  rowsPerSecond: number;
  gbPerHour: number;
  estimatedCostUsd: number;
  estimatedCredits: number;
  costPerMillionRows: number;
  costPerGb: number;
  billingModel: string;
  architecture: string;
  isActive: boolean;
}

interface CostComparison {
  winner: string;
  winnerName: string;
  savingsPercent: number;
  classicCostPer1M: number;
  highPerfCostPer1M: number;
}

interface CompareData {
  classic: ArchitectureStats;
  highPerf: ArchitectureStats;
  costComparison: CostComparison | null;
}

function formatNumber(num: number): string {
  if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
  if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
  return num.toLocaleString();
}

function ArchitectureCard({ stats, color, icon: Icon }: { 
  stats: ArchitectureStats; 
  color: 'cyan' | 'purple';
  icon: typeof Zap;
}) {
  const colors = {
    cyan: {
      bg: 'bg-gradient-to-br from-cyan-500 to-blue-600',
      light: 'bg-cyan-50',
      text: 'text-cyan-600',
      badge: 'bg-cyan-100 text-cyan-700'
    },
    purple: {
      bg: 'bg-gradient-to-br from-purple-500 to-indigo-600',
      light: 'bg-purple-50',
      text: 'text-purple-600',
      badge: 'bg-purple-100 text-purple-700'
    }
  };
  const c = colors[color];

  return (
    <div className="bg-white rounded-xl shadow-lg border overflow-hidden">
      <div className={`${c.bg} p-4 text-white`}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Icon className="h-6 w-6" />
            <h3 className="text-lg font-bold">{stats.name}</h3>
          </div>
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${stats.isActive ? 'bg-white/20' : 'bg-white/10 opacity-60'}`}>
            {stats.isActive ? 'Active' : 'No Data'}
          </span>
        </div>
        <p className="text-sm opacity-80 mt-1">{stats.architecture}</p>
      </div>

      <div className="p-5 space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div className={`${c.light} rounded-lg p-3`}>
            <p className="text-xs text-slate-500 mb-1">Total Events</p>
            <p className={`text-2xl font-bold ${c.text}`}>{formatNumber(stats.totalRows)}</p>
          </div>
          <div className={`${c.light} rounded-lg p-3`}>
            <p className="text-xs text-slate-500 mb-1">Throughput</p>
            <p className={`text-2xl font-bold ${c.text}`}>{formatNumber(stats.rowsPerSecond)}/s</p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-slate-50 rounded-lg p-3">
            <p className="text-xs text-slate-500 mb-1">Data Ingested</p>
            <p className="text-lg font-semibold text-slate-700">{stats.dataGb} GB</p>
          </div>
          <div className="bg-slate-50 rounded-lg p-3">
            <p className="text-xs text-slate-500 mb-1">Duration</p>
            <p className="text-lg font-semibold text-slate-700">{stats.durationMinutes} min</p>
          </div>
        </div>

        <div className="border-t pt-4">
          <div className="flex items-center gap-2 mb-3">
            <DollarSign className="h-4 w-4 text-emerald-500" />
            <span className="text-sm font-medium text-slate-700">Cost Analysis</span>
            <span className={`text-xs px-2 py-0.5 rounded ${c.badge}`}>{stats.billingModel}</span>
          </div>
          
          <div className="grid grid-cols-2 gap-2">
            <div className="text-center p-2 bg-emerald-50 rounded">
              <p className="text-lg font-bold text-emerald-600">~${stats.estimatedCostUsd}</p>
              <p className="text-xs text-slate-500">Total Cost</p>
            </div>
            <div className="text-center p-2 bg-blue-50 rounded">
              <p className="text-lg font-bold text-blue-600">{stats.estimatedCredits}</p>
              <p className="text-xs text-slate-500">Credits</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2 mt-2">
            <div className="text-center p-2 bg-slate-50 rounded">
              <p className="text-lg font-bold text-slate-700">~${stats.costPerMillionRows}</p>
              <p className="text-xs text-slate-500">Per 1M rows</p>
            </div>
            <div className="text-center p-2 bg-slate-50 rounded">
              <p className="text-lg font-bold text-slate-700">~${stats.costPerGb}</p>
              <p className="text-xs text-slate-500">Per GB</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function StreamingComparison() {
  const [data, setData] = useState<CompareData | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    try {
      const res = await fetch('/api/streaming-compare');
      if (res.ok) {
        const json = await res.json();
        setData(json);
      }
    } catch (err) {
      console.error('Failed to fetch comparison data:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 10000);
    return () => clearInterval(interval);
  }, [fetchData]);

  if (loading || !data) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-cyan-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2 mb-2">
        <h1 className="text-xl font-bold text-phantom-dark">Snowpipe Streaming Comparison</h1>
        <InfoTooltip text="Compare Classic (Kafka Connector) vs High-Performance (Direct SDK) architectures for Snowpipe Streaming ingestion." />
        <span className="ml-2 px-2 py-1 bg-purple-100 text-purple-700 text-xs font-medium rounded-full flex items-center gap-1">
          <Layers className="w-3 h-3" />
          Architecture Comparison
        </span>
      </div>

      {data.costComparison && (
        <div className="bg-gradient-to-r from-yellow-400 to-amber-500 rounded-xl p-5 text-white shadow-lg">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Trophy className="h-8 w-8" />
              <div>
                <h2 className="text-lg font-bold">Cost Winner: {data.costComparison.winnerName}</h2>
                <p className="text-sm opacity-90">
                  {data.costComparison.savingsPercent}% cheaper per million rows
                </p>
              </div>
            </div>
            <div className="text-right">
              <div className="flex items-center gap-4">
                <div>
                  <p className="text-xs opacity-80">Classic</p>
                  <p className="text-lg font-bold">~${data.costComparison.classicCostPer1M}/1M</p>
                </div>
                <span className="text-2xl">vs</span>
                <div>
                  <p className="text-xs opacity-80">High-Perf</p>
                  <p className="text-lg font-bold">~${data.costComparison.highPerfCostPer1M}/1M</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ArchitectureCard stats={data.classic} color="cyan" icon={Server} />
        <ArchitectureCard stats={data.highPerf} color="purple" icon={Zap} />
      </div>

      <div className="bg-white rounded-xl shadow-sm border p-5">
        <h3 className="font-semibold text-phantom-dark mb-4">Architecture Differences</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b">
                <th className="text-left py-2 px-3 text-slate-500 font-medium">Feature</th>
                <th className="text-left py-2 px-3 text-cyan-600 font-medium">Classic</th>
                <th className="text-left py-2 px-3 text-purple-600 font-medium">High-Performance</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              <tr>
                <td className="py-2 px-3 text-slate-600">Data Path</td>
                <td className="py-2 px-3">Kafka → Connector → Snowflake</td>
                <td className="py-2 px-3">SDK → PIPE object → Snowflake</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-slate-600">Billing Model</td>
                <td className="py-2 px-3">Per-row (Snowflake credits)</td>
                <td className="py-2 px-3">Per-GB throughput</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-slate-600">Max Throughput</td>
                <td className="py-2 px-3">~100K rows/sec</td>
                <td className="py-2 px-3">Up to 10 GB/s per table</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-slate-600">Latency</td>
                <td className="py-2 px-3">Sub-second</td>
                <td className="py-2 px-3">5-10 seconds end-to-end</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-slate-600">Requires</td>
                <td className="py-2 px-3">Kafka cluster + Connector</td>
                <td className="py-2 px-3">Direct SDK integration</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-slate-600">Transformations</td>
                <td className="py-2 px-3">Client-side only</td>
                <td className="py-2 px-3">Server-side via PIPE object</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-slate-600">Best For</td>
                <td className="py-2 px-3">Existing Kafka infrastructure</td>
                <td className="py-2 px-3">High-volume, direct integration</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div className="bg-slate-50 rounded-xl p-5 border">
        <h3 className="font-semibold text-phantom-dark mb-3">Quick Start Commands</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p className="text-xs text-slate-500 mb-1 font-medium">Classic (Kafka Producer)</p>
            <code className="block bg-slate-800 text-green-400 p-3 rounded text-xs overflow-x-auto">
              python streaming/ultra_high_rate_producer.py
            </code>
          </div>
          <div>
            <p className="text-xs text-slate-500 mb-1 font-medium">High-Performance (Direct SDK)</p>
            <code className="block bg-slate-800 text-purple-400 p-3 rounded text-xs overflow-x-auto">
              python streaming/high_perf_producer.py --rate 10000
            </code>
          </div>
        </div>
      </div>
    </div>
  );
}
