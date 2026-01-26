-- ============================================================================
-- Phantom Airlines IROPS - Intelligence Agents & Cortex Search
-- ============================================================================
-- Creates Cortex Search services and Intelligence Agents for conversational AI
-- 
-- Components:
--   1. IROPS_INCIDENT_SEARCH - Search over historical incidents for pattern matching
--   2. MAINTENANCE_KNOWLEDGE_SEARCH - Search over maintenance logs and procedures
--   3. IROPS_ASSISTANT - Main intelligence agent for operations queries
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- ============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';
SET SEMANTIC_VIEW_FQN = $FULL_PREFIX || '.SEMANTIC_MODELS.IROPS_ANALYTICS';
SET INCIDENT_SEARCH_FQN = $FULL_PREFIX || '.CORTEX_SEARCH.IROPS_INCIDENT_SEARCH';
SET MAINTENANCE_SEARCH_FQN = $FULL_PREFIX || '.CORTEX_SEARCH.MAINTENANCE_KNOWLEDGE_SEARCH';

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);

-- ============================================================================
-- 1. CORTEX SEARCH - HISTORICAL INCIDENTS
-- ============================================================================
-- Enables semantic search over past IROPS events for pattern matching
-- Used to find similar recovery strategies from historical data

USE SCHEMA CORTEX_SEARCH;

CREATE OR REPLACE TABLE INCIDENT_SEARCH_CORPUS AS
SELECT 
    incident_id,
    incident_date,
    incident_type,
    incident_subtype,
    severity,
    affected_hub,
    trigger_event,
    description,
    flights_cancelled,
    flights_delayed,
    passengers_affected,
    recovery_time_hours,
    recovery_strategy,
    lessons_learned,
    total_cost_usd,
    crew_impact,
    incident_type || ' ' || COALESCE(incident_subtype, '') || ' at ' || affected_hub || ': ' ||
    trigger_event || '. ' || description || ' Recovery: ' || COALESCE(recovery_strategy, '') ||
    ' Lessons: ' || COALESCE(lessons_learned, '') AS searchable_content
FROM RAW.HISTORICAL_INCIDENTS;

CREATE OR REPLACE CORTEX SEARCH SERVICE IROPS_INCIDENT_SEARCH
    ON searchable_content
    ATTRIBUTES incident_id, incident_type, severity, affected_hub, recovery_time_hours, total_cost_usd
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    TARGET_LAG = '1 hour'
    COMMENT = 'Semantic search over historical IROPS incidents for pattern matching and recovery strategy recommendations'
AS
SELECT 
    incident_id,
    incident_date,
    incident_type,
    incident_subtype,
    severity,
    affected_hub,
    trigger_event,
    description,
    flights_cancelled,
    flights_delayed,
    passengers_affected,
    recovery_time_hours,
    recovery_strategy,
    lessons_learned,
    total_cost_usd,
    crew_impact,
    searchable_content
FROM INCIDENT_SEARCH_CORPUS;

-- ============================================================================
-- 2. CORTEX SEARCH - MAINTENANCE KNOWLEDGE BASE
-- ============================================================================
-- Enables semantic search over maintenance logs for troubleshooting

CREATE OR REPLACE TABLE MAINTENANCE_SEARCH_CORPUS AS
SELECT 
    log_id,
    aircraft_id,
    log_date,
    log_type,
    ata_chapter,
    description,
    station,
    priority,
    status,
    'ATA ' || COALESCE(ata_chapter, 'Unknown') || ' - ' || log_type || ': ' || description AS searchable_content
FROM RAW.MAINTENANCE_LOGS
WHERE description IS NOT NULL;

CREATE OR REPLACE CORTEX SEARCH SERVICE MAINTENANCE_KNOWLEDGE_SEARCH
    ON searchable_content
    ATTRIBUTES log_id, aircraft_id, log_type, ata_chapter, priority, status
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    TARGET_LAG = '1 hour'
    COMMENT = 'Semantic search over maintenance logs for troubleshooting and pattern identification'
AS
SELECT 
    log_id,
    aircraft_id,
    log_date,
    log_type,
    ata_chapter,
    description,
    station,
    priority,
    status,
    searchable_content
FROM MAINTENANCE_SEARCH_CORPUS;

-- ============================================================================
-- 3. CREATE INTELLIGENCE AGENT
-- ============================================================================
-- Main operations intelligence agent using YAML FROM SPECIFICATION syntax
-- Located in ANALYTICS schema for organizational clarity
-- Includes 24 sample questions for Snowflake Intelligence UI

USE SCHEMA ANALYTICS;

CREATE OR REPLACE AGENT IROPS_ASSISTANT
  COMMENT = 'IROPS Operations Assistant for Phantom Airlines - handles flight disruptions, crew recovery, weather impacts, and maintenance queries'
  PROFILE = '{"display_name": "IROPS Assistant", "avatar": "plane", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    orchestration: |
      You are an expert IROPS (Irregular Operations) assistant for Phantom Airlines.
      
      Tool Selection:
      1. QUANTITATIVE queries (counts, sums, rankings, metrics): Use irops_analytics
      2. INCIDENT research (historical incidents, investigations): Use incident_search
      3. MAINTENANCE info (procedures, knowledge base): Use maintenance_search
      4. For mixed queries: Use analyst first, then augment with search results
      
    response: |
      Format responses clearly:
      
      **Summary:** [1-2 sentence answer]
      
      **Key Findings:**
      - [Finding 1]
      - [Finding 2]
      - [Finding 3]
      
      FLAGGING RULES:
      - Flights delayed >120 minutes: Flag as ⚠️ HIGH PRIORITY
      - Crew duty approaching 12 hours: Flag as ⚠️ CREW ALERT
      - Ghost flights (crew/aircraft missing): Flag as 🔴 CRITICAL
      - Weather impacts >50 flights: Flag as ⛈️ MAJOR WEATHER EVENT

    sample_questions:
      - question: "How many flights are currently delayed?"
        answer: "I'll check the current flight status using our analytics."
      - question: "What is the average delay time today?"
        answer: "I'll calculate the average delay minutes across all affected flights."
      - question: "Show me the top 10 airports by delay count"
        answer: "I'll rank airports by their total delay counts."
      - question: "Which crew members are available for reassignment?"
        answer: "I'll identify crew members with remaining duty hours who can be reassigned."
      - question: "What caused the most disruptions this month?"
        answer: "I'll analyze disruption causes and show the breakdown by category."
      - question: "How many passengers are affected by delays?"
        answer: "I'll sum up the total passengers impacted across delayed flights."
      - question: "Show me crew duty hours remaining"
        answer: "I'll display crew members and their available duty time."
      - question: "What is the weather impact on operations?"
        answer: "I'll analyze weather-related delays and cancellations."
      - question: "Find flights with missing crew assignments"
        answer: "I'll identify ghost flights that lack proper crew assignments."
      - question: "What are the recovery options for flight AA123?"
        answer: "I'll analyze crew availability and suggest recovery candidates."
      - question: "Show aircraft utilization rates"
        answer: "I'll calculate how effectively our aircraft are being used."
      - question: "Which routes have the highest on-time performance?"
        answer: "I'll rank routes by their on-time departure percentages."
      - question: "What is the total delay cost today?"
        answer: "I'll estimate the financial impact of delays using our cost model."
      - question: "Find all mechanical delay incidents"
        answer: "I'll search our incident database for mechanical-related issues."
      - question: "How do I handle an engine fault code?"
        answer: "I'll search our maintenance knowledge base for the procedure."
      - question: "What are the FAA crew rest requirements?"
        answer: "I'll look up the relevant FAA regulations from our contract rules."
      - question: "Show me disruption trends over the past week"
        answer: "I'll visualize the disruption patterns and identify trends."
      - question: "Which airports have weather advisories?"
        answer: "I'll check current weather impacts by airport."
      - question: "What is the crew fit score algorithm?"
        answer: "I'll explain how crew recovery candidates are ranked."
      - question: "Show flights departing in the next 2 hours"
        answer: "I'll filter upcoming departures from the schedule."
      - question: "How many aircraft are currently in maintenance?"
        answer: "I'll check the aircraft status breakdown."
      - question: "What are the passenger rebooking options?"
        answer: "I'll analyze available capacity on alternative flights."
      - question: "Show me the operations summary dashboard"
        answer: "I'll display the real-time operational metrics summary."
      - question: "Find historical similar disruption events"
        answer: "I'll search past incidents for similar patterns."
      - question: "Who are my top tier loyalty members impacted by delays today?"
        answer: "I'll identify Diamond and Platinum members on delayed flights."
      - question: "Show me elite passengers affected by cancellations"
        answer: "I'll find Diamond and Platinum loyalty members with cancelled bookings."
      - question: "Which Diamond members have the longest delays?"
        answer: "I'll rank top-tier passengers by their flight delay duration."
      - question: "How many loyalty members are impacted by delays today?"
        answer: "I'll count affected passengers by loyalty tier across delayed flights."
      - question: "List Platinum passengers on cancelled flights"
        answer: "I'll identify Platinum tier members needing rebooking assistance."
      - question: "What is the total delay impact on elite members?"
        answer: "I'll analyze delays affecting Diamond and Platinum passengers."
      - question: "Show loyalty tier breakdown for delayed flights"
        answer: "I'll display passenger counts by loyalty tier on delayed flights."
      - question: "Which high-value passengers need immediate attention?"
        answer: "I'll prioritize elite members on severely delayed or cancelled flights."

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: irops_analytics
        description: "Use for ALL quantitative analytics: flight counts, delay statistics, crew availability metrics, aircraft status, disruption analysis, passenger impacts, and operational KPIs."
    - tool_spec:
        type: cortex_search
        name: incident_search
        description: "Search historical incident reports and investigations."
    - tool_spec:
        type: cortex_search
        name: maintenance_search
        description: "Search aircraft maintenance procedures and technical documentation."

  tool_resources:
    irops_analytics:
      semantic_view: PHANTOM_IROPS.SEMANTIC_MODELS.IROPS_ANALYTICS
      execution_environment:
        warehouse: PHANTOM_IROPS_WH
        query_timeout: 120
    incident_search:
      name: PHANTOM_IROPS.CORTEX_SEARCH.IROPS_INCIDENT_SEARCH
      max_results: 10
      title_column: INCIDENT_TYPE
      id_column: INCIDENT_ID
    maintenance_search:
      name: PHANTOM_IROPS.CORTEX_SEARCH.MAINTENANCE_KNOWLEDGE_SEARCH
      max_results: 10
      title_column: LOG_TYPE
      id_column: LOG_ID
  $$;

-- ============================================================================
-- 4. REGISTER WITH SNOWFLAKE INTELLIGENCE
-- ============================================================================
-- Makes the agent visible in the Snowflake Intelligence UI

ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT PHANTOM_IROPS.ANALYTICS.IROPS_ASSISTANT;

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON CORTEX SEARCH SERVICE CORTEX_SEARCH.IROPS_INCIDENT_SEARCH TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON CORTEX SEARCH SERVICE CORTEX_SEARCH.MAINTENANCE_KNOWLEDGE_SEARCH TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON AGENT ANALYTICS.IROPS_ASSISTANT TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON AGENT ANALYTICS.IROPS_ASSISTANT TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- INTELLIGENCE AGENTS COMPLETE
-- ============================================================================
-- Created:
--   Cortex Search Services:
--     1. IROPS_INCIDENT_SEARCH - Historical incident pattern matching
--        - title_column: INCIDENT_TYPE
--        - id_column: INCIDENT_ID
--     2. MAINTENANCE_KNOWLEDGE_SEARCH - Maintenance troubleshooting
--        - title_column: LOG_TYPE
--        - id_column: LOG_ID
--   
--   Intelligence Agent:
--     ANALYTICS.IROPS_ASSISTANT - Main operations assistant with:
--       - cortex_analyst_text_to_sql (irops_analytics → IROPS_ANALYTICS semantic view)
--       - cortex_search (incident_search → IROPS_INCIDENT_SEARCH)
--       - cortex_search (maintenance_search → MAINTENANCE_KNOWLEDGE_SEARCH)
--       - 24 sample questions for Snowflake Intelligence UI
--
--   Snowflake Intelligence:
--     - Agent registered with SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
--
-- Agent Specification Format (YAML FROM SPECIFICATION):
--   - models: orchestration model selection
--   - orchestration.budget: time and token limits
--   - instructions: orchestration, response, and sample_questions
--   - tools: tool_spec definitions (type, name, description)
--   - tool_resources: tool configurations with correct column names
--
-- Note: Agent tool_resources use hardcoded PHANTOM_IROPS database name since
-- YAML specifications don't support SQL session variables. If deploying with
-- a different prefix (e.g., DEV_PHANTOM_IROPS), update the tool_resources
-- section accordingly.
-- ============================================================================
