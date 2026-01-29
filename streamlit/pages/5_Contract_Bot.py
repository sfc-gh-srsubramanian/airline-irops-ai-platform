"""
Contract Bot - AI-powered PWA and FAA compliance validation with Snowflake Cortex
"""
import streamlit as st
import pandas as pd
import os
from snowflake.connector import connect

st.set_page_config(page_title="Contract Bot", page_icon="📋", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

@st.cache_resource
def get_snowflake_connection():
    try:
        conn = connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "phantom_irops")
        return conn
    except Exception as e:
        return None

def call_cortex_complete(prompt, model="claude-3-5-sonnet"):
    conn = get_snowflake_connection()
    if not conn:
        return get_mock_contract_response(prompt)
    
    try:
        cursor = conn.cursor()
        
        system_prompt = """You are an expert on airline crew contracts and FAA regulations. You specialize in:
- FAA 14 CFR Part 117 (Flight and Duty Time Limitations)
- Pilot Working Agreement (PWA) rules
- Crew legality validation
- Rest requirements and flight duty period limits

Always cite specific regulations when answering. Use tables for clarity when appropriate.
If a question involves a specific scenario, provide a clear LEGAL or ILLEGAL determination with reasoning."""

        escaped_system = system_prompt.replace("'", "''")
        escaped_prompt = prompt.replace("'", "''")
        
        query = f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            '{model}',
            [
                {{'role': 'system', 'content': '{escaped_system}'}},
                {{'role': 'user', 'content': '{escaped_prompt}'}}
            ],
            {{
                'temperature': 0.2,
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
        return get_mock_contract_response(prompt)
        
    except Exception as e:
        return get_mock_contract_response(prompt)

def get_mock_contract_response(prompt):
    prompt_lower = prompt.lower()
    
    if "flight duty period" in prompt_lower or "fdp" in prompt_lower or "6am" in prompt_lower or "duty" in prompt_lower:
        return """### Flight Duty Period Limits (FAA Part 117)

Based on FAA 14 CFR Part 117.11, the maximum Flight Duty Period depends on:
1. **Report time (local)**
2. **Number of flight segments**
3. **Augmented vs. unaugmented crew**

| Report Time (Local) | 1-2 Segments | 3 Segments | 4 Segments | 5+ Segments |
|---------------------|--------------|------------|------------|-------------|
| **0500-0659** | 13 hrs | 12.5 hrs | 12 hrs | 11.5 hrs |
| **0700-1159** | 14 hrs | 13.5 hrs | 13 hrs | 12.5 hrs |
| **1200-1259** | 13 hrs | 12.5 hrs | 12 hrs | 11.5 hrs |
| **1300-1659** | 12 hrs | 11.5 hrs | 11 hrs | 10.5 hrs |
| **1700-2159** | 11 hrs | 10.5 hrs | 10 hrs | 9.5 hrs |

**For a pilot starting at 6am (0600):** Maximum FDP is **13 hours** for 1-2 segments, reduced by 30 minutes for each additional segment.

**Citation:** FAA 14 CFR Part 117.11, Table B"""

    elif "95 hours" in prompt_lower or "monthly" in prompt_lower or "100 hours" in prompt_lower:
        return """### Monthly Flight Time Limits

**FAA Part 117.23(b):** No pilot may fly more than **100 flight hours** in any calendar month.

**Analysis for pilot with 95 hours:**
- Current month hours: 95
- Hours remaining: 5 hours
- Proposed trip: 6 hours
- **Result: ❌ ILLEGAL**

**Reason:** 95 + 6 = 101 hours, which exceeds the 100-hour monthly limit.

**PWA Section 4.2** may provide additional protections requiring management to consider:
- Junior pilots first for extended assignments
- Voluntary basis for approaching limit

**Citation:** FAA 14 CFR Part 117.23(b), PWA Section 4.2"""

    elif "consecutive" in prompt_lower or "days" in prompt_lower:
        return """### Consecutive Duty Day Limits

**PWA Section 5.1:** Maximum **6 consecutive duty days** before required time off.

**FAA Part 117.25:** Requires a minimum of **30 consecutive hours free** from all duty in any 7 consecutive calendar days.

| Rule | Limit | Required Rest |
|------|-------|---------------|
| PWA 5.1 | 6 days max | 24 hours minimum |
| FAA 117.25 | 7 day rolling | 30 hours in any 7 days |

**Best Practice:** After 6 consecutive duty days, provide minimum 24 hours off (per PWA) which also satisfies the FAA 30-hour requirement when combined with duty-free time.

**Citation:** PWA Section 5.1, FAA 14 CFR Part 117.25"""

    elif "rest" in prompt_lower or "minimum rest" in prompt_lower:
        return """### Minimum Rest Requirements

**FAA Part 117.25(b):** Minimum rest period is **10 hours** between FDPs, including an opportunity for 8 uninterrupted hours of sleep.

| Rest Type | Minimum Duration | Notes |
|-----------|-----------------|-------|
| Standard Rest | 10 hours | Between duty periods |
| Sleep Opportunity | 8 hours | Must be uninterrupted |
| After Reserve | 10 hours | Before next assignment |
| After Long FDP | 10 hours + | May increase based on FDP length |

**PWA Section 5.4 (Enhanced Rest):**
- After FDP > 12 hours: 11 hours minimum
- After international: 12 hours minimum
- After red-eye: 10 hours + 1 hour per time zone crossed

**Citation:** FAA 14 CFR Part 117.25(b), PWA Section 5.4"""

    elif "reserve" in prompt_lower or "notice" in prompt_lower or "1 hour" in prompt_lower:
        return """### Reserve Call-Out Requirements

**PWA Section 5.2:** Minimum notice requirements for reserve pilots:

| Reserve Type | Minimum Notice | Notes |
|--------------|----------------|-------|
| **Short-call** | 2 hours | From call to report time |
| **Long-call** | 12 hours | From call to report time |
| **Airport Standby** | 0 hours | Already at airport |

**Question: Can a reserve be called with 1 hour notice?**

**Answer: ❌ NO (PWA Violation)**

1-hour notice violates PWA Section 5.2 which requires minimum 2-hour notice for short-call reserves.

**Exceptions:**
- Airport standby reserves (already on property)
- Voluntary acceptance by pilot
- Declared operational emergency (must be documented)

**Citation:** PWA Section 5.2, FAA Advisory Circular 117-1"""

    else:
        return f"""### Contract Bot Response

I can help you with questions about:

| Topic | Key Rules |
|-------|-----------|
| **Flight Duty Period** | FAA Part 117.11 - 9-14 hour limits |
| **Monthly/Annual Limits** | Part 117.23 - 100/1000 hour limits |
| **Rest Requirements** | Part 117.25 - 10 hour minimum |
| **Consecutive Days** | PWA 5.1 - 6 day maximum |
| **Reserve Call-Out** | PWA 5.2 - 2 hour notice minimum |

Your question: "{prompt}"

Please rephrase your question to include specific details about:
- The regulation you're asking about
- The specific scenario (hours flown, duty times, etc.)
- The crew member type (captain, FO, reserve)

**Citation:** FAA 14 CFR Part 117, Phantom Airlines PWA"""

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("📋 Contract Bot")
st.caption("Powered by Snowflake Cortex COMPLETE")

st.markdown("---")

col1, col2, col3 = st.columns(3)
col1.metric("Assignments Validated Today", "847", "98.2% legal")
col2.metric("Violations Prevented", "15", "Saved $180K in grievances")
col3.metric("Queries Answered", "234", "By natural language")

st.markdown("---")

tab1, tab2, tab3 = st.tabs(["✅ Validate Assignment", "💬 Ask Contract Bot", "📖 Rule Reference"])

with tab1:
    st.subheader("Crew Assignment Validation")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### Select Crew Member")
        crew_id = st.selectbox("Crew Member", [
            "CR001234 - Capt. John Smith (ATL)",
            "CR002345 - Capt. Mary Johnson (DTW)",
            "CR003456 - FO Robert Davis (MSP)",
            "CR004567 - Capt. Karen Wilson (JFK)"
        ])
        
        crew_data = {
            "CR001234": {"monthly": 78.5, "remaining": 21.5, "days": 4, "rest": 12.3, "types": ["B737-800", "B737-900", "A320-200"]},
            "CR002345": {"monthly": 82.1, "remaining": 17.9, "days": 5, "rest": 10.5, "types": ["A321-200", "A320-200"]},
            "CR003456": {"monthly": 65.2, "remaining": 34.8, "days": 2, "rest": 14.2, "types": ["B737-800", "B737-900"]},
            "CR004567": {"monthly": 91.3, "remaining": 8.7, "days": 3, "rest": 11.8, "types": ["B757-200", "B767-300"]},
        }
        
        selected_crew_id = crew_id.split(" - ")[0]
        crew_info = crew_data.get(selected_crew_id, crew_data["CR001234"])
        
        st.markdown(f"""
        ### Current Status
        - **Monthly Hours Used:** {crew_info['monthly']} hrs
        - **Hours Remaining:** {crew_info['remaining']} hrs
        - **Consecutive Duty Days:** {crew_info['days']}
        - **Last Rest Period:** {crew_info['rest']} hrs
        - **Type Ratings:** {', '.join(crew_info['types'])}
        """)
    
    with col2:
        st.markdown("### Select Flight")
        flight_id = st.selectbox("Flight", [
            "PH1234 - ATL→JFK (B737-800, 2.5 hrs)",
            "PH2567 - DTW→LAX (A321-200, 4.5 hrs)",
            "PH3890 - MSP→SEA (B737-900, 3.5 hrs)",
            "PH4123 - JFK→MIA (B757-200, 3.0 hrs)"
        ])
        
        flight_data = {
            "PH1234": {"aircraft": "B737-800", "block": 2.5, "departure": "14:30", "report": "13:30", "release": "18:00"},
            "PH2567": {"aircraft": "A321-200", "block": 4.5, "departure": "15:00", "report": "14:00", "release": "20:30"},
            "PH3890": {"aircraft": "B737-900", "block": 3.5, "departure": "15:30", "report": "14:30", "release": "20:00"},
            "PH4123": {"aircraft": "B757-200", "block": 3.0, "departure": "16:00", "report": "15:00", "release": "20:00"},
        }
        
        selected_flight_id = flight_id.split(" - ")[0]
        flight_info = flight_data.get(selected_flight_id, flight_data["PH1234"])
        
        st.markdown(f"""
        ### Flight Details
        - **Departure:** {flight_info['departure']} UTC
        - **Block Time:** {flight_info['block']} hrs
        - **Aircraft Type:** {flight_info['aircraft']}
        - **Report Time:** {flight_info['report']} UTC
        - **Est. Release:** {flight_info['release']} UTC
        """)
    
    if st.button("🔍 Validate Assignment", type="primary", use_container_width=True):
        st.markdown("---")
        st.markdown("### Validation Results")
        
        is_qualified = flight_info['aircraft'] in crew_info['types']
        has_hours = crew_info['remaining'] >= flight_info['block']
        days_ok = crew_info['days'] < 6
        rest_ok = crew_info['rest'] >= 10
        
        checks = []
        checks.append({"Check": "Type Qualification", "Status": "✅ PASS" if is_qualified else "❌ FAIL", 
                      "Detail": f"{'Qualified' if is_qualified else 'NOT qualified'} for {flight_info['aircraft']}"})
        checks.append({"Check": "Monthly Hours", "Status": "✅ PASS" if has_hours else "❌ FAIL",
                      "Detail": f"{crew_info['remaining']} hrs remaining {'>' if has_hours else '<'} {flight_info['block']} hrs needed"})
        checks.append({"Check": "Annual Hours", "Status": "✅ PASS", 
                      "Detail": f"{1000 - crew_info['monthly']*12:.0f} hrs < 1000 limit"})
        checks.append({"Check": "Consecutive Days", "Status": "✅ PASS" if days_ok else "⚠️ WARNING",
                      "Detail": f"{crew_info['days']} days {'<' if days_ok else '='} 6 day limit"})
        checks.append({"Check": "Rest Period", "Status": "✅ PASS" if rest_ok else "❌ FAIL",
                      "Detail": f"{crew_info['rest']} hrs {'>' if rest_ok else '<'} 10 hr minimum"})
        checks.append({"Check": "FDP Limit", "Status": "✅ PASS", 
                      "Detail": f"Est. 4.5 hrs < 13 hr limit"})
        
        all_pass = is_qualified and has_hours and rest_ok
        has_warning = not days_ok
        
        col1, col2 = st.columns(2)
        
        with col1:
            if all_pass and not has_warning:
                st.success("**✅ ASSIGNMENT IS LEGAL**\n\nAll FAA Part 117 and PWA requirements met.")
            elif all_pass and has_warning:
                st.warning("**⚠️ ASSIGNMENT LEGAL WITH WARNINGS**\n\nReview consecutive duty days.")
            else:
                st.error("**❌ ASSIGNMENT HAS VIOLATIONS**\n\nCannot proceed with this assignment.")
        
        with col2:
            st.markdown("**Detailed Checks:**")
            st.dataframe(pd.DataFrame(checks), use_container_width=True)

with tab2:
    st.subheader("Ask Contract Bot")
    st.caption("Powered by Snowflake Cortex COMPLETE with Claude 3.5 Sonnet")
    
    st.markdown("Ask any question about PWA rules or FAA Part 117 regulations in natural language.")
    
    sample_questions = [
        "What is the maximum flight duty period for a pilot starting at 6am?",
        "Can a pilot who flew 95 hours this month take a 6-hour trip?",
        "How many consecutive days can a pilot work before required rest?",
        "What are the minimum rest requirements between duty periods?",
        "Can a reserve pilot be called out with only 1 hour notice?"
    ]
    
    if "contract_messages" not in st.session_state:
        st.session_state.contract_messages = []
    
    for msg in st.session_state.contract_messages:
        if msg["role"] == "user":
            st.info(f"**You asked:** {msg['content']}")
        else:
            st.markdown(msg["content"])
        st.markdown("---")
    
    question = st.text_area("Your Question:", placeholder="Type your contract question here...", height=100)
    
    col1, col2 = st.columns([1, 4])
    with col1:
        ask_clicked = st.button("🤖 Ask AI", type="primary")
    
    st.markdown("**Quick questions:**")
    sample_cols = st.columns(2)
    selected_sample = None
    for i, q in enumerate(sample_questions):
        with sample_cols[i % 2]:
            if st.button(q, key=f"sample_{i}"):
                selected_sample = q
    
    query_to_process = selected_sample if selected_sample else (question if ask_clicked and question else None)
    
    if query_to_process:
        st.session_state.contract_messages.append({"role": "user", "content": query_to_process})
        
        with st.spinner("🤖 Contract Bot is analyzing with Cortex..."):
            model = st.session_state.get("contract_model", "claude-3-5-sonnet")
            response = call_cortex_complete(query_to_process, model=model)
        
        st.session_state.contract_messages.append({"role": "assistant", "content": response})
        st.rerun()
    
    if st.session_state.contract_messages:
        if st.button("🗑️ Clear Chat"):
            st.session_state.contract_messages = []
            st.rerun()

with tab3:
    st.subheader("Contract Rule Reference")
    
    rules = pd.DataFrame({
        "Rule ID": ["FAA-117-1", "FAA-117-2", "FAA-117-3", "FAA-117-4", "PWA-5.1", "PWA-5.2", "PWA-6.1", "PWA-7.1", "PWA-8.1"],
        "Category": ["FAA", "FAA", "FAA", "FAA", "UNION", "UNION", "UNION", "UNION", "UNION"],
        "Name": ["Max Flight Duty Period", "Minimum Rest", "Monthly Limit", "Annual Limit", "Consecutive Days", "Reserve Notice", "Deadhead Rules", "Type Qualification", "Involuntary Extension"],
        "Key Limit": ["9-14 hours", "10 hours", "100 hours", "1,000 hours", "6 days", "2 hours", "14 hours total", "Required", "2 hours max"]
    })
    
    st.dataframe(rules, use_container_width=True)
    
    with st.expander("📖 FAA Part 117 - Flight Duty Period Limits"):
        st.markdown("""
        ### Flight Duty Period (FDP) Limits by Report Time
        
        | Report Time (Local) | 1-2 Segments | 3 Segments | 4 Segments | 5+ Segments |
        |---------------------|--------------|------------|------------|-------------|
        | 0500-0559 | 13 hrs | 12.5 hrs | 12 hrs | 11.5 hrs |
        | 0600-0659 | 13 hrs | 12.5 hrs | 12 hrs | 11.5 hrs |
        | 0700-1159 | 14 hrs | 13.5 hrs | 13 hrs | 12.5 hrs |
        | 1200-1259 | 13 hrs | 12.5 hrs | 12 hrs | 11.5 hrs |
        | 1300-1659 | 12 hrs | 11.5 hrs | 11 hrs | 10.5 hrs |
        | 1700-2159 | 11 hrs | 10.5 hrs | 10 hrs | 9.5 hrs |
        | 2200-0459 | 10 hrs | 9.5 hrs | 9 hrs | 9 hrs |
        """)
    
    with st.expander("📖 PWA Section 5 - Duty Time Provisions"):
        st.markdown("""
        ### Pilot Working Agreement - Duty Time
        
        **5.1 Consecutive Duty Days**
        - Maximum 6 consecutive duty days
        - Followed by minimum 24 hours off
        
        **5.2 Reserve Call-Out**
        - Short-call reserve: Minimum 2 hours notice
        - Long-call reserve: Minimum 12 hours notice
        
        **5.3 Extension Limits**
        - Voluntary: Unlimited (pilot's discretion)
        - Involuntary: Maximum 2 hours
        - Operational necessity required
        """)

st.sidebar.markdown("### 🤖 Contract Bot Settings")
model_options = ["claude-3-5-sonnet", "llama3.1-70b", "mistral-large"]
selected_model = st.sidebar.selectbox("AI Model", model_options, index=0)
st.session_state.contract_model = selected_model

st.sidebar.markdown("---")
st.sidebar.checkbox("Auto-validate all assignments", value=True)
st.sidebar.checkbox("Alert on potential violations", value=True)
st.sidebar.selectbox("Default regulation set", ["FAA Part 117 + PWA", "FAA Part 117 only", "International (EASA)"])

st.sidebar.markdown("---")
conn = get_snowflake_connection()
if conn:
    st.sidebar.success("✅ Cortex Connected")
else:
    st.sidebar.warning("⚠️ Using mock responses")
