"""
Ghost Planes Detection - Aircraft-crew synchronization gaps
"""
import streamlit as st
import pandas as pd
import random
import hashlib

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

# --- Initialize session state for resolved flights ---
if "resolved_flights" not in st.session_state:
    st.session_state.resolved_flights = {}


@st.cache_data
def generate_ghost_flight_data():
    """Generate a realistic set of ghost flights from a 1169-flight schedule."""
    random.seed(42)

    hubs = ["ATL", "DTW", "MSP", "JFK", "LAX", "BOS", "SEA", "SLC"]
    spokes = ["ORD", "DEN", "SFO", "MIA", "DFW", "PHX", "IAH", "CLT", "EWR", "PHL",
              "SAN", "TPA", "PDX", "AUS", "BNA", "RDU", "MCI", "IND", "CLE", "PIT"]
    all_airports = hubs + spokes

    captains = [
        "J. Smith", "M. Johnson", "R. Davis", "K. Wilson", "A. Brown",
        "T. Martinez", "L. Anderson", "S. Thomas", "D. Garcia", "P. Miller",
        "C. Robinson", "E. Clark", "B. Lewis", "W. Walker", "H. Young",
        "N. Allen", "F. King", "G. Wright", "I. Lopez", "O. Hill",
        "V. Scott", "Q. Green", "U. Adams", "X. Baker", "Z. Nelson",
        "J. Carter", "M. Mitchell", "R. Perez", "K. Roberts", "A. Turner",
        "T. Phillips", "L. Campbell", "S. Parker", "D. Evans", "P. Edwards",
    ]

    first_officers = [
        "FO R. Chen", "FO M. Patel", "FO K. Lee", "FO J. Kim", "FO A. Singh",
        "FO T. Nguyen", "FO L. White", "FO S. Hall", "FO D. Moore", "FO P. Taylor",
        "FO C. Harris", "FO E. Martin", "FO B. Jackson", "FO W. Thompson", "FO H. Martinez",
    ]

    issue_types = [
        ("Aircraft", "Aircraft at wrong location"),
        ("Aircraft", "Aircraft at wrong location"),
        ("Aircraft", "Aircraft diverted, not repositioned"),
        ("Crew", "Captain in wrong city"),
        ("Crew", "Captain in wrong city"),
        ("Crew", "First officer unavailable"),
        ("Crew", "Crew timed out - duty hours exceeded"),
        ("Both", "Aircraft and crew at wrong location"),
        ("Both", "Aircraft diverted, crew reassigned"),
    ]

    total_flights = 1169
    num_ghosts = 47

    ghost_indices = set(random.sample(range(total_flights), num_ghosts))

    ghost_records = []
    flight_counter = 1000

    for i in range(total_flights):
        if i not in ghost_indices:
            continue

        flight_counter += random.randint(1, 5)
        flight_id = f"PH{flight_counter}"

        hub = random.choice(hubs)
        dest = random.choice([a for a in all_airports if a != hub])
        route = f"{hub} → {dest}"

        hour = random.choice(range(6, 23))
        minute = random.choice([0, 15, 30, 45])
        departure = f"{hour:02d}:{minute:02d}"

        tail_num = f"N{random.randint(1000, 9999)}PH"
        captain = random.choice(captains)

        issue_cat, issue_desc = random.choice(issue_types)

        if issue_cat == "Aircraft":
            wrong_loc = random.choice([a for a in all_airports if a != hub])
            aircraft_loc = wrong_loc
            captain_loc = hub
            issue_display = f"🟣 {issue_desc} (at {wrong_loc})"
        elif issue_cat == "Crew":
            aircraft_loc = hub
            captain_loc = random.choice([a for a in all_airports if a != hub])
            issue_display = f"🟠 {issue_desc} (at {captain_loc})"
        else:
            wrong_loc_ac = random.choice([a for a in all_airports if a != hub])
            aircraft_loc = wrong_loc_ac
            captain_loc = random.choice([a for a in all_airports if a != hub])
            issue_display = f"🔴 {issue_desc}"

        severity = "Critical" if issue_cat in ("Aircraft", "Both") else random.choice(["Critical", "Warning"])
        pax = random.randint(85, 210)
        eta_hours = round(random.uniform(0.5, 5.0), 1)
        eta_str = f"{eta_hours} hrs" if eta_hours >= 1 else f"{int(eta_hours * 60)} min"

        ghost_records.append({
            "Flight": flight_id,
            "Route": route,
            "Hub": hub,
            "Departure": departure,
            "Aircraft": tail_num,
            "Aircraft Location": aircraft_loc,
            "Captain": captain,
            "Captain Location": captain_loc,
            "Issue": issue_display,
            "Issue_Type": issue_cat,
            "Severity": severity,
            "PAX": pax,
            "Resolution ETA": eta_str,
        })

    return pd.DataFrame(ghost_records), total_flights


all_ghost_flights, total_schedule_flights = generate_ghost_flight_data()

# --- Apply resolved flights filter ---
active_ghost_flights = all_ghost_flights[
    ~all_ghost_flights["Flight"].isin(st.session_state.resolved_flights)
].copy()

ghost_flights = active_ghost_flights.copy()

if hub_filter != "All Hubs":
    ghost_flights = ghost_flights[ghost_flights["Hub"] == hub_filter]

if alert_threshold == "Critical only":
    ghost_flights = ghost_flights[ghost_flights["Severity"] == "Critical"]
elif alert_threshold == "Hub ghosts only":
    ghost_flights = ghost_flights[ghost_flights["Severity"].isin(["Critical", "Warning"])]

# --- Compute distinct metrics ---
num_ghost = len(ghost_flights)
num_missing_aircraft = len(ghost_flights[ghost_flights["Issue_Type"].isin(["Aircraft", "Both"])])
num_missing_crew = len(ghost_flights[ghost_flights["Issue_Type"].isin(["Crew", "Both"])])
total_pax_affected = ghost_flights["PAX"].sum() if num_ghost > 0 else 0

col1, col2, col3, col4 = st.columns(4)
resolved_count = len(st.session_state.resolved_flights)
col1.metric("Ghost Flights", f"{num_ghost}", f"of {len(all_ghost_flights)} detected ({resolved_count} resolved)")
col2.metric("Missing Aircraft", f"{num_missing_aircraft}", "Aircraft location mismatch")
col3.metric("Missing Crew", f"{num_missing_crew}", "Crew location mismatch")
col4.metric("PAX Affected", f"{total_pax_affected:,}", f"across {num_ghost} flights")

st.warning(f"⚠️ **Ghost Flights** occur when a scheduled flight's aircraft or crew are physically at a different location than the departure airport. Monitoring {total_schedule_flights:,} flights today.")

st.markdown("---")

st.subheader(f"🔴 Current Ghost Flights ({num_ghost} active)")

if num_ghost == 0:
    st.success("No ghost flights match your current filters.")
else:
    for idx, row in ghost_flights.iterrows():
        with st.expander(f"👻 {row['Flight']} - {row['Route']} | {row['Issue']} | {row['PAX']} PAX", expanded=idx == ghost_flights.index[0]):
            col1, col2 = st.columns(2)

            with col1:
                st.markdown("### ✈️ Aircraft Status")
                st.markdown(f"**Tail Number:** {row['Aircraft']}")
                st.markdown(f"**Current Location:** {row['Aircraft Location']}")
                st.markdown(f"**Scheduled Departure:** {row['Departure']} UTC")
                st.markdown(f"**Flight Origin:** {row['Route'].split(' → ')[0]}")

            with col2:
                st.markdown("### 👨‍✈️ Crew Status")
                st.markdown(f"**Assigned Captain:** {row['Captain']}")
                st.markdown(f"**Captain Location:** {row['Captain Location']}")
                st.markdown(f"**Expected Location:** {row['Route'].split(' → ')[0]}")
                st.markdown(f"**Resolution ETA:** {row['Resolution ETA']}")

            st.markdown("---")
            st.markdown("### 🔧 Resolution Options")

            origin = row["Route"].split(" → ")[0]
            flight_key = row["Flight"]

            res_col1, res_col2, res_col3 = st.columns(3)

            with res_col1:
                if st.button("Find Replacement Crew", key=f"replace_{flight_key}"):
                    st.session_state.resolved_flights[flight_key] = "Crew Replacement"
                    st.success(f"✅ Replacement crew assigned for {flight_key}.")
                    st.rerun()

            with res_col2:
                if st.button("Reposition Captain", key=f"reposition_{flight_key}"):
                    st.session_state.resolved_flights[flight_key] = "Reposition"
                    st.success(f"✅ Deadhead repositioning initiated for {row['Captain']} to {origin}.")
                    st.rerun()

            with res_col3:
                # --- Bug 1 fix: selectable aircraft swap dropdown ---
                random.seed(hashlib.md5(flight_key.encode()).hexdigest())
                available_aircraft = [
                    f"N{random.randint(1000, 9999)}PH ({origin})"
                    for _ in range(random.randint(2, 5))
                ]
                selected_aircraft = st.selectbox(
                    "Swap Aircraft",
                    options=available_aircraft,
                    key=f"swap_select_{flight_key}",
                    label_visibility="collapsed",
                )
                if st.button("Execute Swap", key=f"swap_{flight_key}"):
                    tail = selected_aircraft.split(" ")[0]
                    st.session_state.resolved_flights[flight_key] = f"Aircraft Swap → {tail}"
                    st.success(f"✅ Swapped to {tail} for flight {flight_key}.")
                    st.rerun()

st.markdown("---")

st.subheader("🗺️ Network Synchronization Map")

# Build sync map from active ghost data
hub_list = ["ATL", "DTW", "MSP", "SLC", "SEA", "LAX", "JFK", "BOS"]
sync_rows = []
random.seed(99)
for h in hub_list:
    hub_ghosts = active_ghost_flights[active_ghost_flights["Hub"] == h]
    ghost_count = len(hub_ghosts)
    ac_present = random.randint(20, 95)
    crew_present = ac_present + random.randint(-4, 4)
    idle_captains = max(0, crew_present - ac_present) + random.randint(0, 3) if ghost_count == 0 else random.randint(0, 2)

    if ghost_count == 0:
        status = "🟢 Synced"
    elif ghost_count <= 2:
        status = f"🟡 {ghost_count} Ghost{'s' if ghost_count > 1 else ''}"
    else:
        status = f"🔴 {ghost_count} Ghosts"

    sync_rows.append({
        "Hub": h,
        "Aircraft Present": ac_present,
        "Crew Present": crew_present,
        "Ghost Planes": ghost_count,
        "Idle Captains": idle_captains,
        "Sync Status": status,
    })

sync_data = pd.DataFrame(sync_rows)

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
