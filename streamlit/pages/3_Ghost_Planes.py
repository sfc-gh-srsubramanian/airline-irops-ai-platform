"""
Ghost Planes Detection - Aircraft-crew synchronization gaps
"""
import streamlit as st
import pandas as pd

st.set_page_config(page_title="Ghost Planes", page_icon="👻", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("👻 Ghost Planes Detection")

st.sidebar.markdown("### Detection Settings")
realtime_alerts = st.sidebar.checkbox("Real-time alerts", value=True)
include_international = st.sidebar.checkbox("Include international", value=False)
alert_threshold = st.sidebar.selectbox("Alert threshold", ["All ghosts", "Hub ghosts only", "Critical only"])
hub_filter = st.sidebar.selectbox("Filter by Hub", ["All Hubs", "ATL", "DTW", "MSP", "JFK", "LAX", "BOS", "SEA", "SLC"])

st.markdown("---")

all_ghost_flights = pd.DataFrame({
    "Flight": ["PH1234", "PH3456", "PH5678", "PH7890", "PH2345"],
    "Route": ["ATL → JFK", "DTW → ORD", "MSP → DEN", "JFK → MIA", "LAX → SEA"],
    "Hub": ["ATL", "DTW", "MSP", "JFK", "LAX"],
    "Departure": ["14:30", "15:00", "15:15", "15:45", "16:00"],
    "Aircraft": ["N3102PH", "N9145PH", "N3210PH", "N5723PH", "N2189PH"],
    "Aircraft Location": ["ATL", "DTW", "MSP", "JFK", "LAX"],
    "Captain": ["J. Smith", "M. Johnson", "R. Davis", "K. Wilson", "A. Brown"],
    "Captain Location": ["ORD", "ATL", "DEN", "BOS", "SFO"],
    "Issue": ["🔴 Captain in wrong city", "🔴 Captain in wrong city", "🟡 Captain at wrong terminal", "🔴 Captain in wrong city", "🔴 Captain in wrong city"],
    "Issue_Type": ["Critical", "Critical", "Minor", "Critical", "Critical"],
    "Resolution ETA": ["2.5 hrs", "3.0 hrs", "45 min", "4.0 hrs", "1.5 hrs"]
})

ghost_flights = all_ghost_flights.copy()

if hub_filter != "All Hubs":
    ghost_flights = ghost_flights[ghost_flights["Hub"] == hub_filter]

if alert_threshold == "Critical only":
    ghost_flights = ghost_flights[ghost_flights["Issue_Type"] == "Critical"]
elif alert_threshold == "Hub ghosts only":
    ghost_flights = ghost_flights[ghost_flights["Issue_Type"].isin(["Critical", "Hub"])]

col1, col2, col3, col4 = st.columns(4)
col1.metric("Active Ghost Flights", f"{len(ghost_flights)}", f"of {len(all_ghost_flights)} total")
col2.metric("Aircraft at Wrong Location", f"{len(ghost_flights[ghost_flights['Issue_Type']=='Critical'])}", "Location mismatch")
col3.metric("Minor Issues", f"{len(ghost_flights[ghost_flights['Issue_Type']=='Minor'])}", "Terminal mismatch")
col4.metric("Est. Impact", "$125,000", "If unresolved")

st.warning("⚠️ **Ghost Flights** occur when the crew scheduling system shows a pilot assigned to a flight, but the pilot is physically at a different location than the aircraft.")

st.markdown("---")

st.subheader(f"🔴 Current Ghost Flights ({len(ghost_flights)} found)")

if len(ghost_flights) == 0:
    st.success("No ghost flights match your current filters.")
else:
    for idx, row in ghost_flights.iterrows():
        with st.expander(f"👻 {row['Flight']} - {row['Route']} ({row['Issue']})", expanded=idx==ghost_flights.index[0]):
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("### ✈️ Aircraft Status")
                st.markdown(f"**Tail Number:** {row['Aircraft']}")
                st.markdown(f"**Current Location:** {row['Aircraft Location']}")
                st.markdown(f"**Scheduled Departure:** {row['Departure']} UTC")
                st.markdown(f"**Flight Origin:** {row['Route'].split(' → ')[0]}")
                
            with col2:
                st.markdown("### 👨‍✈️ Captain Status")
                st.markdown(f"**Assigned Captain:** {row['Captain']}")
                st.markdown(f"**Actual Location:** {row['Captain Location']}")
                st.markdown(f"**Expected Location:** {row['Route'].split(' → ')[0]}")
                st.markdown(f"**Resolution ETA:** {row['Resolution ETA']}")
            
            st.markdown("---")
            st.markdown("### 🔧 Resolution Options")
            
            col1, col2, col3 = st.columns(3)
            with col1:
                if st.button(f"Find Replacement Crew", key=f"replace_{idx}"):
                    st.info("Redirecting to Crew Recovery...")
            with col2:
                if st.button(f"Reposition Captain", key=f"reposition_{idx}"):
                    st.info("Calculating deadhead options...")
            with col3:
                if st.button(f"Swap Aircraft", key=f"swap_{idx}"):
                    st.info(f"Finding available aircraft at {row['Route'].split(' → ')[0]}...")

st.markdown("---")

st.subheader("🗺️ Network Synchronization Map")

sync_data = pd.DataFrame({
    "Hub": ["ATL", "DTW", "MSP", "SLC", "SEA", "LAX", "JFK", "BOS"],
    "Aircraft Present": [89, 45, 38, 28, 32, 52, 58, 24],
    "Crew Present": [92, 43, 36, 28, 34, 50, 55, 25],
    "Ghost Planes": [0, 2, 2, 0, 0, 0, 1, 0],
    "Idle Captains": [3, 0, 0, 0, 2, 0, 0, 1],
    "Sync Status": ["🟢 Synced", "🟡 2 Ghosts", "🟡 2 Ghosts", "🟢 Synced", "🟢 Synced", "🟢 Synced", "🟡 1 Ghost", "🟢 Synced"]
})

if hub_filter != "All Hubs":
    sync_data = sync_data[sync_data["Hub"] == hub_filter]

st.dataframe(sync_data, use_container_width=True)

st.markdown("---")

col1, col2 = st.columns(2)

with col1:
    st.subheader("📈 Ghost Flight Trend (24 hrs)")
    trend_data = pd.DataFrame({
        "Hour": list(range(24)),
        "Ghost Flights": [2, 1, 1, 0, 0, 1, 3, 5, 8, 12, 10, 8, 7, 6, 5, 4, 3, 4, 5, 6, 5, 4, 3, 2]
    })
    st.line_chart(trend_data.set_index("Hour"))

with col2:
    st.subheader("📊 Root Causes")
    causes = pd.DataFrame({
        "Cause": ["System Delay", "Weather Diversion", "Crew Timeout", "Manual Error", "Connection Miss"],
        "Count": [12, 8, 5, 3, 2]
    })
    st.bar_chart(causes.set_index("Cause"))
