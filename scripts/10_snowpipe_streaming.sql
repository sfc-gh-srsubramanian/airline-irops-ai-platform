-- =============================================================================
-- SNOWPIPE STREAMING - REAL-TIME FLIGHT STATUS EVENTS
-- =============================================================================
-- This script sets up the infrastructure for real-time flight status ingestion
-- using Snowpipe Streaming via Kafka Connector.
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- =============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

USE ROLE IDENTIFIER($PROJECT_ROLE);
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);

-- =============================================================================
-- 1. FLIGHT_STATUS_EVENTS TABLE
-- =============================================================================
-- Event-sourced table for real-time flight status updates.
-- Kafka Connector with Snowpipe Streaming ingests directly to this table.

CREATE OR REPLACE TABLE RAW.FLIGHT_STATUS_EVENTS (
    event_id VARCHAR(50) PRIMARY KEY,
    flight_id VARCHAR(30) NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    
    new_status VARCHAR(30),
    previous_status VARCHAR(30),
    
    delay_minutes INTEGER,
    delay_code VARCHAR(10),
    delay_reason VARCHAR(500),
    
    departure_gate VARCHAR(10),
    arrival_gate VARCHAR(10),
    
    actual_departure_utc TIMESTAMP_NTZ,
    actual_arrival_utc TIMESTAMP_NTZ,
    estimated_departure_utc TIMESTAMP_NTZ,
    estimated_arrival_utc TIMESTAMP_NTZ,
    
    source_system VARCHAR(50) DEFAULT 'FLIGHT_TRACKER',
    ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    kafka_offset BIGINT,
    kafka_partition INTEGER
);

COMMENT ON TABLE RAW.FLIGHT_STATUS_EVENTS IS 
    'Real-time flight status events ingested via Snowpipe Streaming from Kafka';

-- =============================================================================
-- 2. STREAM FOR CDC ON FLIGHT EVENTS
-- =============================================================================
-- Append-only stream captures new events for merge processing

CREATE OR REPLACE STREAM RAW.FLIGHT_EVENTS_STREAM 
    ON TABLE RAW.FLIGHT_STATUS_EVENTS
    APPEND_ONLY = TRUE;

COMMENT ON STREAM RAW.FLIGHT_EVENTS_STREAM IS 
    'CDC stream for processing new flight status events';

-- =============================================================================
-- 3. TASK TO MERGE EVENTS INTO FLIGHTS TABLE
-- =============================================================================
-- Runs every 30 seconds when stream has data.
-- Uses QUALIFY to get latest event per flight before merging.

CREATE OR REPLACE TASK RAW.MERGE_FLIGHT_EVENTS
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RAW.FLIGHT_EVENTS_STREAM')
AS
MERGE INTO RAW.FLIGHTS f
USING (
    SELECT 
        flight_id,
        new_status,
        delay_minutes,
        delay_code,
        delay_reason,
        departure_gate,
        arrival_gate,
        actual_departure_utc,
        actual_arrival_utc
    FROM RAW.FLIGHT_EVENTS_STREAM
    QUALIFY ROW_NUMBER() OVER (PARTITION BY flight_id ORDER BY event_timestamp DESC) = 1
) e
ON f.flight_id = e.flight_id
WHEN MATCHED THEN UPDATE SET
    status = COALESCE(e.new_status, f.status),
    departure_delay_minutes = COALESCE(e.delay_minutes, f.departure_delay_minutes),
    delay_code = COALESCE(e.delay_code, f.delay_code),
    delay_reason = COALESCE(e.delay_reason, f.delay_reason),
    departure_gate = COALESCE(e.departure_gate, f.departure_gate),
    arrival_gate = COALESCE(e.arrival_gate, f.arrival_gate),
    actual_departure_utc = COALESCE(e.actual_departure_utc, f.actual_departure_utc),
    actual_arrival_utc = COALESCE(e.actual_arrival_utc, f.actual_arrival_utc),
    updated_at = CURRENT_TIMESTAMP();

COMMENT ON TASK RAW.MERGE_FLIGHT_EVENTS IS 
    'Merges streaming flight events into the main FLIGHTS table every minute';

ALTER TASK RAW.MERGE_FLIGHT_EVENTS RESUME;

-- =============================================================================
-- 4. VIEW FOR LATEST EVENTS (DASHBOARD QUERY)
-- =============================================================================
-- Optimized view for the React dashboard live event feed

CREATE OR REPLACE VIEW RAW.V_LATEST_FLIGHT_EVENTS AS
SELECT 
    e.event_id,
    e.flight_id,
    e.event_type,
    e.event_timestamp,
    e.new_status,
    e.previous_status,
    e.delay_minutes,
    e.delay_code,
    e.delay_reason,
    e.departure_gate,
    e.arrival_gate,
    e.source_system,
    e.ingested_at,
    f.flight_number,
    f.origin,
    f.destination,
    f.scheduled_departure_utc
FROM RAW.FLIGHT_STATUS_EVENTS e
LEFT JOIN RAW.FLIGHTS f ON e.flight_id = f.flight_id
ORDER BY e.event_timestamp DESC;

COMMENT ON VIEW RAW.V_LATEST_FLIGHT_EVENTS IS 
    'View joining flight events with flight details for dashboard display';

-- =============================================================================
-- 5. GRANTS FOR STREAMING OBJECTS
-- =============================================================================

GRANT SELECT ON TABLE RAW.FLIGHT_STATUS_EVENTS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON VIEW RAW.V_LATEST_FLIGHT_EVENTS TO ROLE IDENTIFIER($PROJECT_ROLE);

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SELECT 'FLIGHT_STATUS_EVENTS table created' AS status;
SELECT 'FLIGHT_EVENTS_STREAM created' AS status;
SELECT 'MERGE_FLIGHT_EVENTS task created and resumed' AS status;

SHOW TASKS LIKE 'MERGE_FLIGHT_EVENTS' IN SCHEMA RAW;
