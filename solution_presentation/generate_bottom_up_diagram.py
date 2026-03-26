#!/usr/bin/env python3
"""
Generate bottom-up architecture diagram matching original theme exactly
Data flows from Raw Data (bottom) to Presentation (top)
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle
from matplotlib.lines import Line2D
import matplotlib.patheffects as pe
import os

COLORS = {
    'primary_blue': '#29B5E8',
    'dark_blue': '#1E3A5F',
    'light_blue': '#E8F4FC',
    'white': '#FFFFFF',
    'gray': '#6E7681',
    'light_gray': '#E5E7EB',
    'medium_blue': '#4FB8E8',
    'pale_blue': '#B8E2F2',
    'border_gray': '#D1D5DB',
}

def setup_figure(figsize=(14, 10)):
    fig, ax = plt.subplots(figsize=figsize, facecolor=COLORS['white'])
    ax.set_facecolor(COLORS['white'])
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')
    return fig, ax

def draw_header_bar(ax, y, label, color=None):
    if color is None:
        color = COLORS['primary_blue']
    rect = FancyBboxPatch(
        (5, y - 1.5), 90, 3,
        boxstyle="round,pad=0.01,rounding_size=0.5",
        facecolor=color,
        edgecolor='none'
    )
    ax.add_patch(rect)
    ax.text(50, y, label, ha='center', va='center', fontsize=9, 
            fontweight='bold', color=COLORS['white'])

def draw_airplane_icon(ax, x, y, size=1.2, color=None):
    if color is None:
        color = COLORS['primary_blue']
    ax.plot([x-size, x+size], [y, y], color=color, linewidth=1.5)
    ax.plot([x+size*0.3, x+size], [y+size*0.4, y], color=color, linewidth=1.5)
    ax.plot([x+size*0.3, x+size], [y-size*0.4, y], color=color, linewidth=1.5)
    ax.plot([x-size*0.7, x-size*0.3], [y+size*0.25, y], color=color, linewidth=1.5)
    ax.plot([x-size*0.7, x-size*0.3], [y-size*0.25, y], color=color, linewidth=1.5)

def draw_person_icon(ax, x, y, size=1, color=None):
    if color is None:
        color = COLORS['primary_blue']
    head = Circle((x, y + size*0.6), size*0.35, facecolor=color, edgecolor='none')
    ax.add_patch(head)
    ax.plot([x, x], [y + size*0.25, y - size*0.3], color=color, linewidth=2)
    ax.plot([x - size*0.4, x + size*0.4], [y + size*0.1, y + size*0.1], color=color, linewidth=2)
    ax.plot([x - size*0.3, x], [y - size*0.7, y - size*0.3], color=color, linewidth=2)
    ax.plot([x + size*0.3, x], [y - size*0.7, y - size*0.3], color=color, linewidth=2)

def draw_cloud_icon(ax, x, y, size=1, color=None):
    if color is None:
        color = COLORS['primary_blue']
    c1 = Circle((x - size*0.35, y - size*0.1), size*0.35, facecolor=color, edgecolor='none')
    c2 = Circle((x + size*0.25, y - size*0.1), size*0.4, facecolor=color, edgecolor='none')
    c3 = Circle((x, y + size*0.2), size*0.45, facecolor=color, edgecolor='none')
    ax.add_patch(c1)
    ax.add_patch(c2)
    ax.add_patch(c3)

def draw_warning_icon(ax, x, y, size=1, color=None):
    if color is None:
        color = COLORS['primary_blue']
    triangle = plt.Polygon([[x, y + size*0.6], [x - size*0.5, y - size*0.4], [x + size*0.5, y - size*0.4]], 
                           facecolor='none', edgecolor=color, linewidth=2)
    ax.add_patch(triangle)
    ax.plot([x, x], [y + size*0.25, y - size*0.05], color=color, linewidth=2)
    ax.plot([x, x], [y - size*0.2, y - size*0.25], color=color, linewidth=2)

def draw_clipboard_icon(ax, x, y, size=1, color=None):
    if color is None:
        color = COLORS['primary_blue']
    rect = FancyBboxPatch((x - size*0.4, y - size*0.5), size*0.8, size*1, 
                          boxstyle="round,rounding_size=0.1", facecolor='none', edgecolor=color, linewidth=1.5)
    ax.add_patch(rect)
    clip = FancyBboxPatch((x - size*0.2, y + size*0.4), size*0.4, size*0.2,
                          boxstyle="round,rounding_size=0.05", facecolor=color, edgecolor='none')
    ax.add_patch(clip)

def draw_chart_icon(ax, x, y, size=1, color=None):
    if color is None:
        color = COLORS['primary_blue']
    ax.bar([x - size*0.35, x, x + size*0.35], [size*0.4, size*0.7, size*0.5], 
           width=size*0.25, bottom=y - size*0.5, color=color, edgecolor='none')

def draw_search_icon(ax, x, y, size=1.2, color=None):
    if color is None:
        color = COLORS['primary_blue']
    circle = Circle((x, y + size*0.15), size*0.4, facecolor='none', edgecolor=color, linewidth=2)
    ax.add_patch(circle)
    ax.plot([x + size*0.25, x + size*0.55], [y - size*0.15, y - size*0.5], color=color, linewidth=2)

def draw_robot_icon(ax, x, y, size=1.2, color=None):
    if color is None:
        color = COLORS['primary_blue']
    head = FancyBboxPatch((x - size*0.4, y - size*0.3), size*0.8, size*0.7,
                          boxstyle="round,rounding_size=0.1", facecolor='none', edgecolor=color, linewidth=2)
    ax.add_patch(head)
    ax.plot([x - size*0.2, x - size*0.2], [y + size*0.05, y + size*0.15], color=color, linewidth=2)
    ax.plot([x + size*0.2, x + size*0.2], [y + size*0.05, y + size*0.15], color=color, linewidth=2)
    ax.plot([x, x], [y + size*0.4, y + size*0.6], color=color, linewidth=2)
    c = Circle((x, y + size*0.7), size*0.12, facecolor=color, edgecolor='none')
    ax.add_patch(c)

def draw_brain_icon(ax, x, y, size=1.2, color=None):
    if color is None:
        color = COLORS['primary_blue']
    ax.text(x, y, 'ML', ha='center', va='center', fontsize=10, fontweight='bold', color=color,
            bbox=dict(boxstyle='circle', facecolor='none', edgecolor=color, linewidth=2))

def draw_database_icon(ax, x, y, size=1.2, color=None):
    if color is None:
        color = COLORS['primary_blue']
    from matplotlib.patches import Ellipse
    e1 = Ellipse((x, y + size*0.3), size*0.8, size*0.3, facecolor='none', edgecolor=color, linewidth=2)
    ax.add_patch(e1)
    ax.plot([x - size*0.4, x - size*0.4], [y + size*0.3, y - size*0.3], color=color, linewidth=2)
    ax.plot([x + size*0.4, x + size*0.4], [y + size*0.3, y - size*0.3], color=color, linewidth=2)
    e2 = Ellipse((x, y - size*0.3), size*0.8, size*0.3, facecolor='none', edgecolor=color, linewidth=2)
    ax.add_patch(e2)

def draw_data_box(ax, x, y, label, sublabel, icon_func):
    box = FancyBboxPatch(
        (x - 5.5, y - 4), 11, 8,
        boxstyle="round,pad=0.02,rounding_size=0.3",
        facecolor=COLORS['white'],
        edgecolor=COLORS['border_gray'],
        linewidth=1
    )
    ax.add_patch(box)
    icon_func(ax, x, y + 2, size=1.2)
    ax.text(x, y - 0.5, label, ha='center', va='center', fontsize=7, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(x, y - 2.2, sublabel, ha='center', va='center', fontsize=7, color=COLORS['gray'])

def draw_upward_arrow(ax, x, y_start, y_end):
    ax.annotate('', xy=(x, y_end), xytext=(x, y_start),
                arrowprops=dict(arrowstyle='->', color=COLORS['dark_blue'], lw=1.5))

def draw_horizontal_arrow(ax, x_start, x_end, y):
    ax.annotate('', xy=(x_end, y), xytext=(x_start, y),
                arrowprops=dict(arrowstyle='->', color=COLORS['dark_blue'], lw=1.5))

def create_bottom_up_architecture():
    fig, ax = setup_figure(figsize=(14, 11))
    
    ax.text(37, 97, 'AIRLINE IROPS', ha='right', va='center', fontsize=18, fontweight='bold', color=COLORS['primary_blue'])
    ax.text(38, 97, 'AI PLATFORM ARCHITECTURE', ha='left', va='center', fontsize=18, fontweight='bold', color=COLORS['dark_blue'])
    
    # ========== LAYER 1: RAW DATA (BOTTOM) ==========
    draw_header_bar(ax, 8, 'RAW DATA LAYER')
    
    draw_data_box(ax, 10, 17, 'FLIGHTS', '(500K)', draw_airplane_icon)
    draw_data_box(ax, 24, 17, 'CREW', '(40K)', draw_person_icon)
    draw_data_box(ax, 38, 17, 'AIRCRAFT', '(1000)', draw_airplane_icon)
    draw_data_box(ax, 52, 17, 'WEATHER', '(130K)', draw_cloud_icon)
    draw_data_box(ax, 66, 17, 'DISRUPT.', '(50K)', draw_warning_icon)
    draw_data_box(ax, 80, 17, 'BOOKINGS', '(57K)', draw_clipboard_icon)
    draw_data_box(ax, 94, 17, 'HISTORY', '(5)', draw_chart_icon)
    
    draw_upward_arrow(ax, 50, 22, 27)
    
    # ========== LAYER 2: DATA PIPELINE ==========
    draw_header_bar(ax, 30, 'DATA PIPELINE LAYER (Chained Dynamic Tables – 1 min lag)')
    
    staging_box = FancyBboxPatch((5, 33.5), 26, 13, boxstyle="round,pad=0.02,rounding_size=0.3",
                                  facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(staging_box)
    ax.text(18, 44, 'STAGING', ha='center', fontsize=9, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(12, 40.5, '• Flights', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(12, 38, '• Crew', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(12, 35.5, '• Aircraft', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(22, 40.5, '• Weather', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(22, 38, '• Disrupt.', ha='left', fontsize=7, color=COLORS['dark_blue'])
    
    draw_horizontal_arrow(ax, 31, 35, 40)
    
    int_box = FancyBboxPatch((36, 33.5), 26, 13, boxstyle="round,pad=0.02,rounding_size=0.3",
                              facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(int_box)
    ax.text(49, 44, 'INTERMEDIATE', ha='center', fontsize=9, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(49, 40, '• Crew+Aircraft Status', ha='center', fontsize=7, color=COLORS['dark_blue'])
    ax.text(49, 37, '• Flight+Disruption', ha='center', fontsize=7, color=COLORS['dark_blue'])
    
    draw_horizontal_arrow(ax, 62, 66, 40)
    
    analytics_box = FancyBboxPatch((67, 33.5), 28, 13, boxstyle="round,pad=0.02,rounding_size=0.3",
                                    facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(analytics_box)
    ax.text(81, 44, 'ANALYTICS', ha='center', fontsize=9, fontweight='bold', color=COLORS['dark_blue'])
    
    golden_box = FancyBboxPatch((69, 35.5), 24, 8, boxstyle="round,pad=0.01,rounding_size=0.2",
                                 facecolor=COLORS['pale_blue'], edgecolor=COLORS['primary_blue'], linewidth=1.5)
    ax.add_patch(golden_box)
    ax.text(81, 41.5, 'GOLDEN RECORD', ha='center', fontsize=7, fontweight='bold', color=COLORS['primary_blue'])
    ax.text(81, 39.5, '(Single Source of Truth – No Ghosts)', ha='center', fontsize=6, color=COLORS['primary_blue'])
    ax.text(81, 37, '• Operational Summary   • Crew Recovery Candidates', ha='center', fontsize=6, color=COLORS['dark_blue'])
    
    draw_upward_arrow(ax, 50, 47, 52)
    
    # ========== LAYER 3: AI/ML LAYER ==========
    draw_header_bar(ax, 55, 'AI/ML LAYER (Cortex)')
    
    cortex_box = FancyBboxPatch((5, 59), 21, 12, boxstyle="round,pad=0.02,rounding_size=0.3",
                                 facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(cortex_box)
    draw_search_icon(ax, 9, 67.5, size=1.3)
    ax.text(19, 68, 'CORTEX SEARCH', ha='center', fontsize=8, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(15.5, 64, '• Incidents', ha='center', fontsize=7, color=COLORS['dark_blue'])
    ax.text(15.5, 61, '• Maintenance', ha='center', fontsize=7, color=COLORS['dark_blue'])
    
    agent_box = FancyBboxPatch((28, 59), 22, 12, boxstyle="round,pad=0.02,rounding_size=0.3",
                                facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(agent_box)
    draw_robot_icon(ax, 32, 67, size=1.3)
    ax.text(43, 68, 'INTELLIGENCE AGENT', ha='center', fontsize=7, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(39, 63, 'IROPS_ASSISTANT', ha='center', fontsize=7, color=COLORS['primary_blue'], style='italic')
    
    ml_box = FancyBboxPatch((52, 59), 22, 12, boxstyle="round,pad=0.02,rounding_size=0.3",
                             facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(ml_box)
    draw_brain_icon(ax, 56, 67, size=1.3)
    ax.text(67, 68, 'ML MODELS', ha='center', fontsize=8, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(57, 64, '• Delay Pred', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(57, 61, '• Crew Rank', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(68, 64, '• Cost Est', ha='left', fontsize=7, color=COLORS['dark_blue'])
    
    semantic_box = FancyBboxPatch((76, 59), 19, 12, boxstyle="round,pad=0.02,rounding_size=0.3",
                                   facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(semantic_box)
    draw_database_icon(ax, 80, 67, size=1.3)
    ax.text(90, 68, 'SEMANTIC VIEW', ha='center', fontsize=8, fontweight='bold', color=COLORS['dark_blue'])
    ax.text(85.5, 63, 'IROPS_ANALYTICS', ha='center', fontsize=7, color=COLORS['primary_blue'], style='italic')
    
    draw_upward_arrow(ax, 50, 71, 76)
    
    # ========== LAYER 4: PRESENTATION (TOP) ==========
    draw_header_bar(ax, 79, 'PRESENTATION LAYER')
    
    dashboard_box = FancyBboxPatch((15, 82), 70, 12, boxstyle="round,pad=0.02,rounding_size=0.3",
                                    facecolor=COLORS['white'], edgecolor=COLORS['border_gray'], linewidth=1)
    ax.add_patch(dashboard_box)
    draw_chart_icon(ax, 42, 91, size=1.5)
    ax.text(55, 91.5, 'REACT DASHBOARD', ha='center', fontsize=10, fontweight='bold', color=COLORS['dark_blue'])
    
    ax.text(25, 88, 'Operations Dashboard', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(25, 85, 'Crew Recovery (1-Click)', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(50, 88, 'Ghost Planes Detection', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(50, 85, 'Disruption Analysis', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(73, 88, 'Contract Bot', ha='left', fontsize=7, color=COLORS['dark_blue'])
    ax.text(73, 85, 'Intelligence Agent', ha='left', fontsize=7, color=COLORS['dark_blue'])
    
    ax.text(50, 2, 'TRANSFORMING RAW DATA INTO REAL-TIME INTELLIGENT ACTION FOR OPTIMIZED AIRLINE OPERATIONS.', 
            ha='center', fontsize=8, fontweight='bold', color=COLORS['dark_blue'])
    
    plt.tight_layout()
    return fig

if __name__ == '__main__':
    output_dir = '/Users/srsubramanian/Solutions/Airlines-IROPS/solution_presentation/images'
    os.makedirs(output_dir, exist_ok=True)
    
    print("Generating bottom-up architecture diagram...")
    fig = create_bottom_up_architecture()
    
    filepath = os.path.join(output_dir, 'architecture_diagram_bottom_up.jpg')
    fig.savefig(filepath, dpi=150, bbox_inches='tight', facecolor='white', edgecolor='none', format='jpeg')
    plt.close(fig)
    print(f"Saved to {filepath}")
