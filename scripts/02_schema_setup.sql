-- ============================================================================
-- Phantom Airlines IROPS - Schema Setup (RAW Layer Tables)
-- ============================================================================
-- Creates all base tables in the RAW schema for airline operations data
-- 
-- Tables:
--   - AIRPORTS: Airport reference data
--   - AIRCRAFT: Fleet information
--   - AIRCRAFT_TYPES: Aircraft type specifications
--   - CREW_MEMBERS: Pilot and flight attendant roster
--   - CREW_QUALIFICATIONS: Type ratings and certifications
--   - FLIGHTS: Flight schedule and status
--   - DISRUPTIONS: IROPS events (weather, mechanical, crew, ATC)
--   - PASSENGERS: Passenger manifest and loyalty data
--   - BOOKINGS: Reservation data with connections
--   - MAINTENANCE_LOGS: Aircraft maintenance records (unstructured)
--   - WEATHER_DATA: Aviation weather (METAR/TAF)
--   - CREW_DUTY_LOG: Duty time tracking for FAA Part 117 compliance
--   - HISTORICAL_INCIDENTS: Past IROPS events for AI similarity matching
--
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX, $PROJECT_ROLE
-- ============================================================================

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($FULL_PREFIX);
USE SCHEMA RAW;

-- ============================================================================
-- 1. REFERENCE DATA TABLES
-- ============================================================================

-- Airports (Phantom hubs and destinations)
CREATE OR REPLACE TABLE AIRPORTS (
    airport_code VARCHAR(3) PRIMARY KEY,
    airport_name VARCHAR(200) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50),
    country VARCHAR(100) NOT NULL,
    timezone VARCHAR(50) NOT NULL,
    latitude FLOAT,
    longitude FLOAT,
    is_hub BOOLEAN DEFAULT FALSE,
    hub_type VARCHAR(20),  -- 'MEGA_HUB', 'SECONDARY_HUB', 'FOCUS_CITY', NULL
    gates_count INTEGER,
    runway_count INTEGER,
    elevation_ft INTEGER,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Aircraft Types (fleet specifications)
CREATE OR REPLACE TABLE AIRCRAFT_TYPES (
    aircraft_type_code VARCHAR(10) PRIMARY KEY,
    manufacturer VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    variant VARCHAR(20),
    seat_capacity INTEGER NOT NULL,
    first_class_seats INTEGER DEFAULT 0,
    business_class_seats INTEGER DEFAULT 0,
    comfort_plus_seats INTEGER DEFAULT 0,
    main_cabin_seats INTEGER NOT NULL,
    range_nm INTEGER,
    cruise_speed_kts INTEGER,
    fuel_capacity_gal INTEGER,
    max_flight_hours FLOAT,
    turnaround_time_min INTEGER DEFAULT 45,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Aircraft Fleet
CREATE OR REPLACE TABLE AIRCRAFT (
    aircraft_id VARCHAR(20) PRIMARY KEY,
    tail_number VARCHAR(10) NOT NULL UNIQUE,
    aircraft_type_code VARCHAR(10) NOT NULL REFERENCES AIRCRAFT_TYPES(aircraft_type_code),
    manufacture_date DATE,
    acquisition_date DATE,
    current_location VARCHAR(3) REFERENCES AIRPORTS(airport_code),
    status VARCHAR(20) DEFAULT 'ACTIVE',  -- 'ACTIVE', 'MAINTENANCE', 'GROUNDED', 'RETIRED'
    total_flight_hours FLOAT DEFAULT 0,
    total_cycles INTEGER DEFAULT 0,
    last_maintenance_date DATE,
    next_maintenance_due DATE,
    mel_items_count INTEGER DEFAULT 0,  -- Minimum Equipment List deferred items
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 2. CREW MANAGEMENT TABLES
-- ============================================================================

-- Crew Members (pilots and flight attendants)
CREATE OR REPLACE TABLE CREW_MEMBERS (
    crew_id VARCHAR(20) PRIMARY KEY,
    employee_id VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    crew_type VARCHAR(20) NOT NULL,  -- 'CAPTAIN', 'FIRST_OFFICER', 'FLIGHT_ATTENDANT', 'PURSER'
    seniority_number INTEGER,
    hire_date DATE NOT NULL,
    base_airport VARCHAR(3) NOT NULL REFERENCES AIRPORTS(airport_code),
    status VARCHAR(20) DEFAULT 'ACTIVE',  -- 'ACTIVE', 'ON_LEAVE', 'TRAINING', 'INACTIVE'
    phone_number VARCHAR(20),
    email VARCHAR(100),
    home_city VARCHAR(100),
    home_state VARCHAR(50),
    union_member BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Crew Qualifications (type ratings, certifications)
CREATE OR REPLACE TABLE CREW_QUALIFICATIONS (
    qualification_id VARCHAR(30) PRIMARY KEY,
    crew_id VARCHAR(20) NOT NULL REFERENCES CREW_MEMBERS(crew_id),
    aircraft_type_code VARCHAR(10) REFERENCES AIRCRAFT_TYPES(aircraft_type_code),
    qualification_type VARCHAR(50) NOT NULL,  -- 'TYPE_RATING', 'PIC', 'SIC', 'INSTRUCTOR', 'CHECK_AIRMAN'
    certification_date DATE NOT NULL,
    expiration_date DATE,
    status VARCHAR(20) DEFAULT 'ACTIVE',  -- 'ACTIVE', 'EXPIRED', 'SUSPENDED'
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Crew Duty Log (FAA Part 117 compliance tracking)
CREATE OR REPLACE TABLE CREW_DUTY_LOG (
    duty_log_id VARCHAR(30) PRIMARY KEY,
    crew_id VARCHAR(20) NOT NULL REFERENCES CREW_MEMBERS(crew_id),
    duty_date DATE NOT NULL,
    duty_start_utc TIMESTAMP_NTZ NOT NULL,
    duty_end_utc TIMESTAMP_NTZ,
    flight_duty_period_hours FLOAT,  -- FDP hours
    flight_time_hours FLOAT,         -- Actual flight time
    rest_period_hours FLOAT,         -- Rest before this duty
    duty_type VARCHAR(30),           -- 'FLIGHT', 'RESERVE', 'TRAINING', 'DEADHEAD', 'GROUND'
    report_location VARCHAR(3) REFERENCES AIRPORTS(airport_code),
    release_location VARCHAR(3) REFERENCES AIRPORTS(airport_code),
    flights_count INTEGER DEFAULT 0,
    cumulative_monthly_hours FLOAT,   -- Running total for month
    cumulative_annual_hours FLOAT,    -- Running total for year
    consecutive_duty_days INTEGER,    -- Days in a row
    fatigue_risk_score FLOAT,         -- Calculated risk score (0-100)
    is_legal BOOLEAN DEFAULT TRUE,    -- FAA Part 117 compliant
    violation_reason VARCHAR(500),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 3. FLIGHT OPERATIONS TABLES
-- ============================================================================

-- Flights (schedule and real-time status)
CREATE OR REPLACE TABLE FLIGHTS (
    flight_id VARCHAR(30) PRIMARY KEY,
    flight_number VARCHAR(10) NOT NULL,
    flight_date DATE NOT NULL,
    origin VARCHAR(3) NOT NULL REFERENCES AIRPORTS(airport_code),
    destination VARCHAR(3) NOT NULL REFERENCES AIRPORTS(airport_code),
    scheduled_departure_utc TIMESTAMP_NTZ NOT NULL,
    scheduled_arrival_utc TIMESTAMP_NTZ NOT NULL,
    actual_departure_utc TIMESTAMP_NTZ,
    actual_arrival_utc TIMESTAMP_NTZ,
    aircraft_id VARCHAR(20) REFERENCES AIRCRAFT(aircraft_id),
    tail_number VARCHAR(10),
    aircraft_type_code VARCHAR(10) REFERENCES AIRCRAFT_TYPES(aircraft_type_code),
    captain_id VARCHAR(20) REFERENCES CREW_MEMBERS(crew_id),
    first_officer_id VARCHAR(20) REFERENCES CREW_MEMBERS(crew_id),
    purser_id VARCHAR(20) REFERENCES CREW_MEMBERS(crew_id),
    status VARCHAR(30) DEFAULT 'SCHEDULED',  -- 'SCHEDULED', 'BOARDING', 'DEPARTED', 'EN_ROUTE', 'ARRIVED', 'DELAYED', 'CANCELLED', 'DIVERTED'
    departure_gate VARCHAR(10),
    arrival_gate VARCHAR(10),
    departure_delay_minutes INTEGER DEFAULT 0,
    arrival_delay_minutes INTEGER DEFAULT 0,
    delay_code VARCHAR(10),  -- IATA delay codes
    delay_reason VARCHAR(500),
    block_time_scheduled_min INTEGER,
    block_time_actual_min INTEGER,
    distance_nm INTEGER,
    passengers_booked INTEGER DEFAULT 0,
    passengers_checked_in INTEGER DEFAULT 0,
    load_factor FLOAT,
    is_codeshare BOOLEAN DEFAULT FALSE,
    codeshare_partner VARCHAR(10),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE(flight_number, flight_date)
);

-- Disruptions (IROPS events)
CREATE OR REPLACE TABLE DISRUPTIONS (
    disruption_id VARCHAR(30) PRIMARY KEY,
    flight_id VARCHAR(30) REFERENCES FLIGHTS(flight_id),
    disruption_type VARCHAR(50) NOT NULL,  -- 'WEATHER', 'MECHANICAL', 'CREW', 'ATC', 'SECURITY', 'GROUND_OPS', 'PAX_RELATED'
    disruption_subtype VARCHAR(50),
    severity VARCHAR(20) NOT NULL,  -- 'MINOR', 'MODERATE', 'SEVERE', 'CRITICAL'
    start_time_utc TIMESTAMP_NTZ NOT NULL,
    end_time_utc TIMESTAMP_NTZ,
    duration_minutes INTEGER,
    affected_airport VARCHAR(3) REFERENCES AIRPORTS(airport_code),
    description TEXT,
    root_cause TEXT,
    resolution TEXT,
    impact_flights_count INTEGER DEFAULT 1,
    impact_passengers_count INTEGER DEFAULT 0,
    estimated_cost_usd FLOAT DEFAULT 0,
    actual_cost_usd FLOAT,
    recovery_action VARCHAR(500),
    recovery_status VARCHAR(20) DEFAULT 'PENDING',  -- 'PENDING', 'IN_PROGRESS', 'RESOLVED', 'ESCALATED'
    escalated_to VARCHAR(100),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 4. PASSENGER DATA TABLES
-- ============================================================================

-- Passengers (profiles and loyalty)
CREATE OR REPLACE TABLE PASSENGERS (
    passenger_id VARCHAR(30) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    loyalty_number VARCHAR(20),
    loyalty_tier VARCHAR(20),  -- 'DIAMOND', 'PLATINUM', 'GOLD', 'SILVER', 'BLUE'
    loyalty_miles INTEGER DEFAULT 0,
    lifetime_miles INTEGER DEFAULT 0,
    home_airport VARCHAR(3) REFERENCES AIRPORTS(airport_code),
    preferred_seat VARCHAR(20),  -- 'WINDOW', 'AISLE', 'MIDDLE', 'EXIT_ROW', 'BULKHEAD'
    meal_preference VARCHAR(30),
    special_assistance VARCHAR(100),
    tsatsa_precheck BOOLEAN DEFAULT FALSE,
    global_entry BOOLEAN DEFAULT FALSE,
    communication_preference VARCHAR(20) DEFAULT 'EMAIL',  -- 'EMAIL', 'SMS', 'PUSH', 'NONE'
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Bookings (reservations with connection info)
CREATE OR REPLACE TABLE BOOKINGS (
    booking_id VARCHAR(30) PRIMARY KEY,
    confirmation_code VARCHAR(10) NOT NULL,
    passenger_id VARCHAR(30) NOT NULL REFERENCES PASSENGERS(passenger_id),
    flight_id VARCHAR(30) NOT NULL REFERENCES FLIGHTS(flight_id),
    booking_date TIMESTAMP_NTZ NOT NULL,
    booking_channel VARCHAR(30),  -- 'WEB', 'MOBILE', 'CALL_CENTER', 'TRAVEL_AGENT', 'CORPORATE'
    fare_class VARCHAR(5) NOT NULL,  -- 'F', 'J', 'W', 'Y', etc.
    cabin_class VARCHAR(20) NOT NULL,  -- 'FIRST', 'BUSINESS', 'COMFORT_PLUS', 'MAIN_CABIN', 'BASIC'
    seat_number VARCHAR(5),
    fare_amount_usd FLOAT NOT NULL,
    taxes_usd FLOAT DEFAULT 0,
    fees_usd FLOAT DEFAULT 0,
    total_amount_usd FLOAT NOT NULL,
    booking_status VARCHAR(20) DEFAULT 'CONFIRMED',  -- 'CONFIRMED', 'CHECKED_IN', 'BOARDED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'
    is_connection BOOLEAN DEFAULT FALSE,
    connection_booking_id VARCHAR(30),  -- Links to connecting flight booking
    connection_time_min INTEGER,        -- Layover time
    bags_checked INTEGER DEFAULT 0,
    bags_carry_on INTEGER DEFAULT 0,
    upgrade_requested BOOLEAN DEFAULT FALSE,
    upgrade_status VARCHAR(20),  -- 'PENDING', 'CONFIRMED', 'DENIED'
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 5. MAINTENANCE & WEATHER TABLES
-- ============================================================================

-- Maintenance Logs (unstructured text for AI processing)
CREATE OR REPLACE TABLE MAINTENANCE_LOGS (
    log_id VARCHAR(30) PRIMARY KEY,
    aircraft_id VARCHAR(20) NOT NULL REFERENCES AIRCRAFT(aircraft_id),
    log_date DATE NOT NULL,
    log_time_utc TIMESTAMP_NTZ NOT NULL,
    log_type VARCHAR(30) NOT NULL,  -- 'SQUAWK', 'MEL', 'CDL', 'SERVICE', 'INSPECTION', 'REPAIR', 'COMPONENT_CHANGE'
    ata_chapter VARCHAR(10),  -- ATA 100 chapter code (e.g., '32' for landing gear)
    description TEXT NOT NULL,  -- Free-form maintenance description for AI parsing
    reported_by VARCHAR(100),
    station VARCHAR(3) REFERENCES AIRPORTS(airport_code),
    priority VARCHAR(20) DEFAULT 'ROUTINE',  -- 'AOG', 'CRITICAL', 'HIGH', 'ROUTINE', 'DEFERRED'
    status VARCHAR(20) DEFAULT 'OPEN',  -- 'OPEN', 'IN_PROGRESS', 'DEFERRED', 'CLOSED'
    deferred_to_date DATE,
    mel_reference VARCHAR(50),  -- MEL item reference
    parts_required TEXT,
    parts_available BOOLEAN,
    estimated_repair_hours FLOAT,
    actual_repair_hours FLOAT,
    technician_id VARCHAR(20),
    sign_off_timestamp TIMESTAMP_NTZ,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Weather Data (aviation weather)
CREATE OR REPLACE TABLE WEATHER_DATA (
    weather_id VARCHAR(30) PRIMARY KEY,
    airport_code VARCHAR(3) NOT NULL REFERENCES AIRPORTS(airport_code),
    observation_time_utc TIMESTAMP_NTZ NOT NULL,
    weather_type VARCHAR(20) NOT NULL,  -- 'METAR', 'TAF', 'SIGMET', 'AIRMET', 'NOTAM'
    raw_text TEXT,  -- Raw METAR/TAF string
    temperature_c FLOAT,
    dewpoint_c FLOAT,
    wind_direction_deg INTEGER,
    wind_speed_kts INTEGER,
    wind_gust_kts INTEGER,
    visibility_sm FLOAT,
    ceiling_ft INTEGER,
    sky_condition VARCHAR(20),  -- 'VFR', 'MVFR', 'IFR', 'LIFR'
    weather_phenomena VARCHAR(100),  -- Rain, snow, fog, etc.
    altimeter_inhg FLOAT,
    flight_category VARCHAR(10),  -- 'VFR', 'MVFR', 'IFR', 'LIFR'
    is_thunderstorm BOOLEAN DEFAULT FALSE,
    is_freezing BOOLEAN DEFAULT FALSE,
    is_fog BOOLEAN DEFAULT FALSE,
    is_low_visibility BOOLEAN DEFAULT FALSE,
    ground_stop_active BOOLEAN DEFAULT FALSE,
    ground_delay_minutes INTEGER DEFAULT 0,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 6. HISTORICAL DATA FOR AI LEARNING
-- ============================================================================

-- Historical Incidents (for AI_SIMILARITY matching)
CREATE OR REPLACE TABLE HISTORICAL_INCIDENTS (
    incident_id VARCHAR(30) PRIMARY KEY,
    incident_date DATE NOT NULL,
    incident_type VARCHAR(50) NOT NULL,
    incident_subtype VARCHAR(50),
    severity VARCHAR(20) NOT NULL,
    affected_hub VARCHAR(3) REFERENCES AIRPORTS(airport_code),
    trigger_event TEXT NOT NULL,
    description TEXT NOT NULL,
    flights_cancelled INTEGER,
    flights_delayed INTEGER,
    passengers_affected INTEGER,
    recovery_time_hours FLOAT,
    recovery_strategy TEXT,
    recovery_actions VARIANT,  -- JSON array of actions taken
    lessons_learned TEXT,
    total_cost_usd FLOAT,
    crew_impact TEXT,
    similar_incidents VARIANT,  -- JSON array of related incident IDs
    embedding VECTOR(FLOAT, 768),  -- For AI_SIMILARITY searches
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 7. CREW ASSIGNMENT & RECOVERY TABLES
-- ============================================================================

-- Crew Assignments (current and proposed)
CREATE OR REPLACE TABLE CREW_ASSIGNMENTS (
    assignment_id VARCHAR(30) PRIMARY KEY,
    crew_id VARCHAR(20) NOT NULL REFERENCES CREW_MEMBERS(crew_id),
    flight_id VARCHAR(30) NOT NULL REFERENCES FLIGHTS(flight_id),
    assignment_role VARCHAR(30) NOT NULL,  -- 'CAPTAIN', 'FIRST_OFFICER', 'PURSER', 'FLIGHT_ATTENDANT'
    assignment_status VARCHAR(20) DEFAULT 'SCHEDULED',  -- 'SCHEDULED', 'CONFIRMED', 'CHECKED_IN', 'REASSIGNED', 'REMOVED'
    assignment_source VARCHAR(30),  -- 'ORIGINAL', 'SWAP', 'RECOVERY', 'RESERVE_CALL'
    original_assignment_id VARCHAR(30),  -- For tracking reassignments
    is_legal BOOLEAN DEFAULT TRUE,  -- Contract/FAA compliant
    legality_check_details TEXT,
    notification_sent_at TIMESTAMP_NTZ,
    notification_method VARCHAR(20),  -- 'SMS', 'EMAIL', 'PHONE', 'APP'
    response_received_at TIMESTAMP_NTZ,
    response_status VARCHAR(20),  -- 'ACCEPTED', 'DECLINED', 'NO_RESPONSE', 'TIMEOUT'
    decline_reason VARCHAR(200),
    report_time_utc TIMESTAMP_NTZ,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Crew Recovery Queue (for One-Click Recovery)
CREATE OR REPLACE TABLE CREW_RECOVERY_QUEUE (
    queue_id VARCHAR(30) PRIMARY KEY,
    flight_id VARCHAR(30) NOT NULL REFERENCES FLIGHTS(flight_id),
    required_role VARCHAR(30) NOT NULL,
    queue_status VARCHAR(20) DEFAULT 'OPEN',  -- 'OPEN', 'NOTIFYING', 'FILLED', 'ESCALATED', 'CANCELLED'
    priority_score FLOAT,  -- ML-calculated priority
    created_at TIMESTAMP_NTZ NOT NULL,
    deadline_utc TIMESTAMP_NTZ,  -- Must fill by this time
    candidates_notified INTEGER DEFAULT 0,
    batch_notification_sent_at TIMESTAMP_NTZ,
    filled_by_crew_id VARCHAR(20) REFERENCES CREW_MEMBERS(crew_id),
    filled_at TIMESTAMP_NTZ,
    time_to_fill_minutes FLOAT,
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Crew Recovery Candidates (ML-ranked list)
CREATE OR REPLACE TABLE CREW_RECOVERY_CANDIDATES (
    candidate_id VARCHAR(30) PRIMARY KEY,
    queue_id VARCHAR(30) NOT NULL REFERENCES CREW_RECOVERY_QUEUE(queue_id),
    crew_id VARCHAR(20) NOT NULL REFERENCES CREW_MEMBERS(crew_id),
    rank_position INTEGER NOT NULL,  -- 1 = best candidate
    ml_score FLOAT NOT NULL,  -- ML "best fit" score (0-100)
    proximity_score FLOAT,     -- Distance/time to aircraft
    duty_hours_remaining FLOAT,
    qualification_match BOOLEAN DEFAULT TRUE,
    historical_accept_rate FLOAT,  -- Past acceptance probability
    downstream_impact_score FLOAT,  -- Impact on other flights if assigned
    contract_legal BOOLEAN DEFAULT TRUE,
    contract_check_details TEXT,
    notification_status VARCHAR(20) DEFAULT 'PENDING',  -- 'PENDING', 'SENT', 'DELIVERED', 'OPENED', 'RESPONDED'
    notification_sent_at TIMESTAMP_NTZ,
    response_status VARCHAR(20),  -- 'ACCEPTED', 'DECLINED', 'TIMEOUT'
    response_at TIMESTAMP_NTZ,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- 8. INDEXES FOR PERFORMANCE
-- ============================================================================

-- Note: Snowflake auto-clusters based on query patterns, but we can add 
-- clustering keys for frequently filtered columns

ALTER TABLE FLIGHTS CLUSTER BY (flight_date, origin, destination);
ALTER TABLE DISRUPTIONS CLUSTER BY (start_time_utc, disruption_type);
ALTER TABLE CREW_DUTY_LOG CLUSTER BY (duty_date, crew_id);
ALTER TABLE BOOKINGS CLUSTER BY (flight_id, passenger_id);
ALTER TABLE WEATHER_DATA CLUSTER BY (observation_time_utc, airport_code);

-- ============================================================================
-- SCHEMA SETUP COMPLETE
-- ============================================================================
-- RAW schema tables created:
--   Reference: AIRPORTS, AIRCRAFT_TYPES, AIRCRAFT
--   Crew: CREW_MEMBERS, CREW_QUALIFICATIONS, CREW_DUTY_LOG
--   Operations: FLIGHTS, DISRUPTIONS
--   Passengers: PASSENGERS, BOOKINGS
--   Maintenance/Weather: MAINTENANCE_LOGS, WEATHER_DATA
--   Historical: HISTORICAL_INCIDENTS
--   Recovery: CREW_ASSIGNMENTS, CREW_RECOVERY_QUEUE, CREW_RECOVERY_CANDIDATES
-- ============================================================================
