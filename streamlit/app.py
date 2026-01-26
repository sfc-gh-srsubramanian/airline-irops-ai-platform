"""
Phantom Airlines IROPS Platform
================================
Main Streamlit application for the IROPS Operations Control Center
"""
import streamlit as st

st.set_page_config(
    page_title="Phantom Airlines IROPS Platform",
    page_icon="✈️",
    layout="wide",
    initial_sidebar_state="expanded"
)

SNOWFLAKE_BLUE = "#29B5E8"
DARK_BLUE = "#1E3A5F"
LIGHT_BLUE = "#E8F4FC"



st.markdown(f"""
<style>
    .main-header {{
        background: linear-gradient(135deg, {DARK_BLUE} 0%, {SNOWFLAKE_BLUE} 100%);
        padding: 2rem;
        border-radius: 10px;
        margin-bottom: 2rem;
    }}
    .main-header h1 {{
        color: white;
        margin: 0;
    }}
    .main-header p {{
        color: {LIGHT_BLUE};
        margin: 0.5rem 0 0 0;
    }}
    .metric-card {{
        background: white;
        padding: 1.5rem;
        border-radius: 8px;
        border-left: 4px solid {SNOWFLAKE_BLUE};
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }}
    .critical {{
        border-left-color: #FF4B4B !important;
    }}
    .warning {{
        border-left-color: #FFA500 !important;
    }}
    .success {{
        border-left-color: #00CC00 !important;
    }}
    
    /* Sidebar navigation styling */
    [data-testid="stSidebarNav"] {{
        padding-top: 0.5rem;
    }}
    [data-testid="stSidebarNav"] ul {{
        padding-left: 0.5rem;
    }}
    [data-testid="stSidebarNav"] li > a {{
        padding: 0.5rem 1rem;
        border-radius: 8px;
        margin: 2px 8px;
        transition: background 0.2s;
    }}
    [data-testid="stSidebarNav"] li > a:hover {{
        background: {LIGHT_BLUE};
    }}
    [data-testid="stSidebarNav"] li > a[aria-selected="true"] {{
        background: linear-gradient(90deg, {DARK_BLUE}, {SNOWFLAKE_BLUE});
        color: white !important;
    }}
    
    /* Quick Navigation link styling */
    .stMarkdown h3 a {{
        color: {DARK_BLUE};
        text-decoration: none;
        transition: color 0.2s;
    }}
    .stMarkdown h3 a:hover {{
        color: {SNOWFLAKE_BLUE};
        text-decoration: underline;
    }}
    
    /* Compact sidebar metrics */
    [data-testid="stSidebar"] [data-testid="stMetricValue"] {{
        font-size: 1.3rem;
    }}
    [data-testid="stSidebar"] [data-testid="stMetricLabel"] {{
        font-size: 0.8rem;
    }}
</style>
""", unsafe_allow_html=True)

st.markdown("""
<div class="main-header">
    <h1>✈️ Phantom Airlines IROPS Platform</h1>
    <p>AI-Powered Irregular Operations Management</p>
</div>
""", unsafe_allow_html=True)

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.markdown("""
    <div class="metric-card success">
        <h3 style="margin:0; color:#666;">Network Health</h3>
        <h1 style="margin:0; color:#00CC00;">87.3%</h1>
        <p style="margin:0; color:#888;">↑ 2.1% from yesterday</p>
    </div>
    """, unsafe_allow_html=True)

with col2:
    st.markdown("""
    <div class="metric-card">
        <h3 style="margin:0; color:#666;">Active Disruptions</h3>
        <h1 style="margin:0; color:#1E3A5F;">24</h1>
        <p style="margin:0; color:#888;">3 critical, 7 severe</p>
    </div>
    """, unsafe_allow_html=True)

with col3:
    st.markdown("""
    <div class="metric-card warning">
        <h3 style="margin:0; color:#666;">Ghost Flights</h3>
        <h1 style="margin:0; color:#FFA500;">5</h1>
        <p style="margin:0; color:#888;">Aircraft-crew mismatch</p>
    </div>
    """, unsafe_allow_html=True)

with col4:
    st.markdown("""
    <div class="metric-card critical">
        <h3 style="margin:0; color:#666;">Flights Needing Crew</h3>
        <h1 style="margin:0; color:#FF4B4B;">12</h1>
        <p style="margin:0; color:#888;">8 captains, 4 FOs needed</p>
    </div>
    """, unsafe_allow_html=True)

st.markdown("---")

st.subheader("📍 Quick Navigation")
st.caption("👈 Use the sidebar to navigate between pages")

col1, col2, col3 = st.columns(3)

with col1:
    st.markdown("""
    <div style="background: white; padding: 1rem; border-radius: 8px; border-left: 4px solid #29B5E8; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h4 style="color: #1E3A5F; margin: 0 0 0.5rem 0;">📊 Operations Dashboard</h4>
        <p style="color: #666; font-size: 0.9rem; margin: 0 0 0.5rem 0;">Real-time flight status, OTP metrics, and network overview.</p>
        <p style="color: #888; font-size: 0.8rem; margin: 0;">• Live flight tracking<br>• Delay analysis<br>• Hub capacity monitoring</p>
    </div>
    """, unsafe_allow_html=True)

with col2:
    st.markdown("""
    <div style="background: white; padding: 1rem; border-radius: 8px; border-left: 4px solid #29B5E8; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h4 style="color: #1E3A5F; margin: 0 0 0.5rem 0;">👨‍✈️ Crew Recovery</h4>
        <p style="color: #666; font-size: 0.9rem; margin: 0 0 0.5rem 0;">AI-powered crew reassignment with batch notifications.</p>
        <p style="color: #888; font-size: 0.8rem; margin: 0;">• ML-ranked candidates<br>• Contract validation<br>• Batch notifications</p>
    </div>
    """, unsafe_allow_html=True)

with col3:
    st.markdown("""
    <div style="background: white; padding: 1rem; border-radius: 8px; border-left: 4px solid #29B5E8; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h4 style="color: #1E3A5F; margin: 0 0 0.5rem 0;">👻 Ghost Planes</h4>
        <p style="color: #666; font-size: 0.9rem; margin: 0 0 0.5rem 0;">Identify aircraft-crew synchronization gaps.</p>
        <p style="color: #888; font-size: 0.8rem; margin: 0;">• Real-time detection<br>• Location mismatch alerts<br>• Resolution workflow</p>
    </div>
    """, unsafe_allow_html=True)

col4, col5, col6 = st.columns(3)

with col4:
    st.markdown("""
    <div style="background: white; padding: 1rem; border-radius: 8px; border-left: 4px solid #FFA500; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h4 style="color: #1E3A5F; margin: 0 0 0.5rem 0;">⚠️ Disruption Analysis</h4>
        <p style="color: #666; font-size: 0.9rem; margin: 0 0 0.5rem 0;">Track and analyze IROPS events across the network.</p>
        <p style="color: #888; font-size: 0.8rem; margin: 0;">• Event timeline<br>• Cost analysis<br>• Cascading impact</p>
    </div>
    """, unsafe_allow_html=True)

with col5:
    st.markdown("""
    <div style="background: white; padding: 1rem; border-radius: 8px; border-left: 4px solid #29B5E8; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h4 style="color: #1E3A5F; margin: 0 0 0.5rem 0;">📋 Contract Bot</h4>
        <p style="color: #666; font-size: 0.9rem; margin: 0 0 0.5rem 0;">AI-powered PWA and FAA compliance validation.</p>
        <p style="color: #888; font-size: 0.8rem; margin: 0;">• Crew legality checks<br>• Natural language queries<br>• Rule reference</p>
    </div>
    """, unsafe_allow_html=True)

with col6:
    st.markdown("""
    <div style="background: white; padding: 1rem; border-radius: 8px; border-left: 4px solid #29B5E8; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h4 style="color: #1E3A5F; margin: 0 0 0.5rem 0;">🤖 Intelligence Agent</h4>
        <p style="color: #666; font-size: 0.9rem; margin: 0 0 0.5rem 0;">Conversational AI for operations queries.</p>
        <p style="color: #888; font-size: 0.8rem; margin: 0;">• Natural language Q&A<br>• Historical analysis<br>• Recommendations</p>
    </div>
    """, unsafe_allow_html=True)

st.markdown("---")

st.subheader("🔔 Recent Alerts")

alerts = [
    {"time": "2 min ago", "type": "CRITICAL", "message": "Ground stop issued at ATL due to thunderstorms"},
    {"time": "15 min ago", "type": "WARNING", "message": "Captain needed for PH1234 ATL-JFK departing 14:30"},
    {"time": "32 min ago", "type": "INFO", "message": "Weather improving at MSP, delays expected to decrease"},
    {"time": "1 hr ago", "type": "WARNING", "message": "Aircraft N3102PH MEL item reported at DTW"},
]

for alert in alerts:
    color = "#FF4B4B" if alert["type"] == "CRITICAL" else "#FFA500" if alert["type"] == "WARNING" else SNOWFLAKE_BLUE
    st.markdown(f"""
    <div style="padding: 0.5rem 1rem; margin: 0.5rem 0; border-left: 3px solid {color}; background: white;">
        <span style="color: {color}; font-weight: bold;">[{alert["type"]}]</span>
        <span style="color: #666; margin-left: 1rem;">{alert["time"]}</span>
        <span style="margin-left: 1rem;">{alert["message"]}</span>
    </div>
    """, unsafe_allow_html=True)

st.sidebar.markdown("<br>", unsafe_allow_html=True)
st.sidebar.markdown("#### ⚡ Quick Stats")
col1, col2, col3 = st.sidebar.columns(3)
col1.metric("Flights", "1,423", "↑45")
col2.metric("OTP", "82.4%", "↓3.2%")
col3.metric("Crew", "847", "↓23")

st.sidebar.markdown("---")
st.sidebar.markdown("#### 🏢 Hub Status")
hub_html = """
<div style="display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 4px; padding: 4px 0;">
    <div style="background: #e8f5e9; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟢 ATL</div>
    <div style="background: #e8f5e9; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟢 DTW</div>
    <div style="background: #fff8e1; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟡 MSP</div>
    <div style="background: #e8f5e9; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟢 SLC</div>
    <div style="background: #e8f5e9; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟢 SEA</div>
    <div style="background: #e8f5e9; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟢 LAX</div>
    <div style="background: #fff8e1; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟡 JFK</div>
    <div style="background: #e8f5e9; padding: 4px 6px; border-radius: 4px; text-align: center; font-size: 0.75rem;">🟢 BOS</div>
</div>
"""
st.sidebar.markdown(hub_html, unsafe_allow_html=True)
