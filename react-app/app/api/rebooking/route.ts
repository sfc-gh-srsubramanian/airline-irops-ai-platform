import { NextResponse } from "next/server";
import { query } from "@/lib/snowflake";

export async function GET() {
  try {
    const data = await query<{
      BOOKING_ID: string;
      CONFIRMATION_CODE: string;
      FIRST_NAME: string;
      LAST_NAME: string;
      LOYALTY_TIER: string;
      ORIGINAL_FLIGHT_NUMBER: string;
      ORIGIN: string;
      DESTINATION: string;
      ORIGINAL_STATUS: string;
      REBOOK_FLIGHT_NUMBER: string;
      REBOOK_DEPARTURE: string;
      AVAILABLE_SEATS: number;
      MINUTES_AFTER_ORIGINAL: number;
      OPTION_RANK: number;
    }>(`
      SELECT 
        BOOKING_ID,
        CONFIRMATION_CODE,
        FIRST_NAME,
        LAST_NAME,
        LOYALTY_TIER,
        ORIGINAL_FLIGHT_NUMBER,
        ORIGIN,
        DESTINATION,
        ORIGINAL_STATUS,
        REBOOK_FLIGHT_NUMBER,
        REBOOK_DEPARTURE,
        AVAILABLE_SEATS,
        MINUTES_AFTER_ORIGINAL,
        OPTION_RANK
      FROM PHANTOM_IROPS.ANALYTICS.REBOOKING_OPTIONS
      WHERE ORIGINAL_STATUS = 'CANCELLED'
        AND DATE(ORIGINAL_DEPARTURE) = CURRENT_DATE()
        AND OPTION_RANK <= 3
      ORDER BY 
        CASE LOYALTY_TIER 
          WHEN 'DIAMOND' THEN 1 
          WHEN 'PLATINUM' THEN 2 
          WHEN 'GOLD' THEN 3 
          WHEN 'SILVER' THEN 4 
          ELSE 5 
        END,
        OPTION_RANK,
        MINUTES_AFTER_ORIGINAL
      LIMIT 100
    `);

    return NextResponse.json({ data });
  } catch (error) {
    console.error("Error fetching rebooking data:", error);
    return NextResponse.json({ error: "Failed to fetch rebooking data" }, { status: 500 });
  }
}
