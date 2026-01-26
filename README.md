# ✈️ Phantom Airlines IROPS Platform

> AI-Powered Irregular Operations Management for Modern Airlines

<p align="center">
  <img src="https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white" alt="Snowflake"/>
  <img src="https://img.shields.io/badge/Cortex_AI-1E3A5F?style=for-the-badge&logo=snowflake&logoColor=white" alt="Cortex AI"/>
  <img src="https://img.shields.io/badge/Streamlit-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white" alt="Streamlit"/>
</p>

## 🎯 Overview

The Phantom Airlines IROPS Platform is a comprehensive AI-powered solution for managing Irregular Operations (IROPS) using Snowflake's native capabilities. Built to address real-world airline challenges exposed during events like the 2024 CrowdStrike incident, this platform eliminates operational bottlenecks and provides real-time visibility into crew, aircraft, and flight status.

### Key Problems Solved

| Challenge | Traditional Approach | IROPS Platform Solution |
|-----------|---------------------|------------------------|
| **12-Minute Bottleneck** | Sequential phone calls to pilots | One-Click Recovery with batch notifications |
| **Ghost Flights** | Manual reconciliation | Real-time Golden Record synchronization |
| **Contract Compliance** | Paper-based validation | AI Contract Bot with PWA/FAA rules |
| **Recovery Decisions** | Tribal knowledge | AI similarity matching with historical incidents |
| **Network Visibility** | Multiple disconnected systems | Unified Operations Dashboard |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        STREAMLIT DASHBOARD                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │Operations│ │  Crew    │ │  Ghost   │ │Disruption│ │ Contract │ │
│  │Dashboard │ │ Recovery │ │  Planes  │ │ Analysis │ │   Bot    │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
└───────┼────────────┼────────────┼────────────┼────────────┼────────┘
        │            │            │            │            │
┌───────┴────────────┴────────────┴────────────┴────────────┴────────┐
│                     SNOWFLAKE CORTEX AI LAYER                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │
│  │   Cortex     │ │ Intelligence │ │   Cortex     │                │
│  │   Search     │ │    Agents    │ │ ML Functions │                │
│  └──────────────┘ └──────────────┘ └──────────────┘                │
└─────────────────────────────────────────────────────────────────────┘
        │                    │                    │
┌───────┴────────────────────┴────────────────────┴──────────────────┐
│                   SEMANTIC MODELS LAYER                             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐       │
│  │  Flight    │ │ Disruption │ │   Crew     │ │  Network   │       │
│  │ Operations │ │ Analytics  │ │ Management │ │   Health   │       │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
        │                    │                    │
┌───────┴────────────────────┴────────────────────┴──────────────────┐
│              DYNAMIC TABLES PIPELINE (1-min latency)                │
│  ┌─────────┐      ┌─────────────┐      ┌─────────────────────────┐ │
│  │ STAGING │ ──▶  │INTERMEDIATE │ ──▶  │      ANALYTICS          │ │
│  │  DTs    │      │    DTs      │      │ ┌─────────────────────┐ │ │
│  └─────────┘      └─────────────┘      │ │   GOLDEN RECORD     │ │ │
│                                         │ │ (Unified Truth)     │ │ │
│                                         │ └─────────────────────┘ │ │
│                                         └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
        │
┌───────┴────────────────────────────────────────────────────────────┐
│                        RAW DATA LAYER                               │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐│
│  │Flights │ │ Crew   │ │Aircraft│ │Weather │ │Disrupt.│ │Maint.  ││
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Snowflake account with Cortex enabled
- Snowflake CLI (`snow`) installed and configured
- ACCOUNTADMIN role access (for initial setup)

### One-Click Deployment

```bash
# Clone the repository
git clone <repository-url>
cd Airlines-IROPS

# Deploy (uses default connection)
./deploy.sh

# Or specify a connection
./deploy.sh my_connection

# For development environment with prefix
./deploy.sh my_connection dev
```

### Validate Deployment

```bash
./run.sh
```

### Launch Dashboard

```bash
cd streamlit
streamlit run app.py
```

### Cleanup

```bash
./clean.sh
```

## 📊 Data Volumes

The platform generates Phantom-scale synthetic data:

| Entity | Volume | Description |
|--------|--------|-------------|
| Airports | 58 | 8 hubs + 50 destinations |
| Aircraft | 1,000 | Mixed fleet (737, 757, 767, A320, A321, A330, A350) |
| Crew | 40,000 | 15K pilots + 25K flight attendants |
| Flights | 500,000 | 365 days of operations |
| Disruptions | 50,000 | Weather, mechanical, crew, ATC events |
| Passengers | 200,000 | With loyalty tiers |
| Maintenance Logs | 100,000 | Unstructured text for AI parsing |
| Weather | 130,000 | 90 days × all airports |

## 🎯 Key Features

### 1. Golden Record (Unified Truth)
- Real-time synchronization of crew, aircraft, and flight data
- Eliminates "ghost flights" caused by system lag
- 1-minute refresh via chained Dynamic Tables

### 2. One-Click Recovery
- ML-ranked crew candidates for open trips
- Batch notification to top 20 candidates simultaneously
- Eliminates 12-minute sequential calling bottleneck
- Contract validation before notification

### 3. Contract Bot
- AI-powered PWA and FAA Part 117 compliance
- Natural language queries about contract rules
- Automatic assignment validation
- Prevents union grievances and legal violations

### 4. Intelligence Agents
- **PHANTOM_OPERATIONS_AGENT**: Main OCC assistant
- **CREW_RECOVERY_AGENT**: Crew scheduling specialist
- **COST_ANALYSIS_AGENT**: Financial impact expert

### 5. Historical Pattern Matching
- Cortex Search over past IROPS events
- AI_SIMILARITY for recovery strategy recommendations
- Proven playbooks from similar incidents

## 📁 Project Structure

```
Airlines-IROPS/
├── deploy.sh                 # One-click deployment
├── clean.sh                  # Teardown script
├── run.sh                    # Validation script
├── README.md                 # This file
│
├── scripts/
│   ├── 01_account_setup.sql      # Database, roles, warehouse
│   ├── 02_schema_setup.sql       # RAW layer tables
│   ├── 03_data_generation.sql    # Synthetic data (500K+ records)
│   ├── 04_dynamic_tables.sql     # Chained DT pipeline
│   ├── 05_semantic_views.sql     # Cortex Analyst views
│   ├── 06_intelligence_agents.sql # Cortex Agents
│   ├── 07_ml_models.sql          # ML infrastructure & fallback views
│   ├── 08_cortex_ai_functions.sql # AI functions + Contract Bot
│   └── 09_sample_queries.sql     # Demo queries
│
├── notebooks/                    # Snowflake ML Notebooks
│   ├── 01_delay_prediction_model.ipynb   # Feature Store + XGBoost
│   ├── 02_crew_ranking_model.ipynb       # Feature Store + LightGBM
│   └── 03_cost_estimation_model.ipynb    # Feature Store + XGBoost
│
├── streamlit/
│   ├── app.py                    # Main dashboard
│   └── pages/
│       ├── 1_Operations_Dashboard.py
│       ├── 2_Crew_Recovery.py
│       ├── 3_Ghost_Planes.py
│       ├── 4_Disruption_Analysis.py
│       ├── 5_Contract_Bot.py
│       └── 6_Intelligence_Agent.py
│
├── solution_presentation/
│   ├── Phantom_IROPS_Solution_Overview.md
│   └── Phantom_IROPS_Presentation_Guide.md
│
└── demo/                     # Demo scenarios
```

## 🔧 Snowflake Objects Created

### Schemas
- `RAW` - Source data tables
- `STAGING` - Cleansed Dynamic Tables
- `INTERMEDIATE` - Joined Dynamic Tables
- `ANALYTICS` - Business-ready marts
- `ML_MODELS` - ML predictions and functions
- `FEATURE_STORE` - Snowflake Feature Store entities and views
- `SEMANTIC_MODELS` - Cortex Analyst views
- `CORTEX_SEARCH` - Search services

### Key Dynamic Tables
- `MART_GOLDEN_RECORD` - Unified operational view
- `MART_CREW_RECOVERY_CANDIDATES` - Pre-ranked crew list
- `MART_OPERATIONAL_SUMMARY` - Real-time metrics

### Intelligence Agents
- `PHANTOM_OPERATIONS_AGENT`
- `CREW_RECOVERY_AGENT`
- `COST_ANALYSIS_AGENT`

### Cortex Search Services
- `IROPS_INCIDENT_SEARCH`
- `MAINTENANCE_KNOWLEDGE_SEARCH`

## 🤖 ML Models & Feature Store

The platform includes three ML models built with Snowflake's native ML capabilities:

### Snowflake ML Features Used
- **Feature Store**: Centralized feature management with point-in-time correctness
- **Model Registry**: Version control, lineage tracking, and deployment
- **Model Observability**: Performance monitoring and drift detection

### ML Notebooks

| Notebook | Model Type | Features | Purpose |
|----------|-----------|----------|---------|
| `01_delay_prediction_model.ipynb` | XGBoost Classifier | Flight schedule, weather, route history | Predict delay category |
| `02_crew_ranking_model.ipynb` | LightGBM Classifier | Crew profile, fatigue, acceptance history | Rank crew for One-Click Recovery |
| `03_cost_estimation_model.ipynb` | XGBoost Regressor | Disruption type, severity, airport impact | Estimate disruption costs |

### Feature Store Entities
- `FLIGHT` - Flight-level features for delay prediction
- `AIRPORT` - Airport weather and operational features
- `ROUTE` - Historical route performance metrics
- `CREW_MEMBER` - Crew profile, fatigue, and history features
- `DISRUPTION` - Disruption characteristics for cost estimation

### Running the ML Notebooks

```bash
# Set environment variables
export SNOWFLAKE_CONNECTION_NAME=my_connection
export IROPS_DATABASE=PHANTOM_IROPS
export IROPS_WAREHOUSE=PHANTOM_IROPS_WH

# Open in Jupyter
cd notebooks
jupyter lab
```

Or deploy notebooks to Snowflake for execution in Snowsight.

## 📈 Sample Queries

```sql
-- Get current network health
SELECT * FROM ANALYTICS.MART_OPERATIONAL_SUMMARY;

-- Find ghost flights
SELECT * FROM ANALYTICS.MART_GOLDEN_RECORD
WHERE is_ghost_flight = TRUE;

-- Validate crew assignment
SELECT ML_MODELS.VALIDATE_CREW_ASSIGNMENT('CR001234', 'FLT20240101-PH1234-01', 'CAPTAIN');

-- Ask Contract Bot
SELECT ML_MODELS.CONTRACT_BOT_QUERY('What is the max FDP for a 6am report?');

-- Find similar historical incidents
SELECT * FROM TABLE(ML_MODELS.FIND_SIMILAR_INCIDENTS('Winter storm causing crew positioning issues', 3));
```

## 🎨 Brand Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Snowflake Blue | `#29B5E8` | Primary |
| Dark Blue | `#1E3A5F` | Headers |
| Light Blue | `#E8F4FC` | Backgrounds |
| White | `#FFFFFF` | Text, cards |
| Accent Blue | `#0D47A1` | Highlights |

## 📚 Documentation

- [Solution Overview](solution_presentation/Phantom_IROPS_Solution_Overview.md)
- [Presentation Guide](solution_presentation/Phantom_IROPS_Presentation_Guide.md)

## 🤝 Contributing

This is a demonstration project showcasing Snowflake's capabilities for airline IROPS management.

## 📄 License

This project is provided as-is for demonstration purposes.

---

<p align="center">
  Built with ❄️ Snowflake
</p>
