# Manages database connections and data fetching.
import pymssql
import time
from decimal import Decimal

class SQLMonitorDB:
    """Handles database connections and metric fetching."""
    
    METRICS = {
        "cpu": "usp_SQLMonLit_CPU",
        "memory": "usp_SQLMonLit_Memory",
        "tempdb": "usp_SQLMonLit_Tempdb",
        "disk": "usp_SQLMonLit_Batch",
        "backup": None,  # Placeholder, no stored proc yet
        "activity": "usp_SQLMonLit_Activity"
    }

    @staticmethod
    def connect(instance_config):
        """Establishes a database connection.

        Args:
            instance_config (dict): Configuration for the database instance.

        Returns:
            tuple: (connection object or None, error message or None)
        """
        try:
            conn = pymssql.connect(
                server=instance_config['host'],
                user=instance_config['user'],
                password=instance_config['password'],
                database=instance_config['database']
            )
            return conn, None
        except pymssql.DatabaseError as e:
            return None, f"Database connection failed: {e}"

    @staticmethod
    def fetch_metric(conn, metric_key):
        """Fetches data for a specific metric."""
        if not conn:
            return {"error": "Cannot connect to SQL Server"}
        
        if metric_key == "backup":
            return {"last_backup": "TBD"}
        
        proc_name = SQLMonitorDB.METRICS.get(metric_key)
        if not proc_name:
            return {"error": f"No procedure defined for {metric_key}"}
        
        cursor = conn.cursor(as_dict=True)
        try:
            cursor.callproc(proc_name)
            result = cursor.fetchone() or {}
            # Convert Decimal to float in results
            return {k: float(v) if isinstance(v, Decimal) else v for k, v in result.items()}
        except pymssql.Error as e:
            return {"error": f"SQL query error: {e}"}

    @staticmethod
    def update_metrics(results, instance_config):
        """Updates metrics with new data, preventing duplicates."""
        conn, error = SQLMonitorDB.connect(instance_config)
        if not conn:
            print(error)
            return
        
        try:
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
            # Check latest timestamp to avoid duplicates
            latest_timestamps = {k: results[k][0][0] if results[k] else None for k in results}
            
            for metric_key in SQLMonitorDB.METRICS:
                if latest_timestamps[metric_key] == timestamp:
                    continue  # Skip if timestamp matches latest (duplicate prevention)
                data = SQLMonitorDB.fetch_metric(conn, metric_key)
                if "error" not in data:
                    results[metric_key].insert(0, (timestamp, data))
                    if len(results[metric_key]) > 10:
                        results[metric_key] = results[metric_key][:10]
        finally:
            conn.close()