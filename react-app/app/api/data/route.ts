import { NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const timeRange = searchParams.get("timeRange") || "today";

  let dateFilter = "FLIGHT_DATE = CURRENT_DATE()";
  let otpDays = 1;

  switch (timeRange) {
    case "next2hours":
      dateFilter = "SCHEDULED_DEPARTURE_UTC BETWEEN CURRENT_TIMESTAMP() AND TIMESTAMPADD('hour', 2, CURRENT_TIMESTAMP())";
      break;
    case "next6hours":
      dateFilter = "SCHEDULED_DEPARTURE_UTC BETWEEN CURRENT_TIMESTAMP() AND TIMESTAMPADD('hour', 6, CURRENT_TIMESTAMP())";
      break;
    case "today":
      dateFilter = "FLIGHT_DATE = CURRENT_DATE()";
      break;
    case "tomorrow":
      dateFilter = "FLIGHT_DATE = DATEADD('day', 1, CURRENT_DATE())";
      break;
    case "last7days":
      dateFilter = "FLIGHT_DATE BETWEEN DATEADD('day', -7, CURRENT_DATE()) AND CURRENT_DATE()";
      otpDays = 7;
      break;
  }

  try {
    const [summary] = await query<{
      TOTAL_FLIGHTS: number;
      DELAYED_FLIGHTS: number;
      CANCELLED_FLIGHTS: number;
      ON_TIME_FLIGHTS: number;
      IN_PROGRESS_FLIGHTS: number;
      TOTAL_PASSENGERS_AFFECTED: number;
      AVG_DELAY_MINUTES: number;
    }>(`
      SELECT 
        COUNT(*) as TOTAL_FLIGHTS,
        COUNT(CASE WHEN STATUS = 'DELAYED' OR (STATUS = 'ARRIVED' AND DEPARTURE_DELAY_MINUTES > 15) THEN 1 END) as DELAYED_FLIGHTS,
        COUNT(CASE WHEN STATUS = 'CANCELLED' THEN 1 END) as CANCELLED_FLIGHTS,
        COUNT(CASE WHEN STATUS IN ('ON_TIME', 'SCHEDULED') OR (STATUS = 'ARRIVED' AND (DEPARTURE_DELAY_MINUTES IS NULL OR DEPARTURE_DELAY_MINUTES <= 15)) THEN 1 END) as ON_TIME_FLIGHTS,
        COUNT(CASE WHEN STATUS = 'IN_FLIGHT' THEN 1 END) as IN_PROGRESS_FLIGHTS,
        SUM(CASE WHEN STATUS IN ('DELAYED', 'CANCELLED') OR (STATUS = 'ARRIVED' AND DEPARTURE_DELAY_MINUTES > 15) THEN PASSENGERS_BOOKED ELSE 0 END) as TOTAL_PASSENGERS_AFFECTED,
        AVG(CASE WHEN DEPARTURE_DELAY_MINUTES > 0 THEN DEPARTURE_DELAY_MINUTES END) as AVG_DELAY_MINUTES
      FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
      WHERE ${dateFilter}
    `);

    const hubStats = await query<{
      ORIGIN: string;
      FLIGHT_COUNT: number;
      DELAYED_COUNT: number;
      AVG_DELAY: number;
    }>(`
      SELECT 
        ORIGIN,
        COUNT(*) as FLIGHT_COUNT,
        COUNT(CASE WHEN STATUS = 'DELAYED' OR (STATUS = 'ARRIVED' AND DEPARTURE_DELAY_MINUTES > 15) THEN 1 END) as DELAYED_COUNT,
        AVG(DEPARTURE_DELAY_MINUTES) as AVG_DELAY
      FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
      WHERE ${dateFilter}
      GROUP BY ORIGIN
      ORDER BY DELAYED_COUNT DESC
      LIMIT 8
    `);

    const otpTrend = await query<{
      DATE_LABEL: string;
      OTP: number;
      FLIGHTS: number;
    }>(`
      SELECT 
        ${otpDays > 1 
          ? "TO_CHAR(FLIGHT_DATE, 'MM/DD') as DATE_LABEL" 
          : "TO_CHAR(HOUR(SCHEDULED_DEPARTURE_UTC), 'FM00') || ':00' as DATE_LABEL"},
        ROUND(100.0 * COUNT(CASE WHEN STATUS IN ('ON_TIME', 'SCHEDULED') OR (STATUS = 'ARRIVED' AND (DEPARTURE_DELAY_MINUTES IS NULL OR DEPARTURE_DELAY_MINUTES <= 15)) THEN 1 END) / NULLIF(COUNT(CASE WHEN STATUS NOT IN ('CANCELLED') THEN 1 END), 0), 1) as OTP,
        COUNT(*) as FLIGHTS
      FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
      WHERE ${otpDays > 1 ? "FLIGHT_DATE BETWEEN DATEADD('day', -7, CURRENT_DATE()) AND CURRENT_DATE()" : "FLIGHT_DATE = CURRENT_DATE()"}
      GROUP BY ${otpDays > 1 ? "FLIGHT_DATE" : "HOUR(SCHEDULED_DEPARTURE_UTC)"}
      ORDER BY ${otpDays > 1 ? "FLIGHT_DATE" : "HOUR(SCHEDULED_DEPARTURE_UTC)"}
    `);

    return NextResponse.json({
      summary: summary || {
        TOTAL_FLIGHTS: 0,
        DELAYED_FLIGHTS: 0,
        CANCELLED_FLIGHTS: 0,
        ON_TIME_FLIGHTS: 0,
        IN_PROGRESS_FLIGHTS: 0,
        TOTAL_PASSENGERS_AFFECTED: 0,
        AVG_DELAY_MINUTES: 0,
      },
      hubStats,
      otpTrend,
      timeRange,
    });
  } catch (error) {
    console.error("Error fetching operations data:", error);
    return NextResponse.json({ error: "Failed to fetch data" }, { status: 500 });
  }
}
