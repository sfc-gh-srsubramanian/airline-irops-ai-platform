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
--   - Rebooking options for passengers on cancelled/delayed flights

CREATE OR REPLACE SEMANTIC VIEW IROPS_ANALYTICS 
TABLES ( 
    FLIGHTS as STAGING.STG_FLIGHTS primary key (FLIGHT_ID), 
    DISRUPTIONS as STAGING.STG_DISRUPTIONS primary key (DISRUPTION_ID), 
    CREW as STAGING.STG_CREW primary key (CREW_ID), 
    AIRCRAFT as STAGING.STG_AIRCRAFT primary key (AIRCRAFT_ID),
    CREW_SWAP as ANALYTICS.MART_CREW_RECOVERY_CANDIDATES primary key (FLIGHT_ID, CREW_ID, REQUIRED_ROLE),
    PASSENGERS as STAGING.STG_PASSENGERS primary key (PASSENGER_ID),
    BOOKINGS as STAGING.STG_BOOKINGS primary key (BOOKING_ID),
    REBOOKING_OPTIONS as ANALYTICS.REBOOKING_OPTIONS primary key (BOOKING_ID, REBOOK_FLIGHT_ID)
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
    FLIGHTS.LOAD_FACTOR as load_factor,
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
    BOOKINGS.BOOKING_AMOUNT as total_amount_usd,
    REBOOKING_OPTIONS.AVAILABLE_SEATS as available_seats,
    REBOOKING_OPTIONS.MINUTES_AFTER_ORIGINAL as minutes_after_original,
    REBOOKING_OPTIONS.OPTION_RANK as option_rank
) 
DIMENSIONS ( 
    FLIGHTS.FLIGHT_NUMBER as FLIGHT_NUMBER, 
    FLIGHTS.ORIGIN_AIRPORT as ORIGIN WITH SYNONYMS = ('departure airport', 'from', 'hub') COMMENT = 'Origin airport IATA code. Hub airports are: LAX, JFK, ORD, DFW, ATL',
    FLIGHTS.DESTINATION_AIRPORT as DESTINATION WITH SYNONYMS = ('arrival airport', 'to') COMMENT = 'Destination airport IATA code. Hub airports are: LAX, JFK, ORD, DFW, ATL',
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
    BOOKINGS.BOOKING_STATUS as BOOKING_STATUS,
    REBOOKING_OPTIONS.CONFIRMATION_CODE as CONFIRMATION_CODE,
    REBOOKING_OPTIONS.FIRST_NAME as FIRST_NAME,
    REBOOKING_OPTIONS.LAST_NAME as LAST_NAME,
    REBOOKING_OPTIONS.EMAIL as EMAIL,
    REBOOKING_OPTIONS.LOYALTY_TIER as LOYALTY_TIER WITH SYNONYMS = ('elite status', 'membership level'),
    REBOOKING_OPTIONS.ORIGINAL_FLIGHT_NUMBER as ORIGINAL_FLIGHT_NUMBER,
    REBOOKING_OPTIONS.ORIGIN as ORIGIN,
    REBOOKING_OPTIONS.DESTINATION as DESTINATION,
    REBOOKING_OPTIONS.ORIGINAL_STATUS as ORIGINAL_STATUS,
    REBOOKING_OPTIONS.REBOOK_FLIGHT_NUMBER as REBOOK_FLIGHT_NUMBER,
    REBOOKING_OPTIONS.REBOOK_DEPARTURE as REBOOK_DEPARTURE,
    REBOOKING_OPTIONS.ORIGINAL_DEPARTURE as ORIGINAL_DEPARTURE
) 
METRICS ( 
    FLIGHTS.FLIGHT_COUNT as COUNT(flights.FLIGHT_ID), 
    FLIGHTS.DELAYED_COUNT as COUNT_IF(flights.STATUS = 'DELAYED'), 
    FLIGHTS.CANCELLED_COUNT as COUNT_IF(flights.STATUS = 'CANCELLED'), 
    FLIGHTS.AVG_DELAY as AVG(flights.DEPARTURE_DELAY_MINUTES),
    FLIGHTS.ON_TIME_FLIGHTS as COUNT_IF(flights.DEPARTURE_DELAY_MINUTES <= 15) WITH SYNONYMS = ('punctual flights', 'flights on time') COMMENT = 'Count of on-time flights (departure delay 15 min or less per A14 industry standard)',
    FLIGHTS.ON_TIME_PERFORMANCE as ROUND(COUNT_IF(flights.DEPARTURE_DELAY_MINUTES <= 15) * 100.0 / NULLIF(COUNT(flights.FLIGHT_ID), 0), 1) WITH SYNONYMS = ('OTP', 'on time rate', 'punctuality', 'on-time percentage') COMMENT = 'On-Time Performance percentage',
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
    BOOKINGS.ELITE_BOOKINGS as COUNT_IF(bookings.IS_ELITE_MEMBER = TRUE),
    REBOOKING_OPTIONS.PASSENGERS_NEEDING_REBOOKING as COUNT(DISTINCT rebooking_options.BOOKING_ID),
    REBOOKING_OPTIONS.ELITE_REBOOKINGS as COUNT_IF(rebooking_options.LOYALTY_TIER IN ('DIAMOND', 'PLATINUM'))
) 
COMMENT = 'IROPS Analytics for Phantom Airlines - includes crew swap candidates, passenger loyalty, and rebooking options'
AI_SQL_GENERATION 'IMPORTANT BUSINESS DEFINITIONS:

## Hub Airports
Phantom Airlines operates 5 hub airports: LAX (Los Angeles), JFK (New York), ORD (Chicago), DFW (Dallas), ATL (Atlanta).

## On-Time Performance (OTP)
A flight is ON-TIME if departure_delay_minutes <= 15 (A14 industry standard).

## Data Conventions
All enumerated dimension values are stored in UPPERCASE.
- LOYALTY_TIER: DIAMOND, PLATINUM, GOLD, SILVER, BLUE
- STATUS: SCHEDULED, DELAYED, CANCELLED, DEPARTED, IN_AIR, LANDED, ARRIVED

## Rebooking Options
The REBOOKING_OPTIONS table contains alternative flights for passengers on cancelled or delayed flights.
- Elite members are DIAMOND and PLATINUM tiers - prioritize them for rebooking
- OPTION_RANK = 1 means the next immediate available flight
- Use ORIGINAL_STATUS to filter for CANCELLED or DELAYED flights
- AVAILABLE_SEATS shows capacity on the rebooking flight
- For today cancellations: ORIGINAL_STATUS = ''CANCELLED'' AND DATE(ORIGINAL_DEPARTURE) = CURRENT_DATE()';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT SELECT ON SEMANTIC VIEW IROPS_ANALYTICS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT SELECT ON SEMANTIC VIEW IROPS_ANALYTICS TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- SEMANTIC VIEW COMPLETE
-- ============================================================================
-- Created IROPS_ANALYTICS semantic view with:
--   Tables: FLIGHTS, DISRUPTIONS, CREW, AIRCRAFT, CREW_SWAP, PASSENGERS, BOOKINGS, REBOOKING_OPTIONS
--   Relationships: flight_to_disruption, flight_to_aircraft, bookings_to_flights, bookings_to_passengers
--   Facts: 20 numeric measures (delays, costs, hours, swap scores, rebooking options, etc.)
--   Dimensions: 30 categorical attributes 
--   Metrics: 20 pre-defined calculations
--
-- Usage with Cortex Analyst:
--   "How many flights are delayed today?"
--   "What is the total cost of active disruptions?"
--   "Show me available captains at ATL"
--   "Which aircraft have health scores below 70?"
--   "What crew swap options are available today?"
--   "How many flights need crew replacement?"
--   "Give me rebooking options for elite members on cancelled flights"
--   "Show rebooking options for passengers impacted by today's cancellations"
-- ============================================================================
