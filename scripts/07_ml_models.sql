-- ============================================================================
-- Phantom Airlines IROPS - ML Models Setup
-- ============================================================================
-- Creates schema infrastructure and fallback views for ML models.
-- 
-- PRIMARY ML MODELS are created via Snowflake Notebooks in /notebooks/:
--   - 01_delay_prediction_model.ipynb (Feature Store + Model Registry)
--   - 02_crew_ranking_model.ipynb (Feature Store + Model Registry)
--   - 03_cost_estimation_model.ipynb (Feature Store + Model Registry)
--
-- This script creates:
--   1. ML_MODELS and FEATURE_STORE schemas
--   2. Fallback scoring functions for when notebooks haven't been run
--   3. Cascading impact analysis views (SQL-based, no ML training needed)
--   4. Model monitoring views
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- ============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);

-- ============================================================================
-- 1. CREATE SCHEMAS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS ML_MODELS;
CREATE SCHEMA IF NOT EXISTS FEATURE_STORE;

USE SCHEMA ML_MODELS;

-- ============================================================================
-- 2. CREW FIT SCORING FUNCTION (Fallback when notebook model not available)
-- ============================================================================
-- This function provides deterministic crew ranking for One-Click Recovery.
-- The notebook-based LightGBM model provides ML-enhanced predictions.

CREATE OR REPLACE FUNCTION CALCULATE_CREW_FIT_SCORE(
    is_type_qualified BOOLEAN,
    is_same_base BOOLEAN,
    monthly_hours_remaining FLOAT,
    flight_hours_last_7_days FLOAT,
    seniority_number INTEGER,
    historical_acceptance_rate FLOAT DEFAULT 0.5,
    faa_compliant BOOLEAN DEFAULT TRUE
)
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    CASE WHEN NOT faa_compliant THEN 0 ELSE
        (CASE WHEN is_type_qualified THEN 30 ELSE 0 END) +
        (CASE WHEN is_same_base THEN 25 ELSE 10 END) +
        (LEAST(20, monthly_hours_remaining * 0.4)) +
        (GREATEST(0, 10 - flight_hours_last_7_days * 0.3)) +
        (CASE WHEN seniority_number < 5000 THEN 5 ELSE 0 END) +
        (historical_acceptance_rate * 10)
    END
$$;

-- ============================================================================
-- 3. CREW CANDIDATE RANKINGS VIEW
-- ============================================================================

CREATE OR REPLACE VIEW CREW_CANDIDATE_RANKINGS AS
WITH flights_needing_crew AS (
    SELECT 
        f.FLIGHT_ID,
        f.FLIGHT_NUMBER,
        f.ORIGIN,
        f.DESTINATION,
        f.SCHEDULED_DEPARTURE_UTC,
        f.AIRCRAFT_TYPE_CODE,
        f.CAPTAIN_ID,
        f.FIRST_OFFICER_ID,
        CASE WHEN f.CAPTAIN_ID IS NULL THEN TRUE ELSE FALSE END AS NEEDS_CAPTAIN,
        CASE WHEN f.FIRST_OFFICER_ID IS NULL THEN TRUE ELSE FALSE END AS NEEDS_FIRST_OFFICER
    FROM ANALYTICS.MART_GOLDEN_RECORD f
    WHERE f.FLIGHT_DATE >= CURRENT_DATE()
      AND (f.CAPTAIN_ID IS NULL OR f.FIRST_OFFICER_ID IS NULL)
),
available_crew AS (
    SELECT 
        c.CREW_ID,
        c.FULL_NAME,
        c.CREW_TYPE,
        c.BASE_AIRPORT,
        c.PHONE_NUMBER,
        c.EMAIL,
        c.QUALIFIED_AIRCRAFT_TYPES,
        c.SENIORITY_NUMBER,
        c.MONTHLY_HOURS_REMAINING,
        c.FLIGHT_HOURS_LAST_7_DAYS AS FLIGHT_HOURS_7D,
        0.5 AS HISTORICAL_ACCEPTANCE_RATE,
        c.AVAILABILITY_STATUS = 'AVAILABLE' AS IS_AVAILABLE,
        c.MONTHLY_HOURS_REMAINING > 8 AS FAA_COMPLIANT
    FROM STAGING.STG_CREW c
    WHERE c.AVAILABILITY_STATUS = 'AVAILABLE'
      AND c.CREW_TYPE IN ('CAPTAIN', 'FIRST_OFFICER')
)
SELECT 
    f.FLIGHT_ID,
    f.FLIGHT_NUMBER,
    f.ORIGIN,
    f.DESTINATION,
    f.SCHEDULED_DEPARTURE_UTC,
    f.AIRCRAFT_TYPE_CODE,
    c.CREW_ID,
    c.FULL_NAME AS CREW_NAME,
    c.CREW_TYPE,
    c.BASE_AIRPORT,
    c.PHONE_NUMBER,
    c.EMAIL,
    CONTAINS(c.QUALIFIED_AIRCRAFT_TYPES, f.AIRCRAFT_TYPE_CODE) AS IS_TYPE_QUALIFIED,
    c.BASE_AIRPORT = f.ORIGIN AS IS_SAME_BASE,
    c.MONTHLY_HOURS_REMAINING,
    c.FLIGHT_HOURS_7D AS FLIGHT_HOURS_LAST_7_DAYS,
    c.SENIORITY_NUMBER,
    c.HISTORICAL_ACCEPTANCE_RATE,
    c.FAA_COMPLIANT,
    CALCULATE_CREW_FIT_SCORE(
        CONTAINS(c.QUALIFIED_AIRCRAFT_TYPES, f.AIRCRAFT_TYPE_CODE),
        c.BASE_AIRPORT = f.ORIGIN,
        c.MONTHLY_HOURS_REMAINING,
        c.FLIGHT_HOURS_7D,
        c.SENIORITY_NUMBER,
        c.HISTORICAL_ACCEPTANCE_RATE,
        c.FAA_COMPLIANT
    ) AS ML_FIT_SCORE,
    ROW_NUMBER() OVER (
        PARTITION BY f.FLIGHT_ID, c.CREW_TYPE 
        ORDER BY CALCULATE_CREW_FIT_SCORE(
            CONTAINS(c.QUALIFIED_AIRCRAFT_TYPES, f.AIRCRAFT_TYPE_CODE),
            c.BASE_AIRPORT = f.ORIGIN,
            c.MONTHLY_HOURS_REMAINING,
            c.FLIGHT_HOURS_7D,
            c.SENIORITY_NUMBER,
            c.HISTORICAL_ACCEPTANCE_RATE,
            c.FAA_COMPLIANT
        ) DESC
    ) AS CANDIDATE_RANK
FROM flights_needing_crew f
CROSS JOIN available_crew c
WHERE c.FAA_COMPLIANT
  AND (
    (f.NEEDS_CAPTAIN AND c.CREW_TYPE = 'CAPTAIN') OR
    (f.NEEDS_FIRST_OFFICER AND c.CREW_TYPE = 'FIRST_OFFICER')
  );

-- ============================================================================
-- 4. DELAY PREDICTIONS VIEW (Fallback)
-- ============================================================================

CREATE OR REPLACE VIEW DELAY_PREDICTIONS AS
WITH upcoming_flights AS (
    SELECT 
        f.FLIGHT_ID,
        f.FLIGHT_NUMBER,
        f.FLIGHT_DATE,
        f.ORIGIN,
        f.DESTINATION,
        f.SCHEDULED_DEPARTURE_UTC,
        f.STATUS,
        f.AIRCRAFT_TYPE_CODE,
        HOUR(f.SCHEDULED_DEPARTURE_UTC) AS DEPARTURE_HOUR,
        a.IS_HUB,
        COALESCE(w.WEATHER_IMPACT_SCORE, 20) AS WEATHER_IMPACT_SCORE,
        COALESCE(w.IS_THUNDERSTORM, FALSE) AS IS_THUNDERSTORM,
        COALESCE(w.GROUND_STOP_ACTIVE, FALSE) AS GROUND_STOP_ACTIVE,
        COALESCE(r.ROUTE_AVG_DELAY, 0) AS ROUTE_AVG_DELAY_30D
    FROM RAW.FLIGHTS f
    JOIN RAW.AIRPORTS a ON f.ORIGIN = a.AIRPORT_CODE
    LEFT JOIN STAGING.STG_WEATHER w ON f.ORIGIN = w.AIRPORT_CODE
    LEFT JOIN (
        SELECT ORIGIN, DESTINATION, AVG(DEPARTURE_DELAY_MINUTES) AS ROUTE_AVG_DELAY
        FROM STAGING.STG_FLIGHTS
        WHERE FLIGHT_DATE BETWEEN DATEADD('day', -30, CURRENT_DATE()) AND DATEADD('day', -1, CURRENT_DATE())
          AND DEPARTURE_DELAY_MINUTES IS NOT NULL
        GROUP BY ORIGIN, DESTINATION
    ) r ON f.ORIGIN = r.ORIGIN AND f.DESTINATION = r.DESTINATION
    WHERE f.FLIGHT_DATE >= CURRENT_DATE()
      AND f.STATUS IN ('SCHEDULED', 'BOARDING')
)
SELECT 
    FLIGHT_ID,
    FLIGHT_NUMBER,
    FLIGHT_DATE,
    ORIGIN,
    DESTINATION,
    SCHEDULED_DEPARTURE_UTC,
    STATUS,
    CASE 
        WHEN GROUND_STOP_ACTIVE THEN 'SEVERE_DELAY'
        WHEN IS_THUNDERSTORM THEN 'MODERATE_DELAY'
        WHEN WEATHER_IMPACT_SCORE > 70 THEN 'MODERATE_DELAY'
        WHEN WEATHER_IMPACT_SCORE > 50 THEN 'MINOR_DELAY'
        WHEN ROUTE_AVG_DELAY_30D > 30 THEN 'MINOR_DELAY'
        ELSE 'ON_TIME'
    END AS PREDICTED_DELAY_CATEGORY,
    WEATHER_IMPACT_SCORE,
    IS_THUNDERSTORM,
    GROUND_STOP_ACTIVE,
    ROUTE_AVG_DELAY_30D
FROM upcoming_flights;

-- ============================================================================
-- 5. COST PREDICTIONS VIEW (Fallback)
-- ============================================================================

CREATE OR REPLACE VIEW COST_PREDICTIONS AS
SELECT 
    d.DISRUPTION_ID,
    d.FLIGHT_ID,
    d.DISRUPTION_TYPE,
    d.SEVERITY,
    d.IMPACT_FLIGHTS_COUNT,
    d.IMPACT_PASSENGERS_COUNT,
    d.ESTIMATED_COST_USD AS CURRENT_ESTIMATE,
    (
        CASE d.SEVERITY 
            WHEN 'CRITICAL' THEN 4 
            WHEN 'SEVERE' THEN 3 
            WHEN 'MODERATE' THEN 2 
            ELSE 1 
        END * 5000 +
        COALESCE(d.ACTUAL_DURATION_MINUTES, 60) * 50 +
        COALESCE(d.IMPACT_FLIGHTS_COUNT, 1) * 2000 +
        COALESCE(d.IMPACT_PASSENGERS_COUNT, 100) * 75
    ) * CASE 
        WHEN d.DISRUPTION_TYPE = 'WEATHER' THEN 1.5
        WHEN d.DISRUPTION_TYPE = 'MECHANICAL' THEN 1.2
        ELSE 1.0
    END * CASE 
        WHEN a.IS_HUB AND a.HUB_TYPE = 'PRIMARY' THEN 2.0
        WHEN a.IS_HUB THEN 1.5
        ELSE 1.0
    END AS ML_PREDICTED_COST
FROM STAGING.STG_DISRUPTIONS d
LEFT JOIN RAW.AIRPORTS a ON d.AFFECTED_AIRPORT = a.AIRPORT_CODE
WHERE d.RECOVERY_STATUS IN ('PENDING', 'IN_PROGRESS');

-- ============================================================================
-- 6. CASCADING IMPACT PREDICTION
-- ============================================================================

CREATE OR REPLACE VIEW CASCADING_IMPACT_PREDICTIONS AS
WITH initial_disruption AS (
    SELECT 
        d.DISRUPTION_ID,
        d.FLIGHT_ID,
        f.ORIGIN,
        f.DESTINATION,
        f.AIRCRAFT_ID,
        f.CAPTAIN_ID,
        f.FIRST_OFFICER_ID,
        d.SEVERITY,
        d.DISRUPTION_TYPE,
        f.SCHEDULED_DEPARTURE_UTC,
        f.DEPARTURE_DELAY_MINUTES
    FROM STAGING.STG_DISRUPTIONS d
    JOIN STAGING.STG_FLIGHTS f ON d.FLIGHT_ID = f.FLIGHT_ID
    WHERE d.RECOVERY_STATUS IN ('PENDING', 'IN_PROGRESS')
),
aircraft_cascade AS (
    SELECT 
        i.DISRUPTION_ID,
        f.FLIGHT_ID AS DOWNSTREAM_FLIGHT_ID,
        f.FLIGHT_NUMBER AS DOWNSTREAM_FLIGHT,
        f.ORIGIN AS DOWNSTREAM_ORIGIN,
        f.DESTINATION AS DOWNSTREAM_DESTINATION,
        f.SCHEDULED_DEPARTURE_UTC AS DOWNSTREAM_DEPARTURE,
        f.PASSENGERS_BOOKED AS DOWNSTREAM_PASSENGERS,
        'AIRCRAFT_ROTATION' AS CASCADE_TYPE,
        GREATEST(0, COALESCE(i.DEPARTURE_DELAY_MINUTES, 0) - DATEDIFF('minute', i.SCHEDULED_DEPARTURE_UTC, f.SCHEDULED_DEPARTURE_UTC) + 45) AS ESTIMATED_DELAY
    FROM initial_disruption i
    JOIN STAGING.STG_FLIGHTS f ON i.AIRCRAFT_ID = f.AIRCRAFT_ID
    WHERE f.SCHEDULED_DEPARTURE_UTC > i.SCHEDULED_DEPARTURE_UTC
      AND f.FLIGHT_DATE <= DATEADD('day', 1, i.SCHEDULED_DEPARTURE_UTC::DATE)
      AND f.FLIGHT_ID != i.FLIGHT_ID
),
crew_cascade AS (
    SELECT 
        i.DISRUPTION_ID,
        f.FLIGHT_ID AS DOWNSTREAM_FLIGHT_ID,
        f.FLIGHT_NUMBER AS DOWNSTREAM_FLIGHT,
        f.ORIGIN AS DOWNSTREAM_ORIGIN,
        f.DESTINATION AS DOWNSTREAM_DESTINATION,
        f.SCHEDULED_DEPARTURE_UTC AS DOWNSTREAM_DEPARTURE,
        f.PASSENGERS_BOOKED AS DOWNSTREAM_PASSENGERS,
        'CREW_ROTATION' AS CASCADE_TYPE,
        GREATEST(0, COALESCE(i.DEPARTURE_DELAY_MINUTES, 0) - DATEDIFF('minute', i.SCHEDULED_DEPARTURE_UTC, f.SCHEDULED_DEPARTURE_UTC) + 60) AS ESTIMATED_DELAY
    FROM initial_disruption i
    JOIN STAGING.STG_FLIGHTS f ON (i.CAPTAIN_ID = f.CAPTAIN_ID OR i.FIRST_OFFICER_ID = f.FIRST_OFFICER_ID)
    WHERE f.SCHEDULED_DEPARTURE_UTC > i.SCHEDULED_DEPARTURE_UTC
      AND f.FLIGHT_DATE <= DATEADD('day', 1, i.SCHEDULED_DEPARTURE_UTC::DATE)
      AND f.FLIGHT_ID != i.FLIGHT_ID
),
all_cascades AS (
    SELECT * FROM aircraft_cascade
    UNION ALL
    SELECT * FROM crew_cascade
)
SELECT 
    DISRUPTION_ID,
    DOWNSTREAM_FLIGHT_ID,
    DOWNSTREAM_FLIGHT,
    DOWNSTREAM_ORIGIN,
    DOWNSTREAM_DESTINATION,
    DOWNSTREAM_DEPARTURE,
    DOWNSTREAM_PASSENGERS,
    CASCADE_TYPE,
    ESTIMATED_DELAY,
    CASE 
        WHEN ESTIMATED_DELAY > 180 THEN DOWNSTREAM_PASSENGERS * 150
        WHEN ESTIMATED_DELAY > 60 THEN DOWNSTREAM_PASSENGERS * 50
        WHEN ESTIMATED_DELAY > 15 THEN DOWNSTREAM_PASSENGERS * 10
        ELSE 0
    END AS ESTIMATED_CASCADE_COST,
    ROW_NUMBER() OVER (PARTITION BY DISRUPTION_ID ORDER BY DOWNSTREAM_DEPARTURE) AS CASCADE_SEQUENCE
FROM all_cascades
WHERE ESTIMATED_DELAY > 0;

CREATE OR REPLACE VIEW CASCADING_IMPACT_SUMMARY AS
SELECT 
    DISRUPTION_ID,
    COUNT(DISTINCT DOWNSTREAM_FLIGHT_ID) AS TOTAL_DOWNSTREAM_FLIGHTS,
    SUM(DOWNSTREAM_PASSENGERS) AS TOTAL_DOWNSTREAM_PASSENGERS,
    SUM(ESTIMATED_CASCADE_COST) AS TOTAL_CASCADE_COST,
    AVG(ESTIMATED_DELAY) AS AVG_CASCADE_DELAY,
    MAX(ESTIMATED_DELAY) AS MAX_CASCADE_DELAY,
    LISTAGG(DISTINCT CASCADE_TYPE, ', ') AS CASCADE_TYPES
FROM CASCADING_IMPACT_PREDICTIONS
GROUP BY DISRUPTION_ID;

-- ============================================================================
-- 7. MODEL OBSERVABILITY TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS DELAY_MODEL_PREDICTIONS_LOG (
    PREDICTION_ID VARCHAR(50) DEFAULT UUID_STRING(),
    PREDICTION_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    MODEL_NAME VARCHAR(100),
    MODEL_VERSION VARCHAR(20),
    FLIGHT_ID VARCHAR(50),
    PREDICTED_CATEGORY VARCHAR(50),
    ACTUAL_CATEGORY VARCHAR(50),
    IS_CORRECT BOOLEAN,
    LATENCY_MS INTEGER
);

CREATE TABLE IF NOT EXISTS CREW_RANKING_PREDICTIONS_LOG (
    PREDICTION_ID VARCHAR(50) DEFAULT UUID_STRING(),
    PREDICTION_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    MODEL_VERSION VARCHAR(20),
    FLIGHT_ID VARCHAR(50),
    CREW_ID VARCHAR(50),
    ML_FIT_SCORE FLOAT,
    CANDIDATE_RANK INTEGER,
    WAS_NOTIFIED BOOLEAN,
    ACTUAL_RESPONSE VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS COST_MODEL_PREDICTIONS_LOG (
    PREDICTION_ID VARCHAR(50) DEFAULT UUID_STRING(),
    PREDICTION_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    MODEL_VERSION VARCHAR(20),
    DISRUPTION_ID VARCHAR(50),
    PREDICTED_COST FLOAT,
    ACTUAL_COST FLOAT
);

-- ============================================================================
-- 8. MODEL PERFORMANCE MONITORING VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW MODEL_PERFORMANCE_METRICS AS
SELECT 
    'DELAY_PREDICTION_MODEL' AS MODEL_NAME,
    'Classification' AS MODEL_TYPE,
    'XGBoost' AS ALGORITHM,
    'FEATURE_STORE' AS FEATURE_SOURCE,
    'notebooks/01_delay_prediction_model.ipynb' AS TRAINING_NOTEBOOK,
    CURRENT_TIMESTAMP() AS LAST_UPDATED
UNION ALL
SELECT 
    'CREW_RANKING_MODEL' AS MODEL_NAME,
    'Classification' AS MODEL_TYPE,
    'LightGBM' AS ALGORITHM,
    'FEATURE_STORE' AS FEATURE_SOURCE,
    'notebooks/02_crew_ranking_model.ipynb' AS TRAINING_NOTEBOOK,
    CURRENT_TIMESTAMP() AS LAST_UPDATED
UNION ALL
SELECT 
    'COST_ESTIMATION_MODEL' AS MODEL_NAME,
    'Regression' AS MODEL_TYPE,
    'XGBoost' AS ALGORITHM,
    'FEATURE_STORE' AS FEATURE_SOURCE,
    'notebooks/03_cost_estimation_model.ipynb' AS TRAINING_NOTEBOOK,
    CURRENT_TIMESTAMP() AS LAST_UPDATED;

-- ============================================================================
-- 9. GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON SCHEMA ML_MODELS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON SCHEMA FEATURE_STORE TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON ALL VIEWS IN SCHEMA ML_MODELS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON ALL TABLES IN SCHEMA ML_MODELS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT USAGE ON FUNCTION CALCULATE_CREW_FIT_SCORE(BOOLEAN, BOOLEAN, FLOAT, FLOAT, INTEGER, FLOAT, BOOLEAN) TO ROLE IDENTIFIER($PROJECT_ROLE);

-- ============================================================================
-- ML MODELS SETUP COMPLETE
-- ============================================================================
-- This script creates the infrastructure for ML models.
-- 
-- For full ML functionality with Feature Store and Model Registry,
-- run the Snowflake notebooks in the /notebooks/ directory:
--
--   1. 01_delay_prediction_model.ipynb
--      - Feature Store: FLIGHT, AIRPORT, ROUTE entities
--      - Model: XGBoost classifier for delay prediction
--      - Observability: Drift detection alerts
--
--   2. 02_crew_ranking_model.ipynb  
--      - Feature Store: CREW_MEMBER entity with fatigue features
--      - Model: LightGBM classifier for acceptance prediction
--      - Observability: Acceptance rate monitoring
--
--   3. 03_cost_estimation_model.ipynb
--      - Feature Store: DISRUPTION entity
--      - Model: XGBoost regressor for cost estimation
--      - Observability: MAPE tracking
--
-- Views created:
--   - CREW_CANDIDATE_RANKINGS (One-Click Recovery)
--   - DELAY_PREDICTIONS
--   - COST_PREDICTIONS
--   - CASCADING_IMPACT_PREDICTIONS
--   - CASCADING_IMPACT_SUMMARY
--   - MODEL_PERFORMANCE_METRICS
-- ============================================================================
