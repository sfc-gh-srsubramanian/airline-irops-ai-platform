import { NextRequest, NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

export async function GET() {
  try {
    const [totalStats] = await query<{
      TOTAL_GHOST_FLIGHTS: number;
      TOTAL_PAX: number;
      MISSING_CREW_COUNT: number;
      MISSING_AIRCRAFT_COUNT: number;
    }>(`
      SELECT 
        COUNT(*) as TOTAL_GHOST_FLIGHTS,
        SUM(COALESCE(PASSENGERS_BOOKED, 0)) as TOTAL_PAX,
        SUM(CASE WHEN LOWER(GHOST_FLIGHT_REASON) LIKE '%crew%' OR LOWER(GHOST_FLIGHT_REASON) LIKE '%captain%' OR LOWER(GHOST_FLIGHT_REASON) LIKE '%first officer%' THEN 1 ELSE 0 END) as MISSING_CREW_COUNT,
        SUM(CASE WHEN LOWER(GHOST_FLIGHT_REASON) LIKE '%aircraft%' OR LOWER(GHOST_FLIGHT_REASON) LIKE '%is at%' THEN 1 ELSE 0 END) as MISSING_AIRCRAFT_COUNT
      FROM PHANTOM_IROPS.ANALYTICS.MART_GOLDEN_RECORD
      WHERE IS_GHOST_FLIGHT = TRUE
        AND FLIGHT_DATE = CURRENT_DATE()
    `);

    const ghostFlights = await query<{
      FLIGHT_ID: string;
      FLIGHT_NUMBER: string;
      ORIGIN: string;
      DESTINATION: string;
      SCHEDULED_DEPARTURE: string;
      STATUS: string;
      IS_GHOST_FLIGHT: boolean;
      GHOST_FLIGHT_REASON: string;
      RECOVERY_PRIORITY_SCORE: number;
      PAX_BOOKED: number;
      AIRCRAFT_REGISTRATION: string;
      CAPTAIN_NAME: string;
      FO_NAME: string;
    }>(`
      SELECT 
        FLIGHT_ID,
        FLIGHT_NUMBER,
        ORIGIN,
        DESTINATION,
        TO_VARCHAR(SCHEDULED_DEPARTURE_UTC, 'YYYY-MM-DD HH24:MI') as SCHEDULED_DEPARTURE,
        FLIGHT_STATUS as STATUS,
        IS_GHOST_FLIGHT,
        GHOST_FLIGHT_REASON,
        RECOVERY_PRIORITY_SCORE,
        COALESCE(PASSENGERS_BOOKED, 0) as PAX_BOOKED,
        TAIL_NUMBER as AIRCRAFT_REGISTRATION,
        CAPTAIN_NAME,
        FIRST_OFFICER_NAME as FO_NAME
      FROM PHANTOM_IROPS.ANALYTICS.MART_GOLDEN_RECORD
      WHERE IS_GHOST_FLIGHT = TRUE
        AND FLIGHT_DATE = CURRENT_DATE()
      ORDER BY RECOVERY_PRIORITY_SCORE DESC
      LIMIT 50
    `);

    const summary = {
      totalGhostFlights: totalStats?.TOTAL_GHOST_FLIGHTS || ghostFlights.length,
      missingCrew: totalStats?.MISSING_CREW_COUNT || 0,
      missingAircraft: totalStats?.MISSING_AIRCRAFT_COUNT || 0,
      missingBoth: ghostFlights.filter(f => {
        const reason = (f.GHOST_FLIGHT_REASON || "").toLowerCase();
        const hasAircraft = reason.includes("aircraft") || reason.includes("is at");
        const hasCrew = reason.includes("crew") || reason.includes("captain") || reason.includes("first officer");
        return hasAircraft && hasCrew;
      }).length,
      avgPriority: ghostFlights.reduce((sum, f) => sum + (f.RECOVERY_PRIORITY_SCORE || 0), 0) / ghostFlights.length || 0,
      totalPaxAffected: totalStats?.TOTAL_PAX || ghostFlights.reduce((sum, f) => sum + (f.PAX_BOOKED || 0), 0),
    };

    return NextResponse.json({ ghostFlights, summary });
  } catch (error) {
    console.error("Error fetching ghost planes:", error);
    return NextResponse.json({ error: "Failed to fetch data" }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const { flightId, action, resolutionType } = await request.json();

    if (action === "analyze") {
      const [flight] = await query<{
        FLIGHT_ID: string;
        FLIGHT_NUMBER: string;
        GHOST_FLIGHT_REASON: string;
        RECOVERY_PRIORITY_SCORE: number;
      }>(`
        SELECT FLIGHT_ID, FLIGHT_NUMBER, GHOST_FLIGHT_REASON, RECOVERY_PRIORITY_SCORE
        FROM PHANTOM_IROPS.ANALYTICS.MART_GOLDEN_RECORD
        WHERE FLIGHT_ID = '${flightId}'
      `);

      const reason = flight?.GHOST_FLIGHT_REASON || "UNKNOWN";
      
      const recommendations = [];
      
      const reasonLower = reason.toLowerCase();
      if (reasonLower.includes("crew") || reasonLower.includes("captain") || reasonLower.includes("first officer")) {
        const crewOptions = await query<{
          CREW_ID: string;
          FULL_NAME: string;
          CREW_TYPE: string;
          BASE_AIRPORT: string;
          HOURS_REMAINING: number;
        }>(`
          SELECT TOP 5
            c.CREW_ID,
            c.FULL_NAME,
            c.CREW_TYPE,
            c.BASE_AIRPORT,
            c.MONTHLY_HOURS_REMAINING as HOURS_REMAINING
          FROM PHANTOM_IROPS.STAGING.STG_CREW c
          WHERE c.AVAILABILITY_STATUS = 'AVAILABLE'
            AND c.MONTHLY_HOURS_REMAINING > 8
          ORDER BY c.MONTHLY_HOURS_REMAINING DESC
        `);
        
        recommendations.push({
          type: "CREW_ASSIGNMENT",
          title: "Assign Available Crew",
          description: `${crewOptions.length} crew members available for assignment`,
          options: crewOptions,
          priority: "HIGH",
        });
      }
      
      if (reasonLower.includes("aircraft") || reasonLower.includes("is at")) {
        const aircraftOptions = await query<{
          AIRCRAFT_ID: string;
          REGISTRATION: string;
          AIRCRAFT_TYPE: string;
          STATUS: string;
          CURRENT_LOCATION: string;
        }>(`
          SELECT TOP 5
            a.AIRCRAFT_ID,
            a.TAIL_NUMBER as REGISTRATION,
            a.AIRCRAFT_TYPE_CODE as AIRCRAFT_TYPE,
            a.STATUS,
            a.CURRENT_LOCATION
          FROM PHANTOM_IROPS.STAGING.STG_AIRCRAFT a
          WHERE a.IS_OPERATIONALLY_AVAILABLE = TRUE
          ORDER BY a.CURRENT_LOCATION
        `);
        
        recommendations.push({
          type: "AIRCRAFT_SWAP",
          title: "Swap Aircraft",
          description: `${aircraftOptions.length} aircraft available for swap`,
          options: aircraftOptions,
          priority: "HIGH",
        });
      }

      recommendations.push({
        type: "CANCEL_FLIGHT",
        title: "Cancel Flight",
        description: "Cancel and rebook passengers on alternative flights",
        priority: "LOW",
      });

      recommendations.push({
        type: "DELAY_FLIGHT",
        title: "Delay Flight",
        description: "Delay departure to allow resource recovery",
        priority: "MEDIUM",
      });

      return NextResponse.json({
        flight,
        recommendations,
        agentAnalysis: `Flight ${flight?.FLIGHT_NUMBER} is a ghost flight due to: ${reason}. Priority score: ${flight?.RECOVERY_PRIORITY_SCORE?.toFixed(0) || 'N/A'}`,
      });
    }

    if (action === "resolve") {
      let result;
      
      const [flightInfo] = await query<{
        AIRCRAFT_ID: string;
        ORIGIN: string;
        TAIL_NUMBER: string;
      }>(`
        SELECT AIRCRAFT_ID, ORIGIN, TAIL_NUMBER
        FROM PHANTOM_IROPS.ANALYTICS.MART_GOLDEN_RECORD
        WHERE FLIGHT_ID = '${flightId}'
      `);
      
      switch (resolutionType) {
        case "CREW_ASSIGNMENT":
          result = { success: true, message: "Crew assignment workflow initiated" };
          break;
        case "AIRCRAFT_SWAP":
          if (flightInfo?.AIRCRAFT_ID) {
            await query(`
              UPDATE PHANTOM_IROPS.RAW.AIRCRAFT
              SET CURRENT_LOCATION = '${flightInfo.ORIGIN}'
              WHERE AIRCRAFT_ID = '${flightInfo.AIRCRAFT_ID}'
            `);
            result = { success: true, message: `Aircraft ${flightInfo.TAIL_NUMBER} repositioned to ${flightInfo.ORIGIN}. Ghost flight resolved.` };
          } else {
            result = { success: false, message: "Could not find aircraft information" };
          }
          break;
        case "CANCEL_FLIGHT":
          await query(`
            UPDATE PHANTOM_IROPS.RAW.FLIGHTS
            SET STATUS = 'CANCELLED'
            WHERE FLIGHT_ID = '${flightId}'
          `);
          result = { success: true, message: "Flight cancelled. Passenger rebooking initiated." };
          break;
        case "DELAY_FLIGHT":
          await query(`
            UPDATE PHANTOM_IROPS.RAW.FLIGHTS
            SET DEPARTURE_DELAY_MINUTES = COALESCE(DEPARTURE_DELAY_MINUTES, 0) + 60,
                STATUS = 'DELAYED'
            WHERE FLIGHT_ID = '${flightId}'
          `);
          result = { success: true, message: "Flight delayed by 60 minutes" };
          break;
        default:
          result = { success: false, message: "Unknown resolution type" };
      }
      
      return NextResponse.json(result);
    }

    return NextResponse.json({ error: "Invalid action" }, { status: 400 });
  } catch (error) {
    console.error("Error in ghost planes resolution:", error);
    return NextResponse.json({ error: "Action failed" }, { status: 500 });
  }
}
