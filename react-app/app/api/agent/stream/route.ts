import { NextRequest } from "next/server";
import fs from "fs";

const AGENT_FQN = "PHANTOM_IROPS.ANALYTICS.IROPS_ASSISTANT";
const WAREHOUSE = "PHANTOM_IROPS_WH";

function getAccountUrl(): string {
  const host = process.env.SNOWFLAKE_HOST;
  if (host) return `https://${host}`;
  const account = process.env.SNOWFLAKE_ACCOUNT!;
  const accountLower = account.toLowerCase().replace(/_/g, "-");
  return `https://${accountLower}.snowflakecomputing.com`;
}

function getAuthToken(): string {
  const pat = process.env.SNOWFLAKE_PASSWORD;
  if (pat) return pat;
  const tokenPath = "/snowflake/session/token";
  try {
    if (fs.existsSync(tokenPath)) {
      return fs.readFileSync(tokenPath, "utf8");
    }
  } catch {}
  throw new Error("No auth token available: SNOWFLAKE_PASSWORD not set and SPCS token file not found");
}

export async function POST(request: NextRequest) {
  const { query, thread_id } = await request.json();

  const accountUrl = getAccountUrl();
  let pat: string;
  try {
    pat = getAuthToken();
  } catch {
    return new Response(JSON.stringify({ error: "SNOWFLAKE_PASSWORD not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  const [db, schema, agent] = AGENT_FQN.split(".");
  const agentUrl = `${accountUrl}/api/v2/databases/${db}/schemas/${schema}/agents/${agent}:run`;

  const requestBody: Record<string, unknown> = {
    messages: [{ role: "user", content: [{ type: "text", text: query }] }],
    warehouse: WAREHOUSE
  };

  if (thread_id) {
    requestBody.thread_id = thread_id;
  }

  try {
    const agentResponse = await fetch(agentUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/event-stream",
        "Authorization": `Bearer ${pat}`
      },
      body: JSON.stringify(requestBody)
    });

    if (!agentResponse.ok) {
      const errorText = await agentResponse.text();
      return new Response(JSON.stringify({ error: `Agent API error: ${agentResponse.status} - ${errorText}` }), {
        status: agentResponse.status,
        headers: { "Content-Type": "application/json" }
      });
    }

    const stream = new ReadableStream({
      async start(controller) {
        const reader = agentResponse.body?.getReader();
        if (!reader) {
          controller.close();
          return;
        }

        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            controller.enqueue(value);
          }
        } finally {
          controller.close();
          reader.releaseLock();
        }
      }
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "X-Accel-Buffering": "no"
      }
    });
  } catch (error) {
    console.error("Streaming error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
}
