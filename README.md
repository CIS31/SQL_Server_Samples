# SQL_Server_Samples


This repository contains essential SQL Server scripts categorized into two main directories:

**SQL\_Server\_Administration**

   - Focused on database management and maintenance tasks.
   - Includes scripts for index optimization, log file management, and file movement.

**SQL\_Server\_Development**

   - Contains scripts related to stored procedures, data ingestion, and development tasks.

## Folder Structure and Script Details


### SQL\_Server\_Administration

- **`Index_Rebuild_Update.sql`** → Optimizes indexes by rebuilding or reorganizing them 
- **`Move_Filtred_Files.sql`** → Handles filtering and moving of specific files.
- **`Maintenance_Backup.sql`** → Performs full and transaction log backups, maintains indexes by reorganizing or rebuilding based on fragmentation.

### SQL\_Server\_Development

- **`Create_Alter_Procedure.txt`** → Provides SQL commands for creating and modifying stored procedures.
- **`Ingest_Data.txt`** → Contains scripts for inserting and managing data efficiently.

## How to Use These Scripts


### Running the Scripts

1. Open **SQL Server Management Studio (SSMS)**.
2. Connect to your SQL Server instance.
3. Open the script file.
4. Modify necessary parameters (e.g., database names, file paths) as required.
5. Execute the script by pressing **F5** or clicking "Execute".

### Automating Maintenance Scripts

- **Schedule SQL Jobs** in SQL Server Agent to run maintenance scripts periodically.

## Additional Notes


- Ensure you have proper **permissions** before executing scripts that modify databases.
- For critical operations like **backups**, verify storage paths and retention policies.
- Regularly test and optimize queries to maintain database **performance and integrity**.

