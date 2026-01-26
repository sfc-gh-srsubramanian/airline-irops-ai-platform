"""
Contract Bot - AI-powered PWA and FAA compliance validation
"""
import streamlit as st
import pandas as pd

st.set_page_config(page_title="Contract Bot", page_icon="📋", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("📋 Contract Bot")

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
        
        st.markdown("### Current Status")
        st.markdown("""
        - **Monthly Hours Used:** 78.5 hrs
        - **Hours Remaining:** 21.5 hrs
        - **Consecutive Duty Days:** 4
        - **Last Rest Period:** 12.3 hrs
        - **Type Ratings:** B737-800, B737-900, A320-200
        """)
    
    with col2:
        st.markdown("### Select Flight")
        flight_id = st.selectbox("Flight", [
            "PH1234 - ATL→JFK (B737-800, 2.5 hrs)",
            "PH2567 - DTW→LAX (A321-200, 4.5 hrs)",
            "PH3890 - MSP→SEA (B737-900, 3.5 hrs)",
            "PH4123 - JFK→MIA (B757-200, 3.0 hrs)"
        ])
        
        st.markdown("### Flight Details")
        st.markdown("""
        - **Departure:** 14:30 UTC
        - **Block Time:** 2.5 hrs
        - **Aircraft Type:** B737-800
        - **Report Time:** 13:30 UTC
        - **Est. Release:** 18:00 UTC
        """)
    
    if st.button("🔍 Validate Assignment", type="primary", use_container_width=True):
        st.markdown("---")
        st.markdown("### ✅ Validation Results")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.success("**ASSIGNMENT IS LEGAL**")
            st.markdown("""
            All FAA Part 117 and PWA requirements met.
            """)
        
        with col2:
            st.markdown("**Detailed Checks:**")
            checks = pd.DataFrame({
                "Check": ["Type Qualification", "Monthly Hours", "Annual Hours", "Consecutive Days", "Rest Period", "FDP Limit"],
                "Status": ["✅ PASS", "✅ PASS", "✅ PASS", "✅ PASS", "✅ PASS", "✅ PASS"],
                "Detail": ["Qualified for B737-800", "21.5 hrs remaining > 2.5 hrs needed", "921.5 hrs < 1000 limit", "4 days < 6 day limit", "12.3 hrs > 10 hr minimum", "Est. 4.5 hrs < 13 hr limit"]
            })
            st.dataframe(checks, use_container_width=True)

with tab2:
    st.subheader("Ask Contract Bot")
    
    st.markdown("Ask any question about PWA rules or FAA Part 117 regulations in natural language.")
    
    sample_questions = [
        "What is the maximum flight duty period for a pilot starting at 6am?",
        "Can a pilot who flew 95 hours this month take a 6-hour trip?",
        "How many consecutive days can a pilot work before required rest?",
        "What are the minimum rest requirements between duty periods?",
        "Can a reserve pilot be called out with only 1 hour notice?"
    ]
    
    question = st.text_area("Your Question:", placeholder="Type your contract question here...", height=100)
    
    col1, col2 = st.columns([1, 4])
    with col1:
        ask_clicked = st.button("Ask", type="primary")
    with col2:
        st.markdown("**Sample Questions:**")
        for q in sample_questions:
            if st.button(q, key=q):
                st.session_state.question = q
    
    if ask_clicked and question:
        with st.spinner("Contract Bot is thinking..."):
            import time
            time.sleep(2)
        
        st.markdown("---")
        st.markdown("### 📋 Contract Bot Response")
        
        response_container = st.container()
        with response_container:
            st.info(f"**Your question:** {question}")
            st.markdown("""
Based on FAA Part 117 and the Phantom Airlines PWA:

The maximum Flight Duty Period (FDP) for a pilot depends on several factors:

| Factor | Details |
|--------|---------|
| **Report Time** | FDP limits vary by start time per FAA Part 117 |
| **0500-0659 local** | 13 hours maximum |
| **0700-1159 local** | 14 hours maximum |
| **1200-1259 local** | 13 hours maximum |
| **1300-1659 local** | 12 hours maximum |
| **Number of Segments** | More segments reduce max FDP by 30-60 min each |
| **PWA 5.1** | Pilots may not exceed 6 consecutive duty days |

**Citation:** FAA 14 CFR Part 117.11, PWA Section 5.1
            """)

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

st.sidebar.markdown("### Contract Bot Settings")
st.sidebar.checkbox("Auto-validate all assignments", value=True)
st.sidebar.checkbox("Alert on potential violations", value=True)
st.sidebar.selectbox("Default regulation set", ["FAA Part 117 + PWA", "FAA Part 117 only", "International (EASA)"])
