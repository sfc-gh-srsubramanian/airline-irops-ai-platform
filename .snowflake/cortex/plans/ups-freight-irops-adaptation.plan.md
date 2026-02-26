# Plan: UPS Freight IROPS Adaptation

## Overview

Transform the Phantom Airlines IROPS platform into a UPS Freight Irregular Operations platform. This requires changes across 6 major areas: branding/terminology, data models, business logic, UI components, AI/ML models, and documentation.

---

## 1. Branding and Terminology Changes

### Global Find/Replace Mappings

| Airline Term | Freight Term |
|--------------|--------------|
| Phantom Airlines | UPS Freight |
| Flight | Shipment / Route / Delivery |
| Pilot / Captain | Driver |
| First Officer | Co-Driver |
| Flight Attendant | Package Handler |
| Passenger | Package / Shipment |
| Aircraft | Vehicle / Truck / Trailer |
| Airport | Hub / Distribution Center / Facility |
| Gate | Dock / Loading Bay |
| Boarding | Loading |
| Takeoff / Departure | Dispatch |
| Landing / Arrival | Delivery Complete |
| On-Time Performance (OTP) | On-Time Delivery (OTD) |
| Ghost Flight | Ghost Route (vehicle not at expected location) |
| Crew Recovery | Driver Recovery |
| Loyalty Tier (Diamond/Platinum) | Service Level (Premium/Priority/Ground) |

### Files Requiring Branding Updates

- [README.md](README.md) - Project overview and branding
- [react-app/components/*.tsx](react-app/components/) - All 12 React components
- [scripts/*.sql](scripts/) - All 9 SQL scripts
- [solution_presentation/*.md](solution_presentation/) - Documentation
- [solution_presentation/images/architecture_diagram.jpg](solution_presentation/images/architecture_diagram.jpg) - Architecture diagram

---

## 2. Data Model Transformation

### Schema Changes Required

The current schema has 17 RAW tables. Each needs freight-domain equivalents:

#### Reference Data Tables

| Current Table | New Table | Key Changes |
|---------------|-----------|-------------|
| `AIRPORTS` | `FACILITIES` | airport_code -> facility_code, hub -> distribution_center, gates -> docks |
| `AIRCRAFT_TYPES` | `VEHICLE_TYPES` | seat_capacity -> cargo_capacity_lbs, range_nm -> range_miles |
| `AIRCRAFT` | `VEHICLES` | tail_number -> vehicle_id, aircraft_type -> vehicle_type (truck, trailer, van) |

#### Crew/Driver Tables

| Current Table | New Table | Key Changes |
|---------------|-----------|-------------|
| `CREW_MEMBERS` | `DRIVERS` | crew_type (CAPTAIN/FO) -> driver_type (DRIVER/CO-DRIVER), seniority_number -> years_experience |
| `CREW_QUALIFICATIONS` | `DRIVER_CERTIFICATIONS` | type_rating -> CDL class (A/B/C), hazmat, tanker endorsements |
| `CREW_DUTY_LOG` | `DRIVER_HOURS_LOG` | FDP hours -> driving_hours, FAA Part 117 -> DOT HOS compliance |

#### Operations Tables

| Current Table | New Table | Key Changes |
|---------------|-----------|-------------|
| `FLIGHTS` | `ROUTES` | flight_number -> route_id, origin/destination airports -> origin/destination facilities |
| `DISRUPTIONS` | `SERVICE_EXCEPTIONS` | WEATHER, MECHANICAL, CREW -> WEATHER, MECHANICAL, DRIVER, TRAFFIC |
| `BOOKINGS` | `SHIPMENTS` | passenger_id -> shipper_id, fare_class -> service_level |
| `PASSENGERS` | `SHIPPERS` / `PACKAGES` | loyalty_tier -> account_tier (Enterprise/Business/Retail) |

#### Supporting Tables

| Current Table | New Table | Key Changes |
|---------------|-----------|-------------|
| `MAINTENANCE_LOGS` | `VEHICLE_MAINTENANCE` | ATA chapters -> DOT inspection categories |
| `WEATHER_DATA` | `WEATHER_DATA` | Similar structure, focus on road conditions |
| `HISTORICAL_INCIDENTS` | `HISTORICAL_INCIDENTS` | CrowdStrike scenario -> logistics disruption scenarios |

### New Freight-Specific Columns

Add to `ROUTES` table:
- `load_weight_lbs` - Total weight of packages
- `load_volume_cuft` - Cubic feet utilized
- `stops_count` - Number of delivery stops
- `estimated_drive_time_min` - Based on route distance
- `traffic_delay_minutes` - Real-time traffic impact

Add to `PACKAGES` table:
- `tracking_number` - UPS tracking ID
- `service_level` - Next Day Air, Ground, Freight, etc.
- `declared_value_usd` - Package value
- `weight_lbs` - Package weight
- `dimensions` - L x W x H

---

## 3. Business Logic and Compliance Changes

### Replace FAA Part 117 with DOT Hours of Service (HOS)

Current Contract Bot rules in [scripts/08_cortex_ai_functions.sql](scripts/08_cortex_ai_functions.sql):

```sql
-- CURRENT: FAA Rules
'FAA-117-1', 'Maximum Flight Duty Period', 'max_fdp_hours: 13'
'FAA-117-2', 'Minimum Rest Period', 'min_rest_hours: 10'
'FAA-117-3', 'Monthly Flight Time Limit', 'max_monthly_hours: 100'
```

**Replace with DOT HOS Rules:**

```sql
-- NEW: DOT HOS Rules for Property-Carrying Drivers
'DOT-HOS-1', 'Maximum Driving Time', '11 hours driving after 10 consecutive hours off duty'
'DOT-HOS-2', 'Maximum On-Duty Time', '14-hour limit after coming on duty'
'DOT-HOS-3', '30-Minute Break', 'Required after 8 cumulative hours driving'
'DOT-HOS-4', '60/70 Hour Limit', 'Max 60 hrs in 7 days or 70 hrs in 8 days'
'DOT-HOS-5', 'Sleeper Berth', 'Split sleeper berth provisions'
```

### Replace PWA with Teamsters Contract Rules

```sql
-- NEW: Teamsters National Master Freight Agreement
'TEAM-1', 'Seniority Bidding', 'Route bids by seniority'
'TEAM-2', 'Overtime', 'Time-and-a-half after 8 hours'
'TEAM-3', 'Forced Dispatch', 'Rules for mandatory overtime'
```

### Update ML Models

Notebooks in [notebooks/](notebooks/) need retraining:

| Current Model | New Model | Changes |
|---------------|-----------|---------|
| `01_delay_prediction_model.ipynb` | Delivery delay prediction | Features: traffic, weather, load weight, stop count |
| `02_crew_ranking_model.ipynb` | Driver ranking | Features: route familiarity, HOS remaining, proximity |
| `03_cost_estimation_model.ipynb` | Exception cost estimation | Features: service level, customer tier, exception type |

---

## 4. React Dashboard Components

### Component-by-Component Changes

Each file in [react-app/components/](react-app/components/):

| Component | Current Purpose | New Purpose |
|-----------|-----------------|-------------|
| [CrowdStrikeScenario.tsx](react-app/components/CrowdStrikeScenario.tsx) | IT outage simulation | Logistics system outage simulation (e.g., sorting facility down) |
| [GhostPlanes.tsx](react-app/components/GhostPlanes.tsx) | Detect flights with wrong aircraft/crew location | Detect routes with wrong vehicle/driver location |
| [PassengerRebooking.tsx](react-app/components/PassengerRebooking.tsx) | Elite passenger rebooking | Priority package rerouting (Premium/Priority first) |
| [CrewRecovery.tsx](react-app/components/CrewRecovery.tsx) | ML-ranked pilot candidates | ML-ranked driver candidates |
| [ContractBot.tsx](react-app/components/ContractBot.tsx) | FAA/PWA compliance | DOT HOS/Teamsters compliance |
| [DisruptionAnalysis.tsx](react-app/components/DisruptionAnalysis.tsx) | Flight disruption costs | Delivery exception costs |
| [NotificationSystem.tsx](react-app/components/NotificationSystem.tsx) | Crew/passenger alerts | Driver/shipper alerts |
| [SnowflakeIntelligence.tsx](react-app/components/SnowflakeIntelligence.tsx) | Text-to-SQL for flights | Text-to-SQL for routes/deliveries |
| [OperationsDashboard.tsx](react-app/components/OperationsDashboard.tsx) | Flight operations KPIs | Delivery operations KPIs |
| [Sidebar.tsx](react-app/components/Sidebar.tsx) | Navigation with airline icons | Navigation with logistics icons |

### UI Terminology Updates

```typescript
// CURRENT
"Flights Today", "Delayed Flights", "Cancelled Flights"
"Passengers Affected", "Elite Members Impacted"
"On-Time Performance", "Ghost Flights"

// NEW
"Routes Today", "Delayed Deliveries", "Cancelled Routes"
"Packages Affected", "Premium Shipments Impacted"
"On-Time Delivery Rate", "Ghost Routes"
```

### Color Scheme Update (Optional)

| Current (Snowflake Blue) | UPS Brown Theme |
|--------------------------|-----------------|
| `#29B5E8` | `#351C15` (UPS Brown) |
| `#1E3A5F` | `#FFB500` (UPS Gold) |

---

## 5. Semantic Views and Intelligence Agent

### Update Semantic View

Current semantic view in [scripts/05_semantic_views.sql](scripts/05_semantic_views.sql):

```sql
-- CURRENT: Airline semantic model
TABLES (FLIGHTS, DISRUPTIONS, CREW, AIRCRAFT, PASSENGERS, BOOKINGS)
DIMENSIONS (FLIGHT_NUMBER, ORIGIN_AIRPORT, LOYALTY_TIER...)
METRICS (ON_TIME_PERFORMANCE, DELAYED_COUNT...)

-- NEW: Freight semantic model
TABLES (ROUTES, SERVICE_EXCEPTIONS, DRIVERS, VEHICLES, PACKAGES, SHIPMENTS)
DIMENSIONS (ROUTE_ID, ORIGIN_FACILITY, SERVICE_LEVEL...)
METRICS (ON_TIME_DELIVERY_RATE, EXCEPTION_COUNT...)
```

### Update AI SQL Generation Hints

```sql
-- CURRENT
AI_SQL_GENERATION 'Hub Airports: LAX, JFK, ORD...'
'LOYALTY_TIER: DIAMOND, PLATINUM, GOLD, SILVER, BLUE'

-- NEW
AI_SQL_GENERATION 'Distribution Centers: LOUISVILLE, ONTARIO, CHICAGO...'
'SERVICE_LEVEL: NEXT_DAY_AIR, 2ND_DAY_AIR, GROUND, FREIGHT'
'ACCOUNT_TIER: ENTERPRISE, BUSINESS, RETAIL'
```

### Update Cortex Search Services

| Current | New |
|---------|-----|
| `IROPS_INCIDENT_SEARCH` | `LOGISTICS_EXCEPTION_SEARCH` |
| `MAINTENANCE_KNOWLEDGE_SEARCH` | `VEHICLE_MAINTENANCE_SEARCH` |

---

## 6. Documentation and Presentation Updates

### Files to Update

- [README.md](README.md) - Full rewrite for UPS Freight context
- [solution_presentation/Phantom_IROPS_Solution_Overview.md](solution_presentation/Phantom_IROPS_Solution_Overview.md) - Executive summary for freight
- [solution_presentation/Phantom_IROPS_Presentation_Guide.md](solution_presentation/Phantom_IROPS_Presentation_Guide.md) - Demo script for freight
- [solution_presentation/images/architecture_diagram.jpg](solution_presentation/images/architecture_diagram.jpg) - Recreate with freight icons

### Key Story Changes

| Airline Story | Freight Story |
|---------------|---------------|
| CrowdStrike 2024 incident | Peak season surge / sorting facility outage |
| Ghost flights (pilot in wrong city) | Ghost routes (driver/truck in wrong facility) |
| 12-minute pilot callback bottleneck | Driver availability bottleneck |
| FAA fines for duty violations | DOT fines for HOS violations |
| Passenger loyalty (Diamond/Platinum) | Shipper priority (Enterprise/Premium) |

### Demo Flow Adaptation

1. **Crisis Scenario**: Show sorting hub outage during peak season
2. **Ghost Routes**: Vehicles not at expected distribution center
3. **Package Rerouting**: Priority packages get next available route
4. **Driver Recovery**: ML-ranked drivers based on HOS, proximity, route familiarity
5. **Compliance Bot**: DOT HOS and Teamsters contract validation
6. **Intelligence Agent**: "What is our on-time delivery rate today?"

---

## Estimated Effort

| Category | Files | Estimated Hours |
|----------|-------|-----------------|
| Branding/Terminology | 25+ files | 4-6 hrs |
| Data Models (SQL) | 9 SQL scripts | 8-12 hrs |
| Business Logic | Contract rules, ML notebooks | 6-8 hrs |
| React Components | 12 components + APIs | 12-16 hrs |
| Semantic Views | 2 SQL files | 4-6 hrs |
| Documentation | 4 files + diagram | 4-6 hrs |
| Testing & Validation | All | 8-10 hrs |
| **Total** | | **46-64 hrs** |

---

## Risks and Considerations

1. **Domain Expertise**: Freight logistics has different KPIs and priorities than airlines - may need UPS SME input
2. **Regulatory Differences**: DOT HOS is more complex than FAA Part 117 (sleeper berth rules, team driving, etc.)
3. **Data Generation**: Synthetic data needs realistic freight patterns (not hub-and-spoke like airlines)
4. **ML Model Retraining**: Models need real freight data for accurate predictions
5. **Cortex Search Content**: Historical incidents need freight-specific scenarios

---

## Quick Start Option

For a faster demo, consider a "light touch" approach:
1. Update branding only (Phantom -> UPS)
2. Rename key entities (Flight -> Route, Pilot -> Driver)
3. Keep data structure similar but relabel
4. Update documentation and UI labels

This reduces effort to approximately **16-20 hours** but results in less authentic freight demo.