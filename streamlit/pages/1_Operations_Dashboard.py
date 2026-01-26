"""
Operations Dashboard - Real-time flight monitoring
"""
import streamlit as st
import pandas as pd

st.set_page_config(page_title="Operations Dashboard", page_icon="📊", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("📊 Operations Dashboard")

st.sidebar.markdown("### Filters")
hub_filter = st.sidebar.selectbox("Hub", ["All Hubs", "ATL", "DTW", "MSP", "SLC", "SEA", "LAX", "JFK", "BOS"])
status_filter = st.sidebar.selectbox("Status", ["All Statuses", "On Time", "Delayed", "Cancelled", "Boarding"])
time_filter = st.sidebar.selectbox("Time Range", ["Next 2 hours", "Next 6 hours", "Today", "Tomorrow"])

st.markdown("---")

all_flights = pd.DataFrame({
    "Flight": ["PH1234", "PH2567", "PH3890", "PH4123", "PH5678", "PH6901", "PH7234", "PH8567"],
    "Route": ["ATL → JFK", "DTW → LAX", "MSP → SEA", "SLC → DEN", "JFK → MIA", "ATL → ORD", "LAX → SEA", "BOS → JFK"],
    "Hub": ["ATL", "DTW", "MSP", "SLC", "JFK", "ATL", "LAX", "BOS"],
    "Departure": ["14:30", "14:45", "15:00", "15:15", "15:30", "15:45", "16:00", "16:15"],
    "Status": ["On Time", "Delayed", "On Time", "Cancelled", "Delayed", "Boarding", "On Time", "On Time"],
    "Status_Display": ["🟢 On Time", "🟡 Delayed (23 min)", "🟢 On Time", "🔴 Cancelled", "🟡 Delayed (45 min)", "🟢 Boarding", "🟢 On Time", "🟢 On Time"],
    "Aircraft": ["N3102PH", "N9145PH", "N3210PH", "N2156PH", "N5723PH", "N3108PH", "N4521PH", "N6234PH"],
    "Captain": ["J. Smith", "M. Johnson", "R. Davis", "—", "K. Wilson", "A. Brown", "T. Lee", "S. Park"],
    "Health Score": [95, 72, 88, 0, 65, 91, 89, 94]
})

filtered_flights = all_flights.copy()

if hub_filter != "All Hubs":
    filtered_flights = filtered_flights[filtered_flights["Hub"] == hub_filter]

if status_filter != "All Statuses":
    filtered_flights = filtered_flights[filtered_flights["Status"] == status_filter]

total = len(all_flights)
completed = len(all_flights[all_flights["Status"].isin(["On Time", "Boarding"])])
delayed = len(all_flights[all_flights["Status"] == "Delayed"])
cancelled = len(all_flights[all_flights["Status"] == "Cancelled"])

col1, col2, col3, col4, col5 = st.columns(5)
col1.metric("Total Flights Today", f"{total}", "")
col2.metric("On Time/Boarding", f"{completed}", f"{completed*100//total}%")
col3.metric("In Progress", f"{total - completed - cancelled}", "")
col4.metric("Delayed", f"{delayed}", "")
col5.metric("Cancelled", f"{cancelled}", f"{cancelled*100//total}%")

st.markdown("---")

tab1, tab2, tab3 = st.tabs(["🛫 Flight Status", "📈 Performance Trends", "🗺️ Hub Overview"])

with tab1:
    st.subheader("Live Flight Status")
    if hub_filter != "All Hubs" or status_filter != "All Statuses":
        st.info(f"Showing {len(filtered_flights)} flights (filtered from {len(all_flights)})")
    
    display_df = filtered_flights[["Flight", "Route", "Departure", "Status_Display", "Aircraft", "Captain", "Health Score"]].copy()
    display_df.columns = ["Flight", "Route", "Departure", "Status", "Aircraft", "Captain", "Health Score"]
    st.dataframe(display_df, use_container_width=True)

with tab2:
    st.subheader("On-Time Performance Trend (Last 7 Days)")
    
    chart_data = pd.DataFrame({
        "Date": pd.date_range(end=pd.Timestamp.today(), periods=7),
        "OTP %": [84.2, 82.1, 79.8, 81.5, 83.2, 85.6, 82.4],
        "Target": [85, 85, 85, 85, 85, 85, 85]
    })
    st.line_chart(chart_data.set_index("Date"))
    
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Delay Distribution by Cause")
        delay_causes = pd.DataFrame({
            "Cause": ["Weather", "Crew", "Mechanical", "ATC", "Ground Ops"],
            "Count": [45, 32, 28, 21, 14]
        })
        st.bar_chart(delay_causes.set_index("Cause"))
    
    with col2:
        st.subheader("Cancellations by Hub")
        cancel_data = pd.DataFrame({
            "Hub": ["ATL", "DTW", "MSP", "JFK", "LAX"],
            "Cancellations": [12, 8, 5, 6, 3]
        })
        st.bar_chart(cancel_data.set_index("Hub"))

with tab3:
    st.subheader("Hub Operational Status")
    
    hub_data = pd.DataFrame({
        "Hub": ["ATL", "DTW", "MSP", "SLC", "SEA", "LAX", "JFK", "BOS"],
        "Status": ["🟢 Normal", "🟢 Normal", "🟡 Weather Watch", "🟢 Normal", "🟢 Normal", "🟢 Normal", "🟡 ATC Delays", "🟢 Normal"],
        "Flights": [342, 156, 134, 98, 112, 187, 203, 89],
        "OTP %": [84, 82, 71, 88, 86, 83, 74, 87],
        "Available Crew": [245, 112, 98, 67, 78, 134, 156, 67],
        "Available Aircraft": [89, 45, 38, 28, 32, 52, 58, 24],
        "Weather": ["Thunderstorms", "Clear", "Snow", "Clear", "Fog", "Clear", "Rain", "Clear"]
    })
    
    if hub_filter != "All Hubs":
        hub_data = hub_data[hub_data["Hub"] == hub_filter]
    
    st.dataframe(hub_data, use_container_width=True)
