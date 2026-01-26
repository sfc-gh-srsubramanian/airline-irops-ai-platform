"""
One-Click Crew Recovery - AI-powered crew reassignment
"""
import streamlit as st
import pandas as pd

st.set_page_config(page_title="Crew Recovery", page_icon="👨‍✈️", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("👨‍✈️ One-Click Crew Recovery")

st.sidebar.markdown("### Recovery Settings")
include_reserve = st.sidebar.checkbox("Include reserve pilots", value=True)
include_longcall = st.sidebar.checkbox("Include long-call reserves", value=True)
auto_validate = st.sidebar.checkbox("Auto-validate contracts", value=True)
max_batch = st.sidebar.number_input("Max notification batch size", 5, 50, 20)
base_filter = st.sidebar.selectbox("Filter by Base", ["All Bases", "ATL", "DTW", "MSP", "JFK", "LAX", "BOS", "SEA"])

st.markdown("---")

col1, col2, col3 = st.columns(3)
col1.metric("Flights Needing Crew", "12", "↑ 3")
col2.metric("Available Captains", "156", "Network-wide")
col3.metric("Avg Fill Time (Old)", "12 min", "Per pilot call")

st.info("💡 **One-Click Recovery** enables batch notification to top-ranked candidates simultaneously, reducing the 12-minute sequential calling bottleneck to seconds.")

st.markdown("---")

st.subheader("🔴 Flights Needing Crew")

flights_needing = pd.DataFrame({
    "Flight": ["PH1234", "PH2567", "PH3890", "PH5678", "PH7890"],
    "Route": ["ATL → JFK", "DTW → LAX", "MSP → SEA", "JFK → MIA", "ATL → DFW"],
    "Hub": ["ATL", "DTW", "MSP", "JFK", "ATL"],
    "Departure": ["14:30", "15:00", "15:30", "16:00", "16:30"],
    "Aircraft": ["B737-800", "A321-200", "B737-900", "B757-200", "A320-200"],
    "Need": ["Captain", "First Officer", "Captain", "Captain", "First Officer"],
    "Priority": [98, 95, 92, 88, 85]
})

selected_flight = st.selectbox(
    "Select flight for crew recovery:",
    flights_needing["Flight"].tolist(),
    format_func=lambda x: f"{x} - {flights_needing[flights_needing['Flight']==x]['Route'].values[0]} ({flights_needing[flights_needing['Flight']==x]['Need'].values[0]} needed)"
)

st.markdown("---")

st.subheader(f"👥 Top Candidates for {selected_flight}")

all_candidates = pd.DataFrame({
    "Rank": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    "Name": ["Capt. Johnson", "Capt. Williams", "Capt. Davis", "Capt. Brown", "Capt. Miller", "Capt. Wilson", "Capt. Moore", "Capt. Taylor", "Capt. Anderson", "Capt. Thomas"],
    "Base": ["ATL", "ATL", "DTW", "ATL", "MSP", "ATL", "JFK", "ATL", "DTW", "ATL"],
    "Type": ["Line", "Line", "Reserve", "Line", "Reserve", "Line", "Long-call", "Line", "Long-call", "Reserve"],
    "ML Score": [94.2, 91.8, 89.5, 87.3, 85.1, 83.4, 81.2, 79.8, 77.5, 75.2],
    "Type Qualified": ["✅ Yes", "✅ Yes", "✅ Yes", "✅ Yes", "✅ Yes", "✅ Yes", "✅ Yes", "✅ Yes", "✅ Yes", "✅ Yes"],
    "Hours Remaining": [45.2, 38.7, 52.1, 41.3, 35.8, 48.9, 29.4, 44.6, 31.2, 47.8],
    "Last 7 Days": ["18.5 hrs", "22.3 hrs", "15.2 hrs", "19.8 hrs", "24.1 hrs", "16.7 hrs", "28.3 hrs", "17.9 hrs", "26.5 hrs", "14.2 hrs"],
    "Contract Legal": ["✅", "✅", "✅", "✅", "✅", "✅", "⚠️", "✅", "⚠️", "✅"]
})

candidates = all_candidates.copy()

if base_filter != "All Bases":
    candidates = candidates[candidates["Base"] == base_filter]

if not include_reserve:
    candidates = candidates[candidates["Type"] != "Reserve"]

if not include_longcall:
    candidates = candidates[candidates["Type"] != "Long-call"]

if len(candidates) == 0:
    st.warning("No candidates match your current filter settings. Try adjusting the filters.")
else:
    st.info(f"Showing {len(candidates)} candidates (filtered from {len(all_candidates)})")
    display_df = candidates[["Rank", "Name", "Base", "Type", "ML Score", "Type Qualified", "Hours Remaining", "Last 7 Days", "Contract Legal"]]
    st.dataframe(display_df, use_container_width=True)

st.markdown("---")

st.subheader("🚀 One-Click Recovery Action")

col1, col2 = st.columns([2, 1])

with col1:
    num_candidates = st.slider("Number of candidates to notify", 5, min(max_batch, len(candidates)) if len(candidates) > 0 else 20, min(10, len(candidates)) if len(candidates) > 0 else 10)
    st.markdown(f"""
    **Notification Preview:**
    
    > URGENT: Open trip available. {selected_flight} ATL-JFK departing 14:30 UTC.
    > Reply YES to accept or call Crew Scheduling.
    
    This message will be sent to the top **{num_candidates}** candidates simultaneously.
    """)

with col2:
    st.markdown("### Ready to Send")
    st.markdown(f"- **Flight:** {selected_flight}")
    st.markdown(f"- **Candidates:** {num_candidates}")
    st.markdown(f"- **Method:** SMS + Email")
    
    if st.button("📤 Send Batch Notification", type="primary", use_container_width=True):
        with st.spinner("Sending notifications..."):
            import time
            time.sleep(2)
        st.success(f"✅ Notifications sent to {num_candidates} candidates!")
        st.balloons()

st.markdown("---")

st.subheader("📊 Recovery Metrics")

col1, col2, col3, col4 = st.columns(4)
col1.metric("Avg Time to Fill (New)", "2.3 min", "-9.7 min", delta_color="inverse")
col2.metric("First Response Rate", "78%", "↑ 12%")
col3.metric("Acceptance Rate", "62%", "↑ 8%")
col4.metric("Flights Saved Today", "45", "vs 23 cancelled")
