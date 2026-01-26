"""
Intelligence Agent - Conversational AI for operations queries
"""
import streamlit as st
import time

st.set_page_config(page_title="Intelligence Agent", page_icon="🤖", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("🤖 Intelligence Agent")

st.markdown("---")

if "messages" not in st.session_state:
    st.session_state.messages = []

if "current_response" not in st.session_state:
    st.session_state.current_response = None

def get_response(prompt):
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

Currently detecting **5 ghost flights**:

| Flight | Issue | Captain | Aircraft Location | Captain Location |
|--------|-------|---------|------------------|------------------|
| PH1234 | 🔴 Location mismatch | J. Smith | ATL | ORD |
| PH3456 | 🔴 Location mismatch | M. Johnson | DTW | ATL |
| PH5678 | 🟡 Terminal mismatch | R. Davis | MSP T1 | MSP T2 |
| PH7890 | 🔴 Location mismatch | K. Wilson | JFK | BOS |
| PH2345 | 🔴 Location mismatch | A. Brown | LAX | SFO |

**Estimated Impact:** $125,000 if unresolved"""

    elif "captain" in prompt.lower() or "crew" in prompt.lower():
        return """### Crew Availability Summary

**Network-wide:**
- Available Captains: **156**
- Available First Officers: **234**
- Crew Near Monthly Limit: **23**

**By Hub:**
| Hub | Captains | First Officers |
|-----|----------|----------------|
| ATL | 45 | 62 |
| DTW | 23 | 31 |
| MSP | 18 | 28 |
| JFK | 28 | 35 |
| LAX | 22 | 38 |

**Alert:** 8 flights currently need captains, 4 need first officers."""

    elif "cost" in prompt.lower():
        return """### Today's Disruption Costs

**Total Estimated Cost: $2.32M**

| Category | Amount |
|----------|--------|
| Direct Disruption | $1.45M |
| Passenger Compensation | $520K |
| Crew Repositioning | $180K |
| Cascading Impact | $170K |

**By Disruption Type:**
| Type | Cost | % of Total |
|------|------|------------|
| Weather | $1.27M | 55% |
| Mechanical | $450K | 19% |
| Crew | $320K | 14% |
| ATC | $280K | 12% |"""

    elif "similar" in prompt.lower() or "historical" in prompt.lower():
        return """### Historical Incident Analysis

Based on current disruptions, I found **3 similar historical events**:

**1. Winter Storm Elliott (Dec 2022)** - 87% similarity
- Duration: 96 hours | Flights Cancelled: 2,500 | Cost: $45M

**2. CrowdStrike Outage (Jul 2024)** - 72% similarity
- Duration: 120 hours | Flights Cancelled: 4,000 | Cost: $85M

**3. B737 Fleet AD (Aug 2023)** - 65% similarity
- Duration: 72 hours | Flights Cancelled: 1,200 | Cost: $25M

**Recommended Strategy:** Apply Winter Storm Elliott playbook"""

    else:
        return f"""I understand you're asking about: "{prompt}"

Based on the current state of the network:
- **Network Health:** 87.3%
- **Active Disruptions:** 24
- **Ghost Flights:** 5
- **Flights Needing Crew:** 12

I can help with flight status, disruptions, crew availability, historical patterns, and cost estimation."""

st.markdown("""
**Welcome!** I can help you with:
- **Flight Operations:** Current status, delays, cancellations
- **Disruption Analysis:** Active events, costs, recovery strategies
- **Crew Management:** Availability, duty times, assignments
- **Historical Patterns:** Find similar past incidents
""")

st.markdown("---")

sample_queries = [
    "What is our on-time performance today?",
    "How many active disruptions do we have?",
    "Are there any ghost flights right now?",
    "How many captains are available at ATL?",
    "What is the estimated cost of disruptions today?",
    "Find historical incidents similar to a winter storm"
]

st.markdown("### 💬 Ask a Question")

col1, col2 = st.columns([3, 1])
with col1:
    user_query = st.text_input("Your question:", placeholder="Ask me anything about operations...")
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
    st.markdown("---")
    st.markdown(f"**You asked:** {query_to_process}")
    
    with st.spinner("🤖 Analyzing..."):
        time.sleep(1)
    
    response = get_response(query_to_process)
    st.markdown(response)

st.sidebar.markdown("### Agent Settings")
st.sidebar.selectbox("Model", ["llama3.1-70b", "llama3.1-8b", "mistral-large"])
st.sidebar.slider("Temperature", 0.0, 1.0, 0.3)
st.sidebar.checkbox("Include historical search", value=True)
st.sidebar.checkbox("Show data sources", value=False)
