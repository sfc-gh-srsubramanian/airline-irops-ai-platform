import { NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

interface StatsRow {
  TOTAL_EVENTS: number;
  EVENTS_LAST_5_MIN: number;
  AVG_LATENCY_MS: number;
  LATEST_EVENT: string | null;
}

export async function GET() {
  try {
    const sql = `
      WITH recent AS (
        SELECT 
          EVENT_TIMESTAMP,
          RECORD_METADATA:CreateTime::NUMBER as create_time
        FROM PHANTOM_IROPS.RAW.FLIGHT_EVENTS_STREAMING
        WHERE EVENT_TIMESTAMP >= DATEADD(MINUTE, -10, CURRENT_TIMESTAMP())
        LIMIT 100000
      ),
      total_count AS (
        SELECT APPROX_COUNT_DISTINCT(EVENT_ID) * 1.05 as approx_total
        FROM PHANTOM_IROPS.RAW.FLIGHT_EVENTS_STREAMING
      )
      SELECT 
        (SELECT COUNT(*) FROM PHANTOM_IROPS.RAW.FLIGHT_EVENTS_STREAMING) AS total_events,
        (SELECT COUNT(*) FROM recent WHERE EVENT_TIMESTAMP >= DATEADD(MINUTE, -5, CURRENT_TIMESTAMP())) AS events_last_5_min,
        (SELECT ABS(AVG(TIMESTAMPDIFF(MILLISECOND, EVENT_TIMESTAMP, TO_TIMESTAMP(create_time / 1000)))) FROM recent LIMIT 1000) AS avg_latency_ms,
        (SELECT MAX(EVENT_TIMESTAMP) FROM recent) AS latest_event
    `;

    const rows = await query<StatsRow>(sql);
    const row = rows[0];

    return NextResponse.json({
      totalEvents: row?.TOTAL_EVENTS || 0,
      eventsLast5Min: row?.EVENTS_LAST_5_MIN || 0,
      avgLatencyMs: Math.round(row?.AVG_LATENCY_MS || 0),
      streamHasData: (row?.EVENTS_LAST_5_MIN || 0) > 0,
      latestEvent: row?.LATEST_EVENT || null,
    });
  } catch (error) {
    console.error("Streaming stats error:", error);
    return NextResponse.json({
      totalEvents: 0,
      eventsLast5Min: 0,
      avgLatencyMs: 0,
      streamHasData: false,
      latestEvent: null,
      error: error instanceof Error ? error.message : "Unknown error"
    });
  }
}
