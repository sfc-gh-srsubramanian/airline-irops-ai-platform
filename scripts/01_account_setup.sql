-- ============================================================================
-- Phantom Airlines IROPS - Account Setup
-- ============================================================================
-- Creates database, schemas, roles, and warehouse for the IROPS platform
-- 
-- Session variables (set by deploy.sh):
--   $FULL_PREFIX - Environment prefix (e.g., PHANTOM_IROPS or DEV_PHANTOM_IROPS)
--   $PROJECT_ROLE - Role for the project
--   $WAREHOUSE_SIZE - Warehouse size (default: MEDIUM)
-- ============================================================================

-- Derive warehouse name
SET WAREHOUSE_NAME = $FULL_PREFIX || '_WH';

-- ============================================================================
-- 1. CREATE ROLES
-- ============================================================================

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS IDENTIFIER($PROJECT_ROLE)
    COMMENT = 'Phantom IROPS platform administrator role';

-- Grant the new role to SYSADMIN for hierarchy
GRANT ROLE IDENTIFIER($PROJECT_ROLE) TO ROLE SYSADMIN;

GRANT CREATE DATABASE ON ACCOUNT TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT EXECUTE TASK ON ACCOUNT TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE IDENTIFIER($PROJECT_ROLE);

-- ============================================================================
-- 2. CREATE WAREHOUSE (staying as ACCOUNTADMIN)
-- ============================================================================

CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($WAREHOUSE_NAME)
    WAREHOUSE_SIZE = $WAREHOUSE_SIZE
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Phantom IROPS compute warehouse';

GRANT ALL ON WAREHOUSE IDENTIFIER($WAREHOUSE_NAME) TO ROLE IDENTIFIER($PROJECT_ROLE);

USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);

-- ============================================================================
-- 3. CREATE DATABASE
-- ============================================================================

CREATE DATABASE IF NOT EXISTS IDENTIFIER($FULL_PREFIX)
    COMMENT = 'Phantom Airlines IROPS Platform - AI-powered Irregular Operations Management';

GRANT ALL ON DATABASE IDENTIFIER($FULL_PREFIX) TO ROLE IDENTIFIER($PROJECT_ROLE);

USE DATABASE IDENTIFIER($FULL_PREFIX);

-- ============================================================================
-- 4. CREATE SCHEMAS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw ingested data from source systems (flights, crew, aircraft, passengers, weather)';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Staging layer - cleaned and validated data via Dynamic Tables';

CREATE SCHEMA IF NOT EXISTS INTERMEDIATE
    COMMENT = 'Intermediate layer - joined and enriched data via Dynamic Tables';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Analytics layer - business-ready mart tables via Dynamic Tables';

CREATE SCHEMA IF NOT EXISTS ML_MODELS
    COMMENT = 'Machine learning models and predictions (delay, cost, crew ranking)';

CREATE SCHEMA IF NOT EXISTS SEMANTIC_MODELS
    COMMENT = 'Semantic views and models for Cortex Analyst integration';

CREATE SCHEMA IF NOT EXISTS CORTEX_SEARCH
    COMMENT = 'Cortex Search services for historical incident retrieval';

-- ============================================================================
-- 5. GRANT SCHEMA PERMISSIONS
-- ============================================================================

GRANT ALL ON SCHEMA RAW TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT ALL ON SCHEMA STAGING TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT ALL ON SCHEMA INTERMEDIATE TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT ALL ON SCHEMA ANALYTICS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT ALL ON SCHEMA ML_MODELS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT ALL ON SCHEMA SEMANTIC_MODELS TO ROLE IDENTIFIER($PROJECT_ROLE);
GRANT ALL ON SCHEMA CORTEX_SEARCH TO ROLE IDENTIFIER($PROJECT_ROLE);

-- ============================================================================
-- 6. CREATE INTERNAL STAGE FOR SEMANTIC MODELS
-- ============================================================================

USE SCHEMA SEMANTIC_MODELS;

CREATE STAGE IF NOT EXISTS SEMANTIC_MODEL_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for semantic model YAML files';

-- ============================================================================
-- 7. CREATE FILE FORMAT FOR DATA LOADING
-- ============================================================================

USE SCHEMA RAW;

CREATE FILE FORMAT IF NOT EXISTS JSON_FORMAT
    TYPE = JSON
    STRIP_OUTER_ARRAY = TRUE;

CREATE FILE FORMAT IF NOT EXISTS CSV_FORMAT
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1;

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- Database: $FULL_PREFIX
-- Schemas: RAW, STAGING, INTERMEDIATE, ANALYTICS, ML_MODELS, SEMANTIC_MODELS, CORTEX_SEARCH
-- Warehouse: $FULL_PREFIX_WH
-- Role: $PROJECT_ROLE
-- ============================================================================
