# Handles configuration loading and validation.
import configparser
import os

def load_db_instances(config_file="config.ini"):
    """Loads database instances from a configuration file.

    Args:
        config_file (str): Path to the configuration file.

    Returns:
        dict: Database instance configurations, or None if an error occurs.
    """
    if not os.path.exists(config_file):
        print(f"Config file {config_file} not found.")
        return None
    
    try:
        config = configparser.ConfigParser()
        config.read(config_file)
        db_instances = {}
        for section in config.sections():
            if section.startswith('database'):
                # instance_name = config[section].get('host', section.replace('database', 'Instance'))
                instance_name = section.replace('database', config[section]['host']).strip()
                db_instances[instance_name] = dict(config[section])
        return db_instances or None
    except Exception as e:
        print(f"Error loading configuration: {e}")
        return None