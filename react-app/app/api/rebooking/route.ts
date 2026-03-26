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
      WITH balanced AS (
        SELECT *,
          ROW_NUMBER() OVER (
            PARTITION BY LOYALTY_TIER
            ORDER BY MINUTES_AFTER_ORIGINAL
          ) AS tier_rank
        FROM PHANTOM_IROPS.ANALYTICS.REBOOKING_OPTIONS
        WHERE ORIGINAL_STATUS = 'CANCELLED'
          AND DATE(ORIGINAL_DEPARTURE) = CURRENT_DATE()
          AND OPTION_RANK = 1
      )
      SELECT 
        b.BOOKING_ID,
        b.CONFIRMATION_CODE,
        b.FIRST_NAME,
        b.LAST_NAME,
        b.LOYALTY_TIER,
        b.ORIGINAL_FLIGHT_NUMBER,
        b.ORIGIN,
        b.DESTINATION,
        b.ORIGINAL_STATUS,
        b.REBOOK_FLIGHT_NUMBER,
        b.REBOOK_DEPARTURE,
        b.AVAILABLE_SEATS,
        b.MINUTES_AFTER_ORIGINAL,
        b.OPTION_RANK
      FROM balanced b
      WHERE b.tier_rank <= 20
      ORDER BY 
        CASE b.LOYALTY_TIER 
          WHEN 'DIAMOND' THEN 1 
          WHEN 'PLATINUM' THEN 2 
          WHEN 'GOLD' THEN 3 
          WHEN 'SILVER' THEN 4 
          ELSE 5 
        END,
        b.MINUTES_AFTER_ORIGINAL
    `);

    return NextResponse.json({ data });
  } catch (error) {
    console.error("Error fetching rebooking data:", error);
    return NextResponse.json({ error: "Failed to fetch rebooking data" }, { status: 500 });
  }
}
