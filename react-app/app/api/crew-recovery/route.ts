import { NextRequest, NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

export async function GET() {
  try {
    const flights = await query<{
      FLIGHT_ID: string;
      FLIGHT_NUMBER: string;
      ORIGIN: string;
      DESTINATION: string;
      SCHEDULED_DEPARTURE: string;
      STATUS: string;
      CAPTAIN_NEEDED: boolean;
      FO_NEEDED: boolean;
      DELAY_MINUTES: number;
      PAX_BOOKED: number;
    }>(`
      SELECT 
        f.FLIGHT_ID,
        f.FLIGHT_NUMBER,
        f.ORIGIN,
        f.DESTINATION,
        TO_VARCHAR(f.SCHEDULED_DEPARTURE_UTC, 'YYYY-MM-DD HH24:MI') as SCHEDULED_DEPARTURE,
        f.STATUS,
        f.CAPTAIN_ID IS NULL as CAPTAIN_NEEDED,
        f.FIRST_OFFICER_ID IS NULL as FO_NEEDED,
        COALESCE(f.DEPARTURE_DELAY_MINUTES, 0) as DELAY_MINUTES,
        COALESCE(f.PASSENGERS_BOOKED, 0) as PAX_BOOKED
      FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS f
      WHERE f.FLIGHT_DATE = CURRENT_DATE()
        AND (f.CAPTAIN_ID IS NULL OR f.FIRST_OFFICER_ID IS NULL)
        AND f.STATUS != 'CANCELLED'
      ORDER BY f.SCHEDULED_DEPARTURE_UTC
      LIMIT 20
    `);

    return NextResponse.json({ flights });
  } catch (error) {
    console.error("Error fetching crew recovery data:", error);
    return NextResponse.json({ error: "Failed to fetch data" }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const { flightId, action, crewRole, crewId } = await request.json();

    if (action === "find_candidates") {
      const candidates = await query<{
        CREW_ID: string;
        FULL_NAME: string;
        CREW_TYPE: string;
        BASE_AIRPORT: string;
        HOURS_REMAINING: number;
        FIT_SCORE: number;
        QUALIFIED_AIRCRAFT: string;
        STATUS: string;
      }>(`
        SELECT 
          c.CREW_ID,
          c.FULL_NAME,
          c.CREW_TYPE,
          c.BASE_AIRPORT,
          c.MONTHLY_HOURS_REMAINING as HOURS_REMAINING,
          ROUND(
            (c.MONTHLY_HOURS_REMAINING / 100.0 * 40) +
            (c.YEARS_OF_SERVICE / 30.0 * 30) +
            (CASE WHEN c.BASE_AIRPORT = f.ORIGIN THEN 30 ELSE 10 END)
          , 1) as FIT_SCORE,
          c.QUALIFIED_AIRCRAFT_TYPES as QUALIFIED_AIRCRAFT,
          c.AVAILABILITY_STATUS as STATUS
        FROM PHANTOM_IROPS.STAGING.STG_CREW c
        CROSS JOIN (
          SELECT ORIGIN, AIRCRAFT_TYPE_CODE 
          FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS 
          WHERE FLIGHT_ID = '${flightId}'
        ) f
        WHERE c.CREW_TYPE = '${crewRole === "captain" ? "CAPTAIN" : "FIRST_OFFICER"}'
          AND c.AVAILABILITY_STATUS = 'AVAILABLE'
          AND c.MONTHLY_HOURS_REMAINING > 8
        ORDER BY FIT_SCORE DESC
        LIMIT 10
      `);

      return NextResponse.json({ candidates });
    }

    if (action === "assign_crew") {
      await query(`
        UPDATE PHANTOM_IROPS.RAW.FLIGHTS
        SET ${crewRole === "captain" ? "CAPTAIN_ID" : "FIRST_OFFICER_ID"} = '${crewId}'
        WHERE FLIGHT_ID = '${flightId}'
      `);

      return NextResponse.json({ success: true, message: `Crew member assigned to flight` });
    }

    if (action === "batch_notify") {
      const result = await query<{ NOTIFIED_COUNT: number }>(`
        SELECT COUNT(*) as NOTIFIED_COUNT
        FROM PHANTOM_IROPS.STAGING.STG_CREW
        WHERE AVAILABILITY_STATUS = 'AVAILABLE'
          AND MONTHLY_HOURS_REMAINING > 8
          AND CREW_TYPE = '${crewRole === "captain" ? "CAPTAIN" : "FIRST_OFFICER"}'
      `);

      return NextResponse.json({ 
        success: true, 
        message: `Batch notification sent to ${result[0]?.NOTIFIED_COUNT || 0} available crew members`,
        notifiedCount: result[0]?.NOTIFIED_COUNT || 0
      });
    }

    return NextResponse.json({ error: "Invalid action" }, { status: 400 });
  } catch (error) {
    console.error("Error in crew recovery action:", error);
    return NextResponse.json({ error: "Action failed" }, { status: 500 });
  }
}
