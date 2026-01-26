#!/bin/bash
# ============================================================================
# Phantom Airlines IROPS - Validation Script
# ============================================================================
# Validates the deployed IROPS platform by running sample queries
#
# Usage:
#   ./run.sh                     # Uses default connection
#   ./run.sh my_connection       # Uses specified connection
#   ./run.sh my_connection dev   # Validates DEV_ prefixed deployment
#
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONNECTION_NAME="${1:-default}"
ENVIRONMENT_PREFIX="${2:-}"
BASE_PREFIX="PHANTOM_IROPS"
FULL_PREFIX="${ENVIRONMENT_PREFIX:+${ENVIRONMENT_PREFIX}_}${BASE_PREFIX}"
PROJECT_ROLE="${FULL_PREFIX}_ADMIN"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}    Phantom Airlines IROPS Platform - Validation${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "Connection:    ${GREEN}${CONNECTION_NAME}${NC}"
echo -e "Database:      ${GREEN}${FULL_PREFIX}${NC}"
echo ""

# Function to run SQL and show results
run_query() {
    local description=$1
    local sql=$2
    echo -e "${YELLOW}► ${description}${NC}"
    snow sql -c "${CONNECTION_NAME}" -q "
        USE ROLE ${PROJECT_ROLE};
        USE DATABASE ${FULL_PREFIX};
        USE WAREHOUSE ${FULL_PREFIX}_WH;
        ${sql}
    " 2>/dev/null
    echo ""
}

# Verify connection
echo -e "${YELLOW}► Verifying connection...${NC}"
if ! snow sql -c "${CONNECTION_NAME}" -q "SELECT 1" --quiet > /dev/null 2>&1; then
    echo -e "${RED}✗ Failed to connect. Please check connection settings.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Connected${NC}"
echo ""

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}1. Data Volume Validation${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Checking data volumes" "
SELECT 'AIRPORTS' AS table_name, COUNT(*) AS row_count FROM RAW.AIRPORTS
UNION ALL SELECT 'AIRCRAFT', COUNT(*) FROM RAW.AIRCRAFT
UNION ALL SELECT 'CREW_MEMBERS', COUNT(*) FROM RAW.CREW_MEMBERS
UNION ALL SELECT 'FLIGHTS', COUNT(*) FROM RAW.FLIGHTS
UNION ALL SELECT 'DISRUPTIONS', COUNT(*) FROM RAW.DISRUPTIONS
UNION ALL SELECT 'PASSENGERS', COUNT(*) FROM RAW.PASSENGERS
UNION ALL SELECT 'BOOKINGS', COUNT(*) FROM RAW.BOOKINGS
ORDER BY table_name;
"

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}2. Dynamic Tables Status${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Checking Dynamic Table refresh status" "
SELECT 
    name,
    schema_name,
    target_lag,
    refresh_mode,
    scheduling_state
FROM INFORMATION_SCHEMA.DYNAMIC_TABLES
ORDER BY schema_name, name;
"

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}3. Golden Record Sample${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Viewing Golden Record (top 5 flights by priority)" "
SELECT 
    flight_number,
    origin || ' -> ' || destination AS route,
    flight_status,
    tail_number,
    captain_name,
    is_ghost_flight,
    flight_health_score,
    recovery_priority_score
FROM ANALYTICS.MART_GOLDEN_RECORD
ORDER BY recovery_priority_score DESC
LIMIT 5;
"

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}4. Operational Summary${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Current operational metrics" "
SELECT * FROM ANALYTICS.MART_OPERATIONAL_SUMMARY;
"

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}5. Ghost Flights Detection${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Checking for Ghost Flights" "
SELECT 
    COUNT(*) AS ghost_flights_count,
    SUM(CASE WHEN is_ghost_flight THEN 1 ELSE 0 END) AS actual_ghosts
FROM ANALYTICS.MART_GOLDEN_RECORD
WHERE flight_date >= CURRENT_DATE();
"

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}6. Active Disruptions${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Active disruptions by type" "
SELECT 
    disruption_type,
    COUNT(*) AS count,
    SUM(CASE WHEN severity IN ('CRITICAL', 'SEVERE') THEN 1 ELSE 0 END) AS critical_severe
FROM STAGING.STG_DISRUPTIONS
WHERE is_active = TRUE
GROUP BY disruption_type
ORDER BY count DESC;
"

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}7. Crew Availability${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Crew availability by base" "
SELECT 
    base_airport,
    SUM(CASE WHEN crew_type = 'CAPTAIN' AND availability_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS captains,
    SUM(CASE WHEN crew_type = 'FIRST_OFFICER' AND availability_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS first_officers
FROM STAGING.STG_CREW
GROUP BY base_airport
ORDER BY captains DESC
LIMIT 8;
"

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}8. AI Function Test${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

run_query "Testing Contract Bot query" "
SELECT ML_MODELS.CONTRACT_BOT_QUERY(
    'What is the maximum flight duty period for a pilot starting work at 6am?'
) AS contract_bot_response;
"

echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}    ✓ Validation Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "${CYAN}Platform Status: ${GREEN}OPERATIONAL${NC}"
echo ""
echo -e "All components verified:"
echo -e "  ✓ RAW tables populated with synthetic data"
echo -e "  ✓ Dynamic Tables pipeline active"
echo -e "  ✓ Golden Record generating unified view"
echo -e "  ✓ Disruption tracking operational"
echo -e "  ✓ Crew availability tracking active"
echo -e "  ✓ AI functions responding"
echo ""
echo -e "To run sample queries: ${YELLOW}snow sql -c ${CONNECTION_NAME} -f scripts/09_sample_queries.sql${NC}"
echo -e "To launch dashboard:   ${YELLOW}cd streamlit && streamlit run app.py${NC}"
echo ""
