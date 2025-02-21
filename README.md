# MysqlTableUsageEstimatorByFile

Fast, lightweight bash script MySQL table usage analyzer that examines table file metadata instead of database queries, ideal for analyzing large tablesets where querying would be impractical.

## Overview

This tool helps database administrators and developers identify potentially unused or inactive MySQL tables by analyzing file-level metadata. Instead of running resource-intensive database queries, it examines the timestamps of table files (.ibd and .MYD) to estimate usage patterns.

## Features

- **No Database Impact**: Analyzes file metadata without querying the database
- **Usage Estimation**: Categorizes tables as:
  - Active (used within 7 days)
  - Low Activity (7-30 days without activity)
  - Possibly Inactive (30-90 days without activity)
  - Likely Unused (no activity for 90+ days)
- **Size Analysis**: Optional file size reporting
- **Flexible Sorting**: Sort by name, database, read time, write time, usage, or size
- **Filtering Options**: Filter by database name or table name
- **Debug Mode**: Detailed execution information for troubleshooting

## Requirements

- Bash shell
- Access to MySQL data directory
- Basic file read permissions on MySQL data files
- `stat` command available in the system

## Installation

1. Clone the repository:
```bash
git clone https://github.com/omniglobalstandards/MysqlTableUsageEstimatorByFile.git
```

2. Make the script executable:
```bash
chmod +x mysql_table_usage.sh
```

# Usage

## Basic Usage
```bash
./mysql_table_usage.sh -d /path/to/mysql/data
```

## With Size Information
```bash
./mysql_table_usage.sh -d /path/to/mysql/data -z
```

## All Available Options
```bash
Options:
  -d, --directory DIR    Specify MySQL data directory (default: /var/lib/mysql)
  -s, --sort FIELD       Sort by: name, database, read, write, usage, size
  -r, --reverse         Reverse sort order (DESC instead of ASC)
  -f, --filter-db DB     Filter by database name
  -t, --filter-table TBL Filter by table name
  -z, --show-size        Show table size
  -o, --older-than DAYS  Show only tables not accessed in X days
  -D, --debug           Enable debug mode
  -h, --help            Show this help message
```

## Example Output
```bash
+--------------------------------------------------+-------------------------+---------------------+---------------------+-------------------------+-----------------+
| Table                                             | Database                | Last Read          | Last Write          | Usage Estimate          | Size            |
+--------------------------------------------------+-------------------------+---------------------+---------------------+-------------------------+-----------------+
| active_table                                      | mydb                   | 2024-02-21 08:59:29 | 2024-02-21 08:59:29 | Active (0d)             | 9.00 MB         |
| old_table                                         | mydb                   | 2023-08-21 08:59:29 | 2023-08-21 08:59:29 | Likely Unused (184d)    | 5.00 MB         |
+--------------------------------------------------+-------------------------+---------------------+---------------------+-------------------------+-----------------+
```

# Important Notice
Timestamps are estimates only to determine likely table usage. This is helpful when analyzing large tablesets instead of querying the database directly. For a more accurate table usage, check MySQL's performance_schema or enable slow query logging.

# Common Use Cases
1. Large Database Analysis: Quickly identify potentially unused tables in large databases
2. Migration Planning: Identify inactive tables before database migrations
3. Storage Optimization: Find large, unused tables that might be candidates for archival
4. Maintenance Planning: Identify usage patterns for maintenance scheduling

# Limitations
- Relies on filesystem timestamps which might not always reflect actual database usage
- Some filesystems might have different timestamp update behaviors
- Not a replacement for proper database monitoring tools
- Access times might not be accurate if filesystem is mounted with noatime

# Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

# License
This project is licensed under the MIT License - see the LICENSE file for details.

# Author
[OmniGlobal Standards](https://github.com/omniglobalstandards)

# Acknowledgments
Inspired by the need for lightweight MySQL table analysis tools
Thanks to the MySQL community for documentation and insights
