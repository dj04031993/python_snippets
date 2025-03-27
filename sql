import mysql.connector
import csv
import re
import sys
import pandas as pd
from getpass import getpass

def connect_to_database(environment):
    """Connect to the specified MySQL database environment."""
    # Configuration for different environments
    config = {
        'QA': {
            'host': 'qa-db-server',
            'database': 'qa_database',
            'port': 3306
        },
        'PROD': {
            'host': 'prod-db-server',
            'database': 'prod_database',
            'port': 3306
        }
    }
    
    if environment not in config:
        print(f"Error: Unknown environment '{environment}'. Available options: {', '.join(config.keys())}")
        sys.exit(1)
    
    # Get credentials
    username = input(f"Enter MySQL username for {environment}: ")
    password = getpass(f"Enter MySQL password for {environment}: ")
    
    try:
        connection = mysql.connector.connect(
            host=config[environment]['host'],
            database=config[environment]['database'],
            user=username,
            password=password,
            port=config[environment]['port']
        )
        
        if connection.is_connected():
            print(f"Successfully connected to {environment} MySQL database")
            return connection
            
    except mysql.connector.Error as err:
        print(f"Error: {err}")
        sys.exit(1)

def is_safe_query(query):
    """Check if query contains DELETE or UPDATE statements."""
    unsafe_patterns = [
        r'\bDELETE\b',
        r'\bUPDATE\b',
        r'\bDROP\b',
        r'\bTRUNCATE\b',
        r'\bALTER\b'
    ]
    
    for pattern in unsafe_patterns:
        if re.search(pattern, query, re.IGNORECASE):
            return False
    return True

def is_count_query(query):
    """Check if the query is just for counting records."""
    count_pattern = r'\bSELECT\s+COUNT\s*\('
    return bool(re.search(count_pattern, query, re.IGNORECASE))

def execute_query(connection, query):
    """Execute the given SQL query and return results."""
    try:
        cursor = connection.cursor()
        cursor.execute(query)
        
        # Get column names
        column_names = [column[0] for column in cursor.description] if cursor.description else []
        
        # Fetch all results
        results = cursor.fetchall()
        cursor.close()
        
        return column_names, results
    except mysql.connector.Error as err:
        print(f"Error executing query: {err}")
        return None, None

def main():
    # Step 1: Ask for environment
    print("Available Environments: QA, PROD")
    environment = input("Enter environment (QA/PROD): ").strip().upper()
    
    # Step 2: Connect to database
    connection = connect_to_database(environment)
    
    # Step 3: Ask user for SQL query
    query = input("Enter your SQL query: ")
    
    # Step 4: Check if query contains DELETE or UPDATE
    if not is_safe_query(query):
        print("Error: Query contains unsafe statements (DELETE, UPDATE, DROP, TRUNCATE, ALTER).")
        connection.close()
        sys.exit(1)
    
    # Execute query
    column_names, results = execute_query(connection, query)
    
    if not results:
        print("No results returned or query error occurred.")
        connection.close()
        sys.exit(1)
    
    # Step 5: Check if query is just counting
    if is_count_query(query):
        for row in results:
            print(f"Count result: {row[0]}")
    else:
        # Step 6: Ask for output file name
        output_file = input("Enter output CSV filename (e.g., output.csv): ")
        
        # Create pandas DataFrame and save to CSV
        df = pd.DataFrame(results, columns=column_names)
        df.to_csv(output_file, index=False, quoting=csv.QUOTE_MINIMAL)
        print(f"Query results saved to {output_file}")
        print(f"Total rows: {len(results)}")
    
    # Close connection
    connection.close()
    print("Database connection closed.")

if __name__ == "__main__":
    main()
