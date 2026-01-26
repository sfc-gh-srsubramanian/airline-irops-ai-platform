#!/bin/bash
# ============================================================================
# Phantom Airlines IROPS - Cleanup Script
# ============================================================================
# Removes all IROPS platform objects from Snowflake
#
# Usage:
#   ./clean.sh                     # Uses default connection
#   ./clean.sh my_connection       # Uses specified connection
#   ./clean.sh my_connection dev   # Cleans DEV_ prefixed objects
#
# WARNING: This will permanently delete all data!
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
CONNECTION_NAME="${1:-default}"
ENVIRONMENT_PREFIX="${2:-}"
BASE_PREFIX="PHANTOM_IROPS"
FULL_PREFIX="${ENVIRONMENT_PREFIX:+${ENVIRONMENT_PREFIX}_}${BASE_PREFIX}"
PROJECT_ROLE="${FULL_PREFIX}_ADMIN"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}    Phantom Airlines IROPS Platform - Cleanup${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "Connection:    ${GREEN}${CONNECTION_NAME}${NC}"
echo -e "Database:      ${RED}${FULL_PREFIX}${NC} (will be DELETED)"
echo -e "Role:          ${RED}${PROJECT_ROLE}${NC} (will be DELETED)"
echo -e "Warehouse:     ${RED}${FULL_PREFIX}_WH${NC} (will be DELETED)"
echo ""

# Confirm deletion (auto-approve if FORCE=yes is set)
if [ "${FORCE}" != "yes" ]; then
    echo -e "${YELLOW}WARNING: This will permanently delete all IROPS data and objects!${NC}"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${BLUE}Cleanup cancelled.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${YELLOW}► Starting cleanup...${NC}"

# Function to run SQL
run_sql() {
    local sql=$1
    snow sql -c "${CONNECTION_NAME}" -q "${sql}" --quiet 2>/dev/null || true
}

# Drop database (this drops all objects inside)
echo -e "${YELLOW}► Dropping database ${FULL_PREFIX}...${NC}"
run_sql "USE ROLE ACCOUNTADMIN;"
run_sql "DROP DATABASE IF EXISTS ${FULL_PREFIX};"
echo -e "${GREEN}  ✓ Database dropped${NC}"

# Drop warehouse
echo -e "${YELLOW}► Dropping warehouse ${FULL_PREFIX}_WH...${NC}"
run_sql "DROP WAREHOUSE IF EXISTS ${FULL_PREFIX}_WH;"
echo -e "${GREEN}  ✓ Warehouse dropped${NC}"

# Drop role
echo -e "${YELLOW}► Dropping role ${PROJECT_ROLE}...${NC}"
run_sql "DROP ROLE IF EXISTS ${PROJECT_ROLE};"
echo -e "${GREEN}  ✓ Role dropped${NC}"

echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}    ✓ Cleanup Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "The following objects have been removed:"
echo -e "  • Database: ${FULL_PREFIX}"
echo -e "  • Warehouse: ${FULL_PREFIX}_WH"
echo -e "  • Role: ${PROJECT_ROLE}"
echo ""
echo -e "To redeploy, run: ${YELLOW}./deploy.sh ${CONNECTION_NAME}${NC}"
echo ""
