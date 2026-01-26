# Phantom Airlines IROPS - Presentation Guide

## Demo Flow (30 minutes)

This guide provides a structured walkthrough for demonstrating the Phantom Airlines IROPS Platform to airline operations teams, IT leadership, and Snowflake stakeholders.

---

## 🎬 Pre-Demo Setup (5 minutes before)

1. **Deploy the platform** (if not already deployed):
   ```bash
   ./deploy.sh
   ```

2. **Start Streamlit dashboard** (deployed to Snowflake):
   ```bash
   cd streamlit && snow streamlit deploy --replace
   ```
   Or access directly in Snowsight: `PHANTOM_IROPS.ANALYTICS.IROPS_DASHBOARD`
   
   **Note**: In Streamlit in Snowflake (SiS), use the **sidebar** to navigate between pages.

3. **Open Snowsight** in a separate browser tab for SQL queries

4. **Verify data** is loaded:
   ```bash
   ./run.sh
   ```

---

## 📖 Story Arc

### The CrowdStrike Crisis Context (2 minutes)

> *"In July 2024, a routine software update crashed Windows systems worldwide. For airlines, this exposed critical vulnerabilities in crew management systems..."*

**Key talking points:**
- 4,000+ flights cancelled over 5 days
- Pilots couldn't be located - "ghost flights" everywhere
- Each pilot required a 12-minute phone call to reassign
- Recovery took 5+ days when it should have taken hours

**Transition:** *"Today, we'll show you how Phantom Airlines prevents this scenario with a modern, AI-powered IROPS platform built entirely on Snowflake."*

---

## 🖥️ Demo Sequence

### Act 1: The Golden Record (5 minutes)

**Purpose:** Show how we eliminate ghost flights

**Steps:**
1. Open the **Streamlit app** in Snowsight or via URL
2. Use the **sidebar** to navigate to different pages (Home, Operations Dashboard, Crew Recovery, etc.)
3. Point to the "Ghost Flights" metric on the home page
4. Click **Ghost Planes** in the sidebar
4. Show a specific ghost flight:
   - "This flight PH1234 shows Captain Smith assigned, departing from ATL"
   - "But look - the captain is actually in Chicago!"
   - "The aircraft is in Atlanta, but the pilot isn't"

**Key Message:** *"The Golden Record uses Dynamic Tables with 1-minute refresh to keep crew, aircraft, and flight data synchronized. No more ghost flights."*

**Show the SQL** (optional):
```sql
SELECT * FROM ANALYTICS.MART_GOLDEN_RECORD
WHERE is_ghost_flight = TRUE;
```

---

### Act 2: One-Click Recovery (7 minutes)

**Purpose:** Eliminate the 12-minute bottleneck

**Steps:**
1. Navigate to **Crew Recovery** page
2. Show flights needing crew (highlight urgency)
3. Select a flight that needs a captain
4. Walk through the ML-ranked candidates:
   - "Rank 1: Captain Johnson, 94.2 fit score"
   - "He's type-qualified, at the same base, has 45 hours remaining"
   - "The ML model considers proximity, qualifications, fatigue, and seniority"

5. **Key Demo Moment:** Click "Send Batch Notification"
   - "Instead of calling 20 pilots sequentially over 4 hours..."
   - "We notify all 20 simultaneously"
   - "First responder gets the trip"

**Key Message:** *"What used to take 4 hours now takes minutes. The 12-minute bottleneck is eliminated."*

**Show the function** (optional):
```sql
SELECT * FROM TABLE(ML_MODELS.GENERATE_BATCH_NOTIFICATION_LIST('FLT...', 'CAPTAIN', 10));
```

---

### Act 3: Contract Bot (5 minutes)

**Purpose:** Prevent compliance violations

**Steps:**
1. Navigate to **Contract Bot** page
2. Use the **Validate Assignment** tab:
   - Select a crew member
   - Select a flight
   - Click "Validate"
   - Show the detailed compliance checks

3. Use the **Ask Contract Bot** tab:
   - Ask: "Can a pilot who flew 95 hours this month take a 6-hour trip?"
   - Show the AI response citing FAA Part 117

**Key Message:** *"Contract Bot prevents violations before they happen. No more FAA fines or union grievances."*

**Show the function** (optional):
```sql
SELECT ML_MODELS.CONTRACT_BOT_QUERY('What is the maximum FDP for a 6am report?');
```

---

### Act 4: Intelligence Agent (5 minutes)

**Purpose:** Demonstrate conversational AI for operations

**Steps:**
1. Navigate to **Intelligence Agent** page via sidebar
2. Use the IROPS_ASSISTANT agent or Snowflake Intelligence UI
3. Ask several questions:
   - "What is our on-time performance today?"
   - "How many active disruptions do we have?"
   - "Who are my Diamond loyalty members impacted by delays today?"
   - "Find historical incidents similar to a winter storm"

4. Show how the agent:
   - Uses Cortex Analyst for quantitative queries (text-to-SQL)
   - Searches historical incidents via Cortex Search
   - Provides actionable recommendations

**Key Message:** *"Operations managers can get answers in natural language instead of writing SQL or navigating multiple systems."*

---

### Act 5: Disruption Cost Analysis (3 minutes)

**Purpose:** Show financial impact visibility

**Steps:**
1. Navigate to **Disruption Analysis** page
2. Show the **Cost Analysis** tab:
   - Today's total cost
   - Breakdown by disruption type
   - Cascading impact analysis

3. Show **Historical tab**:
   - Similar past events
   - Proven recovery strategies

**Key Message:** *"We can now quantify the cost of every disruption and apply proven recovery strategies from similar past events."*

---

### Act 6: Architecture Deep-Dive (3 minutes)

**Purpose:** Technical credibility

**Steps:**
1. Show the Snowsight Data panel:
   - 7 schemas (RAW, STAGING, INTERMEDIATE, ANALYTICS, ML_MODELS, SEMANTIC_MODELS, CORTEX_SEARCH)
   - 17 RAW tables (including BOOKINGS with elite loyalty coverage)
   - 10 Dynamic Tables
   - 1 Semantic View (IROPS_ANALYTICS)
   - 1 Cortex Agent (IROPS_ASSISTANT) with 2 Cortex Search services

2. Run a Dynamic Table status query:
   ```sql
   SELECT name, target_lag, scheduling_state 
   FROM INFORMATION_SCHEMA.DYNAMIC_TABLES;
   ```

3. Emphasize:
   - All in one Snowflake database
   - No ETL pipelines to maintain
   - Automatic refresh, no scheduling
   - Elastic compute for any scale

**Key Message:** *"This entire platform runs on Snowflake. No external tools, no data movement, no pipelines to maintain."*

---

## 💬 Expected Questions & Answers

### Q: How does this handle real ADS-B data?
**A:** The platform is designed to ingest ADS-B feeds via Snowpipe. The current demo uses synthetic data that mirrors real data structures. Production deployment would connect to flight tracking providers like FlightAware or ADS-B Exchange.

### Q: What about existing crew management systems like ARCOS?
**A:** This platform complements existing systems. We can ingest data from ARCOS, Jeppesen, or other crew systems via Snowpipe/Kafka. The Golden Record becomes the unified view while source systems continue to operate.

### Q: How long does it take to deploy?
**A:** The demo deploys in 15 minutes. A production deployment with real data integration typically takes 4-6 weeks, depending on source system complexity.

### Q: What's the cost?
**A:** Snowflake consumption-based pricing. For a major airline, expect $50K-$200K/month in compute costs. ROI is typically 10-25x based on IROPS cost savings.

### Q: Can this work with other airlines' data?
**A:** Yes, the data model is airline-agnostic. The platform can be customized for any carrier's specific PWA provisions and operational procedures.

---

## 🎯 Key Takeaways to Emphasize

1. **Single Platform**: All data, AI, and apps in Snowflake
2. **Real-Time**: 1-minute latency via Dynamic Tables
3. **AI-Native**: Cortex AI with zero data movement
4. **Zero Maintenance**: No ETL pipelines or scheduled jobs
5. **Proven ROI**: 25x return from IROPS cost savings

---

## 📊 Supporting Slides

If using slides alongside the demo:

1. **Problem Slide**: CrowdStrike incident impact
2. **Solution Slide**: Architecture diagram
3. **Golden Record Slide**: How ghost flights are detected
4. **One-Click Recovery Slide**: ML ranking diagram
5. **Contract Bot Slide**: Compliance validation flow
6. **ROI Slide**: Cost savings calculation

---

## 🔧 Troubleshooting

### Dashboard not loading?
```bash
cd streamlit && streamlit run app.py --server.port 8501
```

### Data looks empty?
```bash
./run.sh  # Validates data volumes
```

### Dynamic Tables not refreshing?
```sql
-- Check DT status
SELECT name, scheduling_state, last_refresh_time 
FROM INFORMATION_SCHEMA.DYNAMIC_TABLES;

-- Force refresh
ALTER DYNAMIC TABLE ANALYTICS.MART_GOLDEN_RECORD REFRESH;
```

### Agent not responding?
Verify Cortex is enabled for your account and the correct model (llama3.1-70b) is available.

---

## 📝 Post-Demo Follow-Up

1. Share the GitHub repository
2. Offer a customized demo with customer's actual data model
3. Propose a Proof of Concept timeline
4. Connect with Snowflake Solutions Architecture team

---

*Good luck with your demo!*
