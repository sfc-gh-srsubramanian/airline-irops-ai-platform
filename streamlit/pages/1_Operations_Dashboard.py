"""
Operations Dashboard - Real-time flight monitoring with Snowflake data
"""
import streamlit as st
import pandas as pd
from snowflake.connector import connect
import os

st.set_page_config(page_title="Operations Dashboard", page_icon="📊", layout="wide")

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"

@st.cache_resource
def get_snowflake_connection():
    try:
        conn = connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "phantom_irops")
        return conn
    except Exception as e:
        st.warning(f"Could not connect to Snowflake: {e}. Using mock data.")
        return None

def run_query(query_text):
    conn = get_snowflake_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(query_text)
            columns = [desc[0] for desc in cursor.description]
            data = cursor.fetchall()
            return pd.DataFrame(data, columns=columns)
        except Exception as e:
            st.warning(f"Query failed: {e}. Using mock data.")
            return None
    return None

def get_date_filter(time_range):
    if time_range == "Next 2 hours":
        return "FLIGHT_DATE = CURRENT_DATE() AND SCHEDULED_DEPARTURE_TIME BETWEEN CURRENT_TIME() AND TIMEADD('hour', 2, CURRENT_TIME())"
    elif time_range == "Next 6 hours":
        return "FLIGHT_DATE = CURRENT_DATE() AND SCHEDULED_DEPARTURE_TIME BETWEEN CURRENT_TIME() AND TIMEADD('hour', 6, CURRENT_TIME())"
    elif time_range == "Today":
        return "FLIGHT_DATE = CURRENT_DATE()"
    elif time_range == "Tomorrow":
        return "FLIGHT_DATE = DATEADD('day', 1, CURRENT_DATE())"
    elif time_range == "Last 7 Days":
        return "FLIGHT_DATE BETWEEN DATEADD('day', -7, CURRENT_DATE()) AND CURRENT_DATE()"
    return "FLIGHT_DATE = CURRENT_DATE()"

st.markdown(f"""
<div style="background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%); padding: 1.5rem 2rem; border-radius: 10px; margin-bottom: 1.5rem;">
    <h1 style="color: white; margin: 0; font-size: 1.8rem;">✈️ Phantom Control Center</h1>
    <p style="color: {LIGHT_BLUE}; margin: 0.3rem 0 0 0; font-size: 0.95rem;">AI-Powered Irregular Operations Management Platform</p>
</div>
""", unsafe_allow_html=True)

st.subheader("📊 Operations Dashboard")

st.sidebar.markdown("### Filters")
hub_filter = st.sidebar.selectbox("Hub", ["All Hubs", "ATL", "DTW", "MSP", "SLC", "SEA", "LAX", "JFK", "BOS"])
status_filter = st.sidebar.selectbox("Status", ["All Statuses", "On Time", "Delayed", "Cancelled", "Boarding", "In Progress"])
time_filter = st.sidebar.selectbox("Time Range", ["Today", "Next 2 hours", "Next 6 hours", "Tomorrow", "Last 7 Days"])

st.markdown("---")

date_filter = get_date_filter(time_filter)
hub_clause = f"AND ORIGIN = '{hub_filter}'" if hub_filter != "All Hubs" else ""

summary_query = f"""
SELECT 
    COUNT(*) as TOTAL_FLIGHTS,
    COUNT(CASE WHEN STATUS IN ('SCHEDULED', 'ON_TIME') THEN 1 END) as ON_TIME_FLIGHTS,
    COUNT(CASE WHEN STATUS IN ('BOARDING', 'IN_FLIGHT', 'TAXIING') THEN 1 END) as IN_PROGRESS_FLIGHTS,
    COUNT(CASE WHEN STATUS = 'DELAYED' THEN 1 END) as DELAYED_FLIGHTS,
    COUNT(CASE WHEN STATUS = 'CANCELLED' THEN 1 END) as CANCELLED_FLIGHTS,
    SUM(CASE WHEN STATUS IN ('DELAYED', 'CANCELLED') THEN PASSENGERS_BOOKED ELSE 0 END) as PASSENGERS_AFFECTED,
    AVG(CASE WHEN DEPARTURE_DELAY_MINUTES > 0 THEN DEPARTURE_DELAY_MINUTES END) as AVG_DELAY_MINUTES
FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
WHERE {date_filter} {hub_clause}
"""

summary_df = run_query(summary_query)

if summary_df is not None and len(summary_df) > 0:
    total = int(summary_df['TOTAL_FLIGHTS'].iloc[0] or 0)
    on_time = int(summary_df['ON_TIME_FLIGHTS'].iloc[0] or 0)
    in_progress = int(summary_df['IN_PROGRESS_FLIGHTS'].iloc[0] or 0)
    delayed = int(summary_df['DELAYED_FLIGHTS'].iloc[0] or 0)
    cancelled = int(summary_df['CANCELLED_FLIGHTS'].iloc[0] or 0)
    pax_affected = int(summary_df['PASSENGERS_AFFECTED'].iloc[0] or 0)
    avg_delay = float(summary_df['AVG_DELAY_MINUTES'].iloc[0] or 0)
else:
    total, on_time, in_progress, delayed, cancelled = 8, 5, 1, 2, 1
    pax_affected, avg_delay = 450, 34

col1, col2, col3, col4, col5 = st.columns(5)
col1.metric("Total Flights", f"{total}", time_filter)
col2.metric("On Time", f"{on_time}", f"{on_time*100//max(total,1)}%")
col3.metric("In Progress", f"{in_progress}", "")
col4.metric("Delayed", f"{delayed}", "")
col5.metric("Cancelled", f"{cancelled}", f"{cancelled*100//max(total,1)}%")

st.markdown("---")

tab1, tab2, tab3 = st.tabs(["🛫 Flight Status", "📈 Performance Trends", "🗺️ Hub Overview"])

with tab1:
    st.subheader("Live Flight Status")
    
    status_clause = ""
    if status_filter == "On Time":
        status_clause = "AND STATUS IN ('SCHEDULED', 'ON_TIME')"
    elif status_filter == "Delayed":
        status_clause = "AND STATUS = 'DELAYED'"
    elif status_filter == "Cancelled":
        status_clause = "AND STATUS = 'CANCELLED'"
    elif status_filter == "Boarding":
        status_clause = "AND STATUS = 'BOARDING'"
    elif status_filter == "In Progress":
        status_clause = "AND STATUS IN ('BOARDING', 'IN_FLIGHT', 'TAXIING')"
    
    flights_query = f"""
    SELECT 
        FLIGHT_NUMBER as Flight,
        ORIGIN || ' → ' || DESTINATION as Route,
        ORIGIN as Hub,
        TO_CHAR(SCHEDULED_DEPARTURE_TIME, 'HH24:MI') as Departure,
        CASE 
            WHEN STATUS = 'ON_TIME' OR STATUS = 'SCHEDULED' THEN '🟢 On Time'
            WHEN STATUS = 'DELAYED' THEN '🟡 Delayed (' || COALESCE(DEPARTURE_DELAY_MINUTES, 0) || ' min)'
            WHEN STATUS = 'CANCELLED' THEN '🔴 Cancelled'
            WHEN STATUS = 'BOARDING' THEN '🟢 Boarding'
            WHEN STATUS = 'IN_FLIGHT' THEN '🔵 In Flight'
            ELSE '⚪ ' || STATUS
        END as Status,
        AIRCRAFT_REGISTRATION as Aircraft,
        CAPTAIN_NAME as Captain,
        CASE 
            WHEN STATUS = 'CANCELLED' THEN 0
            WHEN STATUS = 'DELAYED' THEN GREATEST(50, 100 - COALESCE(DEPARTURE_DELAY_MINUTES, 0))
            ELSE 95
        END as "Health Score"
    FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
    WHERE {date_filter} {hub_clause} {status_clause}
    ORDER BY SCHEDULED_DEPARTURE_TIME
    LIMIT 50
    """
    
    flights_df = run_query(flights_query)
    
    if flights_df is not None and len(flights_df) > 0:
        st.info(f"Showing {len(flights_df)} flights from Snowflake (filtered)")
        st.dataframe(flights_df, use_container_width=True)
    else:
        all_flights = pd.DataFrame({
            "Flight": ["PH1234", "PH2567", "PH3890", "PH4123", "PH5678", "PH6901", "PH7234", "PH8567"],
            "Route": ["ATL → JFK", "DTW → LAX", "MSP → SEA", "SLC → DEN", "JFK → MIA", "ATL → ORD", "LAX → SEA", "BOS → JFK"],
            "Hub": ["ATL", "DTW", "MSP", "SLC", "JFK", "ATL", "LAX", "BOS"],
            "Departure": ["14:30", "14:45", "15:00", "15:15", "15:30", "15:45", "16:00", "16:15"],
            "Status": ["🟢 On Time", "🟡 Delayed (23 min)", "🟢 On Time", "🔴 Cancelled", "🟡 Delayed (45 min)", "🟢 Boarding", "🟢 On Time", "🟢 On Time"],
            "Aircraft": ["N3102PH", "N9145PH", "N3210PH", "N2156PH", "N5723PH", "N3108PH", "N4521PH", "N6234PH"],
            "Captain": ["J. Smith", "M. Johnson", "R. Davis", "—", "K. Wilson", "A. Brown", "T. Lee", "S. Park"],
            "Health Score": [95, 72, 88, 0, 65, 91, 89, 94]
        })
        filtered_flights = all_flights.copy()
        if hub_filter != "All Hubs":
            filtered_flights = filtered_flights[filtered_flights["Hub"] == hub_filter]
        st.info(f"Showing {len(filtered_flights)} flights (mock data - Snowflake unavailable)")
        st.dataframe(filtered_flights, use_container_width=True)

with tab2:
    is_7day = time_filter == "Last 7 Days"
    chart_title = "On-Time Performance Trend (Last 7 Days)" if is_7day else "On-Time Performance Trend (Today Hourly)"
    st.subheader(chart_title)
    
    if is_7day:
        otp_query = """
        SELECT 
            TO_CHAR(FLIGHT_DATE, 'MM/DD') as Date,
            ROUND(100.0 * COUNT(CASE WHEN STATUS NOT IN ('DELAYED', 'CANCELLED') THEN 1 END) / NULLIF(COUNT(*), 0), 1) as "OTP %",
            85 as Target
        FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
        WHERE FLIGHT_DATE BETWEEN DATEADD('day', -7, CURRENT_DATE()) AND CURRENT_DATE()
        GROUP BY FLIGHT_DATE
        ORDER BY FLIGHT_DATE
        """
    else:
        otp_query = f"""
        SELECT 
            TO_CHAR(HOUR(SCHEDULED_DEPARTURE_TIME), 'FM00') || ':00' as Hour,
            ROUND(100.0 * COUNT(CASE WHEN STATUS NOT IN ('DELAYED', 'CANCELLED') THEN 1 END) / NULLIF(COUNT(*), 0), 1) as "OTP %",
            85 as Target
        FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
        WHERE {date_filter}
        GROUP BY HOUR(SCHEDULED_DEPARTURE_TIME)
        ORDER BY HOUR(SCHEDULED_DEPARTURE_TIME)
        """
    
    otp_df = run_query(otp_query)
    
    if otp_df is not None and len(otp_df) > 0:
        if is_7day:
            st.line_chart(otp_df.set_index("Date")[["OTP %", "Target"]])
        else:
            st.line_chart(otp_df.set_index("Hour")[["OTP %", "Target"]])
    else:
        if is_7day:
            chart_data = pd.DataFrame({
                "Date": pd.date_range(end=pd.Timestamp.today(), periods=7).strftime('%m/%d'),
                "OTP %": [84.2, 82.1, 79.8, 81.5, 83.2, 85.6, 82.4],
                "Target": [85, 85, 85, 85, 85, 85, 85]
            })
            st.line_chart(chart_data.set_index("Date"))
        else:
            chart_data = pd.DataFrame({
                "Hour": ["06:00", "08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"],
                "OTP %": [94, 89, 85, 78, 72, 68, 71, 82],
                "Target": [85, 85, 85, 85, 85, 85, 85, 85]
            })
            st.line_chart(chart_data.set_index("Hour"))
    
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Delay Distribution by Cause")
        delay_query = f"""
        SELECT 
            COALESCE(DELAY_REASON, 'Unknown') as Cause,
            COUNT(*) as Count
        FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
        WHERE {date_filter} AND STATUS = 'DELAYED'
        GROUP BY DELAY_REASON
        ORDER BY Count DESC
        """
        delay_df = run_query(delay_query)
        if delay_df is not None and len(delay_df) > 0:
            st.bar_chart(delay_df.set_index("Cause"))
        else:
            delay_causes = pd.DataFrame({
                "Cause": ["Weather", "Crew", "Mechanical", "ATC", "Ground Ops"],
                "Count": [45, 32, 28, 21, 14]
            })
            st.bar_chart(delay_causes.set_index("Cause"))
    
    with col2:
        st.subheader("Cancellations by Hub")
        cancel_query = f"""
        SELECT 
            ORIGIN as Hub,
            COUNT(*) as Cancellations
        FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
        WHERE {date_filter} AND STATUS = 'CANCELLED'
        GROUP BY ORIGIN
        ORDER BY Cancellations DESC
        LIMIT 5
        """
        cancel_df = run_query(cancel_query)
        if cancel_df is not None and len(cancel_df) > 0:
            st.bar_chart(cancel_df.set_index("Hub"))
        else:
            cancel_data = pd.DataFrame({
                "Hub": ["ATL", "DTW", "MSP", "JFK", "LAX"],
                "Cancellations": [12, 8, 5, 6, 3]
            })
            st.bar_chart(cancel_data.set_index("Hub"))

with tab3:
    st.subheader("Hub Operational Status")
    
    hub_query = f"""
    SELECT 
        ORIGIN as Hub,
        CASE 
            WHEN COUNT(CASE WHEN STATUS = 'DELAYED' THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0) > 0.3 THEN '🔴 Critical'
            WHEN COUNT(CASE WHEN STATUS = 'DELAYED' THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0) > 0.15 THEN '🟡 Warning'
            ELSE '🟢 Normal'
        END as Status,
        COUNT(*) as Flights,
        ROUND(100.0 * COUNT(CASE WHEN STATUS NOT IN ('DELAYED', 'CANCELLED') THEN 1 END) / NULLIF(COUNT(*), 0), 0) as "OTP %",
        COUNT(DISTINCT CAPTAIN_ID) as "Available Crew",
        COUNT(DISTINCT AIRCRAFT_REGISTRATION) as "Available Aircraft"
    FROM PHANTOM_IROPS.STAGING.STG_FLIGHTS
    WHERE {date_filter}
    GROUP BY ORIGIN
    ORDER BY Flights DESC
    """
    
    hub_df = run_query(hub_query)
    
    if hub_df is not None and len(hub_df) > 0:
        if hub_filter != "All Hubs":
            hub_df = hub_df[hub_df["Hub"] == hub_filter]
        st.dataframe(hub_df, use_container_width=True)
    else:
        hub_data = pd.DataFrame({
            "Hub": ["ATL", "DTW", "MSP", "SLC", "SEA", "LAX", "JFK", "BOS"],
            "Status": ["🟢 Normal", "🟢 Normal", "🟡 Warning", "🟢 Normal", "🟢 Normal", "🟢 Normal", "🟡 Warning", "🟢 Normal"],
            "Flights": [342, 156, 134, 98, 112, 187, 203, 89],
            "OTP %": [84, 82, 71, 88, 86, 83, 74, 87],
            "Available Crew": [245, 112, 98, 67, 78, 134, 156, 67],
            "Available Aircraft": [89, 45, 38, 28, 32, 52, 58, 24]
        })
        if hub_filter != "All Hubs":
            hub_data = hub_data[hub_data["Hub"] == hub_filter]
        st.dataframe(hub_data, use_container_width=True)
