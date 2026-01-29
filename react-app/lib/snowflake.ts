import snowflake from "snowflake-sdk";
import fs from "fs";

snowflake.configure({ logLevel: "ERROR" });

let connection: snowflake.Connection | null = null;
let cachedToken: string | null = null;

function getOAuthToken(): string | null {
  const tokenPath = "/snowflake/session/token";
  try {
    if (fs.existsSync(tokenPath)) {
      return fs.readFileSync(tokenPath, "utf8");
    }
  } catch {
    // Not in SPCS environment
  }
  return null;
}

function getConfig(): snowflake.ConnectionOptions {
  const base = {
    account: process.env.SNOWFLAKE_ACCOUNT || "SFSENORTHAMERICA-SRSUBRAMANIAN_AWS1",
    warehouse: process.env.SNOWFLAKE_WAREHOUSE || "PHANTOM_IROPS_WH",
    database: process.env.SNOWFLAKE_DATABASE || "PHANTOM_IROPS",
    schema: process.env.SNOWFLAKE_SCHEMA || "ANALYTICS",
  };

  const token = getOAuthToken();
  if (token) {
    return {
      ...base,
      host: process.env.SNOWFLAKE_HOST,
      token,
      authenticator: "oauth",
    };
  }

  return {
    ...base,
    username: process.env.SNOWFLAKE_USER || "SRSUBRAMANIAN",
    password: process.env.SNOWFLAKE_PASSWORD,
    authenticator: "SNOWFLAKE",
  };
}

async function getConnection(): Promise<snowflake.Connection> {
  const token = getOAuthToken();

  if (connection && (!token || token === cachedToken)) {
    return connection;
  }

  if (connection) {
    console.log("OAuth token changed, reconnecting");
    connection.destroy(() => {});
  }

  console.log(token ? "Connecting with OAuth token" : "Connecting with password auth");
  const conn = snowflake.createConnection(getConfig());
  
  return new Promise((resolve, reject) => {
    conn.connect((err, conn) => {
      if (err) {
        console.error("Connection failed:", err.message);
        reject(err);
      } else {
        connection = conn;
        cachedToken = token;
        resolve(conn);
      }
    });
  });
}

function isRetryableError(err: unknown): boolean {
  const error = err as { message?: string; code?: number };
  return !!(
    error.message?.includes("OAuth access token expired") ||
    error.message?.includes("terminated connection") ||
    error.code === 407002
  );
}

export async function query<T>(sql: string, retries = 1): Promise<T[]> {
  try {
    const conn = await getConnection();
    return await new Promise<T[]>((resolve, reject) => {
      conn.execute({
        sqlText: sql,
        complete: (err, stmt, rows) => {
          if (err) {
            reject(err);
          } else {
            resolve((rows || []) as T[]);
          }
        },
      });
    });
  } catch (err) {
    console.error("Query error:", (err as Error).message);
    if (retries > 0 && isRetryableError(err)) {
      connection = null;
      return query(sql, retries - 1);
    }
    throw err;
  }
}

export async function callAgent(prompt: string): Promise<string> {
  const sql = `
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
      'claude-3-5-sonnet',
      CONCAT(
        'You are an IROPS operations assistant. ',
        'Respond with actionable recommendations. ',
        'User query: ', ?
      )
    ) as response
  `;
  
  const conn = await getConnection();
  return new Promise((resolve, reject) => {
    conn.execute({
      sqlText: sql,
      binds: [prompt],
      complete: (err, stmt, rows) => {
        if (err) reject(err);
        else resolve((rows as Array<{RESPONSE: string}>)?.[0]?.RESPONSE || "No response");
      },
    });
  });
}

export async function invokeIROPSAgent(message: string): Promise<{response: string; sql?: string}> {
  const sql = `
    WITH agent_response AS (
      SELECT SNOWFLAKE.CORTEX.INVOKE_AGENT(
        'PHANTOM_IROPS.ANALYTICS.IROPS_ASSISTANT',
        ?
      ) as result
    )
    SELECT result:response::STRING as response,
           result:sql::STRING as sql_query
    FROM agent_response
  `;
  
  const conn = await getConnection();
  return new Promise((resolve, reject) => {
    conn.execute({
      sqlText: sql,
      binds: [message],
      complete: (err, stmt, rows) => {
        if (err) reject(err);
        else {
          const row = (rows as Array<{RESPONSE: string; SQL_QUERY: string}>)?.[0];
          resolve({
            response: row?.RESPONSE || "No response from agent",
            sql: row?.SQL_QUERY
          });
        }
      },
    });
  });
}
