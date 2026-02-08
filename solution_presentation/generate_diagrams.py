#!/usr/bin/env python3
"""
Generate Snowflake-branded diagrams for IROPS Solution Overview
Blue and white theme matching Snowflake brand guidelines
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Rectangle
import numpy as np
import os

# Snowflake Brand Colors
COLORS = {
    'primary_blue': '#29B5E8',      # Snowflake cyan
    'dark_blue': '#1E3A5F',         # Headers, text
    'light_blue': '#E8F4FC',        # Backgrounds
    'white': '#FFFFFF',             # Cards, containers
    'accent_blue': '#0D47A1',       # Deep blue for emphasis
    'gray': '#6E7681',              # Secondary text
    'light_gray': '#F5F7FA',        # Subtle backgrounds
    'medium_blue': '#4FB8E8',       # Intermediate blue
    'pale_blue': '#B8E2F2',         # Very light blue
}

def setup_figure(figsize=(14, 10)):
    """Create a figure with Snowflake styling"""
    fig, ax = plt.subplots(figsize=figsize, facecolor=COLORS['white'])
    ax.set_facecolor(COLORS['white'])
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')
    return fig, ax

def draw_box(ax, x, y, width, height, label, color=None, text_color=None, fontsize=10, sublabel=None):
    """Draw a rounded box with label"""
    if color is None:
        color = COLORS['primary_blue']
    if text_color is None:
        text_color = COLORS['white']
    
    box = FancyBboxPatch(
        (x - width/2, y - height/2), width, height,
        boxstyle="round,pad=0.02,rounding_size=0.5",
        facecolor=color,
        edgecolor=COLORS['dark_blue'],
        linewidth=2
    )
    ax.add_patch(box)
    
    if sublabel:
        ax.text(x, y + 1.5, label, ha='center', va='center', fontsize=fontsize, 
                fontweight='bold', color=text_color)
        ax.text(x, y - 1.5, sublabel, ha='center', va='center', fontsize=fontsize-2, 
                color=text_color, style='italic')
    else:
        ax.text(x, y, label, ha='center', va='center', fontsize=fontsize, 
                fontweight='bold', color=text_color, wrap=True)

def draw_arrow(ax, start, end, color=None):
    """Draw an arrow between two points"""
    if color is None:
        color = COLORS['dark_blue']
    
    ax.annotate('', xy=end, xytext=start,
                arrowprops=dict(arrowstyle='->', color=color, lw=2))

def draw_section_header(ax, y, label, width=96):
    """Draw a section header bar"""
    rect = FancyBboxPatch(
        (2, y - 2), width, 4,
        boxstyle="round,pad=0.01,rounding_size=0.3",
        facecolor=COLORS['dark_blue'],
        edgecolor='none'
    )
    ax.add_patch(rect)
    ax.text(50, y, label, ha='center', va='center', fontsize=12, 
            fontweight='bold', color=COLORS['white'])

def create_architecture_diagram():
    """Create the main architecture overview diagram"""
    fig, ax = setup_figure(figsize=(16, 12))
    
    # Title
    ax.text(50, 97, 'Phantom Airlines IROPS Platform Architecture', 
            ha='center', va='center', fontsize=18, fontweight='bold', 
            color=COLORS['dark_blue'])
    ax.text(50, 94, 'AI-Powered Irregular Operations Management on Snowflake', 
            ha='center', va='center', fontsize=11, color=COLORS['gray'])
    
    # Layer 1: User Interface (Top)
    draw_section_header(ax, 88, 'USER INTERFACE LAYER')
    ui_components = [
        ('Operations\nDashboard', 15), ('Crew\nRecovery', 30), ('Ghost\nPlanes', 45),
        ('Disruption\nAnalysis', 60), ('Contract\nBot', 75), ('Intelligence\nAgent', 90)
    ]
    for label, x in ui_components:
        draw_box(ax, x, 81, 12, 6, label, COLORS['primary_blue'], fontsize=8)
    
    # Layer 2: Snowflake Cortex AI
    draw_section_header(ax, 72, 'SNOWFLAKE CORTEX AI LAYER')
    ai_components = [
        ('Cortex\nAnalyst', 20, 'Text-to-SQL'),
        ('Cortex\nSearch', 40, 'Pattern Match'),
        ('Intelligence\nAgents', 60, 'Conversational'),
        ('Cortex ML\nFunctions', 80, 'AI_CLASSIFY')
    ]
    for label, x, sublabel in ai_components:
        draw_box(ax, x, 64, 16, 7, label, COLORS['medium_blue'], fontsize=9, sublabel=sublabel)
    
    # Layer 3: Semantic Models
    draw_section_header(ax, 54, 'SEMANTIC MODELS LAYER')
    semantic_components = [
        'IROPS\nAnalytics', 'Flight\nOperations', 'Crew\nManagement', 'Network\nHealth'
    ]
    for i, label in enumerate(semantic_components):
        x = 18 + i * 22
        draw_box(ax, x, 46, 18, 6, label, COLORS['pale_blue'], COLORS['dark_blue'], fontsize=9)
    
    # Layer 4: Dynamic Tables Pipeline
    draw_section_header(ax, 37, 'DYNAMIC TABLES PIPELINE (1-min latency)')
    
    # Staging
    draw_box(ax, 15, 29, 14, 6, 'STAGING', COLORS['light_blue'], COLORS['dark_blue'], fontsize=9)
    ax.text(15, 25, '5 DTs', ha='center', fontsize=7, color=COLORS['gray'])
    
    # Arrow
    draw_arrow(ax, (22, 29), (28, 29))
    
    # Intermediate  
    draw_box(ax, 38, 29, 16, 6, 'INTERMEDIATE', COLORS['light_blue'], COLORS['dark_blue'], fontsize=9)
    ax.text(38, 25, '2 DTs', ha='center', fontsize=7, color=COLORS['gray'])
    
    # Arrow
    draw_arrow(ax, (46, 29), (52, 29))
    
    # Analytics with Golden Record highlight
    analytics_box = FancyBboxPatch(
        (52, 24), 34, 12,
        boxstyle="round,pad=0.02,rounding_size=0.5",
        facecolor=COLORS['light_blue'],
        edgecolor=COLORS['primary_blue'],
        linewidth=3
    )
    ax.add_patch(analytics_box)
    ax.text(69, 32, 'ANALYTICS', ha='center', va='center', fontsize=10, 
            fontweight='bold', color=COLORS['dark_blue'])
    
    # Golden Record inside Analytics
    golden_box = FancyBboxPatch(
        (56, 26), 26, 6,
        boxstyle="round,pad=0.01,rounding_size=0.3",
        facecolor=COLORS['primary_blue'],
        edgecolor=COLORS['dark_blue'],
        linewidth=2
    )
    ax.add_patch(golden_box)
    ax.text(69, 29, 'GOLDEN RECORD', ha='center', va='center', fontsize=9, 
            fontweight='bold', color=COLORS['white'])
    ax.text(69, 26.5, '(Unified Truth)', ha='center', va='center', fontsize=7, 
            color=COLORS['white'], style='italic')
    
    # Layer 5: Raw Data Layer
    draw_section_header(ax, 16, 'RAW DATA LAYER')
    raw_components = ['Flights', 'Crew', 'Aircraft', 'Weather', 'Disruptions', 'Passengers']
    for i, label in enumerate(raw_components):
        x = 12 + i * 14
        draw_box(ax, x, 8, 12, 5, label, COLORS['light_gray'], COLORS['dark_blue'], fontsize=8)
    
    # Draw vertical arrows between layers
    arrow_positions = [20, 40, 60, 80]
    for x in arrow_positions:
        draw_arrow(ax, (x, 78), (x, 75))  # UI to AI
        draw_arrow(ax, (x, 60), (x, 57))  # AI to Semantic
        draw_arrow(ax, (x, 42), (x, 39))  # Semantic to DT
    
    draw_arrow(ax, (50, 21), (50, 18))  # DT to Raw
    
    plt.tight_layout()
    return fig

def create_data_pipeline_diagram():
    """Create the medallion/data pipeline architecture diagram"""
    fig, ax = setup_figure(figsize=(16, 10))
    
    # Title
    ax.text(50, 96, 'Dynamic Tables Pipeline Architecture', 
            ha='center', va='center', fontsize=18, fontweight='bold', 
            color=COLORS['dark_blue'])
    ax.text(50, 92, 'Real-Time Data Transformation with 1-Minute Latency', 
            ha='center', va='center', fontsize=11, color=COLORS['gray'])
    
    # RAW Layer
    raw_y = 75
    raw_box = FancyBboxPatch((5, raw_y - 8), 20, 16, boxstyle="round,pad=0.02,rounding_size=0.5",
                              facecolor=COLORS['light_gray'], edgecolor=COLORS['gray'], linewidth=2)
    ax.add_patch(raw_box)
    ax.text(15, raw_y + 5, 'RAW', ha='center', fontsize=12, fontweight='bold', color=COLORS['dark_blue'])
    
    raw_tables = ['FLIGHTS', 'CREW', 'AIRCRAFT', 'WEATHER', 'DISRUPTIONS', 'PASSENGERS']
    for i, table in enumerate(raw_tables):
        y_pos = raw_y + 2 - i * 2.5
        ax.text(15, y_pos, f'• {table}', ha='center', fontsize=7, color=COLORS['gray'])
    
    # Arrow RAW to STAGING
    draw_arrow(ax, (26, raw_y), (32, raw_y), COLORS['primary_blue'])
    
    # STAGING Layer
    staging_y = 75
    staging_box = FancyBboxPatch((33, staging_y - 8), 18, 16, boxstyle="round,pad=0.02,rounding_size=0.5",
                                  facecolor=COLORS['pale_blue'], edgecolor=COLORS['primary_blue'], linewidth=2)
    ax.add_patch(staging_box)
    ax.text(42, staging_y + 5, 'STAGING', ha='center', fontsize=12, fontweight='bold', color=COLORS['dark_blue'])
    
    staging_tables = ['STG_FLIGHTS', 'STG_CREW', 'STG_AIRCRAFT', 'STG_WEATHER', 'STG_DISRUPTIONS']
    for i, table in enumerate(staging_tables):
        y_pos = staging_y + 2 - i * 2.5
        ax.text(42, y_pos, f'• {table}', ha='center', fontsize=7, color=COLORS['dark_blue'])
    
    # Arrow STAGING to INTERMEDIATE
    draw_arrow(ax, (52, raw_y), (58, raw_y), COLORS['primary_blue'])
    
    # INTERMEDIATE Layer
    int_y = 75
    int_box = FancyBboxPatch((59, int_y - 8), 18, 16, boxstyle="round,pad=0.02,rounding_size=0.5",
                              facecolor=COLORS['light_blue'], edgecolor=COLORS['primary_blue'], linewidth=2)
    ax.add_patch(int_box)
    ax.text(68, int_y + 5, 'INTERMEDIATE', ha='center', fontsize=11, fontweight='bold', color=COLORS['dark_blue'])
    
    int_tables = ['INT_CREW_AIRCRAFT', 'INT_FLIGHT_DISRUPTION']
    for i, table in enumerate(int_tables):
        y_pos = int_y + 1 - i * 3
        ax.text(68, y_pos, f'• {table}', ha='center', fontsize=7, color=COLORS['dark_blue'])
    
    # Arrow INTERMEDIATE to ANALYTICS
    draw_arrow(ax, (78, raw_y), (84, raw_y), COLORS['primary_blue'])
    
    # ANALYTICS Layer (highlighted)
    analytics_y = 75
    analytics_box = FancyBboxPatch((85, analytics_y - 8), 12, 16, boxstyle="round,pad=0.02,rounding_size=0.5",
                                    facecolor=COLORS['primary_blue'], edgecolor=COLORS['dark_blue'], linewidth=3)
    ax.add_patch(analytics_box)
    ax.text(91, analytics_y + 5, 'ANALYTICS', ha='center', fontsize=11, fontweight='bold', color=COLORS['white'])
    
    analytics_tables = ['GOLDEN_RECORD', 'CREW_RECOVERY', 'OPS_SUMMARY']
    for i, table in enumerate(analytics_tables):
        y_pos = analytics_y + 1 - i * 3
        ax.text(91, y_pos, f'• {table}', ha='center', fontsize=7, color=COLORS['white'])
    
    # Golden Record Detail Box
    golden_y = 40
    golden_detail = FancyBboxPatch((25, golden_y - 12), 50, 24, boxstyle="round,pad=0.02,rounding_size=0.5",
                                    facecolor=COLORS['white'], edgecolor=COLORS['primary_blue'], linewidth=3)
    ax.add_patch(golden_detail)
    ax.text(50, golden_y + 9, 'MART_GOLDEN_RECORD', ha='center', fontsize=14, 
            fontweight='bold', color=COLORS['dark_blue'])
    ax.text(50, golden_y + 5, 'Unified Operational View - Eliminates Ghost Flights', 
            ha='center', fontsize=9, color=COLORS['gray'], style='italic')
    
    golden_fields = [
        ('Flight Status', 'Real-time status + delays'),
        ('Aircraft Location', 'Actual GPS vs scheduled'),
        ('Crew Position', 'Badge swipes + app check-ins'),
        ('Weather Impact', 'Origin/destination conditions'),
        ('Ghost Flag', 'is_ghost_flight detection'),
    ]
    for i, (field, desc) in enumerate(golden_fields):
        y_pos = golden_y + 1 - i * 4
        ax.text(32, y_pos, f'{field}:', ha='left', fontsize=9, fontweight='bold', color=COLORS['dark_blue'])
        ax.text(50, y_pos, desc, ha='left', fontsize=8, color=COLORS['gray'])
    
    # Arrow from Analytics to Golden Record detail
    draw_arrow(ax, (91, 58), (91, 54), COLORS['primary_blue'])
    draw_arrow(ax, (91, 54), (75, 44), COLORS['primary_blue'])
    
    # Refresh indicator
    ax.text(50, 18, '⟳ Target Lag: 1 minute  |  Refresh Mode: AUTO  |  Downstream: ON_CHANGE', 
            ha='center', fontsize=10, color=COLORS['primary_blue'], fontweight='bold')
    
    plt.tight_layout()
    return fig

def create_ml_capabilities_diagram():
    """Create the ML models and AI capabilities diagram"""
    fig, ax = setup_figure(figsize=(16, 10))
    
    # Title
    ax.text(50, 96, 'Machine Learning & AI Capabilities', 
            ha='center', va='center', fontsize=18, fontweight='bold', 
            color=COLORS['dark_blue'])
    ax.text(50, 92, 'Predictive Analytics and Intelligent Automation', 
            ha='center', va='center', fontsize=11, color=COLORS['gray'])
    
    # ML Models Section
    ax.text(25, 85, 'ML MODELS', ha='center', fontsize=14, fontweight='bold', color=COLORS['dark_blue'])
    
    models = [
        ('Delay Prediction', 'XGBoost Classifier', ['Flight schedule features', 'Weather conditions', 'Historical patterns'], 'Probability + Category'),
        ('Crew Ranking', 'LightGBM Classifier', ['Proximity score', 'Duty hours remaining', 'Acceptance history'], 'Ranked candidates'),
        ('Cost Estimation', 'XGBoost Regressor', ['Disruption type', 'Severity level', 'Passenger impact'], 'Dollar estimate'),
    ]
    
    for i, (name, model_type, features, output) in enumerate(models):
        y = 72 - i * 20
        
        # Model box
        model_box = FancyBboxPatch((5, y - 6), 40, 14, boxstyle="round,pad=0.02,rounding_size=0.5",
                                    facecolor=COLORS['light_blue'], edgecolor=COLORS['primary_blue'], linewidth=2)
        ax.add_patch(model_box)
        
        ax.text(25, y + 5, name, ha='center', fontsize=11, fontweight='bold', color=COLORS['dark_blue'])
        ax.text(25, y + 2, f'({model_type})', ha='center', fontsize=8, color=COLORS['gray'], style='italic')
        
        for j, feature in enumerate(features):
            ax.text(10, y - 1 - j * 2.5, f'• {feature}', ha='left', fontsize=7, color=COLORS['dark_blue'])
        
        ax.text(40, y - 2, f'→ {output}', ha='left', fontsize=8, color=COLORS['primary_blue'], fontweight='bold')
    
    # AI Functions Section
    ax.text(75, 85, 'CORTEX AI FUNCTIONS', ha='center', fontsize=14, fontweight='bold', color=COLORS['dark_blue'])
    
    ai_functions = [
        ('Contract Bot', 'COMPLETE', 'Validates crew assignments against\nFAA Part 117 + Union PWA rules', '#29B5E8'),
        ('Disruption Classifier', 'CLASSIFY', 'Categorizes incidents by type,\nseverity, and root cause', '#4FB8E8'),
        ('Pattern Matcher', 'SIMILARITY', 'Finds historical incidents\nwith similar characteristics', '#B8E2F2'),
    ]
    
    for i, (name, func, desc, color) in enumerate(ai_functions):
        y = 72 - i * 20
        
        func_box = FancyBboxPatch((55, y - 6), 40, 14, boxstyle="round,pad=0.02,rounding_size=0.5",
                                   facecolor=color, edgecolor=COLORS['dark_blue'], linewidth=2)
        ax.add_patch(func_box)
        
        text_color = COLORS['white'] if color == '#29B5E8' else COLORS['dark_blue']
        ax.text(75, y + 5, name, ha='center', fontsize=11, fontweight='bold', color=text_color)
        ax.text(75, y + 1.5, f'AI_{func}()', ha='center', fontsize=9, color=text_color, 
                family='monospace', style='italic')
        ax.text(75, y - 3, desc, ha='center', fontsize=7, color=text_color)
    
    # Feature Store Section
    feature_box = FancyBboxPatch((10, 8), 80, 12, boxstyle="round,pad=0.02,rounding_size=0.5",
                                  facecolor=COLORS['dark_blue'], edgecolor=COLORS['primary_blue'], linewidth=2)
    ax.add_patch(feature_box)
    ax.text(50, 16, 'SNOWFLAKE FEATURE STORE', ha='center', fontsize=12, 
            fontweight='bold', color=COLORS['white'])
    
    entities = ['FLIGHT Entity', 'AIRPORT Entity', 'ROUTE Entity', 'CREW_MEMBER Entity', 'DISRUPTION Entity']
    for i, entity in enumerate(entities):
        x = 18 + i * 16
        ax.text(x, 11, entity, ha='center', fontsize=8, color=COLORS['pale_blue'])
    
    plt.tight_layout()
    return fig

def create_intelligence_diagram():
    """Create the intelligence/agent architecture diagram"""
    fig, ax = setup_figure(figsize=(16, 10))
    
    # Title
    ax.text(50, 96, 'Snowflake Intelligence Architecture', 
            ha='center', va='center', fontsize=18, fontweight='bold', 
            color=COLORS['dark_blue'])
    ax.text(50, 92, 'Conversational AI for Operations Intelligence', 
            ha='center', va='center', fontsize=11, color=COLORS['gray'])
    
    # User Query (top)
    query_box = FancyBboxPatch((30, 80), 40, 8, boxstyle="round,pad=0.02,rounding_size=0.5",
                                facecolor=COLORS['light_gray'], edgecolor=COLORS['gray'], linewidth=2)
    ax.add_patch(query_box)
    ax.text(50, 84, '"What\'s our OTP today?"', ha='center', fontsize=11, 
            color=COLORS['dark_blue'], style='italic')
    ax.text(50, 81, 'Natural Language Query', ha='center', fontsize=8, color=COLORS['gray'])
    
    # Arrow down
    draw_arrow(ax, (50, 79), (50, 73), COLORS['primary_blue'])
    
    # IROPS Assistant Agent
    agent_box = FancyBboxPatch((25, 58), 50, 14, boxstyle="round,pad=0.02,rounding_size=0.5",
                                facecolor=COLORS['primary_blue'], edgecolor=COLORS['dark_blue'], linewidth=3)
    ax.add_patch(agent_box)
    ax.text(50, 68, 'IROPS_ASSISTANT', ha='center', fontsize=14, 
            fontweight='bold', color=COLORS['white'])
    ax.text(50, 64, 'Snowflake Intelligence Agent', ha='center', fontsize=10, 
            color=COLORS['white'], style='italic')
    ax.text(50, 60, 'Orchestrates tools based on query intent', ha='center', fontsize=8, 
            color=COLORS['pale_blue'])
    
    # Three arrows down to tools
    draw_arrow(ax, (35, 57), (20, 48), COLORS['dark_blue'])
    draw_arrow(ax, (50, 57), (50, 48), COLORS['dark_blue'])
    draw_arrow(ax, (65, 57), (80, 48), COLORS['dark_blue'])
    
    # Tool 1: Cortex Analyst
    tool1_box = FancyBboxPatch((5, 30), 30, 18, boxstyle="round,pad=0.02,rounding_size=0.5",
                                facecolor=COLORS['light_blue'], edgecolor=COLORS['primary_blue'], linewidth=2)
    ax.add_patch(tool1_box)
    ax.text(20, 44, 'Cortex Analyst', ha='center', fontsize=11, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(20, 40, 'irops_analytics', ha='center', fontsize=9, color=COLORS['gray'], family='monospace')
    ax.text(20, 36, 'Text-to-SQL via', ha='center', fontsize=8, color=COLORS['dark_blue'])
    ax.text(20, 33, 'Semantic View', ha='center', fontsize=8, color=COLORS['dark_blue'])
    
    # Tool 2: Semantic View
    tool2_box = FancyBboxPatch((35, 30), 30, 18, boxstyle="round,pad=0.02,rounding_size=0.5",
                                facecolor=COLORS['medium_blue'], edgecolor=COLORS['dark_blue'], linewidth=2)
    ax.add_patch(tool2_box)
    ax.text(50, 44, 'Semantic View', ha='center', fontsize=11, fontweight='bold', color=COLORS['white'])
    ax.text(50, 40, 'IROPS_ANALYTICS', ha='center', fontsize=9, color=COLORS['pale_blue'], family='monospace')
    ax.text(50, 36, 'Business definitions', ha='center', fontsize=8, color=COLORS['white'])
    ax.text(50, 33, 'Deterministic SQL', ha='center', fontsize=8, color=COLORS['white'])
    
    # Tool 3: Cortex Search
    tool3_box = FancyBboxPatch((65, 30), 30, 18, boxstyle="round,pad=0.02,rounding_size=0.5",
                                facecolor=COLORS['pale_blue'], edgecolor=COLORS['primary_blue'], linewidth=2)
    ax.add_patch(tool3_box)
    ax.text(80, 44, 'Cortex Search', ha='center', fontsize=11, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(80, 40, 'incident_search', ha='center', fontsize=9, color=COLORS['gray'], family='monospace')
    ax.text(80, 36, 'Historical pattern', ha='center', fontsize=8, color=COLORS['dark_blue'])
    ax.text(80, 33, 'matching', ha='center', fontsize=8, color=COLORS['dark_blue'])
    
    # Data Sources at bottom
    draw_arrow(ax, (20, 29), (20, 20), COLORS['gray'])
    draw_arrow(ax, (50, 29), (50, 20), COLORS['gray'])
    draw_arrow(ax, (80, 29), (80, 20), COLORS['gray'])
    
    # Dynamic Tables
    dt_box = FancyBboxPatch((5, 8), 30, 11, boxstyle="round,pad=0.02,rounding_size=0.5",
                             facecolor=COLORS['light_gray'], edgecolor=COLORS['gray'], linewidth=1)
    ax.add_patch(dt_box)
    ax.text(20, 15, 'Dynamic Tables', ha='center', fontsize=9, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(20, 11, 'GOLDEN_RECORD', ha='center', fontsize=7, color=COLORS['gray'], family='monospace')
    
    # Semantic Model
    sm_box = FancyBboxPatch((35, 8), 30, 11, boxstyle="round,pad=0.02,rounding_size=0.5",
                             facecolor=COLORS['light_gray'], edgecolor=COLORS['gray'], linewidth=1)
    ax.add_patch(sm_box)
    ax.text(50, 15, 'Semantic Model', ha='center', fontsize=9, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(50, 11, 'irops_semantic.yaml', ha='center', fontsize=7, color=COLORS['gray'], family='monospace')
    
    # Historical Data
    hd_box = FancyBboxPatch((65, 8), 30, 11, boxstyle="round,pad=0.02,rounding_size=0.5",
                             facecolor=COLORS['light_gray'], edgecolor=COLORS['gray'], linewidth=1)
    ax.add_patch(hd_box)
    ax.text(80, 15, 'Historical Data', ha='center', fontsize=9, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(80, 11, 'INCIDENTS + LOGS', ha='center', fontsize=7, color=COLORS['gray'], family='monospace')
    
    plt.tight_layout()
    return fig

def main():
    """Generate all diagrams"""
    output_dir = 'solution_presentation/images'
    os.makedirs(output_dir, exist_ok=True)
    
    print("Generating Snowflake-branded IROPS diagrams...")
    
    # Generate each diagram
    diagrams = [
        ('architecture_overview.png', create_architecture_diagram),
        ('data_pipeline.png', create_data_pipeline_diagram),
        ('ml_capabilities.png', create_ml_capabilities_diagram),
        ('intelligence_architecture.png', create_intelligence_diagram),
    ]
    
    for filename, create_func in diagrams:
        print(f"  Creating {filename}...")
        fig = create_func()
        filepath = os.path.join(output_dir, filename)
        fig.savefig(filepath, dpi=150, bbox_inches='tight', 
                    facecolor='white', edgecolor='none')
        plt.close(fig)
        print(f"    Saved to {filepath}")
    
    print("\nAll diagrams generated successfully!")
    print(f"Output directory: {output_dir}")

if __name__ == '__main__':
    main()
