# SQLMonLit - SQL Monitoring Dashboard

A modular, extensible, and production-ready `Streamlit` application for real-time monitoring of SQL Server instances. This dashboard fetches and displays key performance metrics (**CPU, Memory, TempDB, Disk, Backup, and Activity**) from multiple SQL Server instances, leveraging stored procedures for data retrieval.

## Features
- **Multi-Instance Support**: Monitor multiple SQL Server instances configured via `config.ini`.
- **Real-Time Updates**: Auto-refresh every `60` seconds with a manual refresh option.
- **Tabular UI**: Organized metrics in tabs (CPU, Memory, TempDB, Disk, Backup, Activity) with timestamped entries.
- **Data Limiting**: Retains up to 10 recent records per metric, preventing overload.
- **Duplicate Prevention**: Ensures no duplicate records during rapid updates.
- **Modular Design**: Separates configuration, database logic, UI, and app orchestration for maintainability and scalability.
- **Error Handling**: Graceful handling of connection and query failures with user feedback.

## Project Structure
```
sqlmonlit/
├── app.py            # Main application logic and orchestration
├── config.py         # Configuration loading and management
├── database.py       # Database connection and data fetching logic
├── ui.py             # Streamlit UI components and rendering
├── config.ini        # Sample configuration file (edit with your DB details)
├── requirements.txt  # Python dependencies
└── README.md         # This file
```


## Prerequisites
- **Python**: 3.8 or higher
- **SQL Server**: Accessible instances with the following stored procedures:
  - `usp_SQLMonLit_CPU`
  - `usp_SQLMonLit_Memory`
  - `usp_SQLMonLit_Tempdb`
  - `usp_SQLMonLit_Batch`
  - `usp_SQLMonLit_Activity`
- **Dependencies**: Listed in `requirements.txt`

## Installation
1. **Clone the Repository**: 
   ```bash
   git clone https://github.com/peandaddy/sqlmonlit.git
   cd sqlmonlit
   ```
2. **Set Up a Virtual Environment (recommended)**: 
    ```python
    python -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```
3. **Install Dependencies**: 
    ```python
    pip install -r requirements.txt
    ```
4. **Configure config.ini**: 
*  Copy the sample `config.ini` and edit it with your SQL Server credentials:
    ```ini
    [database1]
    host=your_sql_server_host
    user=your_username
    password=your_password
    database=your_database_name
    
    [database2]
    host=another_sql_server_host
    user=another_username
    password=another_password
    database=another_database_name
    ```
* Add as many `[databaseX]` sections as needed.

## Usage
1. Run the Application:
    ```bash
    streamlit run app.py
    ```
2. Interact with the Dashboard:
* Select an instance from the sidebar.
* View metrics in the tabs (`auto-refreshes every 60 seconds`).
* Use buttons: "`Refresh Now`" (manual update), "`Stop`" (pause monitoring), "`Clear`" (reset data).

## Configuration
* Edit `config.ini`: Modify instance details (host, user, password, database).
* Customize Metrics: Update `SQLMonitorDB.METRICS` in `database.py` to add or change stored procedures.
* Refresh Interval: Adjust the `60` in `app.py` **`current_time - st.session_state["last_update"] >= 60`** to change the auto-refresh timing.

## Development
### Adding New Metrics
1. Add the metric key and stored procedure to `SQLMonitorDB.METRICS` in `database.py`.
2. Update `render_dashboard` in `ui.py` to display the new metric in a tab.
### Testing
1. Install `pytest`: 
    ```python
    pip install pytest
    ```
2. Write tests in a `tests/` directory (not included) to validate `config.py`, `database.py`, etc.

## Contributing
Contributions are welcome!

## License
These samples and templates are all licensed under the MIT license. See the `LICENSE` file in the root.

## Author
* Ji Wang - <a href="https://github.com/peandaddy" target="_blank">https://github.com/peandaddy</a>

Created to demonstrate advanced Python, Streamlit, and SQL Server monitoring skills. Contact me for collaboration or inquiries!

## Acknowledgments
* Built with `Streamlit` and `pymssql`.
* Inspired by the need for robust SQL Server monitoring tools.
