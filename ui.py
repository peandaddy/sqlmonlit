# Handles Streamlit UI components and rendering.
import streamlit as st

TAB_CONFIG = {
    "CPU": ["SQLProcessUtilization", "SystemIdle", "OtherProcessUtilization", "cpu_count"],
    "Memory": ["total_server_memory_mb", "memory_in_use_mb", "total_physical_memory_mb", "available_physical_memory_mb"],
    "TempDB": ["Total_SizeMB", "Provisioned_DBSizeMB", "Used_DBSizeMB", "Provisioned_LogSizeMB", "Used_LogSizeMB"],
    "Disk": ["AvgBatchRequestsPerSec", "PageLifeExpectancySec", "BufferCacheHitRatioPercent"],
    "Backup": ["last_backup"],
    "Activity": ["UserConnections", "SystemConnections", "TotalConnections", "ActiveUserSessions", "blocked_processes", "total_deadlocks"]
}

def render_dashboard(selected_instance, results, content_placeholder, tabs):
    """Renders the monitoring dashboard tabs."""
    
    content_placeholder.empty()
    with content_placeholder.container():
        # Iterate over the tab names and corresponding tabs
        for tab_name, tab in zip(TAB_CONFIG.keys(), tabs):
            with tab:
                # Check if data exists for the current tab
                if results.get(tab_name.lower()):
                    # Loop through the data for the current tab
                    for ts, data in results[tab_name.lower()]:
                        with st.container():
                            # Create columns dynamically based on the number of metrics
                            cols = st.columns(len(TAB_CONFIG[tab_name]) + 1)
                            # Display the timestamp in the first column
                            cols[0].write(ts)
                            # Loop through the metrics and display them
                            for i, metric in enumerate(TAB_CONFIG[tab_name], 1):
                                value = data.get(metric, "N/A")
                                cols[i].metric(metric, value)
                            # Add a separator after each entry
                            st.markdown("---")
                else:
                    st.write("No data yet")

def setup_ui(db_instances):
    """Sets up the Streamlit UI layout."""
    st.sidebar.title("SQL Instances")
    selected_instance = st.sidebar.radio("Select Instance", list(db_instances.keys()))
    
    st.title(f"Monitoring Dashboard - {selected_instance}")
    
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        refresh = st.button("Refresh Now", key="refresh_button")
    with col2:
        stop = st.button("Stop", key="stop_button")
    with col3:
        clear = st.button("Clear", key="clear_button")
    with col4:
        auto_refresh = st.checkbox("Auto-refresh every 60 seconds", value=True, key="auto_refresh_checkbox")
    
    status_placeholder = st.empty()
    content_placeholder = st.empty()
    tabs = st.tabs(["CPU", "Memory", "TempDB", "Disk", "Backup", "Activity"])
    
    return selected_instance, refresh, stop, clear, auto_refresh, status_placeholder, content_placeholder, tabs