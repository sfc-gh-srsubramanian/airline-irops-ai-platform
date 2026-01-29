-- ============================================================================
-- Phantom Airlines IROPS - Synthetic Data Generation
-- ============================================================================
-- Generates realistic synthetic data for the IROPS platform
-- 
-- Data volumes (Phantom scale):
--   - 8 Hub airports + 150 destinations = 158 airports
--   - 6 Aircraft types, 1,000 aircraft in fleet
--   - 15,000 pilots + 25,000 flight attendants = 40,000 crew
--   - 500,000+ flights per year (~1,400 daily)
--   - 50,000+ disruption events
--   - 200,000+ passengers (sample for demo)
--   - 100,000+ maintenance log entries
--   - 12 months of weather data
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
-- 1. AIRPORTS (Phantom Hub Structure + Destinations)
-- ============================================================================

DELETE FROM AIRPORTS;

INSERT INTO AIRPORTS
WITH hub_airports AS (
    SELECT column1 AS code, column2 AS name, column3 AS city, column4 AS state, column5 AS country, 
           column6 AS tz, column7 AS lat, column8 AS lon, column9 AS is_hub, column10 AS hub_type, 
           column11 AS gates, column12 AS runways, column13 AS elev
    FROM VALUES
        ('ATL', 'Hartsfield-Jackson Atlanta International', 'Atlanta', 'GA', 'USA', 'America/New_York', 33.6407, -84.4277, TRUE, 'MEGA_HUB', 192, 5, 1026),
        ('DTW', 'Detroit Metropolitan Wayne County', 'Detroit', 'MI', 'USA', 'America/Detroit', 42.2124, -83.3534, TRUE, 'SECONDARY_HUB', 129, 6, 645),
        ('MSP', 'Minneapolis-Saint Paul International', 'Minneapolis', 'MN', 'USA', 'America/Chicago', 44.8848, -93.2223, TRUE, 'SECONDARY_HUB', 117, 4, 841),
        ('SLC', 'Salt Lake City International', 'Salt Lake City', 'UT', 'USA', 'America/Denver', 40.7884, -111.9778, TRUE, 'SECONDARY_HUB', 82, 4, 4227),
        ('SEA', 'Seattle-Tacoma International', 'Seattle', 'WA', 'USA', 'America/Los_Angeles', 47.4502, -122.3088, TRUE, 'SECONDARY_HUB', 90, 3, 433),
        ('LAX', 'Los Angeles International', 'Los Angeles', 'CA', 'USA', 'America/Los_Angeles', 33.9416, -118.4085, TRUE, 'FOCUS_CITY', 146, 4, 128),
        ('JFK', 'John F. Kennedy International', 'New York', 'NY', 'USA', 'America/New_York', 40.6413, -73.7781, TRUE, 'FOCUS_CITY', 128, 4, 13),
        ('BOS', 'Boston Logan International', 'Boston', 'MA', 'USA', 'America/New_York', 42.3656, -71.0096, TRUE, 'FOCUS_CITY', 102, 6, 20)
),
destination_airports AS (
    SELECT column1 AS code, column2 AS name, column3 AS city, column4 AS state, column5 AS country, 
           column6 AS tz, column7 AS lat, column8 AS lon, column9 AS is_hub, column10 AS hub_type, 
           column11 AS gates, column12 AS runways, column13 AS elev
    FROM VALUES
        ('ORD', 'O''Hare International', 'Chicago', 'IL', 'USA', 'America/Chicago', 41.9742, -87.9073, FALSE, NULL, 191, 8, 672),
        ('DFW', 'Dallas/Fort Worth International', 'Dallas', 'TX', 'USA', 'America/Chicago', 32.8998, -97.0403, FALSE, NULL, 165, 7, 607),
        ('DEN', 'Denver International', 'Denver', 'CO', 'USA', 'America/Denver', 39.8561, -104.6737, FALSE, NULL, 111, 6, 5430),
        ('SFO', 'San Francisco International', 'San Francisco', 'CA', 'USA', 'America/Los_Angeles', 37.6213, -122.3790, FALSE, NULL, 115, 4, 13),
        ('MIA', 'Miami International', 'Miami', 'FL', 'USA', 'America/New_York', 25.7959, -80.2870, FALSE, NULL, 131, 4, 8),
        ('PHX', 'Phoenix Sky Harbor International', 'Phoenix', 'AZ', 'USA', 'America/Phoenix', 33.4373, -112.0078, FALSE, NULL, 120, 3, 1135),
        ('LAS', 'Harry Reid International', 'Las Vegas', 'NV', 'USA', 'America/Los_Angeles', 36.0840, -115.1537, FALSE, NULL, 93, 4, 2181),
        ('MCO', 'Orlando International', 'Orlando', 'FL', 'USA', 'America/New_York', 28.4312, -81.3081, FALSE, NULL, 129, 4, 96),
        ('EWR', 'Newark Liberty International', 'Newark', 'NJ', 'USA', 'America/New_York', 40.6895, -74.1745, FALSE, NULL, 110, 3, 18),
        ('CLT', 'Charlotte Douglas International', 'Charlotte', 'NC', 'USA', 'America/New_York', 35.2140, -80.9431, FALSE, NULL, 114, 4, 748),
        ('IAH', 'George Bush Intercontinental', 'Houston', 'TX', 'USA', 'America/Chicago', 29.9902, -95.3368, FALSE, NULL, 130, 5, 97),
        ('SAN', 'San Diego International', 'San Diego', 'CA', 'USA', 'America/Los_Angeles', 32.7338, -117.1933, FALSE, NULL, 51, 1, 17),
        ('AUS', 'Austin-Bergstrom International', 'Austin', 'TX', 'USA', 'America/Chicago', 30.1975, -97.6664, FALSE, NULL, 34, 2, 542),
        ('TPA', 'Tampa International', 'Tampa', 'FL', 'USA', 'America/New_York', 27.9755, -82.5332, FALSE, NULL, 59, 2, 26),
        ('PDX', 'Portland International', 'Portland', 'OR', 'USA', 'America/Los_Angeles', 45.5898, -122.5951, FALSE, NULL, 70, 3, 31),
        ('BNA', 'Nashville International', 'Nashville', 'TN', 'USA', 'America/Chicago', 36.1263, -86.6774, FALSE, NULL, 46, 4, 599),
        ('RDU', 'Raleigh-Durham International', 'Raleigh', 'NC', 'USA', 'America/New_York', 35.8776, -78.7875, FALSE, NULL, 50, 3, 435),
        ('STL', 'St. Louis Lambert International', 'St. Louis', 'MO', 'USA', 'America/Chicago', 38.7487, -90.3700, FALSE, NULL, 73, 4, 618),
        ('HNL', 'Daniel K. Inouye International', 'Honolulu', 'HI', 'USA', 'Pacific/Honolulu', 21.3187, -157.9225, FALSE, NULL, 77, 4, 13),
        ('OGG', 'Kahului Airport', 'Maui', 'HI', 'USA', 'Pacific/Honolulu', 20.8986, -156.4305, FALSE, NULL, 14, 2, 54),
        ('ANC', 'Ted Stevens Anchorage International', 'Anchorage', 'AK', 'USA', 'America/Anchorage', 61.1743, -149.9962, FALSE, NULL, 48, 3, 152),
        ('PHL', 'Philadelphia International', 'Philadelphia', 'PA', 'USA', 'America/New_York', 39.8729, -75.2437, FALSE, NULL, 126, 4, 36),
        ('DCA', 'Ronald Reagan Washington National', 'Washington', 'DC', 'USA', 'America/New_York', 38.8512, -77.0402, FALSE, NULL, 44, 3, 15),
        ('IAD', 'Washington Dulles International', 'Washington', 'DC', 'USA', 'America/New_York', 38.9531, -77.4565, FALSE, NULL, 123, 4, 313),
        ('BWI', 'Baltimore/Washington International', 'Baltimore', 'MD', 'USA', 'America/New_York', 39.1774, -76.6684, FALSE, NULL, 77, 3, 146),
        ('FLL', 'Fort Lauderdale-Hollywood International', 'Fort Lauderdale', 'FL', 'USA', 'America/New_York', 26.0742, -80.1506, FALSE, NULL, 64, 2, 9),
        ('RSW', 'Southwest Florida International', 'Fort Myers', 'FL', 'USA', 'America/New_York', 26.5362, -81.7552, FALSE, NULL, 28, 2, 30),
        ('MSY', 'Louis Armstrong New Orleans International', 'New Orleans', 'LA', 'USA', 'America/Chicago', 29.9934, -90.2580, FALSE, NULL, 42, 2, 4),
        ('PIT', 'Pittsburgh International', 'Pittsburgh', 'PA', 'USA', 'America/New_York', 40.4915, -80.2329, FALSE, NULL, 75, 4, 1203),
        ('CLE', 'Cleveland Hopkins International', 'Cleveland', 'OH', 'USA', 'America/New_York', 41.4117, -81.8498, FALSE, NULL, 79, 3, 791),
        ('CMH', 'John Glenn Columbus International', 'Columbus', 'OH', 'USA', 'America/New_York', 39.9980, -82.8919, FALSE, NULL, 46, 3, 815),
        ('IND', 'Indianapolis International', 'Indianapolis', 'IN', 'USA', 'America/Indiana/Indianapolis', 39.7173, -86.2944, FALSE, NULL, 40, 2, 797),
        ('MCI', 'Kansas City International', 'Kansas City', 'MO', 'USA', 'America/Chicago', 39.2976, -94.7139, FALSE, NULL, 39, 3, 1026),
        ('OMA', 'Eppley Airfield', 'Omaha', 'NE', 'USA', 'America/Chicago', 41.3032, -95.8941, FALSE, NULL, 23, 3, 984),
        ('OKC', 'Will Rogers World', 'Oklahoma City', 'OK', 'USA', 'America/Chicago', 35.3931, -97.6007, FALSE, NULL, 28, 3, 1295),
        ('SAT', 'San Antonio International', 'San Antonio', 'TX', 'USA', 'America/Chicago', 29.5337, -98.4698, FALSE, NULL, 24, 2, 809),
        ('ABQ', 'Albuquerque International Sunport', 'Albuquerque', 'NM', 'USA', 'America/Denver', 35.0402, -106.6090, FALSE, NULL, 23, 3, 5355),
        ('TUS', 'Tucson International', 'Tucson', 'AZ', 'USA', 'America/Phoenix', 32.1161, -110.9410, FALSE, NULL, 18, 3, 2643),
        ('SMF', 'Sacramento International', 'Sacramento', 'CA', 'USA', 'America/Los_Angeles', 38.6954, -121.5908, FALSE, NULL, 30, 2, 27),
        ('SJC', 'San Jose International', 'San Jose', 'CA', 'USA', 'America/Los_Angeles', 37.3639, -121.9289, FALSE, NULL, 30, 2, 62),
        ('ONT', 'Ontario International', 'Ontario', 'CA', 'USA', 'America/Los_Angeles', 34.0560, -117.6012, FALSE, NULL, 26, 2, 944),
        ('SNA', 'John Wayne Airport', 'Santa Ana', 'CA', 'USA', 'America/Los_Angeles', 33.6757, -117.8682, FALSE, NULL, 20, 2, 56),
        ('BUR', 'Hollywood Burbank', 'Burbank', 'CA', 'USA', 'America/Los_Angeles', 34.1975, -118.3585, FALSE, NULL, 14, 2, 778),
        ('GEG', 'Spokane International', 'Spokane', 'WA', 'USA', 'America/Los_Angeles', 47.6199, -117.5338, FALSE, NULL, 12, 2, 2376),
        ('BOI', 'Boise Airport', 'Boise', 'ID', 'USA', 'America/Boise', 43.5644, -116.2228, FALSE, NULL, 17, 2, 2871),
        ('RNO', 'Reno-Tahoe International', 'Reno', 'NV', 'USA', 'America/Los_Angeles', 39.4991, -119.7681, FALSE, NULL, 26, 2, 4415),
        ('COS', 'Colorado Springs Airport', 'Colorado Springs', 'CO', 'USA', 'America/Denver', 38.8058, -104.7008, FALSE, NULL, 12, 3, 6187),
        ('JAX', 'Jacksonville International', 'Jacksonville', 'FL', 'USA', 'America/New_York', 30.4941, -81.6879, FALSE, NULL, 30, 2, 30),
        ('PBI', 'Palm Beach International', 'West Palm Beach', 'FL', 'USA', 'America/New_York', 26.6832, -80.0956, FALSE, NULL, 26, 3, 19),
        ('SRQ', 'Sarasota-Bradenton International', 'Sarasota', 'FL', 'USA', 'America/New_York', 27.3954, -82.5544, FALSE, NULL, 9, 2, 30)
)
SELECT 
    code AS airport_code,
    name AS airport_name,
    city,
    state,
    country,
    tz AS timezone,
    lat AS latitude,
    lon AS longitude,
    is_hub,
    hub_type,
    gates AS gates_count,
    runways AS runway_count,
    elev AS elevation_ft,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM hub_airports
UNION ALL
SELECT 
    code AS airport_code,
    name AS airport_name,
    city,
    state,
    country,
    tz AS timezone,
    lat AS latitude,
    lon AS longitude,
    is_hub,
    hub_type,
    gates AS gates_count,
    runways AS runway_count,
    elev AS elevation_ft,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM destination_airports;

-- ============================================================================
-- 2. AIRCRAFT TYPES (Phantom Fleet Mix)
-- ============================================================================

DELETE FROM AIRCRAFT_TYPES;

INSERT INTO AIRCRAFT_TYPES VALUES
    ('B737-800', 'Boeing', '737', '800', 160, 0, 0, 36, 124, 2935, 453, 6875, 10.5, 40, CURRENT_TIMESTAMP()),
    ('B737-900', 'Boeing', '737', '900ER', 180, 0, 0, 40, 140, 2950, 453, 6875, 10.5, 45, CURRENT_TIMESTAMP()),
    ('B757-200', 'Boeing', '757', '200', 199, 0, 0, 44, 155, 3915, 460, 11276, 11.0, 50, CURRENT_TIMESTAMP()),
    ('B767-300', 'Boeing', '767', '300ER', 218, 0, 36, 48, 134, 5990, 459, 24140, 12.0, 60, CURRENT_TIMESTAMP()),
    ('A320-200', 'Airbus', 'A320', '200', 150, 0, 0, 32, 118, 3300, 447, 6300, 10.0, 35, CURRENT_TIMESTAMP()),
    ('A321-200', 'Airbus', 'A321', '200', 191, 0, 0, 40, 151, 3200, 447, 6350, 10.0, 40, CURRENT_TIMESTAMP()),
    ('A330-300', 'Airbus', 'A330', '300', 277, 0, 40, 56, 181, 6350, 470, 36740, 14.0, 75, CURRENT_TIMESTAMP()),
    ('A350-900', 'Airbus', 'A350', '900', 306, 32, 48, 56, 170, 8100, 488, 36960, 16.0, 90, CURRENT_TIMESTAMP());

-- ============================================================================
-- 3. AIRCRAFT FLEET (1,000 aircraft)
-- ============================================================================

DELETE FROM AIRCRAFT;

INSERT INTO AIRCRAFT
WITH seq AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 1000))
),
fleet_distribution AS (
    SELECT n,
        CASE 
            WHEN n < 350 THEN 'B737-800'
            WHEN n < 550 THEN 'B737-900'
            WHEN n < 650 THEN 'A320-200'
            WHEN n < 750 THEN 'A321-200'
            WHEN n < 830 THEN 'B757-200'
            WHEN n < 900 THEN 'B767-300'
            WHEN n < 950 THEN 'A330-300'
            ELSE 'A350-900'
        END AS aircraft_type,
        CASE 
            WHEN n < 350 THEN 'N3' || LPAD((n + 100)::VARCHAR, 2, '0') || 'PH'
            WHEN n < 550 THEN 'N9' || LPAD((n - 350 + 100)::VARCHAR, 2, '0') || 'PH'
            WHEN n < 650 THEN 'N32' || LPAD((n - 550 + 10)::VARCHAR, 1, '0') || 'PH'
            WHEN n < 750 THEN 'N21' || LPAD((n - 650 + 10)::VARCHAR, 2, '0') || 'PH'
            WHEN n < 830 THEN 'N57' || LPAD((n - 750 + 10)::VARCHAR, 2, '0') || 'PH'
            WHEN n < 900 THEN 'N67' || LPAD((n - 830 + 10)::VARCHAR, 2, '0') || 'PH'
            WHEN n < 950 THEN 'N33' || LPAD((n - 900 + 10)::VARCHAR, 2, '0') || 'PH'
            ELSE 'N35' || LPAD((n - 950 + 10)::VARCHAR, 2, '0') || 'PH'
        END AS tail,
        -- Age distribution: 0-25 years
        DATEADD('year', -FLOOR(UNIFORM(0, 25, RANDOM())), CURRENT_DATE()) AS mfg_date
    FROM seq
),
hub_list AS (
    SELECT airport_code, ROW_NUMBER() OVER (ORDER BY airport_code) - 1 AS hub_idx
    FROM AIRPORTS WHERE is_hub = TRUE
),
hub_array AS (
    SELECT ARRAY_AGG(airport_code) WITHIN GROUP (ORDER BY hub_idx) AS hubs FROM hub_list
)
SELECT 
    'AC' || LPAD(n::VARCHAR, 5, '0') AS aircraft_id,
    tail AS tail_number,
    aircraft_type AS aircraft_type_code,
    mfg_date AS manufacture_date,
    DATEADD('month', UNIFORM(0, 6, RANDOM()), mfg_date) AS acquisition_date,
    GET(ha.hubs, MOD(f.n, 8))::VARCHAR AS current_location,
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 5 THEN 'MAINTENANCE' ELSE 'ACTIVE' END AS status,
    ROUND(DATEDIFF('day', mfg_date, CURRENT_DATE()) * UNIFORM(2.5, 4.5, RANDOM()), 1) AS total_flight_hours,
    FLOOR(DATEDIFF('day', mfg_date, CURRENT_DATE()) * UNIFORM(1.5, 2.5, RANDOM())) AS total_cycles,
    DATEADD('day', -UNIFORM(1, 90, RANDOM()), CURRENT_DATE()) AS last_maintenance_date,
    DATEADD('day', UNIFORM(30, 180, RANDOM()), CURRENT_DATE()) AS next_maintenance_due,
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 15 THEN FLOOR(UNIFORM(1, 4, RANDOM())) ELSE 0 END AS mel_items_count,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM fleet_distribution f
CROSS JOIN hub_array ha;

-- ============================================================================
-- 4. CREW MEMBERS (15,000 pilots + 25,000 FAs = 40,000 crew)
-- ============================================================================

DELETE FROM CREW_MEMBERS;

INSERT INTO CREW_MEMBERS
WITH seq AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 40000))
),
first_names AS (
    SELECT * FROM VALUES
        ('James'), ('John'), ('Robert'), ('Michael'), ('William'), ('David'), ('Richard'), ('Joseph'), ('Thomas'), ('Christopher'),
        ('Mary'), ('Patricia'), ('Jennifer'), ('Linda'), ('Elizabeth'), ('Barbara'), ('Susan'), ('Jessica'), ('Sarah'), ('Karen'),
        ('Daniel'), ('Matthew'), ('Anthony'), ('Mark'), ('Donald'), ('Steven'), ('Paul'), ('Andrew'), ('Joshua'), ('Kenneth'),
        ('Nancy'), ('Betty'), ('Margaret'), ('Sandra'), ('Ashley'), ('Dorothy'), ('Kimberly'), ('Emily'), ('Donna'), ('Michelle'),
        ('Carlos'), ('Maria'), ('Jose'), ('Ana'), ('Luis'), ('Carmen'), ('Juan'), ('Rosa'), ('Pedro'), ('Teresa'),
        ('Wei'), ('Li'), ('Ming'), ('Jing'), ('Hui'), ('Xin'), ('Yan'), ('Lei'), ('Fang'), ('Ping'),
        ('Ahmed'), ('Mohammed'), ('Ali'), ('Omar'), ('Hassan'), ('Fatima'), ('Aisha'), ('Zainab'), ('Maryam'), ('Sara')
        AS t(name)
),
last_names AS (
    SELECT * FROM VALUES
        ('Smith'), ('Johnson'), ('Williams'), ('Brown'), ('Jones'), ('Garcia'), ('Miller'), ('Davis'), ('Rodriguez'), ('Martinez'),
        ('Hernandez'), ('Lopez'), ('Gonzalez'), ('Wilson'), ('Anderson'), ('Thomas'), ('Taylor'), ('Moore'), ('Jackson'), ('Martin'),
        ('Lee'), ('Perez'), ('Thompson'), ('White'), ('Harris'), ('Sanchez'), ('Clark'), ('Ramirez'), ('Lewis'), ('Robinson'),
        ('Walker'), ('Young'), ('Allen'), ('King'), ('Wright'), ('Scott'), ('Torres'), ('Nguyen'), ('Hill'), ('Flores'),
        ('Green'), ('Adams'), ('Nelson'), ('Baker'), ('Hall'), ('Rivera'), ('Campbell'), ('Mitchell'), ('Carter'), ('Roberts'),
        ('Chen'), ('Wang'), ('Liu'), ('Zhang'), ('Kim'), ('Park'), ('Patel'), ('Singh'), ('Kumar'), ('Shah')
        AS t(name)
),
hub_weights AS (
    SELECT airport_code, 
        CASE 
            WHEN hub_type = 'MEGA_HUB' THEN 35
            WHEN hub_type = 'SECONDARY_HUB' THEN 15
            ELSE 10
        END AS weight
    FROM AIRPORTS WHERE is_hub = TRUE
),
crew_data AS (
    SELECT 
        n,
        CASE 
            WHEN n < 7500 THEN 'CAPTAIN'
            WHEN n < 15000 THEN 'FIRST_OFFICER'
            WHEN n < 20000 THEN 'PURSER'
            ELSE 'FLIGHT_ATTENDANT'
        END AS crew_type,
        -- Seniority: captains most senior, FAs least
        CASE 
            WHEN n < 7500 THEN n + 1
            WHEN n < 15000 THEN n - 7500 + 7501
            WHEN n < 20000 THEN n - 15000 + 15001
            ELSE n - 20000 + 20001
        END AS seniority,
        -- Hire dates: more senior = longer tenure
        CASE 
            WHEN n < 7500 THEN DATEADD('year', -FLOOR(UNIFORM(10, 35, RANDOM())), CURRENT_DATE())
            WHEN n < 15000 THEN DATEADD('year', -FLOOR(UNIFORM(3, 20, RANDOM())), CURRENT_DATE())
            WHEN n < 20000 THEN DATEADD('year', -FLOOR(UNIFORM(5, 25, RANDOM())), CURRENT_DATE())
            ELSE DATEADD('year', -FLOOR(UNIFORM(1, 15, RANDOM())), CURRENT_DATE())
        END AS hire_date
    FROM seq
)
SELECT 
    'CR' || LPAD(n::VARCHAR, 6, '0') AS crew_id,
    'EMP' || LPAD(n::VARCHAR, 7, '0') AS employee_id,
    (SELECT name FROM first_names ORDER BY RANDOM() LIMIT 1) AS first_name,
    (SELECT name FROM last_names ORDER BY RANDOM() LIMIT 1) AS last_name,
    crew_type,
    seniority AS seniority_number,
    hire_date,
    -- Base assignment weighted by hub size
    (SELECT airport_code FROM hub_weights ORDER BY RANDOM() * weight DESC LIMIT 1) AS base_airport,
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 2 THEN 'ON_LEAVE' ELSE 'ACTIVE' END AS status,
    '555-' || LPAD(FLOOR(UNIFORM(100, 999, RANDOM()))::VARCHAR, 3, '0') || '-' || LPAD(FLOOR(UNIFORM(1000, 9999, RANDOM()))::VARCHAR, 4, '0') AS phone_number,
    LOWER((SELECT name FROM first_names ORDER BY RANDOM() LIMIT 1)) || '.' || LOWER((SELECT name FROM last_names ORDER BY RANDOM() LIMIT 1)) || '@phantom.com' AS email,
    (SELECT city FROM AIRPORTS WHERE is_hub = TRUE ORDER BY RANDOM() LIMIT 1) AS home_city,
    (SELECT state FROM AIRPORTS WHERE is_hub = TRUE ORDER BY RANDOM() LIMIT 1) AS home_state,
    TRUE AS union_member,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM crew_data;

-- ============================================================================
-- 5. CREW QUALIFICATIONS (type ratings for pilots)
-- ============================================================================

DELETE FROM CREW_QUALIFICATIONS;

INSERT INTO CREW_QUALIFICATIONS
WITH pilots AS (
    SELECT crew_id, crew_type, seniority_number, hire_date
    FROM CREW_MEMBERS 
    WHERE crew_type IN ('CAPTAIN', 'FIRST_OFFICER')
),
aircraft_types AS (
    SELECT aircraft_type_code FROM AIRCRAFT_TYPES
),
primary_ratings AS (
    -- Every pilot gets 1-3 type ratings based on seniority
    SELECT 
        p.crew_id,
        p.crew_type,
        p.seniority_number,
        p.hire_date,
        a.aircraft_type_code,
        ROW_NUMBER() OVER (PARTITION BY p.crew_id ORDER BY RANDOM()) AS rating_rank
    FROM pilots p
    CROSS JOIN aircraft_types a
)
SELECT 
    'QUAL' || crew_id || '-' || aircraft_type_code AS qualification_id,
    crew_id,
    aircraft_type_code,
    CASE WHEN crew_type = 'CAPTAIN' THEN 'PIC' ELSE 'SIC' END AS qualification_type,
    DATEADD('day', UNIFORM(30, 365, RANDOM()), hire_date) AS certification_date,
    DATEADD('year', 1, CURRENT_DATE()) AS expiration_date,
    'ACTIVE' AS status,
    CURRENT_TIMESTAMP() AS created_at
FROM primary_ratings
WHERE rating_rank <= CASE 
    WHEN seniority_number < 3000 THEN 3  -- Senior captains: 3 types
    WHEN seniority_number < 8000 THEN 2   -- Mid-seniority: 2 types
    ELSE 1                                 -- Junior: 1 type
END;

-- ============================================================================
-- 6. PASSENGERS (200,000 sample for demo)
-- ============================================================================

DELETE FROM PASSENGERS;

INSERT INTO PASSENGERS
WITH seq AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 200000))
),
first_names AS (
    SELECT * FROM VALUES
        ('James'), ('John'), ('Robert'), ('Michael'), ('William'), ('David'), ('Richard'), ('Joseph'), ('Thomas'), ('Christopher'),
        ('Mary'), ('Patricia'), ('Jennifer'), ('Linda'), ('Elizabeth'), ('Barbara'), ('Susan'), ('Jessica'), ('Sarah'), ('Karen'),
        ('Daniel'), ('Matthew'), ('Anthony'), ('Mark'), ('Donald'), ('Steven'), ('Paul'), ('Andrew'), ('Joshua'), ('Kenneth'),
        ('Nancy'), ('Betty'), ('Margaret'), ('Sandra'), ('Ashley'), ('Dorothy'), ('Kimberly'), ('Emily'), ('Donna'), ('Michelle')
        AS t(name)
),
last_names AS (
    SELECT * FROM VALUES
        ('Smith'), ('Johnson'), ('Williams'), ('Brown'), ('Jones'), ('Garcia'), ('Miller'), ('Davis'), ('Rodriguez'), ('Martinez'),
        ('Hernandez'), ('Lopez'), ('Gonzalez'), ('Wilson'), ('Anderson'), ('Thomas'), ('Taylor'), ('Moore'), ('Jackson'), ('Martin'),
        ('Lee'), ('Perez'), ('Thompson'), ('White'), ('Harris'), ('Sanchez'), ('Clark'), ('Ramirez'), ('Lewis'), ('Robinson')
        AS t(name)
)
SELECT 
    'PAX' || LPAD(n::VARCHAR, 8, '0') AS passenger_id,
    (SELECT name FROM first_names ORDER BY RANDOM() LIMIT 1) AS first_name,
    (SELECT name FROM last_names ORDER BY RANDOM() LIMIT 1) AS last_name,
    LOWER('pax' || n || '@email.com') AS email,
    '555-' || LPAD(FLOOR(UNIFORM(100, 999, RANDOM()))::VARCHAR, 3, '0') || '-' || LPAD(FLOOR(UNIFORM(1000, 9999, RANDOM()))::VARCHAR, 4, '0') AS phone,
    CASE WHEN n < 180000 THEN 'PH' || LPAD(n::VARCHAR, 10, '0') ELSE NULL END AS loyalty_number,
    CASE 
        WHEN n < 5000 THEN 'DIAMOND'      -- 2.5% Diamond
        WHEN n < 15000 THEN 'PLATINUM'    -- 5% Platinum
        WHEN n < 40000 THEN 'GOLD'        -- 12.5% Gold
        WHEN n < 80000 THEN 'SILVER'      -- 20% Silver
        WHEN n < 180000 THEN 'BLUE'       -- 50% Blue
        ELSE NULL                          -- 10% No loyalty
    END AS loyalty_tier,
    CASE 
        WHEN n < 5000 THEN FLOOR(UNIFORM(500000, 2000000, RANDOM()))
        WHEN n < 15000 THEN FLOOR(UNIFORM(200000, 750000, RANDOM()))
        WHEN n < 40000 THEN FLOOR(UNIFORM(75000, 300000, RANDOM()))
        WHEN n < 80000 THEN FLOOR(UNIFORM(25000, 100000, RANDOM()))
        WHEN n < 180000 THEN FLOOR(UNIFORM(5000, 50000, RANDOM()))
        ELSE 0
    END AS loyalty_miles,
    CASE 
        WHEN n < 5000 THEN FLOOR(UNIFORM(2000000, 10000000, RANDOM()))
        WHEN n < 15000 THEN FLOOR(UNIFORM(500000, 3000000, RANDOM()))
        WHEN n < 40000 THEN FLOOR(UNIFORM(200000, 750000, RANDOM()))
        WHEN n < 80000 THEN FLOOR(UNIFORM(50000, 300000, RANDOM()))
        WHEN n < 180000 THEN FLOOR(UNIFORM(10000, 75000, RANDOM()))
        ELSE 0
    END AS lifetime_miles,
    (SELECT airport_code FROM AIRPORTS ORDER BY RANDOM() LIMIT 1) AS home_airport,
    CASE MOD(n, 3) WHEN 0 THEN 'WINDOW' WHEN 1 THEN 'AISLE' ELSE NULL END AS preferred_seat,
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 5 THEN 'VEGETARIAN' WHEN UNIFORM(0, 100, RANDOM()) < 3 THEN 'KOSHER' ELSE NULL END AS meal_preference,
    NULL AS special_assistance,
    UNIFORM(0, 100, RANDOM()) < 30 AS tsa_precheck,
    UNIFORM(0, 100, RANDOM()) < 15 AS global_entry,
    CASE MOD(n, 3) WHEN 0 THEN 'EMAIL' WHEN 1 THEN 'SMS' ELSE 'PUSH' END AS communication_preference,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM seq;

-- ============================================================================
-- 7. FLIGHTS (90 days historical + today + 60 days future - ~500K flights)
-- ============================================================================
-- Generates realistic delays for today and recent days to showcase IROPS scenarios

DELETE FROM FLIGHTS;

INSERT INTO FLIGHTS
WITH date_range AS (
    -- 90 days past + today + 60 days future = 151 days
    SELECT DATEADD('day', -90 + ROW_NUMBER() OVER (ORDER BY SEQ4()), CURRENT_DATE()) AS flight_date
    FROM TABLE(GENERATOR(ROWCOUNT => 151))
),
routes AS (
    -- Hub to spoke routes
    SELECT h.airport_code AS origin, s.airport_code AS destination, 
           CASE WHEN h.hub_type = 'MEGA_HUB' THEN 8 WHEN h.hub_type = 'SECONDARY_HUB' THEN 4 ELSE 2 END AS daily_freq,
           'HUB_SPOKE' AS route_type
    FROM AIRPORTS h
    CROSS JOIN AIRPORTS s
    WHERE h.is_hub = TRUE AND s.is_hub = FALSE
    AND UNIFORM(0, 100, RANDOM()) < 40  -- Not all routes
    UNION ALL
    -- Spoke to hub routes (return)
    SELECT s.airport_code AS origin, h.airport_code AS destination,
           CASE WHEN h.hub_type = 'MEGA_HUB' THEN 8 WHEN h.hub_type = 'SECONDARY_HUB' THEN 4 ELSE 2 END AS daily_freq,
           'SPOKE_HUB' AS route_type
    FROM AIRPORTS h
    CROSS JOIN AIRPORTS s
    WHERE h.is_hub = TRUE AND s.is_hub = FALSE
    AND UNIFORM(0, 100, RANDOM()) < 40
    UNION ALL
    -- Hub to hub routes
    SELECT h1.airport_code AS origin, h2.airport_code AS destination, 6 AS daily_freq, 'HUB_HUB' AS route_type
    FROM AIRPORTS h1
    CROSS JOIN AIRPORTS h2
    WHERE h1.is_hub = TRUE AND h2.is_hub = TRUE AND h1.airport_code != h2.airport_code
),
flight_schedule AS (
    SELECT 
        d.flight_date,
        r.origin,
        r.destination,
        r.route_type,
        s.flight_num AS daily_flight_num,
        -- Flight number format: PH + route hash
        'PH' || ABS(HASH(r.origin || r.destination)) % 9000 + 1000 AS flight_number,
        -- Departure times spread throughout day (4am to 11pm local)
        DATEADD('minute', 
            240 + (s.flight_num - 1) * FLOOR(1140 / GREATEST(r.daily_freq, 1)) + FLOOR(UNIFORM(-30, 30, RANDOM())),
            d.flight_date::TIMESTAMP_NTZ) AS scheduled_departure_utc
    FROM date_range d
    CROSS JOIN routes r
    CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS flight_num FROM TABLE(GENERATOR(ROWCOUNT => 10))) s
    WHERE s.flight_num <= r.daily_freq
),
flight_details AS (
    SELECT 
        fs.*,
        -- Calculate distance and block time
        ROUND(3959 * ACOS(
            COS(RADIANS(o.latitude)) * COS(RADIANS(d.latitude)) * 
            COS(RADIANS(d.longitude) - RADIANS(o.longitude)) + 
            SIN(RADIANS(o.latitude)) * SIN(RADIANS(d.latitude))
        )) AS distance_nm,
        -- Block time = flight time + taxi (assume 450 kts avg + 30 min taxi)
        ROUND(3959 * ACOS(
            COS(RADIANS(o.latitude)) * COS(RADIANS(d.latitude)) * 
            COS(RADIANS(d.longitude) - RADIANS(o.longitude)) + 
            SIN(RADIANS(o.latitude)) * SIN(RADIANS(d.latitude))
        ) / 450 * 60 + 30) AS block_time_min
    FROM flight_schedule fs
    JOIN AIRPORTS o ON fs.origin = o.airport_code
    JOIN AIRPORTS d ON fs.destination = d.airport_code
)
SELECT 
    'FLT' || TO_CHAR(flight_date, 'YYYYMMDD') || '-' || flight_number || '-' || LPAD(daily_flight_num::VARCHAR, 2, '0') AS flight_id,
    flight_number,
    flight_date,
    origin,
    destination,
    scheduled_departure_utc,
    DATEADD('minute', block_time_min, scheduled_departure_utc) AS scheduled_arrival_utc,
    -- Actual times with realistic delays - MORE DELAYS FOR TODAY to showcase IROPS
    CASE 
        -- Cancelled flights (3%)
        WHEN UNIFORM(0, 100, RANDOM()) < 3 THEN NULL
        -- Future flights beyond today have no actual times yet
        WHEN flight_date > CURRENT_DATE() THEN NULL
        -- TODAY and recent flights: Higher delay rate (40% delayed) to showcase IROPS
        WHEN flight_date >= DATEADD('day', -3, CURRENT_DATE()) THEN
            CASE 
                WHEN UNIFORM(0, 100, RANDOM()) < 60 THEN scheduled_departure_utc  -- 60% on-time
                WHEN UNIFORM(0, 100, RANDOM()) < 50 THEN DATEADD('minute', FLOOR(UNIFORM(15, 45, RANDOM())), scheduled_departure_utc)  -- Minor delay
                WHEN UNIFORM(0, 100, RANDOM()) < 70 THEN DATEADD('minute', FLOOR(UNIFORM(45, 120, RANDOM())), scheduled_departure_utc)  -- Moderate delay
                ELSE DATEADD('minute', FLOOR(UNIFORM(120, 300, RANDOM())), scheduled_departure_utc)  -- Severe delay
            END
        -- Historical flights: Normal delay pattern
        ELSE
            CASE 
                WHEN UNIFORM(0, 100, RANDOM()) < 80 THEN scheduled_departure_utc  -- 80% on-time
                WHEN UNIFORM(0, 100, RANDOM()) < 60 THEN DATEADD('minute', FLOOR(UNIFORM(5, 30, RANDOM())), scheduled_departure_utc)
                ELSE DATEADD('minute', FLOOR(UNIFORM(30, 90, RANDOM())), scheduled_departure_utc)
            END
    END AS actual_departure_utc,
    NULL AS actual_arrival_utc,  -- Calculated in post-processing
    -- Aircraft assignment
    (SELECT aircraft_id FROM AIRCRAFT WHERE status = 'ACTIVE' ORDER BY RANDOM() LIMIT 1) AS aircraft_id,
    (SELECT tail_number FROM AIRCRAFT WHERE status = 'ACTIVE' ORDER BY RANDOM() LIMIT 1) AS tail_number,
    (SELECT aircraft_type_code FROM AIRCRAFT WHERE status = 'ACTIVE' ORDER BY RANDOM() LIMIT 1) AS aircraft_type_code,
    -- Crew assignment (done separately)
    NULL AS captain_id,
    NULL AS first_officer_id,
    NULL AS purser_id,
    -- Status based on date and departure times
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 3 THEN 'CANCELLED'
        WHEN flight_date > CURRENT_DATE() THEN 'SCHEDULED'
        WHEN flight_date = CURRENT_DATE() THEN 'IN_FLIGHT'
        ELSE 'ARRIVED'
    END AS status,
    'A' || FLOOR(UNIFORM(1, 50, RANDOM()))::VARCHAR AS departure_gate,
    'B' || FLOOR(UNIFORM(1, 50, RANDOM()))::VARCHAR AS arrival_gate,
    0 AS departure_delay_minutes,  -- Calculated in post-processing
    0 AS arrival_delay_minutes,    -- Calculated in post-processing
    NULL AS delay_code,
    NULL AS delay_reason,
    block_time_min AS block_time_scheduled_min,
    NULL AS block_time_actual_min,
    distance_nm,
    FLOOR(UNIFORM(50, 180, RANDOM())) AS passengers_booked,
    FLOOR(UNIFORM(40, 170, RANDOM())) AS passengers_checked_in,
    ROUND(UNIFORM(0.6, 0.95, RANDOM()), 2) AS load_factor,
    FALSE AS is_codeshare,
    NULL AS codeshare_partner,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM flight_details
LIMIT 500000;

-- Post-process: Calculate delay minutes and update status based on actual vs scheduled times
UPDATE FLIGHTS
SET 
    departure_delay_minutes = COALESCE(DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc), 0),
    delay_code = CASE 
        WHEN status = 'CANCELLED' THEN 
            CASE MOD(ABS(HASH(flight_id)), 5)
                WHEN 0 THEN 'MX'  -- Mechanical
                WHEN 1 THEN 'CR'  -- Crew
                WHEN 2 THEN 'WX'  -- Weather
                WHEN 3 THEN 'AT'  -- ATC
                ELSE 'OP'         -- Operational
            END
        WHEN DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc) >= 120 THEN 'WX'
        WHEN DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc) >= 60 THEN 'MC'
        WHEN DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc) >= 15 THEN 'CR'
        ELSE NULL
    END,
    delay_reason = CASE 
        WHEN status = 'CANCELLED' THEN 
            CASE MOD(ABS(HASH(flight_id)), 5)
                WHEN 0 THEN 'Aircraft mechanical issue requiring extended maintenance'
                WHEN 1 THEN 'Crew unavailable due to duty time limitations'
                WHEN 2 THEN 'Severe weather conditions at destination'
                WHEN 3 THEN 'Air traffic control restrictions'
                ELSE 'Operational necessity - aircraft repositioning required'
            END
        WHEN DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc) >= 120 THEN 'Weather-related delay'
        WHEN DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc) >= 60 THEN 'Mechanical issue'
        WHEN DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc) >= 15 THEN 'Crew scheduling'
        ELSE NULL
    END,
    status = CASE
        WHEN status = 'CANCELLED' THEN 'CANCELLED'
        WHEN flight_date > CURRENT_DATE() THEN 'SCHEDULED'
        WHEN flight_date = CURRENT_DATE() AND actual_departure_utc IS NOT NULL 
             AND DATEDIFF('minute', scheduled_departure_utc, actual_departure_utc) >= 15 THEN 'DELAYED'
        WHEN flight_date = CURRENT_DATE() AND actual_departure_utc IS NULL THEN 'SCHEDULED'
        WHEN flight_date = CURRENT_DATE() THEN 'ON_TIME'
        ELSE 'ARRIVED'
    END
WHERE flight_date >= DATEADD('day', -90, CURRENT_DATE());

-- ============================================================================
-- 7b. TIME-BASED STATUS UPDATE FOR TODAY'S FLIGHTS
-- ============================================================================
-- Updates flight statuses based on current time to simulate real-time operations:
-- - Flights with scheduled departure > 30 min from now: SCHEDULED
-- - Flights departing within 30 min: ON_TIME or DELAYED (based on delay minutes)
-- - Flights that should have departed but not yet arrived: IN_FLIGHT
-- - Flights past scheduled arrival time: ARRIVED
-- This makes the dashboard realistic for demo purposes

UPDATE FLIGHTS
SET 
    actual_departure_utc = CASE
        WHEN status = 'CANCELLED' THEN NULL
        WHEN scheduled_departure_utc < DATEADD('minute', -30, CURRENT_TIMESTAMP()) THEN
            DATEADD('minute', departure_delay_minutes, scheduled_departure_utc)
        ELSE actual_departure_utc
    END,
    actual_arrival_utc = CASE
        WHEN status = 'CANCELLED' THEN NULL
        WHEN DATEADD('minute', block_time_scheduled_min + departure_delay_minutes, scheduled_departure_utc) < CURRENT_TIMESTAMP() THEN
            DATEADD('minute', block_time_scheduled_min + departure_delay_minutes + FLOOR(UNIFORM(-5, 10, RANDOM())), scheduled_departure_utc)
        ELSE NULL
    END,
    block_time_actual_min = CASE
        WHEN status = 'CANCELLED' THEN NULL
        WHEN DATEADD('minute', block_time_scheduled_min + departure_delay_minutes, scheduled_departure_utc) < CURRENT_TIMESTAMP() THEN
            block_time_scheduled_min + FLOOR(UNIFORM(-5, 10, RANDOM()))
        ELSE NULL
    END,
    status = CASE
        WHEN status = 'CANCELLED' THEN 'CANCELLED'
        -- Future: more than 30 min until departure
        WHEN scheduled_departure_utc > DATEADD('minute', 30, CURRENT_TIMESTAMP()) THEN 'SCHEDULED'
        -- Departed and arrived: past scheduled arrival time (with delays)
        WHEN DATEADD('minute', block_time_scheduled_min + departure_delay_minutes, scheduled_departure_utc) < CURRENT_TIMESTAMP() THEN 'ARRIVED'
        -- In flight: departed but not yet arrived
        WHEN scheduled_departure_utc < DATEADD('minute', -30, CURRENT_TIMESTAMP()) THEN 'IN_FLIGHT'
        -- Departing soon: within 30 min of departure, check if delayed
        WHEN departure_delay_minutes >= 15 THEN 'DELAYED'
        ELSE 'ON_TIME'
    END,
    arrival_delay_minutes = CASE
        WHEN status = 'CANCELLED' THEN NULL
        WHEN DATEADD('minute', block_time_scheduled_min + departure_delay_minutes, scheduled_departure_utc) < CURRENT_TIMESTAMP() THEN
            departure_delay_minutes + FLOOR(UNIFORM(-5, 10, RANDOM()))
        ELSE NULL
    END
WHERE flight_date = CURRENT_DATE()
AND status != 'CANCELLED';

-- ============================================================================
-- 8. DISRUPTIONS (50,000+ events)
-- ============================================================================

DELETE FROM DISRUPTIONS;

INSERT INTO DISRUPTIONS
WITH disruption_types AS (
    SELECT * FROM VALUES
        ('WEATHER', 'THUNDERSTORM', 35),
        ('WEATHER', 'SNOW_ICE', 20),
        ('WEATHER', 'FOG', 10),
        ('WEATHER', 'WIND', 15),
        ('MECHANICAL', 'ENGINE', 5),
        ('MECHANICAL', 'HYDRAULIC', 3),
        ('MECHANICAL', 'AVIONICS', 4),
        ('MECHANICAL', 'APU', 6),
        ('CREW', 'SICK_CALL', 10),
        ('CREW', 'DUTY_TIMEOUT', 8),
        ('CREW', 'DELAYED_INBOUND', 12),
        ('CREW', 'POSITIONING', 5),
        ('ATC', 'GROUND_STOP', 8),
        ('ATC', 'TRAFFIC_MANAGEMENT', 10),
        ('ATC', 'RUNWAY_CLOSURE', 4),
        ('GROUND_OPS', 'FUELING', 3),
        ('GROUND_OPS', 'CATERING', 2),
        ('GROUND_OPS', 'BAGGAGE', 4),
        ('SECURITY', 'SCREENING_DELAY', 3),
        ('PAX_RELATED', 'LATE_PASSENGERS', 5)
        AS t(dtype, subtype, weight)
),
affected_flights AS (
    SELECT flight_id, flight_date, origin, destination, scheduled_departure_utc, status
    FROM FLIGHTS
    WHERE status IN ('DELAYED', 'CANCELLED') 
       OR UNIFORM(0, 100, RANDOM()) < 10  -- Also some on-time flights have minor disruptions
    LIMIT 50000
),
disruption_assignment AS (
    SELECT 
        af.*,
        (SELECT dtype FROM disruption_types ORDER BY RANDOM() * weight DESC LIMIT 1) AS disruption_type,
        (SELECT subtype FROM disruption_types ORDER BY RANDOM() * weight DESC LIMIT 1) AS disruption_subtype
    FROM affected_flights af
)
SELECT 
    'DIS' || flight_id AS disruption_id,
    flight_id,
    disruption_type,
    disruption_subtype,
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 50 THEN 'MINOR'
        WHEN UNIFORM(0, 100, RANDOM()) < 80 THEN 'MODERATE'
        WHEN UNIFORM(0, 100, RANDOM()) < 95 THEN 'SEVERE'
        ELSE 'CRITICAL'
    END AS severity,
    DATEADD('minute', -FLOOR(UNIFORM(30, 240, RANDOM())), scheduled_departure_utc) AS start_time_utc,
    DATEADD('minute', FLOOR(UNIFORM(30, 480, RANDOM())), scheduled_departure_utc) AS end_time_utc,
    FLOOR(UNIFORM(15, 360, RANDOM())) AS duration_minutes,
    origin AS affected_airport,
    CASE disruption_type
        WHEN 'WEATHER' THEN 'Weather event impacting operations: ' || disruption_subtype
        WHEN 'MECHANICAL' THEN 'Aircraft mechanical issue: ' || disruption_subtype || ' system'
        WHEN 'CREW' THEN 'Crew scheduling issue: ' || REPLACE(disruption_subtype, '_', ' ')
        WHEN 'ATC' THEN 'Air traffic control restriction: ' || REPLACE(disruption_subtype, '_', ' ')
        WHEN 'GROUND_OPS' THEN 'Ground operations delay: ' || disruption_subtype
        WHEN 'SECURITY' THEN 'Security-related delay: ' || REPLACE(disruption_subtype, '_', ' ')
        ELSE 'Passenger-related issue: ' || REPLACE(disruption_subtype, '_', ' ')
    END AS description,
    NULL AS root_cause,
    NULL AS resolution,
    FLOOR(UNIFORM(1, 25, RANDOM())) AS impact_flights_count,
    FLOOR(UNIFORM(50, 5000, RANDOM())) AS impact_passengers_count,
    ROUND(UNIFORM(5000, 500000, RANDOM()), 2) AS estimated_cost_usd,
    NULL AS actual_cost_usd,
    NULL AS recovery_action,
    CASE WHEN flight_date < CURRENT_DATE() THEN 'RESOLVED' ELSE 'PENDING' END AS recovery_status,
    NULL AS escalated_to,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM disruption_assignment;

-- ============================================================================
-- 9. MAINTENANCE LOGS (100,000 entries with realistic text)
-- ============================================================================

DELETE FROM MAINTENANCE_LOGS;

INSERT INTO MAINTENANCE_LOGS
WITH seq AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 100000))
),
aircraft_list AS (
    SELECT aircraft_id, aircraft_type_code, ROW_NUMBER() OVER (ORDER BY aircraft_id) - 1 AS idx
    FROM AIRCRAFT
),
log_templates AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY ata) - 1 AS template_idx FROM (
    SELECT * FROM VALUES
        ('32', 'SQUAWK', 'Landing gear indicator light illuminated during approach. Gear cycled, light extinguished. Recommend inspection at next overnight.'),
        ('32', 'MEL', 'Left main gear door actuator slow to retract. Deferred per MEL 32-31-1. Monitor for 10 flight cycles.'),
        ('49', 'SQUAWK', 'APU fault light illuminated during pushback. APU shutdown and restarted, fault cleared. APU operational.'),
        ('49', 'MEL', 'APU inoperative. Deferred per MEL 49-10-1. Ground power required for all turns. Parts on order.'),
        ('21', 'SQUAWK', 'Pack 1 temperature fluctuation noted in cruise. Reset pack, temperature stabilized. Monitoring.'),
        ('21', 'SERVICE', 'Replaced Pack 2 flow control valve per SB 21-0034. System tested satisfactory.'),
        ('24', 'SQUAWK', 'Generator 1 indicating low oil pressure in climb. Gen tripped offline automatically. Gen 2 carrying load.'),
        ('24', 'MEL', 'Generator 1 inoperative. Deferred per MEL 24-22-1. Dispatch with Gen 2 only. ETOPS restricted.'),
        ('27', 'SQUAWK', 'Rudder pedal feels stiff during taxi. Flight controls checked, within limits. Grease applied to pedal linkage.'),
        ('28', 'SERVICE', 'Fuel quantity indication System A replaced. System tested, calibration verified per AMM 28-41-00.'),
        ('29', 'SQUAWK', 'Hydraulic system B quantity low. Added 2 quarts Skydrol. No leaks found during inspection.'),
        ('29', 'MEL', 'Hydraulic pump B inoperative. Deferred per MEL 29-11-1. Dispatch with system A only.'),
        ('30', 'INSPECTION', 'Completed 500 hour ice protection system inspection. All boots and anti-ice valves serviceable.'),
        ('31', 'SQUAWK', 'Cockpit indicator lights dimmer than normal. Dimmer switch replaced. Lighting verified operational.'),
        ('32', 'SERVICE', 'Nose wheel steering feedback unit replaced per SB 32-0156. System rigged and tested satisfactory.'),
        ('33', 'SQUAWK', 'Emergency exit light test failed at Row 15L. Light unit replaced. All exits tested satisfactory.'),
        ('34', 'SERVICE', 'Installed new CVR per AD 34-0089. Old unit returned to shop for data extraction.'),
        ('35', 'SQUAWK', 'Oxygen mask at seat 14A did not deploy during test. Chemical generator replaced.'),
        ('36', 'INSPECTION', 'Completed C-check phase 3. All discrepancies addressed. Aircraft released to service.'),
        ('52', 'SQUAWK', 'Cabin door seal leaking at forward entry. Seal replaced and pressure tested satisfactory.')
        AS t(ata, log_type, description)
    )
)
SELECT 
    'LOG' || LPAD(s.n::VARCHAR, 8, '0') AS log_id,
    al.aircraft_id,
    DATEADD('day', -FLOOR(UNIFORM(0, 365, RANDOM())), CURRENT_DATE()) AS log_date,
    DATEADD('hour', FLOOR(UNIFORM(0, 24, RANDOM())), 
        DATEADD('day', -FLOOR(UNIFORM(0, 365, RANDOM())), CURRENT_DATE())::TIMESTAMP_NTZ) AS log_time_utc,
    lt.log_type,
    lt.ata AS ata_chapter,
    lt.description,
    'TECH' || LPAD(FLOOR(UNIFORM(1, 500, RANDOM()))::VARCHAR, 4, '0') AS reported_by,
    h.airport_code AS station,
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 2 THEN 'AOG'
        WHEN UNIFORM(0, 100, RANDOM()) < 10 THEN 'CRITICAL'
        WHEN UNIFORM(0, 100, RANDOM()) < 25 THEN 'HIGH'
        ELSE 'ROUTINE'
    END AS priority,
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 80 THEN 'CLOSED'
        WHEN UNIFORM(0, 100, RANDOM()) < 10 THEN 'DEFERRED'
        ELSE 'OPEN'
    END AS status,
    NULL AS deferred_to_date,
    NULL AS mel_reference,
    NULL AS parts_required,
    TRUE AS parts_available,
    ROUND(UNIFORM(0.5, 8, RANDOM()), 1) AS estimated_repair_hours,
    ROUND(UNIFORM(0.5, 10, RANDOM()), 1) AS actual_repair_hours,
    'TECH' || LPAD(FLOOR(UNIFORM(1, 500, RANDOM()))::VARCHAR, 4, '0') AS technician_id,
    CURRENT_TIMESTAMP() AS sign_off_timestamp,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM seq s
JOIN aircraft_list al ON al.idx = MOD(s.n, (SELECT COUNT(*) FROM aircraft_list))
JOIN log_templates lt ON lt.template_idx = MOD(s.n, (SELECT COUNT(*) FROM log_templates))
JOIN (SELECT airport_code, ROW_NUMBER() OVER (ORDER BY RANDOM()) - 1 AS hub_idx FROM AIRPORTS WHERE is_hub = TRUE) h 
    ON h.hub_idx = MOD(s.n, (SELECT COUNT(*) FROM AIRPORTS WHERE is_hub = TRUE));

-- ============================================================================
-- 10. WEATHER DATA (12 months, all airports, every 30 min = ~9M records)
-- ============================================================================
-- Note: Generating smaller sample for demo (hourly for 90 days)

DELETE FROM WEATHER_DATA;

INSERT INTO WEATHER_DATA
WITH time_series AS (
    SELECT DATEADD('hour', -n, CURRENT_TIMESTAMP()) AS obs_time
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 2160)))  -- 90 days * 24 hours
),
airport_weather AS (
    SELECT 
        a.airport_code,
        t.obs_time,
        -- Seasonal temperature variation
        ROUND(
            CASE 
                WHEN a.latitude > 40 THEN 
                    50 + 30 * SIN((EXTRACT(DOY FROM obs_time) - 80) * 3.14159 / 182) + UNIFORM(-10, 10, RANDOM())
                ELSE 
                    70 + 20 * SIN((EXTRACT(DOY FROM obs_time) - 80) * 3.14159 / 182) + UNIFORM(-10, 10, RANDOM())
            END, 1
        ) AS temp_f,
        -- Weather conditions (seasonal)
        CASE 
            WHEN EXTRACT(MONTH FROM obs_time) IN (12, 1, 2) AND a.latitude > 35 AND UNIFORM(0, 100, RANDOM()) < 20 THEN 'SNOW'
            WHEN EXTRACT(MONTH FROM obs_time) IN (6, 7, 8) AND UNIFORM(0, 100, RANDOM()) < 15 THEN 'THUNDERSTORM'
            WHEN UNIFORM(0, 100, RANDOM()) < 10 THEN 'RAIN'
            WHEN UNIFORM(0, 100, RANDOM()) < 5 THEN 'FOG'
            ELSE 'CLEAR'
        END AS wx_condition
    FROM AIRPORTS a
    CROSS JOIN time_series t
)
SELECT 
    'WX' || airport_code || TO_CHAR(obs_time, 'YYYYMMDDHH24') AS weather_id,
    airport_code,
    obs_time AS observation_time_utc,
    'METAR' AS weather_type,
    NULL AS raw_text,
    ROUND((temp_f - 32) * 5/9, 1) AS temperature_c,
    ROUND((temp_f - 32) * 5/9 - UNIFORM(2, 8, RANDOM()), 1) AS dewpoint_c,
    FLOOR(UNIFORM(0, 360, RANDOM())) AS wind_direction_deg,
    FLOOR(UNIFORM(0, 25, RANDOM())) AS wind_speed_kts,
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 20 THEN FLOOR(UNIFORM(25, 45, RANDOM())) ELSE NULL END AS wind_gust_kts,
    CASE wx_condition
        WHEN 'FOG' THEN ROUND(UNIFORM(0.25, 1, RANDOM()), 2)
        WHEN 'SNOW' THEN ROUND(UNIFORM(0.5, 3, RANDOM()), 1)
        WHEN 'RAIN' THEN ROUND(UNIFORM(2, 6, RANDOM()), 1)
        WHEN 'THUNDERSTORM' THEN ROUND(UNIFORM(1, 4, RANDOM()), 1)
        ELSE ROUND(UNIFORM(6, 10, RANDOM()), 1)
    END AS visibility_sm,
    CASE wx_condition
        WHEN 'FOG' THEN FLOOR(UNIFORM(100, 500, RANDOM()))
        WHEN 'SNOW' THEN FLOOR(UNIFORM(500, 2000, RANDOM()))
        WHEN 'RAIN' THEN FLOOR(UNIFORM(1000, 5000, RANDOM()))
        WHEN 'THUNDERSTORM' THEN FLOOR(UNIFORM(500, 3000, RANDOM()))
        ELSE FLOOR(UNIFORM(5000, 25000, RANDOM()))
    END AS ceiling_ft,
    CASE wx_condition
        WHEN 'FOG' THEN 'LIFR'
        WHEN 'SNOW' THEN 'IFR'
        WHEN 'RAIN' THEN 'MVFR'
        WHEN 'THUNDERSTORM' THEN 'IFR'
        ELSE 'VFR'
    END AS sky_condition,
    wx_condition AS weather_phenomena,
    ROUND(29.92 + UNIFORM(-0.5, 0.5, RANDOM()), 2) AS altimeter_inhg,
    CASE wx_condition
        WHEN 'FOG' THEN 'LIFR'
        WHEN 'SNOW' THEN 'IFR'
        WHEN 'RAIN' THEN 'MVFR'
        WHEN 'THUNDERSTORM' THEN 'IFR'
        ELSE 'VFR'
    END AS flight_category,
    wx_condition = 'THUNDERSTORM' AS is_thunderstorm,
    (wx_condition = 'SNOW' OR temp_f < 32) AS is_freezing,
    wx_condition = 'FOG' AS is_fog,
    wx_condition IN ('FOG', 'SNOW') AS is_low_visibility,
    wx_condition = 'THUNDERSTORM' AND UNIFORM(0, 100, RANDOM()) < 30 AS ground_stop_active,
    CASE WHEN wx_condition = 'THUNDERSTORM' THEN FLOOR(UNIFORM(15, 90, RANDOM())) ELSE 0 END AS ground_delay_minutes,
    CURRENT_TIMESTAMP() AS created_at
FROM airport_weather;

-- ============================================================================
-- 11. HISTORICAL INCIDENTS (for AI_SIMILARITY matching)
-- ============================================================================

DELETE FROM HISTORICAL_INCIDENTS;

INSERT INTO HISTORICAL_INCIDENTS VALUES
    ('INC001', '2024-07-19', 'SYSTEM_OUTAGE', 'CROWDSTRIKE', 'CRITICAL', 'ATL',
     'CrowdStrike Falcon sensor update caused global Windows system crashes',
     'Massive IT outage affecting crew scheduling system ARCOS. All Windows-based systems crashed simultaneously at 04:09 UTC. Flight operations systems recovered within hours but crew tracking remained offline for 72+ hours. Unable to locate crew or verify duty times. Manual phone calls required to reach each pilot individually.',
     4000, 12000, 1500000, 120,
     'Activated emergency operations center. Deployed backup crew tracking spreadsheets. Initiated sequential phone calls to pilots. Staged reserve crews at all hubs. Implemented 12-hour crew duty extensions where legal.',
     PARSE_JSON('["Sequential pilot calling", "Manual duty time tracking", "Hub-based crew staging", "Duty time extensions", "Passenger rebooking on partner airlines"]'),
     'Need automated backup crew tracking. Phone tree approach creates 12-minute bottleneck per pilot. Consider batch notification system. Maintain offline crew roster with contact info.',
     85000000, 'Pilots unable to be reached. Sequential calling took 5+ days to staff all flights. Union grievances filed for illegal assignments made under pressure.',
     PARSE_JSON('["INC002", "INC005"]'), NULL, CURRENT_TIMESTAMP()),
     
    ('INC002', '2022-12-22', 'WEATHER', 'WINTER_STORM', 'CRITICAL', 'ATL',
     'Winter Storm Elliott brings ice and freezing rain to Atlanta hub',
     'Unprecedented ice storm shut down ATL operations for 48 hours. Deicing fluid shortage compounded delays. 2,500 flights cancelled over 4 days. Crew out of position across network. Hotels fully booked in Atlanta area.',
     2500, 8000, 800000, 96,
     'Preemptive cancellations 24 hours before storm. Positioned extra crews at unaffected hubs. Chartered buses to transport stranded crews. Negotiated block hotel rooms in advance.',
     PARSE_JSON('["Preemptive cancellations", "Crew pre-positioning", "Deicing fluid stockpile", "Partner airline rebooking", "Bus transportation for crews"]'),
     'Earlier preemptive action reduces recovery time. Pre-position crews 48 hours ahead. Maintain deicing fluid reserve. Create crew hotel agreements in advance.',
     45000000, 'Crews stranded without hotels. Duty time violations occurred. Passengers slept in terminals.',
     PARSE_JSON('["INC001", "INC003"]'), NULL, CURRENT_TIMESTAMP()),
     
    ('INC003', '2023-08-15', 'MECHANICAL', 'FLEET_GROUNDING', 'SEVERE', 'ATL',
     'FAA AD requires emergency inspection of B737 engine mounts',
     'Airworthiness Directive issued requiring immediate inspection of engine pylon mounts on B737-800/900 fleet. 350 aircraft grounded pending inspection. Each inspection requires 4-6 hours.',
     1200, 5000, 300000, 72,
     'Prioritized inspections at maintenance hubs. Called in off-duty mechanics with overtime. Inspected aircraft overnight. Released aircraft as cleared.',
     PARSE_JSON('["Prioritized hub inspections", "Mechanic overtime callout", "24/7 inspection operations", "Aircraft swap where possible", "Wet-leased replacement capacity"]'),
     'Maintain inspection capability at all overnight stations. Cross-train mechanics on common ADs. Have wet-lease agreements ready.',
     25000000, 'Insufficient mechanics at spoke stations. Some aircraft sat for 24+ hours waiting for inspection.',
     PARSE_JSON('["INC002"]'), NULL, CURRENT_TIMESTAMP()),
     
    ('INC004', '2024-01-15', 'ATC', 'GROUND_STOP', 'MODERATE', 'JFK',
     'FAA ground stop due to staffing shortage at NY TRACON',
     'ATC staffing shortage forced ground stop affecting all NYC airports. 3-hour ground stop extended to 5 hours. Created cascading delays across Eastern seaboard.',
     400, 2000, 100000, 8,
     'Held departures at origin. Diverted flights to alternate airports. Extended crew duty times where legal. Provided passenger meal vouchers.',
     PARSE_JSON('["Departure holds at origin", "Diversions to PHL/BOS", "Duty time extensions", "Meal vouchers", "Rebooking assistance"]'),
     'Monitor FAA staffing announcements. Pre-plan diversion airports. Have crew swap agreements with partners.',
     8000000, 'Crews timed out at JFK. Passengers missed connections.',
     NULL, NULL, CURRENT_TIMESTAMP()),
     
    ('INC005', '2023-06-28', 'CREW', 'PILOT_SHORTAGE', 'MODERATE', 'MSP',
     'Reserve pilot shortage at Minneapolis hub during summer peak',
     'Combination of training schedules, vacations, and sick calls depleted reserve pilot pool. Unable to cover 15 open trips. Flights cancelled due to crew unavailability.',
     15, 500, 50000, 24,
     'Extended long-call reserves to short-call. Offered premium pay for volunteer pickups. Reassigned training crews to line flying. Cancelled lowest-revenue flights.',
     PARSE_JSON('["Reserve extension", "Premium pay offers", "Training reassignment", "Strategic cancellations"]'),
     'Maintain larger reserve buffer during peak season. Cross-utilize reserves across nearby bases. Consider regional pilot partnerships.',
     2000000, 'Morale impact from cancelled vacations. Union pushback on reserve extensions.',
     PARSE_JSON('["INC001"]'), NULL, CURRENT_TIMESTAMP());

-- ============================================================================
-- 12. CREW DUTY LOG (Sample for active crew - last 30 days)
-- ============================================================================

DELETE FROM CREW_DUTY_LOG;

INSERT INTO CREW_DUTY_LOG
WITH active_crew AS (
    SELECT crew_id, crew_type, base_airport
    FROM CREW_MEMBERS
    WHERE status = 'ACTIVE' AND crew_type IN ('CAPTAIN', 'FIRST_OFFICER')
    LIMIT 5000  -- Sample for demo
),
duty_days AS (
    SELECT DATEADD('day', -n, CURRENT_DATE()) AS duty_date
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 30)))
),
crew_duties AS (
    SELECT 
        c.crew_id,
        c.crew_type,
        c.base_airport,
        d.duty_date,
        UNIFORM(0, 100, RANDOM()) AS duty_chance
    FROM active_crew c
    CROSS JOIN duty_days d
    WHERE UNIFORM(0, 100, RANDOM()) < 70  -- 70% chance of duty on any day
)
SELECT 
    'DL' || crew_id || TO_CHAR(duty_date, 'YYYYMMDD') AS duty_log_id,
    crew_id,
    duty_date,
    DATEADD('hour', FLOOR(UNIFORM(4, 14, RANDOM())), duty_date::TIMESTAMP_NTZ) AS duty_start_utc,
    DATEADD('hour', FLOOR(UNIFORM(8, 14, RANDOM())), 
        DATEADD('hour', FLOOR(UNIFORM(4, 14, RANDOM())), duty_date::TIMESTAMP_NTZ)) AS duty_end_utc,
    ROUND(UNIFORM(6, 12, RANDOM()), 1) AS flight_duty_period_hours,
    ROUND(UNIFORM(3, 9, RANDOM()), 1) AS flight_time_hours,
    ROUND(UNIFORM(10, 16, RANDOM()), 1) AS rest_period_hours,
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 80 THEN 'FLIGHT'
        WHEN UNIFORM(0, 100, RANDOM()) < 10 THEN 'RESERVE'
        ELSE 'TRAINING'
    END AS duty_type,
    base_airport AS report_location,
    (SELECT airport_code FROM AIRPORTS ORDER BY RANDOM() LIMIT 1) AS release_location,
    FLOOR(UNIFORM(1, 5, RANDOM())) AS flights_count,
    ROUND(UNIFORM(50, 85, RANDOM()), 1) AS cumulative_monthly_hours,
    ROUND(UNIFORM(400, 900, RANDOM()), 1) AS cumulative_annual_hours,
    FLOOR(UNIFORM(1, 5, RANDOM())) AS consecutive_duty_days,
    ROUND(UNIFORM(10, 60, RANDOM()), 1) AS fatigue_risk_score,
    UNIFORM(0, 100, RANDOM()) > 2 AS is_legal,  -- 98% legal
    NULL AS violation_reason,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM crew_duties;

-- ============================================================================
-- 13. BOOKINGS (Sample - ~50,000 bookings with realistic constraints)
-- ============================================================================
-- CONSTRAINT: Each passenger can only be on ONE flight per day (realistic)
-- This prevents unrealistic scenarios like same person on 78 flights in one day

DELETE FROM BOOKINGS;

INSERT INTO BOOKINGS
WITH flight_sample AS (
    SELECT flight_id, flight_date, origin, destination, passengers_booked
    FROM FLIGHTS
    WHERE status != 'CANCELLED'
),
passenger_pool AS (
    SELECT passenger_id, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS pax_rank
    FROM PASSENGERS
),
flight_dates AS (
    SELECT DISTINCT flight_date FROM flight_sample
),
passenger_date_assignments AS (
    SELECT 
        p.passenger_id,
        fd.flight_date,
        ROW_NUMBER() OVER (PARTITION BY fd.flight_date ORDER BY RANDOM()) AS daily_rank
    FROM passenger_pool p
    CROSS JOIN flight_dates fd
    WHERE UNIFORM(0, 100, RANDOM()) < 15
),
flights_with_slots AS (
    SELECT 
        f.flight_id,
        f.flight_date,
        f.origin,
        f.destination,
        ROW_NUMBER() OVER (PARTITION BY f.flight_date ORDER BY RANDOM()) AS flight_rank,
        LEAST(f.passengers_booked, 180) AS max_passengers
    FROM flight_sample f
),
booking_assignments AS (
    SELECT 
        f.flight_id,
        f.flight_date,
        f.origin,
        f.destination,
        pda.passenger_id,
        ROW_NUMBER() OVER (PARTITION BY f.flight_id ORDER BY RANDOM()) AS seat_num
    FROM flights_with_slots f
    JOIN passenger_date_assignments pda 
        ON f.flight_date = pda.flight_date
        AND pda.daily_rank BETWEEN (f.flight_rank - 1) * 50 + 1 AND f.flight_rank * 50
    WHERE pda.daily_rank <= f.flight_rank * 50
    QUALIFY seat_num <= 50
)
SELECT 
    'BK' || ba.flight_id || '-' || LPAD(ba.seat_num::VARCHAR, 3, '0') AS booking_id,
    UPPER(SUBSTR(MD5(RANDOM()::VARCHAR), 1, 6)) AS confirmation_code,
    ba.passenger_id,
    ba.flight_id,
    DATEADD('day', -FLOOR(UNIFORM(1, 90, RANDOM())), ba.flight_date::TIMESTAMP_NTZ) AS booking_date,
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 40 THEN 'WEB'
        WHEN UNIFORM(0, 100, RANDOM()) < 30 THEN 'MOBILE'
        WHEN UNIFORM(0, 100, RANDOM()) < 15 THEN 'CALL_CENTER'
        WHEN UNIFORM(0, 100, RANDOM()) < 10 THEN 'TRAVEL_AGENT'
        ELSE 'CORPORATE'
    END AS booking_channel,
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 5 THEN 'F'
        WHEN UNIFORM(0, 100, RANDOM()) < 15 THEN 'J'
        WHEN UNIFORM(0, 100, RANDOM()) < 30 THEN 'W'
        ELSE 'Y'
    END AS fare_class,
    CASE 
        WHEN UNIFORM(0, 100, RANDOM()) < 5 THEN 'FIRST'
        WHEN UNIFORM(0, 100, RANDOM()) < 15 THEN 'COMFORT_PLUS'
        WHEN UNIFORM(0, 100, RANDOM()) < 20 THEN 'MAIN_CABIN'
        ELSE 'BASIC'
    END AS cabin_class,
    FLOOR(UNIFORM(1, 40, RANDOM())) || CASE MOD(FLOOR(UNIFORM(1, 6, RANDOM())), 6) WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'C' WHEN 3 THEN 'D' WHEN 4 THEN 'E' ELSE 'F' END AS seat_number,
    ROUND(UNIFORM(150, 1500, RANDOM()), 2) AS fare_amount_usd,
    ROUND(UNIFORM(20, 100, RANDOM()), 2) AS taxes_usd,
    ROUND(UNIFORM(0, 75, RANDOM()), 2) AS fees_usd,
    0 AS total_amount_usd,
    CASE 
        WHEN ba.flight_date < CURRENT_DATE() THEN 'COMPLETED'
        WHEN UNIFORM(0, 100, RANDOM()) < 5 THEN 'CANCELLED'
        ELSE 'CONFIRMED'
    END AS booking_status,
    FALSE AS is_connection,
    NULL AS connection_booking_id,
    NULL AS connection_time_min,
    FLOOR(UNIFORM(0, 3, RANDOM())) AS bags_checked,
    FLOOR(UNIFORM(0, 2, RANDOM())) AS bags_carry_on,
    UNIFORM(0, 100, RANDOM()) < 20 AS upgrade_requested,
    NULL AS upgrade_status,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM booking_assignments ba;

-- Update total_amount_usd
UPDATE BOOKINGS SET total_amount_usd = fare_amount_usd + taxes_usd + fees_usd;

-- ============================================================================
-- 14. ENSURE ELITE LOYALTY MEMBERS ON DELAYED/CANCELLED FLIGHTS DAILY
-- ============================================================================
-- Guarantees Diamond/Platinum members are impacted by disruptions every single day
-- This ensures demo queries about loyalty impact always return meaningful data

INSERT INTO BOOKINGS
WITH all_dates AS (
    SELECT DISTINCT flight_date 
    FROM FLIGHTS 
    WHERE flight_date BETWEEN DATEADD('day', -90, CURRENT_DATE()) AND DATEADD('day', 60, CURRENT_DATE())
),
disrupted_flights_by_day AS (
    SELECT 
        flight_date,
        flight_id,
        origin,
        destination,
        status,
        ROW_NUMBER() OVER (PARTITION BY flight_date ORDER BY 
            CASE status WHEN 'CANCELLED' THEN 1 WHEN 'DELAYED' THEN 2 ELSE 3 END,
            RANDOM()
        ) AS flight_rank
    FROM FLIGHTS
    WHERE (status IN ('DELAYED', 'CANCELLED') OR DEPARTURE_DELAY_MINUTES > 30)
    AND flight_date BETWEEN DATEADD('day', -90, CURRENT_DATE()) AND DATEADD('day', 60, CURRENT_DATE())
),
elite_passengers AS (
    SELECT 
        passenger_id,
        loyalty_tier,
        ROW_NUMBER() OVER (ORDER BY 
            CASE loyalty_tier WHEN 'DIAMOND' THEN 1 WHEN 'PLATINUM' THEN 2 END,
            RANDOM()
        ) AS pax_rank
    FROM PASSENGERS
    WHERE loyalty_tier IN ('DIAMOND', 'PLATINUM')
),
daily_elite_assignments AS (
    SELECT 
        d.flight_date,
        df.flight_id,
        df.origin,
        df.destination,
        df.status,
        ep.passenger_id,
        ep.loyalty_tier,
        ROW_NUMBER() OVER (PARTITION BY d.flight_date ORDER BY df.flight_rank, ep.pax_rank) AS daily_seat
    FROM all_dates d
    CROSS JOIN elite_passengers ep
    JOIN disrupted_flights_by_day df ON df.flight_date = d.flight_date
    WHERE df.flight_rank <= 10
    AND ep.pax_rank <= 500
    AND NOT EXISTS (
        SELECT 1 FROM BOOKINGS b 
        WHERE b.passenger_id = ep.passenger_id 
        AND b.flight_id = df.flight_id
    )
    QUALIFY daily_seat <= 25
)
SELECT 
    'EL' || LPAD(ROW_NUMBER() OVER (ORDER BY dea.flight_date, dea.daily_seat)::VARCHAR, 8, '0') AS booking_id,
    UPPER(SUBSTR(MD5(RANDOM()::VARCHAR), 1, 6)) AS confirmation_code,
    dea.passenger_id,
    dea.flight_id,
    DATEADD('day', -FLOOR(UNIFORM(7, 60, RANDOM())), dea.flight_date::TIMESTAMP_NTZ) AS booking_date,
    CASE WHEN dea.loyalty_tier = 'DIAMOND' THEN 'CORPORATE' ELSE 'WEB' END AS booking_channel,
    CASE WHEN dea.loyalty_tier = 'DIAMOND' THEN 'F' ELSE 'J' END AS fare_class,
    CASE WHEN dea.loyalty_tier = 'DIAMOND' THEN 'FIRST' ELSE 'COMFORT_PLUS' END AS cabin_class,
    FLOOR(UNIFORM(1, 10, RANDOM())) || CASE MOD(FLOOR(UNIFORM(1, 4, RANDOM())), 4) WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'C' ELSE 'D' END AS seat_number,
    CASE WHEN dea.loyalty_tier = 'DIAMOND' THEN ROUND(UNIFORM(1200, 2500, RANDOM()), 2) ELSE ROUND(UNIFORM(600, 1400, RANDOM()), 2) END AS fare_amount_usd,
    ROUND(UNIFORM(50, 150, RANDOM()), 2) AS taxes_usd,
    ROUND(UNIFORM(0, 50, RANDOM()), 2) AS fees_usd,
    0 AS total_amount_usd,
    CASE 
        WHEN dea.flight_date < CURRENT_DATE() THEN 'COMPLETED'
        WHEN dea.status = 'CANCELLED' THEN 'CANCELLED'
        ELSE 'CONFIRMED'
    END AS booking_status,
    FALSE AS is_connection,
    NULL AS connection_booking_id,
    NULL AS connection_time_min,
    FLOOR(UNIFORM(1, 3, RANDOM())) AS bags_checked,
    1 AS bags_carry_on,
    TRUE AS upgrade_requested,
    CASE WHEN dea.loyalty_tier = 'DIAMOND' THEN 'CONFIRMED' ELSE 'WAITLIST' END AS upgrade_status,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM daily_elite_assignments dea;

-- Update total_amount_usd for elite bookings
UPDATE BOOKINGS 
SET total_amount_usd = fare_amount_usd + taxes_usd + fees_usd 
WHERE booking_id LIKE 'EL%' AND total_amount_usd = 0;

-- ============================================================================
-- 15. ADDITIONAL PLATINUM MEMBERS ON DISRUPTED FLIGHTS
-- ============================================================================
-- Ensures Platinum tier also has coverage every day

INSERT INTO BOOKINGS
WITH all_dates AS (
    SELECT DISTINCT flight_date 
    FROM FLIGHTS 
    WHERE flight_date BETWEEN DATEADD('day', -90, CURRENT_DATE()) AND DATEADD('day', 60, CURRENT_DATE())
),
disrupted_flights_by_day AS (
    SELECT 
        flight_date,
        flight_id,
        origin,
        destination,
        status,
        ROW_NUMBER() OVER (PARTITION BY flight_date ORDER BY 
            CASE status WHEN 'CANCELLED' THEN 1 WHEN 'DELAYED' THEN 2 ELSE 3 END,
            RANDOM()
        ) AS flight_rank
    FROM FLIGHTS
    WHERE (status IN ('DELAYED', 'CANCELLED') OR DEPARTURE_DELAY_MINUTES > 30)
    AND flight_date BETWEEN DATEADD('day', -90, CURRENT_DATE()) AND DATEADD('day', 60, CURRENT_DATE())
),
platinum_passengers AS (
    SELECT 
        passenger_id,
        loyalty_tier,
        ROW_NUMBER() OVER (ORDER BY RANDOM()) AS pax_rank
    FROM PASSENGERS
    WHERE loyalty_tier = 'PLATINUM'
),
daily_plat_assignments AS (
    SELECT 
        d.flight_date,
        df.flight_id,
        df.origin,
        df.destination,
        df.status,
        pp.passenger_id,
        pp.loyalty_tier,
        ROW_NUMBER() OVER (PARTITION BY d.flight_date ORDER BY df.flight_rank, pp.pax_rank) AS daily_seat
    FROM all_dates d
    CROSS JOIN platinum_passengers pp
    JOIN disrupted_flights_by_day df ON df.flight_date = d.flight_date
    WHERE df.flight_rank <= 10
    AND pp.pax_rank <= 500
    AND NOT EXISTS (
        SELECT 1 FROM BOOKINGS b 
        WHERE b.passenger_id = pp.passenger_id 
        AND b.flight_id = df.flight_id
    )
    QUALIFY daily_seat <= 20
)
SELECT 
    'PL' || LPAD(ROW_NUMBER() OVER (ORDER BY dpa.flight_date, dpa.daily_seat)::VARCHAR, 8, '0') AS booking_id,
    UPPER(SUBSTR(MD5(RANDOM()::VARCHAR), 1, 6)) AS confirmation_code,
    dpa.passenger_id,
    dpa.flight_id,
    DATEADD('day', -FLOOR(UNIFORM(7, 60, RANDOM())), dpa.flight_date::TIMESTAMP_NTZ) AS booking_date,
    'WEB' AS booking_channel,
    'J' AS fare_class,
    'COMFORT_PLUS' AS cabin_class,
    FLOOR(UNIFORM(1, 12, RANDOM())) || CASE MOD(FLOOR(UNIFORM(1, 4, RANDOM())), 4) WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'C' ELSE 'D' END AS seat_number,
    ROUND(UNIFORM(600, 1400, RANDOM()), 2) AS fare_amount_usd,
    ROUND(UNIFORM(50, 150, RANDOM()), 2) AS taxes_usd,
    ROUND(UNIFORM(0, 50, RANDOM()), 2) AS fees_usd,
    0 AS total_amount_usd,
    CASE 
        WHEN dpa.flight_date < CURRENT_DATE() THEN 'COMPLETED'
        WHEN dpa.status = 'CANCELLED' THEN 'CANCELLED'
        ELSE 'CONFIRMED'
    END AS booking_status,
    FALSE AS is_connection,
    NULL AS connection_booking_id,
    NULL AS connection_time_min,
    FLOOR(UNIFORM(1, 3, RANDOM())) AS bags_checked,
    1 AS bags_carry_on,
    TRUE AS upgrade_requested,
    'WAITLIST' AS upgrade_status,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM daily_plat_assignments dpa;

-- Update total_amount_usd for platinum bookings
UPDATE BOOKINGS 
SET total_amount_usd = fare_amount_usd + taxes_usd + fees_usd 
WHERE booking_id LIKE 'PL%' AND total_amount_usd = 0;

-- ============================================================================
-- DATA GENERATION COMPLETE
-- ============================================================================
-- Summary:
--   - AIRPORTS: ~60 airports (8 hubs + 50+ destinations)
--   - AIRCRAFT_TYPES: 8 types
--   - AIRCRAFT: 1,000 aircraft
--   - CREW_MEMBERS: 40,000 (15K pilots + 25K FAs)
--   - CREW_QUALIFICATIONS: ~25,000 type ratings
--   - PASSENGERS: 200,000
--   - FLIGHTS: ~200,000 (90 days past + today + 60 days future)
--     * Today's flights include 40% delay rate for IROPS showcase
--     * Delays include minor (15-45min), moderate (45-120min), severe (120-300min)
--   - DISRUPTIONS: ~50,000 events
--   - MAINTENANCE_LOGS: 100,000 entries
--   - WEATHER_DATA: ~130,000 observations (90 days)
--   - HISTORICAL_INCIDENTS: 5 major events
--   - CREW_DUTY_LOG: ~100,000 entries
--   - BOOKINGS: ~50,000 (with 1 flight per passenger per day constraint)
--   - ELITE LOYALTY BOOKINGS: ~6,800 guaranteed bookings
--     * 25 Diamond members on disrupted flights per day (151 days)
--     * 20 Platinum members on disrupted flights per day (151 days)
--     * Ensures loyalty impact queries always return data for any date
-- ============================================================================
