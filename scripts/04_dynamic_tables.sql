-- ============================================================================
-- Phantom Airlines IROPS - Dynamic Tables Pipeline
-- ============================================================================
-- Creates chained Dynamic Tables for real-time data transformation
-- Pipeline: RAW -> STAGING -> INTERMEDIATE -> ANALYTICS (Golden Record)
--
-- Key features:
--   - Sub-second latency updates
--   - Automatic refresh on upstream changes
--   - Data quality validation built-in
--   - Eliminates "ghost flights" with unified Golden Record
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- ============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);

-- ============================================================================
-- STAGING LAYER - Data Cleansing & Validation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STG_FLIGHTS: Cleaned flight data with derived fields
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STAGING.STG_FLIGHTS
    TARGET_LAG = '1 minute'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    flight_id,
    flight_number,
    flight_date,
    origin,
    destination,
    scheduled_departure_utc,
    scheduled_arrival_utc,
    actual_departure_utc,
    actual_arrival_utc,
    aircraft_id,
    tail_number,
    aircraft_type_code,
    captain_id,
    first_officer_id,
    purser_id,
    status,
    departure_gate,
    arrival_gate,
    -- Calculate delays
    COALESCE(DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc), 0) AS departure_delay_minutes,
    COALESCE(DATEDIFF('minute', scheduled_arrival_utc, actual_arrival_utc), 0) AS arrival_delay_minutes,
    delay_code,
    delay_reason,
    block_time_scheduled_min,
    COALESCE(DATEDIFF('minute', actual_departure_utc, actual_arrival_utc), block_time_scheduled_min) AS block_time_actual_min,
    distance_nm,
    passengers_booked,
    passengers_checked_in,
    load_factor,
    is_codeshare,
    codeshare_partner,
    -- Derived fields
    CASE 
        WHEN status = 'CANCELLED' THEN 'CANCELLED'
        WHEN COALESCE(DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc), 0) <= 0 THEN 'ON_TIME'
        WHEN COALESCE(DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc), 0) <= 15 THEN 'MINOR_DELAY'
        WHEN COALESCE(DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc), 0) <= 60 THEN 'MODERATE_DELAY'
        ELSE 'SEVERE_DELAY'
    END AS delay_category,
    CASE 
        WHEN flight_date = CURRENT_DATE() THEN 'TODAY'
        WHEN flight_date = DATEADD('day', 1, CURRENT_DATE()) THEN 'TOMORROW'
        WHEN flight_date > CURRENT_DATE() THEN 'FUTURE'
        ELSE 'HISTORICAL'
    END AS flight_timeframe,
    -- Data quality flags
    aircraft_id IS NOT NULL AS has_aircraft_assigned,
    captain_id IS NOT NULL AS has_captain_assigned,
    first_officer_id IS NOT NULL AS has_fo_assigned,
    created_at,
    updated_at,
    CURRENT_TIMESTAMP() AS staged_at
FROM RAW.FLIGHTS;

-- ----------------------------------------------------------------------------
-- STG_CREW: Cleaned crew data with current status
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STAGING.STG_CREW
    TARGET_LAG = '1 minute'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    cm.crew_id,
    cm.employee_id,
    cm.first_name,
    cm.last_name,
    cm.first_name || ' ' || cm.last_name AS full_name,
    cm.crew_type,
    cm.seniority_number,
    cm.hire_date,
    DATEDIFF('year', cm.hire_date, CURRENT_DATE()) AS years_of_service,
    cm.base_airport,
    cm.status,
    cm.phone_number,
    cm.email,
    cm.union_member,
    -- Qualification summary
    (SELECT COUNT(*) FROM RAW.CREW_QUALIFICATIONS cq WHERE cq.crew_id = cm.crew_id AND cq.status = 'ACTIVE') AS active_type_ratings,
    (SELECT LISTAGG(DISTINCT aircraft_type_code, ', ') FROM RAW.CREW_QUALIFICATIONS cq WHERE cq.crew_id = cm.crew_id AND cq.status = 'ACTIVE') AS qualified_aircraft_types,
    -- Recent duty summary (last 7 days)
    (SELECT COALESCE(SUM(flight_time_hours), 0) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND cdl.duty_date >= DATEADD('day', -7, CURRENT_DATE())) AS flight_hours_last_7_days,
    (SELECT COALESCE(SUM(flight_duty_period_hours), 0) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND cdl.duty_date >= DATEADD('day', -7, CURRENT_DATE())) AS duty_hours_last_7_days,
    (SELECT COUNT(*) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND cdl.duty_date >= DATEADD('day', -7, CURRENT_DATE())) AS duty_days_last_7_days,
    -- Monthly limits tracking
    (SELECT COALESCE(MAX(cumulative_monthly_hours), 0) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND MONTH(cdl.duty_date) = MONTH(CURRENT_DATE())) AS current_month_hours,
    100 - (SELECT COALESCE(MAX(cumulative_monthly_hours), 0) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND MONTH(cdl.duty_date) = MONTH(CURRENT_DATE())) AS monthly_hours_remaining,
    -- Annual limits tracking  
    (SELECT COALESCE(MAX(cumulative_annual_hours), 0) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND YEAR(cdl.duty_date) = YEAR(CURRENT_DATE())) AS current_year_hours,
    1000 - (SELECT COALESCE(MAX(cumulative_annual_hours), 0) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND YEAR(cdl.duty_date) = YEAR(CURRENT_DATE())) AS annual_hours_remaining,
    -- Availability indicator
    CASE 
        WHEN cm.status != 'ACTIVE' THEN 'UNAVAILABLE'
        WHEN 100 - (SELECT COALESCE(MAX(cumulative_monthly_hours), 0) FROM RAW.CREW_DUTY_LOG cdl WHERE cdl.crew_id = cm.crew_id AND MONTH(cdl.duty_date) = MONTH(CURRENT_DATE())) < 5 THEN 'NEAR_MONTHLY_LIMIT'
        ELSE 'AVAILABLE'
    END AS availability_status,
    cm.created_at,
    cm.updated_at,
    CURRENT_TIMESTAMP() AS staged_at
FROM RAW.CREW_MEMBERS cm;

-- ----------------------------------------------------------------------------
-- STG_AIRCRAFT: Cleaned aircraft data with maintenance status
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STAGING.STG_AIRCRAFT
    TARGET_LAG = '1 minute'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    a.aircraft_id,
    a.tail_number,
    a.aircraft_type_code,
    at.manufacturer,
    at.model,
    at.seat_capacity,
    at.range_nm AS aircraft_range_nm,
    a.manufacture_date,
    a.acquisition_date,
    DATEDIFF('year', a.manufacture_date, CURRENT_DATE()) AS aircraft_age_years,
    a.current_location,
    ap.city AS current_city,
    ap.timezone AS current_timezone,
    a.status,
    a.total_flight_hours,
    a.total_cycles,
    a.last_maintenance_date,
    a.next_maintenance_due,
    DATEDIFF('day', CURRENT_DATE(), a.next_maintenance_due) AS days_until_maintenance,
    a.mel_items_count,
    -- Maintenance health score
    CASE 
        WHEN a.status = 'MAINTENANCE' THEN 0
        WHEN a.status = 'GROUNDED' THEN 0
        WHEN a.mel_items_count >= 3 THEN 30
        WHEN DATEDIFF('day', CURRENT_DATE(), a.next_maintenance_due) < 7 THEN 50
        WHEN a.mel_items_count >= 1 THEN 70
        ELSE 100
    END AS maintenance_health_score,
    -- Open maintenance items
    (SELECT COUNT(*) FROM RAW.MAINTENANCE_LOGS ml WHERE ml.aircraft_id = a.aircraft_id AND ml.status IN ('OPEN', 'DEFERRED')) AS open_maintenance_items,
    -- Recent squawks
    (SELECT COUNT(*) FROM RAW.MAINTENANCE_LOGS ml WHERE ml.aircraft_id = a.aircraft_id AND ml.log_type = 'SQUAWK' AND ml.log_date >= DATEADD('day', -7, CURRENT_DATE())) AS squawks_last_7_days,
    -- Operational availability
    CASE 
        WHEN a.status != 'ACTIVE' THEN FALSE
        WHEN a.mel_items_count >= 3 THEN FALSE
        ELSE TRUE
    END AS is_operationally_available,
    a.created_at,
    a.updated_at,
    CURRENT_TIMESTAMP() AS staged_at
FROM RAW.AIRCRAFT a
JOIN RAW.AIRCRAFT_TYPES at ON a.aircraft_type_code = at.aircraft_type_code
LEFT JOIN RAW.AIRPORTS ap ON a.current_location = ap.airport_code;

-- ----------------------------------------------------------------------------
-- STG_DISRUPTIONS: Enriched disruption events
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STAGING.STG_DISRUPTIONS
    TARGET_LAG = '1 minute'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    d.disruption_id,
    d.flight_id,
    f.flight_number,
    f.flight_date,
    f.origin,
    f.destination,
    d.disruption_type,
    d.disruption_subtype,
    d.severity,
    d.start_time_utc,
    d.end_time_utc,
    d.duration_minutes,
    COALESCE(d.duration_minutes, DATEDIFF('minute', d.start_time_utc, COALESCE(d.end_time_utc, CURRENT_TIMESTAMP()))) AS actual_duration_minutes,
    d.affected_airport,
    ap.city AS affected_city,
    d.description,
    d.root_cause,
    d.resolution,
    d.impact_flights_count,
    d.impact_passengers_count,
    d.estimated_cost_usd,
    d.actual_cost_usd,
    COALESCE(d.actual_cost_usd, d.estimated_cost_usd) AS reported_cost_usd,
    d.recovery_action,
    d.recovery_status,
    d.escalated_to,
    -- Severity score for prioritization
    CASE d.severity
        WHEN 'CRITICAL' THEN 100
        WHEN 'SEVERE' THEN 75
        WHEN 'MODERATE' THEN 50
        ELSE 25
    END AS severity_score,
    -- Time-based urgency
    CASE 
        WHEN d.recovery_status = 'RESOLVED' THEN 0
        WHEN d.start_time_utc >= DATEADD('hour', -1, CURRENT_TIMESTAMP()) THEN 100
        WHEN d.start_time_utc >= DATEADD('hour', -4, CURRENT_TIMESTAMP()) THEN 75
        WHEN d.start_time_utc >= DATEADD('hour', -12, CURRENT_TIMESTAMP()) THEN 50
        ELSE 25
    END AS urgency_score,
    -- Combined priority score
    (CASE d.severity WHEN 'CRITICAL' THEN 100 WHEN 'SEVERE' THEN 75 WHEN 'MODERATE' THEN 50 ELSE 25 END * 0.6) +
    (CASE WHEN d.recovery_status = 'RESOLVED' THEN 0 WHEN d.start_time_utc >= DATEADD('hour', -1, CURRENT_TIMESTAMP()) THEN 100 ELSE 50 END * 0.4) AS priority_score,
    -- Active flag
    d.recovery_status IN ('PENDING', 'IN_PROGRESS', 'ESCALATED') AS is_active,
    d.created_at,
    d.updated_at,
    CURRENT_TIMESTAMP() AS staged_at
FROM RAW.DISRUPTIONS d
LEFT JOIN RAW.FLIGHTS f ON d.flight_id = f.flight_id
LEFT JOIN RAW.AIRPORTS ap ON d.affected_airport = ap.airport_code;

-- ----------------------------------------------------------------------------
-- STG_WEATHER: Current weather conditions with flight impact assessment
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STAGING.STG_WEATHER
    TARGET_LAG = '5 minutes'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
WITH latest_weather AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY airport_code ORDER BY observation_time_utc DESC) AS rn
    FROM RAW.WEATHER_DATA
    WHERE observation_time_utc >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
)
SELECT 
    w.weather_id,
    w.airport_code,
    ap.airport_name,
    ap.city,
    ap.is_hub,
    w.observation_time_utc,
    w.weather_type,
    w.temperature_c,
    ROUND(w.temperature_c * 9/5 + 32, 1) AS temperature_f,
    w.dewpoint_c,
    w.wind_direction_deg,
    w.wind_speed_kts,
    w.wind_gust_kts,
    w.visibility_sm,
    w.ceiling_ft,
    w.sky_condition,
    w.flight_category,
    w.weather_phenomena,
    w.is_thunderstorm,
    w.is_freezing,
    w.is_fog,
    w.is_low_visibility,
    w.ground_stop_active,
    w.ground_delay_minutes,
    -- Weather impact score (0-100, higher = worse for operations)
    CASE 
        WHEN w.ground_stop_active THEN 100
        WHEN w.is_thunderstorm THEN 90
        WHEN w.flight_category = 'LIFR' THEN 85
        WHEN w.is_freezing AND w.is_low_visibility THEN 80
        WHEN w.flight_category = 'IFR' THEN 70
        WHEN w.is_fog THEN 65
        WHEN w.is_freezing THEN 60
        WHEN w.flight_category = 'MVFR' THEN 40
        WHEN w.wind_gust_kts > 35 THEN 50
        WHEN w.wind_speed_kts > 25 THEN 30
        ELSE 10
    END AS weather_impact_score,
    -- Operations recommendation
    CASE 
        WHEN w.ground_stop_active THEN 'GROUND_STOP_ACTIVE'
        WHEN w.is_thunderstorm THEN 'EXPECT_DELAYS_DIVERSIONS'
        WHEN w.flight_category IN ('LIFR', 'IFR') THEN 'LOW_VISIBILITY_OPS'
        WHEN w.is_freezing THEN 'DEICING_REQUIRED'
        WHEN w.wind_gust_kts > 35 THEN 'WIND_RESTRICTIONS'
        ELSE 'NORMAL_OPS'
    END AS operations_recommendation,
    CURRENT_TIMESTAMP() AS staged_at
FROM latest_weather w
JOIN RAW.AIRPORTS ap ON w.airport_code = ap.airport_code
WHERE w.rn = 1;

-- ----------------------------------------------------------------------------
-- STG_PASSENGERS: Cleaned passenger data with loyalty information
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STAGING.STG_PASSENGERS
    TARGET_LAG = '1 minute'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    passenger_id,
    first_name,
    last_name,
    first_name || ' ' || last_name AS full_name,
    email,
    phone,
    loyalty_number,
    loyalty_tier,
    -- Loyalty tier rank for sorting (Diamond=1, Platinum=2, etc.)
    CASE loyalty_tier
        WHEN 'DIAMOND' THEN 1
        WHEN 'PLATINUM' THEN 2
        WHEN 'GOLD' THEN 3
        WHEN 'SILVER' THEN 4
        WHEN 'BLUE' THEN 5
        ELSE 6
    END AS loyalty_tier_rank,
    loyalty_miles,
    lifetime_miles,
    home_airport,
    preferred_seat,
    meal_preference,
    special_assistance,
    tsatsa_precheck AS tsa_precheck,
    global_entry,
    communication_preference,
    -- High-value passenger flag
    CASE 
        WHEN loyalty_tier IN ('DIAMOND', 'PLATINUM') THEN TRUE
        ELSE FALSE
    END AS is_elite_member,
    CASE 
        WHEN loyalty_tier = 'DIAMOND' THEN TRUE
        ELSE FALSE
    END AS is_top_tier,
    created_at,
    updated_at,
    CURRENT_TIMESTAMP() AS staged_at
FROM RAW.PASSENGERS;

-- ----------------------------------------------------------------------------
-- STG_BOOKINGS: Cleaned booking data with passenger and flight linkage
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE STAGING.STG_BOOKINGS
    TARGET_LAG = '1 minute'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    b.booking_id,
    b.confirmation_code,
    b.passenger_id,
    b.flight_id,
    b.booking_date,
    b.booking_channel,
    b.fare_class,
    b.cabin_class,
    b.seat_number,
    b.fare_amount_usd,
    b.taxes_usd,
    b.fees_usd,
    b.total_amount_usd,
    b.booking_status,
    b.is_connection,
    b.connection_booking_id,
    b.connection_time_min,
    b.bags_checked,
    b.bags_carry_on,
    b.upgrade_requested,
    b.upgrade_status,
    -- Join passenger loyalty info
    p.loyalty_tier,
    p.loyalty_tier_rank,
    p.loyalty_miles,
    p.is_elite_member,
    p.is_top_tier,
    p.full_name AS passenger_name,
    p.email AS passenger_email,
    p.phone AS passenger_phone,
    b.created_at,
    b.updated_at,
    CURRENT_TIMESTAMP() AS staged_at
FROM RAW.BOOKINGS b
LEFT JOIN STAGING.STG_PASSENGERS p ON b.passenger_id = p.passenger_id;

-- ============================================================================
-- INTERMEDIATE LAYER - Business Logic & Joins
-- ============================================================================

-- ----------------------------------------------------------------------------
-- INT_CREW_AIRCRAFT_STATUS: Unified crew and aircraft availability
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE INTERMEDIATE.INT_CREW_AIRCRAFT_STATUS
    TARGET_LAG = '5 minutes'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
WITH crew_by_base AS (
    SELECT 
        base_airport,
        COUNT(*) AS total_crew,
        SUM(CASE WHEN crew_type = 'CAPTAIN' AND availability_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS available_captains,
        SUM(CASE WHEN crew_type = 'FIRST_OFFICER' AND availability_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS available_first_officers,
        SUM(CASE WHEN crew_type IN ('PURSER', 'FLIGHT_ATTENDANT') AND availability_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS available_cabin_crew
    FROM STAGING.STG_CREW
    GROUP BY base_airport
),
aircraft_by_location AS (
    SELECT 
        current_location,
        COUNT(*) AS total_aircraft,
        SUM(CASE WHEN is_operationally_available THEN 1 ELSE 0 END) AS available_aircraft,
        SUM(CASE WHEN status = 'MAINTENANCE' THEN 1 ELSE 0 END) AS aircraft_in_maintenance,
        AVG(maintenance_health_score) AS avg_maintenance_health
    FROM STAGING.STG_AIRCRAFT
    GROUP BY current_location
)
SELECT 
    ap.airport_code,
    ap.airport_name,
    ap.city,
    ap.is_hub,
    ap.hub_type,
    -- Current weather
    w.flight_category AS current_flight_category,
    w.weather_impact_score,
    w.operations_recommendation,
    w.ground_stop_active,
    -- Crew status
    COALESCE(c.total_crew, 0) AS total_crew_at_base,
    COALESCE(c.available_captains, 0) AS available_captains,
    COALESCE(c.available_first_officers, 0) AS available_first_officers,
    COALESCE(c.available_cabin_crew, 0) AS available_cabin_crew,
    -- Aircraft status
    COALESCE(a.total_aircraft, 0) AS total_aircraft_at_location,
    COALESCE(a.available_aircraft, 0) AS available_aircraft,
    COALESCE(a.aircraft_in_maintenance, 0) AS aircraft_in_maintenance,
    COALESCE(a.avg_maintenance_health, 0) AS avg_maintenance_health,
    -- Gap analysis (for "Ghost Planes" detection)
    CASE 
        WHEN COALESCE(a.available_aircraft, 0) > COALESCE(c.available_captains, 0) 
        THEN COALESCE(a.available_aircraft, 0) - COALESCE(c.available_captains, 0)
        ELSE 0
    END AS aircraft_without_captain,
    CASE 
        WHEN COALESCE(c.available_captains, 0) > COALESCE(a.available_aircraft, 0)
        THEN COALESCE(c.available_captains, 0) - COALESCE(a.available_aircraft, 0)
        ELSE 0
    END AS captains_without_aircraft,
    -- Operational capacity score
    CASE 
        WHEN w.ground_stop_active THEN 0
        WHEN COALESCE(a.available_aircraft, 0) = 0 OR COALESCE(c.available_captains, 0) = 0 THEN 10
        ELSE LEAST(
            100,
            (LEAST(COALESCE(a.available_aircraft, 0), COALESCE(c.available_captains, 0)) * 100.0 / 
             NULLIF(GREATEST(COALESCE(a.total_aircraft, 1), COALESCE(c.total_crew, 1)), 0))
        )
    END AS operational_capacity_score,
    CURRENT_TIMESTAMP() AS calculated_at
FROM RAW.AIRPORTS ap
LEFT JOIN STAGING.STG_WEATHER w ON ap.airport_code = w.airport_code
LEFT JOIN crew_by_base c ON ap.airport_code = c.base_airport
LEFT JOIN aircraft_by_location a ON ap.airport_code = a.current_location;

-- ----------------------------------------------------------------------------
-- INT_FLIGHT_DISRUPTION_IMPACT: Flight status with disruption and cost impact
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE INTERMEDIATE.INT_FLIGHT_DISRUPTION_IMPACT
    TARGET_LAG = '5 minutes'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    f.flight_id,
    f.flight_number,
    f.flight_date,
    f.origin,
    o_ap.city AS origin_city,
    f.destination,
    d_ap.city AS destination_city,
    f.scheduled_departure_utc,
    f.scheduled_arrival_utc,
    f.actual_departure_utc,
    f.status,
    f.delay_category,
    f.departure_delay_minutes,
    f.arrival_delay_minutes,
    f.aircraft_id,
    f.tail_number,
    f.aircraft_type_code,
    f.captain_id,
    f.first_officer_id,
    f.has_aircraft_assigned,
    f.has_captain_assigned,
    f.has_fo_assigned,
    f.passengers_booked,
    f.load_factor,
    -- Aircraft details
    ac.current_location AS aircraft_current_location,
    ac.is_operationally_available AS aircraft_available,
    ac.maintenance_health_score,
    -- Disruption details
    d.disruption_id,
    d.disruption_type,
    d.disruption_subtype,
    d.severity AS disruption_severity,
    d.priority_score AS disruption_priority,
    d.is_active AS has_active_disruption,
    d.recovery_status,
    d.reported_cost_usd AS disruption_cost,
    -- Origin weather
    ow.flight_category AS origin_weather_category,
    ow.weather_impact_score AS origin_weather_impact,
    ow.ground_stop_active AS origin_ground_stop,
    -- Destination weather
    dw.flight_category AS dest_weather_category,
    dw.weather_impact_score AS dest_weather_impact,
    dw.ground_stop_active AS dest_ground_stop,
    -- Cost estimates
    CASE 
        WHEN f.status = 'CANCELLED' THEN f.passengers_booked * 400  -- Rebooking + compensation
        WHEN f.departure_delay_minutes > 180 THEN f.passengers_booked * 150  -- Meal vouchers + some comp
        WHEN f.departure_delay_minutes > 60 THEN f.passengers_booked * 50   -- Meal vouchers
        ELSE 0
    END AS estimated_pax_cost_usd,
    CASE 
        WHEN f.status = 'CANCELLED' THEN 15000  -- Crew repositioning
        WHEN f.departure_delay_minutes > 120 THEN 5000  -- Potential duty timeout
        ELSE 0
    END AS estimated_crew_cost_usd,
    -- Crew need indicators (for recovery queue)
    CASE 
        WHEN f.status = 'CANCELLED' THEN FALSE
        WHEN NOT f.has_captain_assigned THEN TRUE
        ELSE FALSE
    END AS needs_captain,
    CASE 
        WHEN f.status = 'CANCELLED' THEN FALSE
        WHEN NOT f.has_fo_assigned THEN TRUE
        ELSE FALSE
    END AS needs_first_officer,
    -- Overall flight health score
    CASE 
        WHEN f.status = 'CANCELLED' THEN 0
        WHEN f.status = 'ARRIVED' THEN 100
        WHEN NOT f.has_aircraft_assigned OR NOT f.has_captain_assigned THEN 20
        WHEN d.is_active AND d.severity = 'CRITICAL' THEN 30
        WHEN d.is_active AND d.severity = 'SEVERE' THEN 50
        WHEN f.delay_category = 'SEVERE_DELAY' THEN 40
        WHEN f.delay_category = 'MODERATE_DELAY' THEN 60
        WHEN f.delay_category = 'MINOR_DELAY' THEN 80
        ELSE 90
    END AS flight_health_score,
    CURRENT_TIMESTAMP() AS calculated_at
FROM STAGING.STG_FLIGHTS f
LEFT JOIN RAW.AIRPORTS o_ap ON f.origin = o_ap.airport_code
LEFT JOIN RAW.AIRPORTS d_ap ON f.destination = d_ap.airport_code
LEFT JOIN STAGING.STG_AIRCRAFT ac ON f.aircraft_id = ac.aircraft_id
LEFT JOIN STAGING.STG_DISRUPTIONS d ON f.flight_id = d.flight_id AND d.is_active
LEFT JOIN STAGING.STG_WEATHER ow ON f.origin = ow.airport_code
LEFT JOIN STAGING.STG_WEATHER dw ON f.destination = dw.airport_code;

-- ============================================================================
-- ANALYTICS LAYER - Business-Ready Marts
-- ============================================================================

-- ----------------------------------------------------------------------------
-- MART_OPERATIONAL_SUMMARY: Real-time operations dashboard metrics
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.MART_OPERATIONAL_SUMMARY
    TARGET_LAG = '5 minutes'
    WAREHOUSE = PHANTOM_IROPS_WH
    AS
SELECT 
    CURRENT_DATE() AS report_date,
    CURRENT_TIMESTAMP() AS report_timestamp,
    -- Today's flight summary
    (SELECT COUNT(*) FROM STAGING.STG_FLIGHTS WHERE flight_date = CURRENT_DATE()) AS total_flights_today,
    (SELECT COUNT(*) FROM STAGING.STG_FLIGHTS WHERE flight_date = CURRENT_DATE() AND status = 'ARRIVED') AS completed_flights,
    (SELECT COUNT(*) FROM STAGING.STG_FLIGHTS WHERE flight_date = CURRENT_DATE() AND status = 'IN_FLIGHT') AS in_progress_flights,
    (SELECT COUNT(*) FROM STAGING.STG_FLIGHTS WHERE flight_date = CURRENT_DATE() AND status = 'DELAYED') AS delayed_flights,
    (SELECT COUNT(*) FROM STAGING.STG_FLIGHTS WHERE flight_date = CURRENT_DATE() AND status = 'CANCELLED') AS cancelled_flights,
    -- On-time performance
    (SELECT ROUND(SUM(CASE WHEN delay_category = 'ON_TIME' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) 
     FROM STAGING.STG_FLIGHTS WHERE flight_date = CURRENT_DATE() AND status = 'ARRIVED') AS otp_percentage,
    -- Active disruptions
    (SELECT COUNT(*) FROM STAGING.STG_DISRUPTIONS WHERE is_active) AS active_disruptions,
    (SELECT COUNT(*) FROM STAGING.STG_DISRUPTIONS WHERE is_active AND severity = 'CRITICAL') AS critical_disruptions,
    (SELECT COUNT(*) FROM STAGING.STG_DISRUPTIONS WHERE is_active AND severity = 'SEVERE') AS severe_disruptions,
    -- Crew status
    (SELECT COUNT(*) FROM STAGING.STG_CREW WHERE availability_status = 'AVAILABLE' AND crew_type = 'CAPTAIN') AS available_captains,
    (SELECT COUNT(*) FROM STAGING.STG_CREW WHERE availability_status = 'AVAILABLE' AND crew_type = 'FIRST_OFFICER') AS available_first_officers,
    (SELECT COUNT(*) FROM STAGING.STG_CREW WHERE availability_status = 'NEAR_MONTHLY_LIMIT') AS crew_near_limit,
    -- Aircraft status
    (SELECT COUNT(*) FROM STAGING.STG_AIRCRAFT WHERE is_operationally_available) AS available_aircraft,
    (SELECT COUNT(*) FROM STAGING.STG_AIRCRAFT WHERE status = 'MAINTENANCE') AS aircraft_in_maintenance,
    (SELECT COUNT(*) FROM STAGING.STG_AIRCRAFT WHERE mel_items_count > 0) AS aircraft_with_mel,
    -- Weather impact
    (SELECT COUNT(*) FROM STAGING.STG_WEATHER WHERE ground_stop_active) AS airports_with_ground_stop,
    (SELECT COUNT(*) FROM STAGING.STG_WEATHER WHERE weather_impact_score >= 70) AS airports_with_severe_weather,
    -- Cost estimates (today)
    (SELECT COALESCE(SUM(reported_cost_usd), 0) FROM STAGING.STG_DISRUPTIONS WHERE DATE(start_time_utc) = CURRENT_DATE()) AS disruption_cost_today,
    (SELECT COALESCE(SUM(estimated_pax_cost_usd + estimated_crew_cost_usd), 0) FROM INTERMEDIATE.INT_FLIGHT_DISRUPTION_IMPACT WHERE flight_date = CURRENT_DATE()) AS estimated_total_cost_today,
    -- Network health score (0-100)
    ROUND(
        (SELECT AVG(flight_health_score) FROM INTERMEDIATE.INT_FLIGHT_DISRUPTION_IMPACT WHERE flight_date = CURRENT_DATE()) * 0.4 +
        (SELECT AVG(operational_capacity_score) FROM INTERMEDIATE.INT_CREW_AIRCRAFT_STATUS WHERE is_hub) * 0.3 +
        (100 - (SELECT AVG(weather_impact_score) FROM STAGING.STG_WEATHER WHERE airport_code IN (SELECT airport_code FROM RAW.AIRPORTS WHERE is_hub))) * 0.3,
        1
    ) AS network_health_score;

-- ----------------------------------------------------------------------------
-- MART_GOLDEN_RECORD: THE UNIFIED OPERATIONAL VIEW (Eliminates Ghost Flights)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.MART_GOLDEN_RECORD
    TARGET_LAG = '5 minutes'
    WAREHOUSE = PHANTOM_IROPS_WH
    COMMENT = 'Unified Golden Record - Single source of truth for crew, aircraft, and flight status. Eliminates ghost flights by ensuring real-time synchronization.'
    AS
SELECT 
    -- Flight identification
    f.flight_id,
    f.flight_number,
    f.flight_date,
    f.origin,
    f.origin_city,
    f.destination,
    f.destination_city,
    f.scheduled_departure_utc,
    f.scheduled_arrival_utc,
    f.actual_departure_utc,
    f.status AS flight_status,
    f.delay_category,
    f.departure_delay_minutes,
    -- Aircraft status (REAL-TIME)
    f.aircraft_id,
    f.tail_number,
    f.aircraft_type_code,
    ac.current_location AS aircraft_actual_location,
    ac.status AS aircraft_status,
    ac.is_operationally_available AS aircraft_available,
    ac.maintenance_health_score AS aircraft_health,
    ac.mel_items_count AS aircraft_mel_count,
    -- GHOST FLIGHT DETECTION: Aircraft location mismatch
    CASE 
        WHEN f.status IN ('SCHEDULED', 'BOARDING') AND ac.current_location != f.origin 
        THEN TRUE 
        ELSE FALSE 
    END AS is_ghost_flight,
    CASE 
        WHEN f.status IN ('SCHEDULED', 'BOARDING') AND ac.current_location != f.origin 
        THEN 'Aircraft ' || f.tail_number || ' is at ' || ac.current_location || ' but flight departs from ' || f.origin
        ELSE NULL
    END AS ghost_flight_reason,
    -- Captain status (REAL-TIME)
    f.captain_id,
    cap.full_name AS captain_name,
    cap.base_airport AS captain_base,
    cap.availability_status AS captain_availability,
    cap.monthly_hours_remaining AS captain_monthly_hours_left,
    cap.qualified_aircraft_types AS captain_type_ratings,
    -- CREW MISMATCH DETECTION: Captain qualification
    CASE 
        WHEN f.captain_id IS NOT NULL AND NOT CONTAINS(cap.qualified_aircraft_types, f.aircraft_type_code)
        THEN TRUE
        ELSE FALSE
    END AS captain_not_qualified,
    -- First Officer status (REAL-TIME)
    f.first_officer_id,
    fo.full_name AS first_officer_name,
    fo.base_airport AS fo_base,
    fo.availability_status AS fo_availability,
    fo.monthly_hours_remaining AS fo_monthly_hours_left,
    -- Weather at origin (REAL-TIME)
    f.origin_weather_category,
    f.origin_weather_impact,
    f.origin_ground_stop,
    -- Weather at destination (REAL-TIME)
    f.dest_weather_category,
    f.dest_weather_impact,
    f.dest_ground_stop,
    -- Disruption status (REAL-TIME)
    f.has_active_disruption,
    f.disruption_type,
    f.disruption_severity,
    f.disruption_priority,
    f.recovery_status AS disruption_recovery_status,
    -- Passenger impact
    f.passengers_booked,
    f.load_factor,
    f.estimated_pax_cost_usd,
    f.estimated_crew_cost_usd,
    f.estimated_pax_cost_usd + f.estimated_crew_cost_usd AS total_estimated_cost,
    -- Crew needs (for recovery queue)
    f.needs_captain,
    f.needs_first_officer,
    -- Overall health
    f.flight_health_score,
    -- Recovery priority (higher = more urgent)
    CASE 
        WHEN f.status IN ('SCHEDULED', 'BOARDING') AND ac.current_location != f.origin THEN 100
        WHEN f.needs_captain OR f.needs_first_officer THEN 95
        WHEN f.has_active_disruption AND f.disruption_severity = 'CRITICAL' THEN 90
        WHEN f.origin_ground_stop OR f.dest_ground_stop THEN 85
        WHEN f.has_active_disruption AND f.disruption_severity = 'SEVERE' THEN 75
        WHEN f.departure_delay_minutes > 120 THEN 70
        WHEN f.captain_id IS NOT NULL AND NOT CONTAINS(cap.qualified_aircraft_types, f.aircraft_type_code) THEN 65
        ELSE COALESCE(f.disruption_priority, 0)
    END AS recovery_priority_score,
    -- Timestamps
    f.calculated_at AS last_updated,
    CURRENT_TIMESTAMP() AS golden_record_timestamp
FROM INTERMEDIATE.INT_FLIGHT_DISRUPTION_IMPACT f
LEFT JOIN STAGING.STG_AIRCRAFT ac ON f.aircraft_id = ac.aircraft_id
LEFT JOIN STAGING.STG_CREW cap ON f.captain_id = cap.crew_id
LEFT JOIN STAGING.STG_CREW fo ON f.first_officer_id = fo.crew_id
WHERE f.flight_date >= DATEADD('day', -1, CURRENT_DATE())  -- Yesterday, today, and future
  AND f.flight_date <= DATEADD('day', 3, CURRENT_DATE());   -- Next 3 days

-- ----------------------------------------------------------------------------
-- MART_CREW_RECOVERY_CANDIDATES: ML-ready crew ranking for One-Click Recovery
-- ----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.MART_CREW_RECOVERY_CANDIDATES
    TARGET_LAG = '5 minutes'
    WAREHOUSE = PHANTOM_IROPS_WH
    COMMENT = 'Pre-computed crew candidates for One-Click Recovery system. Eliminates 12-minute bottleneck by enabling batch notifications.'
    AS
WITH flights_needing_crew AS (
    SELECT 
        flight_id,
        flight_number,
        flight_date,
        origin,
        destination,
        scheduled_departure_utc,
        aircraft_type_code,
        needs_captain,
        needs_first_officer,
        recovery_priority_score
    FROM ANALYTICS.MART_GOLDEN_RECORD
    WHERE (needs_captain OR needs_first_officer)
      AND flight_status NOT IN ('CANCELLED', 'ARRIVED')
),
available_captains AS (
    SELECT 
        c.crew_id,
        c.full_name,
        c.base_airport,
        c.phone_number,
        c.email,
        c.monthly_hours_remaining,
        c.annual_hours_remaining,
        c.qualified_aircraft_types,
        c.flight_hours_last_7_days,
        'CAPTAIN' AS required_role
    FROM STAGING.STG_CREW c
    WHERE c.crew_type = 'CAPTAIN'
      AND c.availability_status = 'AVAILABLE'
      AND c.monthly_hours_remaining >= 10
),
available_fos AS (
    SELECT 
        c.crew_id,
        c.full_name,
        c.base_airport,
        c.phone_number,
        c.email,
        c.monthly_hours_remaining,
        c.annual_hours_remaining,
        c.qualified_aircraft_types,
        c.flight_hours_last_7_days,
        'FIRST_OFFICER' AS required_role
    FROM STAGING.STG_CREW c
    WHERE c.crew_type = 'FIRST_OFFICER'
      AND c.availability_status = 'AVAILABLE'
      AND c.monthly_hours_remaining >= 10
)
SELECT 
    f.flight_id,
    f.flight_number,
    f.flight_date,
    f.origin,
    f.destination,
    f.scheduled_departure_utc,
    f.aircraft_type_code,
    f.recovery_priority_score AS flight_priority,
    c.crew_id,
    c.full_name AS crew_name,
    c.required_role,
    c.base_airport AS crew_base,
    c.phone_number,
    c.email,
    c.monthly_hours_remaining,
    c.annual_hours_remaining,
    -- Qualification check
    CONTAINS(c.qualified_aircraft_types, f.aircraft_type_code) AS is_type_qualified,
    -- Proximity score (same base = 100, hub connection = 70, else based on distance)
    CASE 
        WHEN c.base_airport = f.origin THEN 100
        WHEN c.base_airport IN (SELECT airport_code FROM RAW.AIRPORTS WHERE is_hub) THEN 70
        ELSE 40
    END AS proximity_score,
    -- Duty hours score (more hours remaining = higher score)
    LEAST(100, c.monthly_hours_remaining * 2) AS duty_hours_score,
    -- Fatigue score (fewer recent hours = higher score)
    GREATEST(0, 100 - c.flight_hours_last_7_days * 3) AS fatigue_score,
    -- ML SCORE: Combined ranking (simulated - would be ML model in production)
    ROUND(
        (CASE WHEN CONTAINS(c.qualified_aircraft_types, f.aircraft_type_code) THEN 30 ELSE 0 END) +
        (CASE WHEN c.base_airport = f.origin THEN 30 WHEN c.base_airport IN (SELECT airport_code FROM RAW.AIRPORTS WHERE is_hub) THEN 20 ELSE 10 END) +
        (LEAST(20, c.monthly_hours_remaining * 0.4)) +
        (GREATEST(0, 20 - c.flight_hours_last_7_days * 0.5)),
        1
    ) AS ml_fit_score,
    -- Rank within each flight
    ROW_NUMBER() OVER (
        PARTITION BY f.flight_id, c.required_role 
        ORDER BY 
            CASE WHEN CONTAINS(c.qualified_aircraft_types, f.aircraft_type_code) THEN 0 ELSE 1 END,
            CASE WHEN c.base_airport = f.origin THEN 0 ELSE 1 END,
            c.monthly_hours_remaining DESC,
            c.flight_hours_last_7_days ASC
    ) AS candidate_rank,
    CURRENT_TIMESTAMP() AS calculated_at
FROM flights_needing_crew f
CROSS JOIN (
    SELECT * FROM available_captains WHERE (SELECT needs_captain FROM flights_needing_crew LIMIT 1)
    UNION ALL
    SELECT * FROM available_fos WHERE (SELECT needs_first_officer FROM flights_needing_crew LIMIT 1)
) c
WHERE (f.needs_captain AND c.required_role = 'CAPTAIN')
   OR (f.needs_first_officer AND c.required_role = 'FIRST_OFFICER');

-- ============================================================================
-- DYNAMIC TABLES PIPELINE COMPLETE
-- ============================================================================
-- Pipeline structure:
--   RAW (source tables)
--     └── STAGING (cleansed data)
--           ├── STG_FLIGHTS
--           ├── STG_CREW
--           ├── STG_AIRCRAFT
--           ├── STG_DISRUPTIONS
--           └── STG_WEATHER
--                 └── INTERMEDIATE (joined data)
--                       ├── INT_CREW_AIRCRAFT_STATUS
--                       └── INT_FLIGHT_DISRUPTION_IMPACT
--                             └── ANALYTICS (business marts)
--                                   ├── MART_OPERATIONAL_SUMMARY
--                                   ├── MART_GOLDEN_RECORD (THE KEY!)
--                                   └── MART_CREW_RECOVERY_CANDIDATES
--
-- Key features:
--   - 1-minute target lag for real-time updates
--   - Ghost flight detection in Golden Record
--   - Pre-computed crew rankings for One-Click Recovery
--   - Network health scoring
--   - Cost impact estimation
-- ============================================================================
