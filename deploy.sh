#!/bin/bash
# ============================================================================
# Phantom Airlines IROPS - One-Click Deployment Script
# ============================================================================
# Deploys the complete IROPS platform to Snowflake
#
# Usage:
#   ./deploy.sh                     # Uses default connection
#   ./deploy.sh my_connection       # Uses specified connection
#   ./deploy.sh my_connection dev   # Uses DEV_ prefix
#
# Prerequisites:
#   - Snowflake CLI (snow) installed and configured
#   - ACCOUNTADMIN role access for initial setup
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONNECTION_NAME="${1:-default}"
ENVIRONMENT_PREFIX="${2:-}"
BASE_PREFIX="PHANTOM_IROPS"
FULL_PREFIX="${ENVIRONMENT_PREFIX:+${ENVIRONMENT_PREFIX}_}${BASE_PREFIX}"
PROJECT_ROLE="${FULL_PREFIX}_ADMIN"
WAREHOUSE_SIZE="MEDIUM"
DEPLOY_SPCS="${DEPLOY_SPCS:-no}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}    Phantom Airlines IROPS Platform - Deployment${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "Connection:    ${GREEN}${CONNECTION_NAME}${NC}"
echo -e "Database:      ${GREEN}${FULL_PREFIX}${NC}"
echo -e "Role:          ${GREEN}${PROJECT_ROLE}${NC}"
echo -e "Warehouse:     ${GREEN}${FULL_PREFIX}_WH${NC}"
echo -e "SPCS Deploy:   ${GREEN}${DEPLOY_SPCS}${NC}"
echo ""

# Function to run SQL file with session variables
run_sql_file() {
    local file=$1
    local description=$2
    echo -e "${YELLOW}► ${description}...${NC}"
    
    # Create temp file with SET statements prepended
    local temp_file=$(mktemp)
    cat > "${temp_file}" << EOF
SET FULL_PREFIX = '${FULL_PREFIX}';
SET PROJECT_ROLE = '${PROJECT_ROLE}';
SET WAREHOUSE_SIZE = '${WAREHOUSE_SIZE}';

EOF
    cat "${file}" >> "${temp_file}"
    
    snow sql -c "${CONNECTION_NAME}" -f "${temp_file}" --silent
    rm -f "${temp_file}"
    echo -e "${GREEN}  ✓ Complete${NC}"
}

# Function to run inline SQL
run_sql() {
    local sql=$1
    snow sql -c "${CONNECTION_NAME}" -q "${sql}" --silent
}

# Verify connection
echo -e "${YELLOW}► Verifying Snowflake connection...${NC}"
if ! snow connection test -c "${CONNECTION_NAME}" > /dev/null 2>&1; then
    echo -e "${RED}✗ Failed to connect to Snowflake. Please check your connection settings.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Connection verified${NC}"
echo ""

# Start deployment
START_TIME=$(date +%s)

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 1: Account Setup${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/01_account_setup.sql" "Creating database, roles, and warehouse"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 2: Schema Setup${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/02_schema_setup.sql" "Creating RAW layer tables"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 3: Data Generation${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}► Generating synthetic data (this may take 5-10 minutes)...${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/03_data_generation.sql" "Generating Phantom-scale synthetic data"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 4: Dynamic Tables Pipeline${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/04_dynamic_tables.sql" "Creating chained Dynamic Tables"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 5: Semantic Views${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/05_semantic_views.sql" "Creating Cortex Analyst semantic views"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 6: Intelligence Agents${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/06_intelligence_agents.sql" "Creating Cortex Search and Agents"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 7: ML Models Infrastructure${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/07_ml_models.sql" "Creating ML schema and fallback views"
echo -e "${YELLOW}  Note: For full ML with Feature Store & Model Registry,${NC}"
echo -e "${YELLOW}        run notebooks in /notebooks/ directory${NC}"

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Phase 8: Cortex AI Functions${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
run_sql_file "${SCRIPT_DIR}/scripts/08_cortex_ai_functions.sql" "Creating AI functions and Contract Bot"

# Phase 9: SPCS Deployment (optional)
if [ "${DEPLOY_SPCS}" = "yes" ]; then
    echo ""
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}Phase 9: SPCS Dashboard Deployment${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    
    REACT_APP_DIR="${SCRIPT_DIR}/react-app"
    REGISTRY="sfsenorthamerica-srsubramanian-aws1.registry.snowflakecomputing.com/phantom_irops/raw/images"
    
    # Build Docker image
    echo -e "${YELLOW}► Building Docker image (linux/amd64)...${NC}"
    cd "${REACT_APP_DIR}"
    docker build --platform linux/amd64 -t irops-dashboard:latest .
    docker tag irops-dashboard:latest ${REGISTRY}/irops-dashboard:latest
    
    # Push to registry
    echo -e "${YELLOW}► Pushing to Snowflake registry...${NC}"
    docker push ${REGISTRY}/irops-dashboard:latest
    
    # Create compute pool and service
    echo -e "${YELLOW}► Creating SPCS compute pool and service...${NC}"
    run_sql "USE ROLE ACCOUNTADMIN;
    CREATE COMPUTE POOL IF NOT EXISTS ${FULL_PREFIX}_POOL
        MIN_NODES = 1 MAX_NODES = 1
        INSTANCE_FAMILY = CPU_X64_XS
        AUTO_RESUME = TRUE;"
    
    run_sql "USE ROLE ACCOUNTADMIN;
    CREATE SERVICE IF NOT EXISTS ${FULL_PREFIX}.RAW.IROPS_DASHBOARD
        IN COMPUTE POOL ${FULL_PREFIX}_POOL
        FROM SPECIFICATION \$\$
        spec:
          containers:
          - name: app
            image: /${FULL_PREFIX}/raw/images/irops-dashboard:latest
            env:
              SNOWFLAKE_WAREHOUSE: ${FULL_PREFIX}_WH
          endpoints:
          - name: ui
            port: 8080
            public: true
        \$\$
        MIN_INSTANCES = 1 MAX_INSTANCES = 1
        EXTERNAL_ACCESS_INTEGRATIONS = (${FULL_PREFIX}_EGRESS);"
    
    echo -e "${GREEN}  ✓ SPCS deployment complete${NC}"
    
    # Get endpoint URL
    ENDPOINT_URL=$(snow sql -c "${CONNECTION_NAME}" -q "SHOW ENDPOINTS IN SERVICE ${FULL_PREFIX}.RAW.IROPS_DASHBOARD;" --quiet 2>/dev/null | grep -o 'https://[^"]*' | head -1)
    echo -e "${CYAN}  Dashboard URL: ${ENDPOINT_URL}${NC}"
    cd "${SCRIPT_DIR}"
fi

# Calculate deployment time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}    ✓ Deployment Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "Duration:      ${GREEN}${MINUTES}m ${SECONDS}s${NC}"
echo -e "Database:      ${GREEN}${FULL_PREFIX}${NC}"
echo -e "Role:          ${GREEN}${PROJECT_ROLE}${NC}"
echo -e "Warehouse:     ${GREEN}${FULL_PREFIX}_WH${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Run validation:  ${YELLOW}./run.sh ${CONNECTION_NAME}${NC}"
echo -e "  2. Launch React App: ${YELLOW}cd react-app && npm run dev${NC}"
echo -e "  3. Query the data:   ${YELLOW}snow sql -c ${CONNECTION_NAME}${NC}"
echo ""
echo -e "${BLUE}Key Objects Created:${NC}"
echo -e "  • 17 RAW tables with synthetic data"
echo -e "  • 5 Staging Dynamic Tables"
echo -e "  • 2 Intermediate Dynamic Tables"
echo -e "  • 3 Analytics marts (including Golden Record)"
echo -e "  • 5 Semantic Views for Cortex Analyst"
echo -e "  • 2 Cortex Search Services"
echo -e "  • 3 Intelligence Agents"
echo -e "  • Rebooking Options table for passenger prioritization"
echo -e "  • ML infrastructure (Feature Store + Model Registry ready)"
echo -e "  • 10+ Cortex AI Functions"
if [ "${DEPLOY_SPCS}" = "yes" ]; then
    echo -e "  • SPCS Dashboard Service (irops-dashboard)"
fi
echo ""
if [ "${DEPLOY_SPCS}" != "yes" ]; then
    echo -e "${BLUE}SPCS Dashboard (Optional):${NC}"
    echo -e "  To deploy: ${YELLOW}DEPLOY_SPCS=yes ./deploy.sh ${CONNECTION_NAME}${NC}"
    echo ""
fi
echo -e "${BLUE}ML Notebooks (Optional - for full Feature Store integration):${NC}"
echo -e "  • notebooks/01_delay_prediction_model.ipynb"
echo -e "  • notebooks/02_crew_ranking_model.ipynb"
echo -e "  • notebooks/03_cost_estimation_model.ipynb"
echo ""
