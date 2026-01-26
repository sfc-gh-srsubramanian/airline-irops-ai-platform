-- ============================================================================
-- Phantom Airlines IROPS - Semantic Views for Cortex Analyst
-- ============================================================================
-- Creates semantic views that enable natural language querying via Cortex Analyst
-- 
-- Semantic View:
--   IROPS_ANALYTICS - Unified view for flights, disruptions, crew, aircraft, crew_swap
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- ============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE SCHEMA SEMANTIC_MODELS;

-- ============================================================================
-- IROPS ANALYTICS SEMANTIC VIEW
-- ============================================================================
-- Unified semantic view covering:
--   - Flight operations (delays, cancellations, status)
--   - Disruption events (weather, mechanical, crew issues)
--   - Crew availability and duty compliance
--   - Aircraft status and maintenance health
--   - Crew swap candidates for one-click recovery
--   - Passenger loyalty information for impacted travelers

CREATE OR REPLACE SEMANTIC VIEW IROPS_ANALYTICS 
TABLES ( 
    FLIGHTS as STAGING.STG_FLIGHTS primary key (FLIGHT_ID), 
    DISRUPTIONS as STAGING.STG_DISRUPTIONS primary key (DISRUPTION_ID), 
    CREW as STAGING.STG_CREW primary key (CREW_ID), 
    AIRCRAFT as STAGING.STG_AIRCRAFT primary key (AIRCRAFT_ID),
    CREW_SWAP as ANALYTICS.MART_CREW_RECOVERY_CANDIDATES primary key (FLIGHT_ID, CREW_ID, REQUIRED_ROLE),
    PASSENGERS as STAGING.STG_PASSENGERS primary key (PASSENGER_ID),
    BOOKINGS as STAGING.STG_BOOKINGS primary key (BOOKING_ID)
) 
RELATIONSHIPS ( 
    FLIGHTS(AIRCRAFT_ID) references AIRCRAFT(AIRCRAFT_ID), 
    DISRUPTIONS(FLIGHT_ID) references FLIGHTS(FLIGHT_ID),
    BOOKINGS(FLIGHT_ID) references FLIGHTS(FLIGHT_ID),
    BOOKINGS(PASSENGER_ID) references PASSENGERS(PASSENGER_ID)
) 
FACTS ( 
    FLIGHTS.FLIGHT_ID as flight_id, 
    FLIGHTS.DEPARTURE_DELAY_MINUTES as departure_delay_minutes, 
    FLIGHTS.PASSENGERS_BOOKED as passengers_booked, 
    DISRUPTIONS.DISRUPTION_ID as disruption_id, 
    DISRUPTIONS.IMPACT_FLIGHTS_COUNT as impact_flights_count, 
    DISRUPTIONS.REPORTED_COST_USD as reported_cost_usd, 
    CREW.CREW_ID as crew_id, 
    CREW.MONTHLY_HOURS_REMAINING as monthly_hours_remaining, 
    AIRCRAFT.AIRCRAFT_ID as aircraft_id, 
    AIRCRAFT.MAINTENANCE_HEALTH_SCORE as maintenance_health_score,
    CREW_SWAP.ML_FIT_SCORE as ML_FIT_SCORE,
    CREW_SWAP.CANDIDATE_RANK as CANDIDATE_RANK,
    CREW_SWAP.FLIGHT_PRIORITY as FLIGHT_PRIORITY,
    PASSENGERS.LOYALTY_MILES as loyalty_miles,
    PASSENGERS.LIFETIME_MILES as lifetime_miles,
    BOOKINGS.BOOKING_AMOUNT as total_amount_usd
) 
DIMENSIONS ( 
    FLIGHTS.FLIGHT_NUMBER as FLIGHT_NUMBER, 
    FLIGHTS.ORIGIN_AIRPORT as ORIGIN, 
    FLIGHTS.DESTINATION_AIRPORT as DESTINATION, 
    FLIGHTS.FLIGHT_STATUS as STATUS WITH SYNONYMS = ('flight status', 'status') COMMENT = 'Flight status. Valid values: SCHEDULED, DELAYED, CANCELLED, DEPARTED, IN_AIR, LANDED, ARRIVED (all uppercase)', 
    FLIGHTS.FLIGHT_DATE as FLIGHT_DATE, 
    FLIGHTS.DELAY_REASON as DELAY_REASON,
    DISRUPTIONS.DISRUPTION_TYPE as DISRUPTION_TYPE, 
    DISRUPTIONS.SEVERITY as SEVERITY, 
    DISRUPTIONS.RECOVERY_STATUS as RECOVERY_STATUS, 
    CREW.CREW_NAME as FULL_NAME, 
    CREW.CREW_TYPE as CREW_TYPE, 
    CREW.BASE_AIRPORT as BASE_AIRPORT, 
    CREW.AVAILABILITY_STATUS as AVAILABILITY_STATUS, 
    AIRCRAFT.TAIL_NUMBER as TAIL_NUMBER, 
    AIRCRAFT.AIRCRAFT_STATUS as STATUS,
    CREW_SWAP.SWAP_ROLE as REQUIRED_ROLE,
    CREW_SWAP.SWAP_CANDIDATE as CREW_NAME,
    CREW_SWAP.SWAP_BASE as CREW_BASE,
    CREW_SWAP.SWAP_QUALIFIED as IS_TYPE_QUALIFIED,
    CREW_SWAP.SWAP_FLIGHT_DATE as FLIGHT_DATE,
    PASSENGERS.PASSENGER_NAME as FULL_NAME,
    PASSENGERS.LOYALTY_TIER as LOYALTY_TIER WITH SYNONYMS = ('loyalty tier', 'membership tier', 'status tier') COMMENT = 'Loyalty program tier. Valid values: DIAMOND, PLATINUM, GOLD, SILVER, BLUE (all uppercase)',
    PASSENGERS.IS_ELITE as IS_ELITE_MEMBER,
    PASSENGERS.IS_TOP as IS_TOP_TIER,
    PASSENGERS.HOME_AIRPORT as HOME_AIRPORT,
    BOOKINGS.CABIN_CLASS as CABIN_CLASS,
    BOOKINGS.FARE_CLASS as FARE_CLASS,
    BOOKINGS.BOOKING_STATUS as BOOKING_STATUS
) 
METRICS ( 
    FLIGHTS.FLIGHT_COUNT as COUNT(flights.FLIGHT_ID), 
    FLIGHTS.DELAYED_COUNT as COUNT_IF(flights.STATUS = 'DELAYED'), 
    FLIGHTS.CANCELLED_COUNT as COUNT_IF(flights.STATUS = 'CANCELLED'), 
    FLIGHTS.AVG_DELAY as AVG(flights.DEPARTURE_DELAY_MINUTES), 
    DISRUPTIONS.DISRUPTION_COUNT as COUNT(disruptions.DISRUPTION_ID), 
    DISRUPTIONS.COST_TOTAL as SUM(disruptions.REPORTED_COST_USD), 
    CREW.CREW_COUNT as COUNT(crew.CREW_ID), 
    CREW.AVAILABLE_COUNT as COUNT_IF(crew.AVAILABILITY_STATUS = 'AVAILABLE'), 
    AIRCRAFT.AIRCRAFT_COUNT as COUNT(aircraft.AIRCRAFT_ID), 
    AIRCRAFT.AVAILABLE_COUNT as COUNT_IF(aircraft.IS_OPERATIONALLY_AVAILABLE = TRUE),
    CREW_SWAP.FLIGHTS_NEEDING_CREW as COUNT(DISTINCT crew_swap.FLIGHT_ID),
    CREW_SWAP.SWAP_CANDIDATES_COUNT as COUNT(DISTINCT crew_swap.CREW_ID),
    PASSENGERS.ELITE_PASSENGERS_COUNT as COUNT_IF(passengers.IS_ELITE_MEMBER = TRUE),
    PASSENGERS.TOP_TIER_COUNT as COUNT_IF(passengers.IS_TOP_TIER = TRUE),
    BOOKINGS.BOOKING_COUNT as COUNT(bookings.BOOKING_ID),
    BOOKINGS.ELITE_BOOKINGS as COUNT_IF(bookings.IS_ELITE_MEMBER = TRUE)
) 
COMMENT = 'IROPS Analytics for Phantom Airlines - includes crew swap candidates and passenger loyalty'
AI_SQL_GENERATION 'IMPORTANT: All enumerated dimension values are stored in UPPERCASE in the database. When filtering on dimensions like LOYALTY_TIER, STATUS, SEVERITY, DISRUPTION_TYPE, CREW_TYPE, etc., always use uppercase values. Examples: LOYALTY_TIER values are DIAMOND, PLATINUM, GOLD, SILVER, BLUE. Flight STATUS values are SCHEDULED, DELAYED, CANCELLED, DEPARTED, IN_AIR, LANDED, ARRIVED. Never use capitalized versions like Diamond or Delayed.';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT SELECT ON SEMANTIC VIEW IROPS_ANALYTICS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON SEMANTIC VIEW IROPS_ANALYTICS TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- SEMANTIC VIEW COMPLETE
-- ============================================================================
-- Created IROPS_ANALYTICS semantic view with:
--   Tables: FLIGHTS, DISRUPTIONS, CREW, AIRCRAFT, CREW_SWAP
--   Relationships: flight_to_disruption, flight_to_aircraft
--   Facts: 13 numeric measures (delays, costs, hours, swap scores, etc.)
--   Dimensions: 19 categorical attributes 
--   Metrics: 12 pre-defined calculations
--
-- Usage with Cortex Analyst:
--   "How many flights are delayed today?"
--   "What is the total cost of active disruptions?"
--   "Show me available captains at ATL"
--   "Which aircraft have health scores below 70?"
--   "What crew swap options are available today?"
--   "How many flights need crew replacement?"
-- ============================================================================
