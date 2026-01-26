-- ============================================================================
-- Phantom Airlines IROPS - Cortex AI Functions & Contract Bot
-- ============================================================================
-- Implements AI-powered functions using Snowflake Cortex:
--   1. AI_CLASSIFY - Categorize disruptions and maintenance issues
--   2. AI_COMPLETE - Generate summaries and passenger communications
--   3. AI_SIMILARITY - Match current events to historical incidents
--   4. CONTRACT BOT - Validate crew assignments against PWA and FAA rules
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- ============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE SCHEMA ML_MODELS;
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);

-- ============================================================================
-- 1. AI_CLASSIFY - DISRUPTION CATEGORIZATION
-- ============================================================================
-- Automatically categorize disruption severity and type from descriptions

CREATE OR REPLACE FUNCTION CLASSIFY_DISRUPTION_SEVERITY(description TEXT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        description,
        ['MINOR - Minimal impact, less than 15 minute delay',
         'MODERATE - Noticeable impact, 15-60 minute delay, some passenger inconvenience',
         'SEVERE - Significant impact, 1-3 hour delay, many passengers affected, rebooking needed',
         'CRITICAL - Major impact, 3+ hour delay or cancellation, hundreds of passengers affected, cascading effects']
    ):label::VARCHAR
$$;

CREATE OR REPLACE FUNCTION CLASSIFY_DISRUPTION_TYPE(description TEXT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        description,
        ['WEATHER - Related to weather conditions like thunderstorms, snow, ice, fog, wind',
         'MECHANICAL - Related to aircraft mechanical issues, maintenance, equipment failure',
         'CREW - Related to crew availability, sick calls, duty time limits, positioning',
         'ATC - Related to air traffic control, ground stops, traffic management',
         'GROUND_OPS - Related to ground operations like fueling, catering, baggage',
         'SECURITY - Related to security screening, TSA, threats',
         'PAX_RELATED - Related to passenger issues, medical emergencies, unruly behavior']
    ):label::VARCHAR
$$;

-- Create view for auto-classified disruptions
CREATE OR REPLACE VIEW AUTO_CLASSIFIED_DISRUPTIONS AS
SELECT 
    d.disruption_id,
    d.flight_id,
    d.description,
    d.disruption_type AS original_type,
    d.severity AS original_severity,
    CLASSIFY_DISRUPTION_TYPE(d.description) AS ai_classified_type,
    CLASSIFY_DISRUPTION_SEVERITY(d.description) AS ai_classified_severity,
    d.disruption_type = SPLIT_PART(CLASSIFY_DISRUPTION_TYPE(d.description), ' - ', 1) AS type_matches,
    d.severity = SPLIT_PART(CLASSIFY_DISRUPTION_SEVERITY(d.description), ' - ', 1) AS severity_matches
FROM STAGING.STG_DISRUPTIONS d
WHERE d.description IS NOT NULL;

-- ============================================================================
-- 2. AI_CLASSIFY - MAINTENANCE LOG CATEGORIZATION
-- ============================================================================
-- Categorize maintenance issues by priority and ATA chapter

CREATE OR REPLACE FUNCTION CLASSIFY_MAINTENANCE_PRIORITY(description TEXT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        description,
        ['AOG - Aircraft On Ground, cannot dispatch until repaired, highest priority',
         'CRITICAL - Safety of flight issue, must be addressed before next flight',
         'HIGH - Affects dispatch reliability or passenger comfort, address within 24 hours',
         'ROUTINE - Normal wear items, can be deferred to scheduled maintenance',
         'DEFERRED - Already deferred per MEL/CDL, monitor and repair at next opportunity']
    ):label::VARCHAR
$$;

CREATE OR REPLACE FUNCTION CLASSIFY_ATA_CHAPTER(description TEXT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        description,
        ['ATA 21 - Air Conditioning, pressurization, heating, cooling',
         'ATA 24 - Electrical Power, generators, batteries, wiring',
         'ATA 27 - Flight Controls, ailerons, elevators, rudder',
         'ATA 28 - Fuel System, tanks, pumps, quantity indication',
         'ATA 29 - Hydraulic Power, pumps, reservoirs, actuators',
         'ATA 32 - Landing Gear, wheels, brakes, steering, tires',
         'ATA 34 - Navigation, GPS, VOR, ILS, radar',
         'ATA 49 - APU, auxiliary power unit',
         'ATA 52 - Doors, passenger doors, cargo doors, emergency exits',
         'ATA 72 - Engine, turbofan, thrust reversers, nacelles']
    ):label::VARCHAR
$$;

-- ============================================================================
-- 3. AI_COMPLETE - GENERATE SUMMARIES AND COMMUNICATIONS
-- ============================================================================

-- Generate disruption summary for operations dashboard
CREATE OR REPLACE FUNCTION GENERATE_DISRUPTION_SUMMARY(
    disruption_type VARCHAR,
    severity VARCHAR,
    affected_airport VARCHAR,
    flights_affected INTEGER,
    passengers_affected INTEGER,
    description TEXT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        'Generate a brief (2-3 sentence) executive summary of this airline disruption for the Operations Control Center:
        
Disruption Type: ' || disruption_type || '
Severity: ' || severity || '
Affected Airport: ' || affected_airport || '
Flights Affected: ' || flights_affected::VARCHAR || '
Passengers Affected: ' || passengers_affected::VARCHAR || '
Details: ' || description || '

Provide a clear, factual summary focusing on operational impact. Start with the key issue and end with scale of impact.'
    )
$$;

-- Generate passenger notification message
CREATE OR REPLACE FUNCTION GENERATE_PASSENGER_NOTIFICATION(
    flight_number VARCHAR,
    origin VARCHAR,
    destination VARCHAR,
    delay_minutes INTEGER,
    reason TEXT,
    rebooking_available BOOLEAN
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        'Generate a professional, empathetic passenger notification message for this flight delay:

Flight: Phantom Airlines ' || flight_number || '
Route: ' || origin || ' to ' || destination || '
Delay: ' || delay_minutes::VARCHAR || ' minutes
Reason: ' || reason || '
Rebooking Available: ' || CASE WHEN rebooking_available THEN 'Yes' ELSE 'No' END || '

Write a brief (3-4 sentence) SMS-appropriate message that:
1. Apologizes for the inconvenience
2. Explains the situation clearly
3. Provides next steps
4. Thanks them for their patience

Keep it professional but warm. Use "we" for the airline.'
    )
$$;

-- Generate recovery strategy recommendation
CREATE OR REPLACE FUNCTION GENERATE_RECOVERY_RECOMMENDATION(
    disruption_description TEXT,
    current_situation TEXT,
    available_resources TEXT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-70b',
        'You are a senior airline operations manager. Based on the following IROPS situation, recommend a recovery strategy:

DISRUPTION: ' || disruption_description || '

CURRENT SITUATION: ' || current_situation || '

AVAILABLE RESOURCES: ' || available_resources || '

Provide:
1. Immediate actions (next 1 hour)
2. Short-term recovery plan (next 6 hours)
3. Risk mitigation steps
4. Escalation criteria

Be specific and actionable. Consider FAA regulations, union contracts, and passenger impact.'
    )
$$;

-- ============================================================================
-- 4. AI_SIMILARITY - HISTORICAL INCIDENT MATCHING
-- ============================================================================

-- Find similar historical incidents
CREATE OR REPLACE FUNCTION FIND_SIMILAR_INCIDENTS(query_description TEXT, max_results INTEGER DEFAULT 3)
RETURNS TABLE (
    incident_id VARCHAR,
    incident_type VARCHAR,
    severity VARCHAR,
    affected_hub VARCHAR,
    trigger_event TEXT,
    recovery_strategy TEXT,
    similarity_score FLOAT
)
LANGUAGE SQL
AS
$$
    SELECT 
        h.incident_id,
        h.incident_type,
        h.severity,
        h.affected_hub,
        h.trigger_event,
        h.recovery_strategy,
        SNOWFLAKE.CORTEX.SIMILARITY(query_description, h.description) AS similarity_score
    FROM RAW.HISTORICAL_INCIDENTS h
    ORDER BY similarity_score DESC
    LIMIT max_results
$$;

-- Create view for incident similarity analysis
CREATE OR REPLACE VIEW INCIDENT_SIMILARITY_ANALYSIS AS
SELECT 
    d.disruption_id,
    d.flight_id,
    d.disruption_type,
    d.severity,
    d.description,
    h.incident_id AS similar_incident_id,
    h.incident_type AS similar_incident_type,
    h.trigger_event AS similar_trigger,
    h.recovery_strategy AS proven_recovery_strategy,
    h.recovery_time_hours AS historical_recovery_time,
    h.total_cost_usd AS historical_cost,
    SNOWFLAKE.CORTEX.SIMILARITY(d.description, h.description) AS similarity_score
FROM STAGING.STG_DISRUPTIONS d
CROSS JOIN RAW.HISTORICAL_INCIDENTS h
WHERE d.is_active
QUALIFY ROW_NUMBER() OVER (PARTITION BY d.disruption_id ORDER BY SNOWFLAKE.CORTEX.SIMILARITY(d.description, h.description) DESC) <= 3;

-- ============================================================================
-- 5. CONTRACT BOT - PWA & FAA COMPLIANCE VALIDATION
-- ============================================================================
-- AI-powered validation of crew assignments against union contract and FAA rules

-- PWA and FAA knowledge base (simplified for demo)
CREATE OR REPLACE TABLE CONTRACT_RULES (
    rule_id VARCHAR(20) PRIMARY KEY,
    rule_category VARCHAR(50) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT NOT NULL,
    rule_parameters VARIANT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert key contract rules
INSERT INTO CONTRACT_RULES 
SELECT 'FAA-117-1', 'FAA', 'Maximum Flight Duty Period', 'The maximum flight duty period depends on the start time and number of flight segments. For flights starting between 0500-1959 local with 1-2 segments, max FDP is 13 hours.', 
     PARSE_JSON('{"max_fdp_hours": {"0500-0559": 13, "0600-0659": 13, "0700-1159": 14, "1200-1259": 13, "1300-1659": 12, "1700-2159": 11, "2200-0459": 10}}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'FAA-117-2', 'FAA', 'Minimum Rest Period', 'A flight crew member must have a rest period of at least 10 consecutive hours before beginning any flight duty period. The rest must include an opportunity for 8 uninterrupted hours of sleep.',
     PARSE_JSON('{"min_rest_hours": 10, "min_sleep_opportunity": 8}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'FAA-117-3', 'FAA', 'Monthly Flight Time Limit', 'A flight crew member may not accept an assignment if the total flight time will exceed 100 hours in any calendar month.',
     PARSE_JSON('{"max_monthly_hours": 100}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'FAA-117-4', 'FAA', 'Annual Flight Time Limit', 'A flight crew member may not accept an assignment if the total flight time will exceed 1,000 hours in any calendar year.',
     PARSE_JSON('{"max_annual_hours": 1000}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'PWA-5.1', 'UNION', 'Consecutive Duty Days', 'Pilots may not be scheduled for more than 6 consecutive duty days without a minimum 24-hour rest period.',
     PARSE_JSON('{"max_consecutive_days": 6, "min_rest_after_hours": 24}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'PWA-5.2', 'UNION', 'Reserve Call-Out Notice', 'Reserve pilots must receive at least 2 hours notice before report time for a short-call reserve assignment.',
     PARSE_JSON('{"min_notice_hours": 2}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'PWA-6.1', 'UNION', 'Deadhead Positioning', 'Deadhead time counts toward the flight duty period but not toward flight time limits. Maximum deadhead followed by flight duty is 14 hours total.',
     PARSE_JSON('{"max_deadhead_plus_duty": 14}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'PWA-7.1', 'UNION', 'Aircraft Type Qualification', 'A pilot must hold a current type rating for the specific aircraft type to serve as a required flight crew member.',
     PARSE_JSON('{"requires_type_rating": true}'), CURRENT_TIMESTAMP()
UNION ALL SELECT 'PWA-8.1', 'UNION', 'Involuntary Extension', 'Pilots may be involuntarily extended beyond their scheduled duty period only in case of operational emergency, with a maximum extension of 2 hours.',
     PARSE_JSON('{"max_extension_hours": 2}'), CURRENT_TIMESTAMP();

-- Contract Bot validation function
CREATE OR REPLACE FUNCTION VALIDATE_CREW_ASSIGNMENT(
    crew_id VARCHAR,
    flight_id VARCHAR,
    assignment_role VARCHAR
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH crew_status AS (
        SELECT 
            c.crew_id,
            c.full_name,
            c.crew_type,
            c.base_airport,
            c.monthly_hours_remaining,
            c.annual_hours_remaining,
            c.qualified_aircraft_types,
            c.duty_days_last_7_days,
            c.flight_hours_last_7_days
        FROM STAGING.STG_CREW c
        WHERE c.crew_id = crew_id
    ),
    flight_info AS (
        SELECT 
            f.flight_id,
            f.flight_number,
            f.origin,
            f.destination,
            f.aircraft_type_code,
            f.block_time_scheduled_min
        FROM STAGING.STG_FLIGHTS f
        WHERE f.flight_id = flight_id
    ),
    validation_checks AS (
        SELECT 
            -- Check 1: Type qualification
            CASE WHEN CONTAINS(cs.qualified_aircraft_types, fi.aircraft_type_code) 
                 THEN TRUE ELSE FALSE END AS is_type_qualified,
            -- Check 2: Monthly hours
            CASE WHEN cs.monthly_hours_remaining >= (fi.block_time_scheduled_min / 60.0)
                 THEN TRUE ELSE FALSE END AS has_monthly_hours,
            -- Check 3: Annual hours  
            CASE WHEN cs.annual_hours_remaining >= (fi.block_time_scheduled_min / 60.0)
                 THEN TRUE ELSE FALSE END AS has_annual_hours,
            -- Check 4: Consecutive duty days
            CASE WHEN cs.duty_days_last_7_days < 6
                 THEN TRUE ELSE FALSE END AS within_duty_day_limit,
            cs.*,
            fi.*
        FROM crew_status cs, flight_info fi
    )
    SELECT OBJECT_CONSTRUCT(
        'is_legal', (is_type_qualified AND has_monthly_hours AND has_annual_hours AND within_duty_day_limit),
        'crew_id', crew_id,
        'crew_name', full_name,
        'flight_number', flight_number,
        'aircraft_type', aircraft_type_code,
        'checks', OBJECT_CONSTRUCT(
            'type_qualification', OBJECT_CONSTRUCT(
                'passed', is_type_qualified,
                'detail', CASE WHEN is_type_qualified 
                          THEN 'Crew is qualified for ' || aircraft_type_code
                          ELSE 'VIOLATION: Crew is NOT qualified for ' || aircraft_type_code || '. Qualified types: ' || qualified_aircraft_types
                          END
            ),
            'monthly_hours', OBJECT_CONSTRUCT(
                'passed', has_monthly_hours,
                'remaining', monthly_hours_remaining,
                'required', ROUND(block_time_scheduled_min / 60.0, 1),
                'detail', CASE WHEN has_monthly_hours 
                          THEN 'Sufficient monthly hours remaining (' || monthly_hours_remaining || ' hrs)'
                          ELSE 'VIOLATION: Insufficient monthly hours. Remaining: ' || monthly_hours_remaining || ', Required: ' || ROUND(block_time_scheduled_min / 60.0, 1)
                          END
            ),
            'annual_hours', OBJECT_CONSTRUCT(
                'passed', has_annual_hours,
                'remaining', annual_hours_remaining,
                'detail', CASE WHEN has_annual_hours 
                          THEN 'Sufficient annual hours remaining (' || annual_hours_remaining || ' hrs)'
                          ELSE 'VIOLATION: Insufficient annual hours. Remaining: ' || annual_hours_remaining
                          END
            ),
            'consecutive_duty_days', OBJECT_CONSTRUCT(
                'passed', within_duty_day_limit,
                'current_streak', duty_days_last_7_days,
                'detail', CASE WHEN within_duty_day_limit 
                          THEN 'Within 6-day duty limit (' || duty_days_last_7_days || ' days)'
                          ELSE 'VIOLATION: Exceeds 6 consecutive duty day limit. Current: ' || duty_days_last_7_days
                          END
            )
        ),
        'recommendation', CASE 
            WHEN NOT is_type_qualified THEN 'Cannot assign - crew not type qualified'
            WHEN NOT has_monthly_hours THEN 'Cannot assign - would exceed monthly flight time limit'
            WHEN NOT has_annual_hours THEN 'Cannot assign - would exceed annual flight time limit'
            WHEN NOT within_duty_day_limit THEN 'Cannot assign - exceeds consecutive duty day limit'
            ELSE 'Assignment is LEGAL and compliant with FAA Part 117 and PWA'
        END
    )
    FROM validation_checks
$$;

-- Contract Bot natural language query function
CREATE OR REPLACE FUNCTION CONTRACT_BOT_QUERY(user_question TEXT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-70b',
        'You are the Phantom Airlines Contract Bot, an expert on the Pilot Working Agreement (PWA) and FAA Part 117 regulations.

KEY REGULATIONS:
- Max Flight Duty Period: 9-14 hours depending on start time (FAA 117)
- Minimum Rest: 10 hours with 8 hours sleep opportunity (FAA 117)
- Monthly Flight Time Limit: 100 hours (FAA 117)
- Annual Flight Time Limit: 1,000 hours (FAA 117)
- Max Consecutive Duty Days: 6 days, then 24 hour rest (PWA 5.1)
- Reserve Call-Out Notice: Minimum 2 hours (PWA 5.2)
- Type Qualification Required: Yes (PWA 7.1)
- Max Involuntary Extension: 2 hours (PWA 8.1)

USER QUESTION: ' || user_question || '

Provide a clear, specific answer based on the regulations above. If the question involves a specific scenario, explain which rules apply and why. Always cite the specific regulation (e.g., "Per FAA 117..." or "Per PWA 5.1..."). If you cannot determine legality without more information, list what additional details are needed.'
    )
$$;

-- Create view for crew assignment validations
CREATE OR REPLACE VIEW CREW_ASSIGNMENT_VALIDATIONS AS
SELECT 
    gr.flight_id,
    gr.flight_number,
    gr.origin,
    gr.destination,
    gr.captain_id,
    gr.captain_name,
    CASE WHEN gr.captain_id IS NOT NULL 
         THEN VALIDATE_CREW_ASSIGNMENT(gr.captain_id, gr.flight_id, 'CAPTAIN')
         ELSE NULL 
    END AS captain_validation,
    gr.first_officer_id,
    gr.first_officer_name,
    CASE WHEN gr.first_officer_id IS NOT NULL 
         THEN VALIDATE_CREW_ASSIGNMENT(gr.first_officer_id, gr.flight_id, 'FIRST_OFFICER')
         ELSE NULL 
    END AS fo_validation
FROM ANALYTICS.MART_GOLDEN_RECORD gr
WHERE gr.flight_status IN ('SCHEDULED', 'BOARDING', 'DELAYED')
  AND gr.flight_date >= CURRENT_DATE();

-- ============================================================================
-- 6. BATCH NOTIFICATION HELPER
-- ============================================================================
-- Support function for One-Click Recovery batch notifications

CREATE OR REPLACE FUNCTION GENERATE_BATCH_NOTIFICATION_LIST(
    flight_id VARCHAR,
    required_role VARCHAR,
    max_candidates INTEGER DEFAULT 20
)
RETURNS TABLE (
    candidate_rank INTEGER,
    crew_id VARCHAR,
    crew_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    ml_fit_score FLOAT,
    notification_message VARCHAR
)
LANGUAGE SQL
AS
$$
    WITH top_candidates AS (
        SELECT 
            cr.candidate_rank,
            cr.crew_id,
            cr.crew_name,
            cr.phone_number,
            cr.email,
            cr.ml_fit_score,
            cr.flight_number,
            cr.origin,
            cr.destination,
            TO_CHAR(cr.scheduled_departure_utc, 'HH24:MI') AS departure_time
        FROM ML_MODELS.CREW_CANDIDATE_RANKINGS cr
        WHERE cr.flight_id = flight_id
          AND cr.crew_type = required_role
          AND cr.is_type_qualified
        ORDER BY cr.ml_fit_score DESC
        LIMIT max_candidates
    )
    SELECT 
        candidate_rank,
        crew_id,
        crew_name,
        phone_number,
        email,
        ml_fit_score,
        'URGENT: Open trip available. ' || flight_number || ' ' || origin || '-' || destination || 
        ' departing ' || departure_time || ' UTC. Reply YES to accept or call Crew Scheduling.' AS notification_message
    FROM top_candidates
$$;

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================

GRANT SELECT ON TABLE CONTRACT_RULES TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON VIEW AUTO_CLASSIFIED_DISRUPTIONS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON VIEW INCIDENT_SIMILARITY_ANALYSIS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON VIEW CREW_ASSIGNMENT_VALIDATIONS TO ROLE IDENTIFIER($PROJECT_ROLE);

GRANT USAGE ON FUNCTION CLASSIFY_DISRUPTION_SEVERITY(TEXT) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION CLASSIFY_DISRUPTION_TYPE(TEXT) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION CLASSIFY_MAINTENANCE_PRIORITY(TEXT) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION CLASSIFY_ATA_CHAPTER(TEXT) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION GENERATE_DISRUPTION_SUMMARY(VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER, TEXT) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION GENERATE_PASSENGER_NOTIFICATION(VARCHAR, VARCHAR, VARCHAR, INTEGER, TEXT, BOOLEAN) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION GENERATE_RECOVERY_RECOMMENDATION(TEXT, TEXT, TEXT) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION FIND_SIMILAR_INCIDENTS(TEXT, INTEGER) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION VALIDATE_CREW_ASSIGNMENT(VARCHAR, VARCHAR, VARCHAR) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION CONTRACT_BOT_QUERY(TEXT) TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION GENERATE_BATCH_NOTIFICATION_LIST(VARCHAR, VARCHAR, INTEGER) TO ROLE IDENTIFIER($PROJECT_ROLE);

-- ============================================================================
-- CORTEX AI FUNCTIONS COMPLETE
-- ============================================================================
-- Created:
--   Classification Functions:
--     - CLASSIFY_DISRUPTION_SEVERITY
--     - CLASSIFY_DISRUPTION_TYPE
--     - CLASSIFY_MAINTENANCE_PRIORITY
--     - CLASSIFY_ATA_CHAPTER
--   
--   Generation Functions:
--     - GENERATE_DISRUPTION_SUMMARY
--     - GENERATE_PASSENGER_NOTIFICATION
--     - GENERATE_RECOVERY_RECOMMENDATION
--   
--   Similarity Functions:
--     - FIND_SIMILAR_INCIDENTS
--   
--   Contract Bot:
--     - VALIDATE_CREW_ASSIGNMENT
--     - CONTRACT_BOT_QUERY
--     - GENERATE_BATCH_NOTIFICATION_LIST
--
-- Views:
--     - AUTO_CLASSIFIED_DISRUPTIONS
--     - INCIDENT_SIMILARITY_ANALYSIS
--     - CREW_ASSIGNMENT_VALIDATIONS
-- ============================================================================
