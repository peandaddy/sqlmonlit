# Orchestrates the application.
import streamlit as st
import time
from config import load_db_instances
from database import SQLMonitorDB
from ui import setup_ui, render_dashboard

def main():
    # Load configuration
    db_instances = load_db_instances("config.ini")
    if not db_instances:
        st.error("Failed to load database configurations. Check config.ini.")
        return

    # Initialize session state
    state_defaults = {
        "current_instance": None,
        "refresh_pressed": False,
        "monitoring_active": True,
        "last_update": 0,
        "animation_frame": 0,
        "clearing_in_progress": False
    }
    for key, default in state_defaults.items():
        if key not in st.session_state:
            st.session_state[key] = default

    # Setup UI
    selected_instance, refresh, stop, clear, auto_refresh, status_placeholder, content_placeholder, tabs = setup_ui(db_instances)
    instance_config = db_instances[selected_instance]

    # Initialize results
    results_key = f'results_{selected_instance}'
    if results_key not in st.session_state:
        st.session_state[results_key] = {metric: [] for metric in SQLMonitorDB.METRICS}

    # Handle instance switch
    if st.session_state["current_instance"] != selected_instance:
        st.session_state["current_instance"] = selected_instance
        content_placeholder.empty()
        st.session_state["monitoring_active"] = True
        st.session_state["last_update"] = 0

    # Handle button actions
    if refresh:
        st.session_state["refresh_pressed"] = True
        st.session_state["monitoring_active"] = True
    if stop:
        st.session_state["monitoring_active"] = False
    if clear:
        st.session_state[results_key] = {metric: [] for metric in SQLMonitorDB.METRICS}
        st.session_state["clearing_in_progress"] = True

    # Animation
    if st.session_state["monitoring_active"] and auto_refresh:
        animation_frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        frame = animation_frames[st.session_state["animation_frame"] % len(animation_frames)]
        status_placeholder.markdown(f"**Monitoring Active** {frame}")
        st.session_state["animation_frame"] += 1
    else:
        status_placeholder.empty()

    # Monitoring logic
    if st.session_state["monitoring_active"]:
        current_time = time.time()
        if st.session_state["clearing_in_progress"]:
            st.session_state["clearing_in_progress"] = False
        elif st.session_state["refresh_pressed"] or (auto_refresh and (current_time - st.session_state["last_update"] >= 60)):
            with st.spinner(f"Fetching data for {selected_instance}..."):
                SQLMonitorDB.update_metrics(st.session_state[results_key], instance_config)
            st.session_state["last_update"] = current_time
            st.session_state["refresh_pressed"] = False

    # Render UI
    render_dashboard(selected_instance, st.session_state[results_key], content_placeholder, tabs)

    # Rerun logic
    if (st.session_state["monitoring_active"] and auto_refresh) or st.session_state["clearing_in_progress"]:
        time.sleep(0.2)
        st.session_state["clearing_in_progress"] = False
        st.rerun()

if __name__ == "__main__":
    main()