import { NextRequest, NextResponse } from "next/server";
import snowflake from "snowflake-sdk";

snowflake.configure({ logLevel: "ERROR" });

const SEMANTIC_VIEW = "PHANTOM_IROPS.SEMANTIC_MODELS.IROPS_ANALYTICS";

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

interface AnalystContent {
  type: string;
  text?: string;
  statement?: string;
  suggestions?: string[];
}

interface AnalystResponse {
  message: {
    content: AnalystContent[];
  };
  request_id?: string;
}

async function callCortexAnalystSQL(
  conn: snowflake.Connection,
  userMessage: string
): Promise<AnalystResponse> {
  const prompt = JSON.stringify({
    messages: [
      { role: "user", content: [{ type: "text", text: userMessage }] }
    ],
    semantic_view: SEMANTIC_VIEW
  });

  const sql = `SELECT SNOWFLAKE.CORTEX.ANALYST_PREVIEW('${prompt.replace(/'/g, "''")}') as RESPONSE`;

  return new Promise((resolve, reject) => {
    conn.execute({
      sqlText: sql,
      complete: (err, stmt, rows) => {
        if (err) reject(err);
        else {
          const responseStr = (rows as Array<{ RESPONSE: string }>)?.[0]?.RESPONSE;
          if (responseStr) {
            try {
              const parsed = JSON.parse(responseStr);
              resolve(parsed);
            } catch {
              reject(new Error(`Failed to parse Analyst response: ${responseStr}`));
            }
          } else {
            reject(new Error("No response from Cortex Analyst"));
          }
        }
      },
    });
  });
}

async function executeSQL(conn: snowflake.Connection, sql: string): Promise<Record<string, unknown>[]> {
  return new Promise((resolve, reject) => {
    conn.execute({
      sqlText: sql,
      complete: (err, stmt, rows) => {
        if (err) reject(err);
        else resolve((rows || []) as Record<string, unknown>[]);
      },
    });
  });
}

export async function POST(request: NextRequest) {
  try {
    const { message } = await request.json();

    const conn = await getConnection();
    const analystResponse = await callCortexAnalystSQL(conn, message);
    const content = analystResponse.message.content;

    let textResponse = "";
    let sqlStatement = "";
    let sqlResults: Record<string, unknown>[] = [];
    let suggestions: string[] = [];

    for (const item of content) {
      if (item.type === "text" && item.text) {
        textResponse += item.text + "\n";
      } else if (item.type === "sql" && item.statement) {
        sqlStatement = item.statement;
        try {
          sqlResults = await executeSQL(conn, sqlStatement);
        } catch (sqlErr) {
          textResponse += `\n\nSQL execution error: ${(sqlErr as Error).message}`;
        }
      } else if (item.type === "suggestions" && item.suggestions) {
        suggestions = item.suggestions;
      }
    }

    return NextResponse.json({
      response: textResponse.trim(),
      sql: sqlStatement || undefined,
      results: sqlResults.length > 0 ? sqlResults : undefined,
      suggestions: suggestions.length > 0 ? suggestions : undefined,
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
