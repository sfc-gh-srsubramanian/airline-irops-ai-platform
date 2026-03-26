import { NextRequest, NextResponse } from "next/server";
import { callAgent } from "@/lib/snowflake";

export async function POST(request: NextRequest) {
  try {
    const { message } = await request.json();

    const response = await callAgent(message);

    return NextResponse.json({
      response: response.trim(),
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Agent error:", error);
    return NextResponse.json({
      response: `Error: ${(error as Error).message}`,
      error: true,
    }, { status: 500 });
  }
}
