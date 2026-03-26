import { NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

interface StatsRow {
  TOTAL_ROWS: number;
  DURATION_SECONDS: number;
  FIRST_EVENT: string;
  LAST_EVENT: string;
}

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

function calculateCost(totalRows: number, durationSec: number, billingModel: 'classic' | 'high_perf'): {
  dataGb: number;
  estimatedCostUsd: number;
  estimatedCredits: number;
  costPerMillionRows: number;
  costPerGb: number;
  rowsPerSecond: number;
  gbPerHour: number;
} {
  const avgRowSizeBytes = 250;
  const dataGb = (totalRows * avgRowSizeBytes) / (1024 * 1024 * 1024);
  const safeDuration = Math.max(durationSec, 1);
  const creditPriceUsd = 2.35;
  
  let estimatedCostUsd: number;
  let estimatedCredits: number;
  
  if (billingModel === 'classic') {
    const creditsPerThousandRows = 0.000024;
    estimatedCredits = (totalRows / 1000) * creditsPerThousandRows;
    estimatedCostUsd = estimatedCredits * creditPriceUsd;
  } else {
    const creditsPerGb = 0.0037;
    estimatedCredits = dataGb * creditsPerGb;
    estimatedCostUsd = estimatedCredits * creditPriceUsd;
  }
  
  const rowsPerSecond = totalRows / safeDuration;
  const gbPerHour = (dataGb / safeDuration) * 3600;
  const costPerMillionRows = totalRows > 0 ? (estimatedCostUsd / totalRows) * 1000000 : 0;
  const costPerGb = dataGb > 0 ? estimatedCostUsd / dataGb : 0;
  
  return {
    dataGb: Math.round(dataGb * 1000) / 1000,
    estimatedCostUsd: Math.round(estimatedCostUsd * 10000) / 10000,
    estimatedCredits: Math.round(estimatedCredits * 10000) / 10000,
    costPerMillionRows: Math.round(costPerMillionRows * 10000) / 10000,
    costPerGb: Math.round(costPerGb * 10000) / 10000,
    rowsPerSecond: Math.round(rowsPerSecond),
    gbPerHour: Math.round(gbPerHour * 100) / 100,
  };
}

export async function GET() {
  try {
    const [classicRows, highPerfRows] = await Promise.all([
      query<StatsRow>(`
        SELECT 
          COUNT(*) as total_rows,
          TIMESTAMPDIFF(SECOND, MIN(EVENT_TIMESTAMP), MAX(EVENT_TIMESTAMP)) as duration_seconds,
          MIN(EVENT_TIMESTAMP) as first_event,
          MAX(EVENT_TIMESTAMP) as last_event
        FROM PHANTOM_IROPS.RAW.FLIGHT_EVENTS_STREAMING
      `),
      query<StatsRow>(`
        SELECT 
          COUNT(*) as total_rows,
          TIMESTAMPDIFF(SECOND, MIN(EVENT_TIMESTAMP), MAX(EVENT_TIMESTAMP)) as duration_seconds,
          MIN(EVENT_TIMESTAMP) as first_event,
          MAX(EVENT_TIMESTAMP) as last_event
        FROM PHANTOM_IROPS.RAW.FLIGHT_EVENTS_HIGH_PERF
      `)
    ]);
    
    const classicRow = classicRows[0];
    const highPerfRow = highPerfRows[0];
    
    const classicCost = calculateCost(
      classicRow?.TOTAL_ROWS || 0,
      classicRow?.DURATION_SECONDS || 0,
      'classic'
    );
    
    const highPerfCost = calculateCost(
      highPerfRow?.TOTAL_ROWS || 0,
      highPerfRow?.DURATION_SECONDS || 0,
      'high_perf'
    );
    
    const classic: ArchitectureStats = {
      name: 'Classic',
      totalRows: classicRow?.TOTAL_ROWS || 0,
      durationMinutes: Math.round((classicRow?.DURATION_SECONDS || 0) / 60 * 10) / 10,
      ...classicCost,
      billingModel: 'Per-row (credits)',
      architecture: 'Kafka → Connector → Snowflake',
      isActive: (classicRow?.TOTAL_ROWS || 0) > 0
    };
    
    const highPerf: ArchitectureStats = {
      name: 'High-Performance',
      totalRows: highPerfRow?.TOTAL_ROWS || 0,
      durationMinutes: Math.round((highPerfRow?.DURATION_SECONDS || 0) / 60 * 10) / 10,
      ...highPerfCost,
      billingModel: 'Per-GB (throughput)',
      architecture: 'SDK → PIPE → Snowflake',
      isActive: (highPerfRow?.TOTAL_ROWS || 0) > 0
    };
    
    let costComparison = null;
    if (classic.totalRows > 0 && highPerf.totalRows > 0) {
      const normalizedClassicCost = classic.costPerMillionRows;
      const normalizedHighPerfCost = highPerf.costPerMillionRows;
      const winner = normalizedClassicCost < normalizedHighPerfCost ? 'classic' : 'high_perf';
      const savings = Math.abs(normalizedClassicCost - normalizedHighPerfCost) / Math.max(normalizedClassicCost, normalizedHighPerfCost) * 100;
      
      costComparison = {
        winner,
        winnerName: winner === 'classic' ? 'Classic' : 'High-Performance',
        savingsPercent: Math.round(savings),
        classicCostPer1M: normalizedClassicCost,
        highPerfCostPer1M: normalizedHighPerfCost
      };
    }

    return NextResponse.json({
      classic,
      highPerf,
      costComparison
    });
  } catch (error) {
    console.error("Streaming comparison error:", error);
    return NextResponse.json({
      classic: { name: 'Classic', totalRows: 0, isActive: false },
      highPerf: { name: 'High-Performance', totalRows: 0, isActive: false },
      error: error instanceof Error ? error.message : "Unknown error"
    });
  }
}
