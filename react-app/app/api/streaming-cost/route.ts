import { NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

interface CostRow {
  TOTAL_ROWS: number;
  DURATION_SECONDS: number;
  FIRST_EVENT: string;
  LAST_EVENT: string;
}

export async function GET() {
  try {
    const sql = `
      SELECT 
        COUNT(*) as total_rows,
        TIMESTAMPDIFF(SECOND, MIN(EVENT_TIMESTAMP), MAX(EVENT_TIMESTAMP)) as duration_seconds,
        MIN(EVENT_TIMESTAMP) as first_event,
        MAX(EVENT_TIMESTAMP) as last_event
      FROM PHANTOM_IROPS.RAW.FLIGHT_EVENTS_STREAMING
    `;

    const rows = await query<CostRow>(sql);
    const row = rows[0];

    const totalRows = row?.TOTAL_ROWS || 0;
    const durationSec = Math.max(row?.DURATION_SECONDS || 1, 1);
    
    const avgRowSizeBytes = 250;
    const dataGb = (totalRows * avgRowSizeBytes) / (1024 * 1024 * 1024);
    
    const creditsPerThousandRows = 0.000024;
    const estimatedCredits = (totalRows / 1000) * creditsPerThousandRows;
    const creditPriceUsd = 3.00;
    const estimatedCostUsd = estimatedCredits * creditPriceUsd;
    
    const rowsPerSecond = totalRows / durationSec;
    const gbPerHour = (dataGb / durationSec) * 3600;
    const costPerMillionRows = totalRows > 0 ? (estimatedCostUsd / totalRows) * 1000000 : 0;
    const costPerGb = dataGb > 0 ? estimatedCostUsd / dataGb : 0;

    return NextResponse.json({
      totalRows,
      dataGb: Math.round(dataGb * 1000) / 1000,
      durationSeconds: durationSec,
      durationMinutes: Math.round(durationSec / 60 * 10) / 10,
      rowsPerSecond: Math.round(rowsPerSecond),
      gbPerHour: Math.round(gbPerHour * 100) / 100,
      estimatedCredits: Math.round(estimatedCredits * 10000) / 10000,
      estimatedCostUsd: Math.round(estimatedCostUsd * 100) / 100,
      costPerMillionRows: Math.round(costPerMillionRows * 100) / 100,
      costPerGb: Math.round(costPerGb * 100) / 100,
      warehouseEquivalentCost: Math.round((durationSec / 3600) * 4 * 100) / 100,
      savingsPercent: Math.round((1 - estimatedCostUsd / Math.max((durationSec / 3600) * 4, 0.01)) * 100),
      firstEvent: row?.FIRST_EVENT,
      lastEvent: row?.LAST_EVENT,
    });
  } catch (error) {
    console.error("Streaming cost error:", error);
    return NextResponse.json({
      totalRows: 0,
      dataGb: 0,
      estimatedCredits: 0,
      estimatedCostUsd: 0,
      error: error instanceof Error ? error.message : "Unknown error"
    });
  }
}
