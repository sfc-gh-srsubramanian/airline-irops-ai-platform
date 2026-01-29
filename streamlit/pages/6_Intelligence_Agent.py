"""
Intelligence Agent - Conversational AI powered by Snowflake Cortex COMPLETE
"""
import streamlit as st
import os
from snowflake.connector import connect

st.set_page_config(page_title="Intelligence Agent", page_icon="🤖", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

@st.cache_resource
def get_snowflake_connection():
    try:
        conn = connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "phantom_irops")
        return conn
    except Exception as e:
        st.warning(f"Could not connect to Snowflake: {e}")
        return None

def call_cortex_complete(prompt, model="claude-3-5-sonnet", context=""):
    conn = get_snowflake_connection()
    if not conn:
        return get_mock_response(prompt)
    
    try:
        cursor = conn.cursor()
        
        system_prompt = """You are an AI assistant for Phantom Airlines Operations Control Center. 
You help with irregular operations (IROPS) management including:
- Flight status and on-time performance analysis
- Disruption tracking and cost estimation
- Crew recovery and ghost flight detection
- Contract compliance (FAA Part 117, PWA)
- Historical pattern analysis

Always provide specific, actionable insights based on the data. Use tables and structured formatting when appropriate."""

        full_prompt = f"{context}\n\nUser question: {prompt}" if context else prompt
        
        escaped_system = system_prompt.replace("'", "''")
        escaped_prompt = full_prompt.replace("'", "''")
        
        query = f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            '{model}',
            [
                {{'role': 'system', 'content': '{escaped_system}'}},
                {{'role': 'user', 'content': '{escaped_prompt}'}}
            ],
            {{
                'temperature': 0.3,
                'max_tokens': 1024
            }}
        ) as response
        """
        
        cursor.execute(query)
        result = cursor.fetchone()
        
        if result and result[0]:
            import json
            response_data = json.loads(result[0]) if isinstance(result[0], str) else result[0]
            if isinstance(response_data, dict) and 'choices' in response_data:
                return response_data['choices'][0]['messages']
            elif isinstance(response_data, dict) and 'message' in response_data:
                return response_data['message']
            return str(response_data)
        return get_mock_response(prompt)
        
    except Exception as e:
        st.warning(f"Cortex COMPLETE call failed: {e}. Using fallback response.")
        return get_mock_response(prompt)

def get_live_context():
    conn = get_snowflake_connection()
    if not conn:
        return ""
    
    try:
        cursor = conn.cursor()
        
        cursor.execute("""
        SELECT 
            COUNT(*) as total_flights,
            COUNT(CASE WHEN STATUS NOT IN ('DELAYED', 'CANCELLED') THEN 1 END) as on_time,
            COUNT(CASE WHEN STATUS = 'DELAYED' THEN 1 END) as delayed,
            COUNT(CASE WHEN STATUS = 'CANCELLED' THEN 1 END) as cancelled,
            ROUND(AVG(CASE WHEN DEPARTURE_DELAY_MINUTES > 0 THEN DEPARTURE_DELAY_MINUTES END), 0) as avg_delay
        FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
        WHERE FLIGHT_DATE = CURRENT_DATE()
        """)
        flight_data = cursor.fetchone()
        
        cursor.execute("""
        SELECT COUNT(*) as ghost_count
        FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
        WHERE FLIGHT_DATE = CURRENT_DATE() AND IS_GHOST_FLIGHT = TRUE
        """)
        ghost_data = cursor.fetchone()
        
        cursor.execute("""
        SELECT COUNT(*) as crew_needed
        FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
        WHERE FLIGHT_DATE = CURRENT_DATE() AND (CAPTAIN_NEEDED = TRUE OR FO_NEEDED = TRUE)
        """)
        crew_data = cursor.fetchone()
        
        context = f"""
CURRENT OPERATIONS DATA (Live from Snowflake):
- Total Flights Today: {flight_data[0] if flight_data else 'N/A'}
- On-Time Flights: {flight_data[1] if flight_data else 'N/A'}
- Delayed Flights: {flight_data[2] if flight_data else 'N/A'}
- Cancelled Flights: {flight_data[3] if flight_data else 'N/A'}
- Average Delay: {flight_data[4] if flight_data else 'N/A'} minutes
- Ghost Flights: {ghost_data[0] if ghost_data else 'N/A'}
- Flights Needing Crew: {crew_data[0] if crew_data else 'N/A'}
"""
        return context
    except:
        return ""

def get_mock_response(prompt):
    if "on-time" in prompt.lower() or "otp" in prompt.lower():
        return """### Today's On-Time Performance

| Metric | Value |
|--------|-------|
| **OTP** | 82.4% |
| **Total Flights** | 1,423 |
| **On-Time Departures** | 1,172 |
| **Delayed** | 156 (11.0%) |
| **Cancelled** | 34 (2.4%) |

**Trend:** OTP is down 3.2% from yesterday due to weather in Atlanta.

**Key Factors:**
- ATL thunderstorms: -2.1% impact
- JFK ATC delays: -0.8% impact
- MSP snow: -0.3% impact"""

    elif "disruption" in prompt.lower():
        return """### Active Disruptions Summary

Currently tracking **24 active disruptions**:

| Severity | Count | Est. Cost |
|----------|-------|-----------|
| 🔴 Critical | 3 | $1.27M |
| 🟠 Severe | 7 | $580K |
| 🟡 Moderate | 9 | $320K |
| 🟢 Minor | 5 | $85K |

**Top 3 by Impact:**
1. **ATL Thunderstorms** - 45 flights, 4,500 pax, $850K
2. **ATL Tornado Warning** - 23 flights, 2,100 pax, $420K
3. **JFK ATC Delays** - 12 flights, 1,200 pax, $180K"""

    elif "ghost" in prompt.lower():
        return """### Ghost Flights Detection

Currently detecting **5 ghost flights** where crew and aircraft locations don't match:

| Flight | Issue | Captain | Aircraft Location | Captain Location |
|--------|-------|---------|------------------|------------------|
| PH1234 | 🔴 Location mismatch | J. Smith | ATL | ORD |
| PH3456 | 🔴 Location mismatch | M. Johnson | DTW | ATL |
| PH5678 | 🟡 Terminal mismatch | R. Davis | MSP T1 | MSP T2 |
| PH7890 | 🔴 Location mismatch | K. Wilson | JFK | BOS |
| PH2345 | 🔴 Location mismatch | A. Brown | LAX | SFO |

**Estimated Impact:** $125,000 if unresolved

**Recommended Actions:**
1. Reposition captains via deadhead flights
2. Find replacement crew from local base
3. Consider aircraft swaps where feasible"""

    elif "captain" in prompt.lower() or "crew" in prompt.lower():
        return """### Crew Availability Summary

**Network-wide:**
- Available Captains: **156**
- Available First Officers: **234**
- Crew Near Monthly Limit: **23**

**By Hub:**
| Hub | Captains | First Officers | Status |
|-----|----------|----------------|--------|
| ATL | 45 | 62 | 🟢 Normal |
| DTW | 23 | 31 | 🟢 Normal |
| MSP | 18 | 28 | 🟡 Watch |
| JFK | 28 | 35 | 🟢 Normal |
| LAX | 22 | 38 | 🟢 Normal |

**Alert:** 8 flights currently need captains, 4 need first officers.

**One-Click Recovery:** Batch notifications can reach top 10 candidates simultaneously, reducing fill time from 12 minutes to under 2 minutes."""

    elif "cost" in prompt.lower():
        return """### Today's Disruption Costs

**Total Estimated Cost: $2.32M**

| Category | Amount | % of Total |
|----------|--------|------------|
| Direct Disruption | $1.45M | 62% |
| Passenger Compensation | $520K | 22% |
| Crew Repositioning | $180K | 8% |
| Cascading Impact | $170K | 7% |

**By Disruption Type:**
| Type | Cost | Flights Affected |
|------|------|------------------|
| Weather | $1.27M | 68 |
| Mechanical | $450K | 12 |
| Crew | $320K | 15 |
| ATC | $280K | 24 |

**Recovery Opportunity:** Fast crew recovery could save an estimated $95K in further delays."""

    elif "contract" in prompt.lower() or "pwa" in prompt.lower() or "faa" in prompt.lower():
        return """### Contract Compliance Summary

**Today's Validation Results:**
- Assignments Validated: **847**
- Legal Assignments: **832** (98.2%)
- Violations Prevented: **15**
- Estimated Savings: **$180K** in grievances

**Key FAA Part 117 Limits:**
| Rule | Limit | Current Compliance |
|------|-------|-------------------|
| Flight Duty Period | 9-14 hrs | ✅ 100% |
| Minimum Rest | 10 hrs | ✅ 100% |
| Monthly Hours | 100 hrs | ⚠️ 23 near limit |
| Consecutive Days | 6 days | ✅ 100% |

**PWA Section 5 Alerts:**
- 3 pilots at 5 consecutive duty days
- 8 reserve pilots approaching short-call limits"""

    else:
        return f"""I understand you're asking about: "{prompt}"

Based on the current state of the network, here's what I can tell you:

| Metric | Current Value |
|--------|---------------|
| **Network Health** | 87.3% |
| **Active Disruptions** | 24 |
| **Ghost Flights** | 5 |
| **Flights Needing Crew** | 12 |
| **Today's OTP** | 82.4% |

I can help you with:
- **Flight status and OTP analysis** - "What is our on-time performance?"
- **Disruption tracking** - "How many active disruptions do we have?"
- **Crew management** - "How many captains are available at ATL?"
- **Ghost flight detection** - "Are there any ghost flights right now?"
- **Cost estimation** - "What is the estimated cost of disruptions today?"
- **Contract compliance** - "Can this pilot legally fly this trip?"

What would you like to know more about?"""

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("🤖 Intelligence Agent")
st.caption("Powered by Snowflake Cortex COMPLETE with Claude 3.5 Sonnet")

st.markdown("---")

if "chat_history" not in st.session_state:
    st.session_state.chat_history = []

st.markdown("""
**Welcome!** I'm your AI operations assistant powered by **Snowflake Cortex**. I can help you with:
- 📊 **Flight Operations:** Current status, delays, cancellations, OTP trends
- ⚠️ **Disruption Analysis:** Active events, costs, recovery strategies
- 👨‍✈️ **Crew Management:** Availability, duty times, assignments
- 👻 **Ghost Flights:** Detection and resolution recommendations
- 📋 **Contract Compliance:** FAA Part 117, PWA rule validation
- 📜 **Historical Patterns:** Find similar past incidents
""")

st.markdown("---")

sample_queries = [
    "What is our on-time performance today?",
    "How many active disruptions do we have?",
    "Are there any ghost flights right now?",
    "How many captains are available?",
    "What is the estimated cost of disruptions today?",
    "What are the FAA Part 117 duty limits?"
]

st.markdown("### 💬 Chat with the Agent")

for message in st.session_state.chat_history:
    if message["role"] == "user":
        st.markdown(f"""
        <div style="background: {SNOWFLAKE_BLUE}; color: white; padding: 1rem; border-radius: 10px; margin: 0.5rem 0; margin-left: 20%;">
            <strong>You:</strong> {message["content"]}
        </div>
        """, unsafe_allow_html=True)
    else:
        st.markdown(f"""
        <div style="background: #f0f2f6; padding: 1rem; border-radius: 10px; margin: 0.5rem 0; margin-right: 20%;">
            <strong>🤖 Agent:</strong>
        </div>
        """, unsafe_allow_html=True)
        st.markdown(message["content"])

col1, col2 = st.columns([4, 1])
with col1:
    user_query = st.text_input("Your question:", placeholder="Ask me anything about operations...", key="user_input")
with col2:
    ask_button = st.button("🔍 Ask", type="primary", use_container_width=True)

st.markdown("**Quick queries:**")
query_cols = st.columns(3)
selected_sample = None
for i, query in enumerate(sample_queries):
    with query_cols[i % 3]:
        if st.button(query, key=f"sample_{i}", use_container_width=True):
            selected_sample = query

query_to_process = selected_sample if selected_sample else (user_query if ask_button and user_query else None)

if query_to_process:
    st.session_state.chat_history.append({"role": "user", "content": query_to_process})
    
    with st.spinner("🤖 Thinking with Snowflake Cortex..."):
        context = get_live_context()
        
        model = st.session_state.get("selected_model", "claude-3-5-sonnet")
        response = call_cortex_complete(query_to_process, model=model, context=context)
    
    st.session_state.chat_history.append({"role": "assistant", "content": response})
    
    st.rerun()

if st.session_state.chat_history:
    if st.button("🗑️ Clear Chat History"):
        st.session_state.chat_history = []
        st.rerun()

st.sidebar.markdown("### 🧠 Agent Settings")
model_options = ["claude-3-5-sonnet", "llama3.1-70b", "llama3.1-8b", "mistral-large"]
selected_model = st.sidebar.selectbox("Model", model_options, index=0)
st.session_state.selected_model = selected_model

st.sidebar.markdown("---")
st.sidebar.markdown("### 📊 Live Data Status")
conn = get_snowflake_connection()
if conn:
    st.sidebar.success("✅ Connected to Snowflake")
    st.sidebar.caption("Using live operations data")
else:
    st.sidebar.warning("⚠️ Using mock data")
    st.sidebar.caption("Snowflake connection unavailable")

st.sidebar.markdown("---")
st.sidebar.checkbox("Include live context", value=True, key="include_context")
st.sidebar.checkbox("Show data sources", value=False, key="show_sources")
