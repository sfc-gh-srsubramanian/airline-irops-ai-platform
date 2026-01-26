import os
import json
import snowflake.connector

conn = snowflake.connector.connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "USWEST_DEMOACCOUNT")
cur = conn.cursor()

cur.execute("USE ROLE ACCOUNTADMIN")
cur.execute("USE WAREHOUSE PHANTOM_IROPS_WH")
cur.execute("USE DATABASE PHANTOM_IROPS")
cur.execute("USE SCHEMA SEMANTIC_MODELS")

agent_spec = {
    "models": {
        "orchestration": "auto"
    },
    "instructions": {
        "orchestration": "You are an IROPS (Irregular Operations) Assistant for Phantom Airlines. Your role is to help airline operations staff manage disruptions, crew assignments, and aircraft availability. Focus on actionable information for operational decision-making.",
        "response": "Format responses as clear, scannable information with bullet points. Highlight critical information and include relevant counts and metrics."
    },
    "tools": [
        {
            "tool_spec": {
                "type": "cortex_analyst_text_to_sql",
                "name": "irops_analytics",
                "description": "Query IROPS operational data including flights, disruptions, crew availability, and aircraft status."
            }
        }
    ],
    "tool_resources": {
        "irops_analytics": {
            "semantic_view": "PHANTOM_IROPS.SEMANTIC_MODELS.IROPS_ANALYTICS"
        }
    }
}

agent_spec_json = json.dumps(agent_spec).replace("'", "''")

sql = f"""
CREATE AGENT PHANTOM_IROPS.SEMANTIC_MODELS.IROPS_ASSISTANT
  AGENT_SPEC = '{agent_spec_json}'
  COMMENT = 'IROPS Assistant for Phantom Airlines'
"""

print("Executing SQL:")
print(sql[:500])
cur.execute(sql)
print("Agent created successfully!")

cur.execute("DESCRIBE AGENT PHANTOM_IROPS.SEMANTIC_MODELS.IROPS_ASSISTANT")
result = cur.fetchall()
for row in result:
    print(f"Name: {row[0]}")
    print(f"Database: {row[1]}")
    print(f"Schema: {row[2]}")
    print(f"Agent Spec: {row[6][:200] if row[6] else 'None'}...")

conn.close()
