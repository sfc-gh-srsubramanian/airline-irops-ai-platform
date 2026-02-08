import { NextRequest, NextResponse } from "next/server";
import snowflake from "snowflake-sdk";

snowflake.configure({ logLevel: "ERROR" });

async function getConnection(): Promise<snowflake.Connection> {
  const conn = snowflake.createConnection({
    account: process.env.SNOWFLAKE_ACCOUNT || "SFSENORTHAMERICA-SRSUBRAMANIAN_AWS1",
    username: process.env.SNOWFLAKE_USER || "SRSUBRAMANIAN",
    password: process.env.SNOWFLAKE_PASSWORD,
    warehouse: process.env.SNOWFLAKE_WAREHOUSE || "PHANTOM_IROPS_WH",
    database: process.env.SNOWFLAKE_DATABASE || "PHANTOM_IROPS",
    schema: process.env.SNOWFLAKE_SCHEMA || "ANALYTICS",
    authenticator: "SNOWFLAKE",
  });

  return new Promise((resolve, reject) => {
    conn.connect((err, conn) => {
      if (err) reject(err);
      else resolve(conn);
    });
  });
}

async function callCortexComplete(
  conn: snowflake.Connection,
  userMessage: string
): Promise<string> {
  const escapedMessage = userMessage.replace(/'/g, "''");
  const sql = `
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
      'claude-3-5-sonnet',
      'You are an airline IROPS operations assistant. Provide brief, actionable recommendations. User query: ${escapedMessage}'
    ) as RESPONSE
  `;

  return new Promise((resolve, reject) => {
    conn.execute({
      sqlText: sql,
      complete: (err, stmt, rows) => {
        if (err) reject(err);
        else {
          const response = (rows as Array<{ RESPONSE: string }>)?.[0]?.RESPONSE;
          resolve(response || "No recommendation available.");
        }
      },
    });
  });
}

export async function POST(request: NextRequest) {
  try {
    const { message } = await request.json();

    const conn = await getConnection();
    const response = await callCortexComplete(conn, message);

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
