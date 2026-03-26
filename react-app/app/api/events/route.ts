import { NextRequest, NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

interface FlightEvent {
  EVENT_ID: string;
  FLIGHT_ID: string;
  EVENT_TYPE: string;
  EVENT_TIMESTAMP: string;
  NEW_STATUS: string | null;
  PREVIOUS_STATUS: string | null;
  DELAY_MINUTES: number | null;
  DELAY_CODE: string | null;
  DELAY_REASON: string | null;
  DEPARTURE_GATE: string | null;
  ARRIVAL_GATE: string | null;
  SOURCE_SYSTEM: string | null;
  INGESTED_AT: string | null;
  FLIGHT_NUMBER: string | null;
  ORIGIN: string | null;
  DESTINATION: string | null;
  SCHEDULED_DEPARTURE_UTC: string | null;
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const limit = Math.min(parseInt(searchParams.get("limit") || "20"), 100);
    const eventType = searchParams.get("type");

    let sql = `
      SELECT 
        e.EVENT_ID,
        e.FLIGHT_ID,
        e.EVENT_TYPE,
        e.EVENT_TIMESTAMP,
        e.NEW_STATUS,
        e.PREVIOUS_STATUS,
        e.DELAY_MINUTES,
        e.DELAY_CODE,
        e.DELAY_REASON,
        e.DEPARTURE_GATE,
        e.ARRIVAL_GATE,
        e.SOURCE_SYSTEM,
        e.EVENT_TIMESTAMP AS INGESTED_AT,
        f.FLIGHT_NUMBER,
        f.ORIGIN,
        f.DESTINATION,
        f.SCHEDULED_DEPARTURE_UTC
      FROM PHANTOM_IROPS.RAW.FLIGHT_EVENTS_STREAMING e
      LEFT JOIN PHANTOM_IROPS.RAW.FLIGHTS f ON e.FLIGHT_ID = f.FLIGHT_ID
    `;

    if (eventType) {
      sql += ` WHERE e.EVENT_TYPE = '${eventType}'`;
    }

    sql += ` ORDER BY e.EVENT_TIMESTAMP DESC LIMIT ${limit}`;

    const events = await query<FlightEvent>(sql);

    return NextResponse.json({
      events,
      count: events.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Events API error:", error);
    return NextResponse.json(
      { 
        error: "Failed to fetch events",
        message: error instanceof Error ? error.message : "Unknown error",
        events: []
      },
      { status: 500 }
    );
  }
}
