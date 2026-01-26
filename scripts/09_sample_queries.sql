-- ============================================================================
-- Phantom Airlines IROPS - Sample Queries & Validation
-- ============================================================================
-- Sample queries for demo, testing, and validation of the IROPS platform
-- 
-- Categories:
--   1. Data Validation - Verify data generation
--   2. Golden Record - Unified operational view
--   3. Ghost Flights - Synchronization gap detection
--   4. Crew Recovery - One-Click Recovery candidates
--   5. Disruption Analysis - IROPS events and costs
--   6. AI Functions - Cortex AI demonstrations
--   7. Contract Bot - PWA validation examples
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- ============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);

-- ============================================================================
-- 1. DATA VALIDATION QUERIES
-- ============================================================================

-- Verify data volumes
SELECT 'AIRPORTS' AS table_name, COUNT(*) AS row_count FROM RAW.AIRPORTS
UNION ALL SELECT 'AIRCRAFT_TYPES', COUNT(*) FROM RAW.AIRCRAFT_TYPES
UNION ALL SELECT 'AIRCRAFT', COUNT(*) FROM RAW.AIRCRAFT
UNION ALL SELECT 'CREW_MEMBERS', COUNT(*) FROM RAW.CREW_MEMBERS
UNION ALL SELECT 'CREW_QUALIFICATIONS', COUNT(*) FROM RAW.CREW_QUALIFICATIONS
UNION ALL SELECT 'PASSENGERS', COUNT(*) FROM RAW.PASSENGERS
UNION ALL SELECT 'FLIGHTS', COUNT(*) FROM RAW.FLIGHTS
UNION ALL SELECT 'DISRUPTIONS', COUNT(*) FROM RAW.DISRUPTIONS
UNION ALL SELECT 'MAINTENANCE_LOGS', COUNT(*) FROM RAW.MAINTENANCE_LOGS
UNION ALL SELECT 'WEATHER_DATA', COUNT(*) FROM RAW.WEATHER_DATA
UNION ALL SELECT 'HISTORICAL_INCIDENTS', COUNT(*) FROM RAW.HISTORICAL_INCIDENTS
UNION ALL SELECT 'BOOKINGS', COUNT(*) FROM RAW.BOOKINGS
ORDER BY table_name;

-- Verify hub distribution
SELECT 
    hub_type,
    COUNT(*) AS airport_count,
    LISTAGG(airport_code, ', ') AS airports
FROM RAW.AIRPORTS
WHERE is_hub = TRUE
GROUP BY hub_type
ORDER BY airport_count DESC;

-- Verify crew distribution by type and base
SELECT 
    base_airport,
    COUNT(CASE WHEN crew_type = 'CAPTAIN' THEN 1 END) AS captains,
    COUNT(CASE WHEN crew_type = 'FIRST_OFFICER' THEN 1 END) AS first_officers,
    COUNT(CASE WHEN crew_type = 'PURSER' THEN 1 END) AS pursers,
    COUNT(CASE WHEN crew_type = 'FLIGHT_ATTENDANT' THEN 1 END) AS flight_attendants,
    COUNT(*) AS total
FROM RAW.CREW_MEMBERS
GROUP BY base_airport
ORDER BY total DESC;

-- Verify flight distribution by status
SELECT 
    status,
    COUNT(*) AS flight_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM RAW.FLIGHTS
GROUP BY status
ORDER BY flight_count DESC;

-- ============================================================================
-- 2. GOLDEN RECORD QUERIES
-- ============================================================================

-- Get current operational summary
SELECT * FROM ANALYTICS.MART_OPERATIONAL_SUMMARY;

-- View today's flights with full context from Golden Record
SELECT 
    flight_id,
    flight_number,
    origin || ' -> ' || destination AS route,
    flight_status,
    delay_category,
    departure_delay_minutes,
    tail_number,
    aircraft_status,
    captain_name,
    captain_availability,
    origin_weather_category,
    origin_ground_stop,
    has_active_disruption,
    disruption_type,
    flight_health_score,
    recovery_priority_score
FROM ANALYTICS.MART_GOLDEN_RECORD
WHERE flight_date = CURRENT_DATE()
ORDER BY recovery_priority_score DESC
LIMIT 20;

-- Find flights with lowest health scores (most at risk)
SELECT 
    flight_number,
    origin || ' -> ' || destination AS route,
    scheduled_departure_utc,
    flight_status,
    flight_health_score,
    recovery_priority_score,
    CASE 
        WHEN is_ghost_flight THEN 'GHOST FLIGHT: ' || ghost_flight_reason
        WHEN needs_captain THEN 'NEEDS CAPTAIN'
        WHEN needs_first_officer THEN 'NEEDS FIRST OFFICER'
        WHEN has_active_disruption THEN 'ACTIVE DISRUPTION: ' || disruption_type
        ELSE 'WEATHER/DELAY'
    END AS primary_issue
FROM ANALYTICS.MART_GOLDEN_RECORD
WHERE flight_date >= CURRENT_DATE()
  AND flight_status NOT IN ('ARRIVED', 'CANCELLED')
ORDER BY flight_health_score ASC
LIMIT 15;

-- ============================================================================
-- 3. GHOST FLIGHTS DETECTION
-- ============================================================================

-- Find Ghost Flights (aircraft at wrong location)
SELECT 
    flight_id,
    flight_number,
    origin AS flight_origin,
    aircraft_actual_location AS aircraft_location,
    tail_number,
    scheduled_departure_utc,
    ghost_flight_reason,
    recovery_priority_score
FROM ANALYTICS.MART_GOLDEN_RECORD
WHERE is_ghost_flight = TRUE
ORDER BY scheduled_departure_utc;

-- Ghost Planes summary by hub
SELECT 
    s.airport_code,
    s.city,
    s.aircraft_without_captain AS ghost_planes,
    s.captains_without_aircraft AS idle_captains,
    s.available_aircraft,
    s.available_captains,
    s.operational_capacity_score
FROM INTERMEDIATE.INT_CREW_AIRCRAFT_STATUS s
WHERE s.is_hub = TRUE
ORDER BY s.aircraft_without_captain DESC;

-- ============================================================================
-- 4. CREW RECOVERY QUERIES (One-Click Recovery)
-- ============================================================================

-- Find flights needing crew
SELECT 
    flight_id,
    flight_number,
    origin || ' -> ' || destination AS route,
    scheduled_departure_utc,
    aircraft_type_code,
    needs_captain,
    needs_first_officer,
    recovery_priority_score
FROM ANALYTICS.MART_GOLDEN_RECORD
WHERE (needs_captain OR needs_first_officer)
  AND flight_status NOT IN ('CANCELLED', 'ARRIVED')
ORDER BY recovery_priority_score DESC
LIMIT 10;

-- Get top 10 captain candidates for a specific flight (One-Click Recovery)
SELECT 
    candidate_rank,
    crew_name,
    crew_base,
    is_type_qualified,
    is_same_base,
    monthly_hours_remaining,
    flight_hours_last_7_days,
    ml_fit_score,
    phone_number
FROM ANALYTICS.MART_CREW_RECOVERY_CANDIDATES
WHERE crew_type = 'CAPTAIN'
  AND is_type_qualified = TRUE
ORDER BY ml_fit_score DESC
LIMIT 10;

-- Simulate batch notification list
SELECT * FROM TABLE(ML_MODELS.GENERATE_BATCH_NOTIFICATION_LIST(
    (SELECT flight_id FROM ANALYTICS.MART_GOLDEN_RECORD WHERE needs_captain LIMIT 1),
    'CAPTAIN',
    10
));

-- ============================================================================
-- 5. DISRUPTION ANALYSIS QUERIES
-- ============================================================================

-- Active disruptions summary
SELECT 
    disruption_type,
    COUNT(*) AS active_count,
    SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) AS critical,
    SUM(CASE WHEN severity = 'SEVERE' THEN 1 ELSE 0 END) AS severe,
    SUM(impact_passengers_count) AS total_pax_affected,
    ROUND(SUM(reported_cost_usd), 0) AS total_cost
FROM STAGING.STG_DISRUPTIONS
WHERE is_active = TRUE
GROUP BY disruption_type
ORDER BY active_count DESC;

-- Most expensive disruptions
SELECT 
    disruption_id,
    flight_number,
    disruption_type,
    disruption_subtype,
    severity,
    affected_city,
    impact_flights_count,
    impact_passengers_count,
    reported_cost_usd,
    recovery_status
FROM STAGING.STG_DISRUPTIONS
WHERE is_active = TRUE
ORDER BY reported_cost_usd DESC
LIMIT 10;

-- Disruption trends by day
SELECT 
    DATE(start_time_utc) AS disruption_date,
    COUNT(*) AS disruption_count,
    SUM(CASE WHEN disruption_type = 'WEATHER' THEN 1 ELSE 0 END) AS weather,
    SUM(CASE WHEN disruption_type = 'MECHANICAL' THEN 1 ELSE 0 END) AS mechanical,
    SUM(CASE WHEN disruption_type = 'CREW' THEN 1 ELSE 0 END) AS crew,
    ROUND(SUM(reported_cost_usd), 0) AS daily_cost
FROM STAGING.STG_DISRUPTIONS
WHERE start_time_utc >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY DATE(start_time_utc)
ORDER BY disruption_date DESC;

-- Cascading impact analysis for active disruptions
SELECT 
    d.disruption_id,
    d.flight_number,
    d.disruption_type,
    c.total_downstream_flights,
    c.total_downstream_passengers,
    c.total_cascade_cost,
    c.avg_cascade_delay,
    c.cascade_types
FROM STAGING.STG_DISRUPTIONS d
JOIN ML_MODELS.CASCADING_IMPACT_SUMMARY c ON d.disruption_id = c.disruption_id
WHERE d.is_active = TRUE
ORDER BY c.total_cascade_cost DESC
LIMIT 10;

-- ============================================================================
-- 6. AI FUNCTIONS DEMO QUERIES
-- ============================================================================

-- Auto-classify disruption severity
SELECT 
    disruption_id,
    description,
    original_severity,
    ai_classified_severity,
    severity_matches
FROM ML_MODELS.AUTO_CLASSIFIED_DISRUPTIONS
LIMIT 5;

-- Generate disruption summary for OCC
SELECT ML_MODELS.GENERATE_DISRUPTION_SUMMARY(
    'WEATHER',
    'SEVERE',
    'ATL',
    45,
    8500,
    'Severe thunderstorms moving through Atlanta area causing ground stops and diversions. Multiple aircraft holding or diverting to alternate airports.'
) AS executive_summary;

-- Generate passenger notification
SELECT ML_MODELS.GENERATE_PASSENGER_NOTIFICATION(
    'PH1234',
    'ATL',
    'JFK',
    90,
    'Weather delays in Atlanta area',
    TRUE
) AS passenger_message;

-- Find similar historical incidents
SELECT * FROM TABLE(ML_MODELS.FIND_SIMILAR_INCIDENTS(
    'Major winter storm causing widespread cancellations and crew positioning issues',
    3
));

-- View similar incidents for active disruptions
SELECT 
    disruption_id,
    disruption_type,
    severity,
    similar_incident_id,
    similar_trigger,
    proven_recovery_strategy,
    historical_recovery_time,
    similarity_score
FROM ML_MODELS.INCIDENT_SIMILARITY_ANALYSIS
ORDER BY similarity_score DESC
LIMIT 10;

-- ============================================================================
-- 7. CONTRACT BOT DEMO QUERIES
-- ============================================================================

-- Validate a specific crew assignment
SELECT ML_MODELS.VALIDATE_CREW_ASSIGNMENT(
    (SELECT crew_id FROM STAGING.STG_CREW WHERE crew_type = 'CAPTAIN' AND availability_status = 'AVAILABLE' LIMIT 1),
    (SELECT flight_id FROM STAGING.STG_FLIGHTS WHERE flight_date = CURRENT_DATE() LIMIT 1),
    'CAPTAIN'
) AS validation_result;

-- Ask Contract Bot a question
SELECT ML_MODELS.CONTRACT_BOT_QUERY(
    'Can a pilot who has flown 95 hours this month accept a 6-hour flight assignment?'
) AS contract_bot_answer;

-- View crew assignment validations for today's flights
SELECT 
    flight_number,
    origin || ' -> ' || destination AS route,
    captain_name,
    captain_validation:is_legal::BOOLEAN AS captain_legal,
    captain_validation:recommendation::VARCHAR AS captain_recommendation,
    first_officer_name,
    fo_validation:is_legal::BOOLEAN AS fo_legal,
    fo_validation:recommendation::VARCHAR AS fo_recommendation
FROM ML_MODELS.CREW_ASSIGNMENT_VALIDATIONS
LIMIT 10;

-- ============================================================================
-- 8. NETWORK HEALTH QUERIES
-- ============================================================================

-- Hub status overview
SELECT 
    airport_code,
    city,
    current_flight_category,
    weather_impact_score,
    operations_recommendation,
    available_captains,
    available_aircraft,
    aircraft_without_captain AS ghost_planes,
    operational_capacity_score
FROM INTERMEDIATE.INT_CREW_AIRCRAFT_STATUS
WHERE is_hub = TRUE
ORDER BY operational_capacity_score ASC;

-- Weather impact across network
SELECT 
    w.airport_code,
    w.city,
    w.flight_category,
    w.weather_impact_score,
    w.weather_phenomena,
    w.ground_stop_active,
    w.ground_delay_minutes,
    w.operations_recommendation
FROM STAGING.STG_WEATHER w
WHERE w.weather_impact_score >= 50
ORDER BY w.weather_impact_score DESC;

-- ============================================================================
-- 9. COST ANALYSIS QUERIES
-- ============================================================================

-- Today's cost breakdown
SELECT 
    'Disruption Direct Costs' AS cost_category,
    SUM(reported_cost_usd) AS amount
FROM STAGING.STG_DISRUPTIONS
WHERE DATE(start_time_utc) = CURRENT_DATE()
UNION ALL
SELECT 
    'Passenger Impact Costs',
    SUM(estimated_pax_cost_usd)
FROM INTERMEDIATE.INT_FLIGHT_DISRUPTION_IMPACT
WHERE flight_date = CURRENT_DATE()
UNION ALL
SELECT 
    'Crew Impact Costs',
    SUM(estimated_crew_cost_usd)
FROM INTERMEDIATE.INT_FLIGHT_DISRUPTION_IMPACT
WHERE flight_date = CURRENT_DATE()
UNION ALL
SELECT 
    'Cascading Impact Costs',
    SUM(total_cascade_cost)
FROM ML_MODELS.CASCADING_IMPACT_SUMMARY;

-- Cost by disruption type
SELECT 
    disruption_type,
    COUNT(*) AS event_count,
    SUM(impact_passengers_count) AS passengers_affected,
    ROUND(SUM(reported_cost_usd), 0) AS total_cost,
    ROUND(AVG(reported_cost_usd), 0) AS avg_cost_per_event
FROM STAGING.STG_DISRUPTIONS
WHERE DATE(start_time_utc) >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY disruption_type
ORDER BY total_cost DESC;

-- ============================================================================
-- 10. SEMANTIC VIEW QUERIES (for Cortex Analyst)
-- ============================================================================

-- Flight operations metrics
SELECT 
    flight_date,
    COUNT(*) AS total_flights,
    SUM(CASE WHEN delay_category = 'ON_TIME' THEN 1 ELSE 0 END) AS on_time_flights,
    ROUND(SUM(CASE WHEN delay_category = 'ON_TIME' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS otp_pct,
    SUM(CASE WHEN flight_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancellations
FROM SEMANTIC_MODELS.FLIGHT_OPERATIONS_VIEW
WHERE flight_date >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY flight_date
ORDER BY flight_date DESC;

-- Crew availability summary
SELECT 
    base_airport,
    SUM(CASE WHEN crew_type = 'CAPTAIN' AND availability_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS available_captains,
    SUM(CASE WHEN crew_type = 'FIRST_OFFICER' AND availability_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS available_fos,
    ROUND(AVG(monthly_hours_remaining), 1) AS avg_monthly_hours_remaining
FROM SEMANTIC_MODELS.CREW_MANAGEMENT_VIEW
WHERE crew_type IN ('CAPTAIN', 'FIRST_OFFICER')
GROUP BY base_airport
ORDER BY available_captains DESC;

-- ============================================================================
-- SAMPLE QUERIES COMPLETE
-- ============================================================================
-- Categories covered:
--   1. Data Validation - Row counts and distributions
--   2. Golden Record - Unified operational view
--   3. Ghost Flights - Synchronization gaps
--   4. Crew Recovery - One-Click Recovery candidates
--   5. Disruption Analysis - Events and costs
--   6. AI Functions - Classification, generation, similarity
--   7. Contract Bot - PWA/FAA validation
--   8. Network Health - Hub status and weather
--   9. Cost Analysis - Financial impact
--   10. Semantic Views - Cortex Analyst queries
-- ============================================================================
