"""
Disruption Analysis - IROPS event tracking and cost analysis
"""
import streamlit as st
import pandas as pd

st.set_page_config(page_title="Disruption Analysis", page_icon="⚠️", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("⚠️ Disruption Analysis")

st.sidebar.markdown("### Alert Settings")
critical_alerts = st.sidebar.checkbox("Critical alerts", value=True)
severe_alerts = st.sidebar.checkbox("Severe alerts", value=True)
cost_alerts = st.sidebar.checkbox("Cost threshold alerts", value=True)
cost_threshold = st.sidebar.number_input("Cost alert threshold ($K)", 50, 1000, 100)
sidebar_hub = st.sidebar.selectbox("Filter Hub", ["All Hubs", "ATL", "DTW", "MSP", "JFK", "LAX"])

st.markdown("---")

all_disruptions = pd.DataFrame({
    "ID": ["DIS001", "DIS002", "DIS003", "DIS004", "DIS005", "DIS006"],
    "Type": ["WEATHER", "MECHANICAL", "CREW", "ATC", "WEATHER", "GROUND_OPS"],
    "Severity": ["CRITICAL", "SEVERE", "SEVERE", "MODERATE", "CRITICAL", "MODERATE"],
    "Severity_Display": ["🔴 CRITICAL", "🟠 SEVERE", "🟠 SEVERE", "🟡 MODERATE", "🔴 CRITICAL", "🟡 MODERATE"],
    "Hub": ["ATL", "DTW", "MSP", "JFK", "ATL", "LAX"],
    "Description": ["Severe thunderstorms causing ground stop", "Engine issue on N3102PH", "Captain sick call - 3 flights affected", "ATC staffing shortage", "Tornado warning - diversions", "Fueling equipment failure"],
    "Flights": [45, 1, 3, 12, 23, 5],
    "Passengers": [4500, 180, 450, 1200, 2100, 750],
    "Est_Cost_Num": [850, 125, 95, 180, 420, 65],
    "Est. Cost": ["$850K", "$125K", "$95K", "$180K", "$420K", "$65K"],
    "Status": ["IN_PROGRESS", "IN_PROGRESS", "PENDING", "RESOLVED", "IN_PROGRESS", "PENDING"],
    "Started": ["2 hrs ago", "45 min ago", "30 min ago", "4 hrs ago", "1.5 hrs ago", "20 min ago"]
})

filtered = all_disruptions.copy()
if sidebar_hub != "All Hubs":
    filtered = filtered[filtered["Hub"] == sidebar_hub]
if not critical_alerts:
    filtered = filtered[filtered["Severity"] != "CRITICAL"]
if not severe_alerts:
    filtered = filtered[filtered["Severity"] != "SEVERE"]
if cost_alerts:
    filtered = filtered[filtered["Est_Cost_Num"] >= cost_threshold]

total_active = len(all_disruptions)
critical_count = len(all_disruptions[all_disruptions["Severity"] == "CRITICAL"])
severe_count = len(all_disruptions[all_disruptions["Severity"] == "SEVERE"])
total_pax = all_disruptions["Passengers"].sum()
total_cost = all_disruptions["Est_Cost_Num"].sum()

col1, col2, col3, col4, col5 = st.columns(5)
col1.metric("Active Disruptions", f"{total_active}", "")
col2.metric("Critical", f"{critical_count}", "🔴")
col3.metric("Severe", f"{severe_count}", "🟠")
col4.metric("Passengers Affected", f"{total_pax:,}", "Today")
col5.metric("Est. Cost Today", f"${total_cost/1000:.1f}M", "")

st.markdown("---")

tab1, tab2, tab3, tab4 = st.tabs(["🔴 Active Events", "📈 Cost Analysis", "🌊 Cascading Impact", "📜 Historical"])

with tab1:
    st.subheader("Active Disruption Events")
    
    col1, col2, col3 = st.columns(3)
    with col1:
        type_filter = st.multiselect("Type", ["WEATHER", "MECHANICAL", "CREW", "ATC", "GROUND_OPS"], default=["WEATHER", "MECHANICAL", "CREW", "ATC", "GROUND_OPS"])
    with col2:
        severity_filter = st.multiselect("Severity", ["CRITICAL", "SEVERE", "MODERATE", "MINOR"], default=["CRITICAL", "SEVERE", "MODERATE"])
    with col3:
        hub_filter = st.selectbox("Hub", ["All Hubs", "ATL", "DTW", "MSP", "JFK", "LAX"])
    
    display_disruptions = filtered.copy()
    if type_filter:
        display_disruptions = display_disruptions[display_disruptions["Type"].isin(type_filter)]
    if severity_filter:
        display_disruptions = display_disruptions[display_disruptions["Severity"].isin(severity_filter)]
    if hub_filter != "All Hubs":
        display_disruptions = display_disruptions[display_disruptions["Hub"] == hub_filter]
    
    st.info(f"Showing {len(display_disruptions)} disruptions (filtered from {len(all_disruptions)})")
    
    display_df = display_disruptions[["ID", "Type", "Severity_Display", "Hub", "Description", "Flights", "Passengers", "Est. Cost", "Status", "Started"]].copy()
    display_df.columns = ["ID", "Type", "Severity", "Hub", "Description", "Flights", "Passengers", "Est. Cost", "Status", "Started"]
    st.dataframe(display_df, use_container_width=True)

with tab2:
    st.subheader("Cost Breakdown by Disruption Type")
    
    col1, col2 = st.columns(2)
    
    with col1:
        cost_by_type = pd.DataFrame({
            "Type": ["WEATHER", "MECHANICAL", "CREW", "ATC", "GROUND_OPS"],
            "Direct Cost": [1250000, 450000, 320000, 280000, 120000],
            "Passenger Cost": [450000, 125000, 95000, 180000, 65000],
            "Crew Cost": [180000, 45000, 85000, 65000, 25000]
        })
        st.bar_chart(cost_by_type.set_index("Type"))
    
    with col2:
        st.markdown("### Cost Categories")
        st.markdown("""
        **Direct Costs:**
        - Aircraft repositioning
        - Fuel burn during holds
        - Airport fees
        
        **Passenger Costs:**
        - Meal vouchers
        - Hotel accommodations
        - DOT compensation
        - Rebooking fees
        
        **Crew Costs:**
        - Overtime pay
        - Deadhead positioning
        - Reserve callouts
        - Duty time violations
        """)

with tab3:
    st.subheader("Cascading Impact Analysis")
    
    selected_disruption = st.selectbox("Select disruption to analyze:", ["DIS001 - ATL Thunderstorms", "DIS002 - DTW Engine Issue", "DIS005 - ATL Tornado Warning"])
    
    st.markdown(f"### Downstream Impact: {selected_disruption}")
    
    col1, col2, col3 = st.columns(3)
    col1.metric("Downstream Flights", "23", "In cascade")
    col2.metric("Additional Passengers", "3,200", "Affected")
    col3.metric("Cascade Cost", "$420K", "Additional")
    
    cascade_flights = pd.DataFrame({
        "Flight": ["PH1235", "PH1456", "PH1678", "PH1890", "PH2012"],
        "Route": ["JFK → LAX", "JFK → MIA", "ATL → ORD", "ORD → DEN", "LAX → SEA"],
        "Cascade Type": ["Aircraft Rotation", "Crew Rotation", "Aircraft Rotation", "Crew Rotation", "Aircraft Rotation"],
        "Est. Delay": ["45 min", "60 min", "90 min", "120 min", "75 min"],
        "Passengers": [180, 150, 165, 145, 170],
        "Cost Impact": ["$18K", "$22K", "$35K", "$48K", "$28K"]
    })
    
    st.dataframe(cascade_flights, use_container_width=True)

with tab4:
    st.subheader("Historical Incident Patterns")
    
    st.markdown("### Similar Past Events")
    
    similar_events = pd.DataFrame({
        "Date": ["2024-07-19", "2022-12-22", "2023-08-15"],
        "Event": ["CrowdStrike Outage", "Winter Storm Elliott", "B737 Fleet AD"],
        "Type": ["SYSTEM_OUTAGE", "WEATHER", "MECHANICAL"],
        "Duration": ["120 hrs", "96 hrs", "72 hrs"],
        "Flights Cancelled": ["4,000", "2,500", "1,200"],
        "Total Cost": ["$85M", "$45M", "$25M"],
        "Key Learning": ["Need backup crew tracking", "Pre-position crews 48hrs ahead", "Cross-train mechanics"]
    })
    
    st.dataframe(similar_events, use_container_width=True)
    
    st.markdown("### Apply Proven Recovery Strategy")
    if st.button("🔍 Find Similar Incidents for Current Disruption", type="primary"):
        st.info("AI analyzing current disruption against historical patterns...")
        st.success("Found 3 similar incidents with proven recovery strategies. Recommendation: Apply Winter Storm Elliott playbook.")
