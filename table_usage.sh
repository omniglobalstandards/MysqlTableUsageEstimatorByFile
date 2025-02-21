#!/bin/bash

# Default values
MYSQL_DATA_DIR="/var/lib/mysql"
SORT_BY="none"
FILTER_DB=""
FILTER_TABLE=""
SHOW_SIZE=false
DAYS_OLD=0
DEBUG=false  # Debug set to false by default

# Colors for debug output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Debug function
debug() {
    local level=$1
    shift
    local message="$@"
    if [ "$DEBUG" = true ]; then
        case $level in
            "INFO")    echo -e "${GREEN}[INFO]${NC} $message" ;;
            "WARN")    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            "ERROR")   echo -e "${RED}[ERROR]${NC} $message" ;;
            "DEBUG")   echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        esac
    fi
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --directory DIR    Specify MySQL data directory (default: /var/lib/mysql)"
    echo "  -s, --sort FIELD       Sort by: name, database, read, write, usage, size (default: none)"
    echo "  -r, --reverse         Reverse sort order (DESC instead of ASC)"
    echo "  -f, --filter-db DB     Filter by database name"
    echo "  -t, --filter-table TBL Filter by table name"
    echo "  -z, --show-size        Show table size"
    echo "  -o, --older-than DAYS  Show only tables not accessed in X days"
    echo "  -D, --debug           Enable debug mode"
    echo "  -h, --help            Show this help message"
    exit 1
}

# Function to format size
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        printf "%.2f GB" $(echo "scale=2; $size/1073741824" | bc)
    elif [ $size -ge 1048576 ]; then
        printf "%.2f MB" $(echo "scale=2; $size/1048576" | bc)
    elif [ $size -ge 1024 ]; then
        printf "%.2f KB" $(echo "scale=2; $size/1024" | bc)
    else
        printf "%d B" $size
    fi
}

# Function to calculate days since and provide usage estimation
estimate_usage() {
    local read_time=$1
    local write_time=$2
    local current_time=$(date +%s)
    
    local days_since_read=$(( (current_time - read_time) / 86400 ))
    local days_since_write=$(( (current_time - write_time) / 86400 ))
    
    # Estimation logic
    if [ $days_since_write -gt 90 ] && [ $days_since_read -gt 90 ]; then
        echo "Likely Unused (${days_since_read}d)"
    elif [ $days_since_write -gt 30 ] && [ $days_since_read -gt 30 ]; then
        echo "Possibly Inactive (${days_since_read}d)"
    elif [ $days_since_write -gt 7 ] && [ $days_since_read -gt 7 ]; then
        echo "Low Activity (${days_since_read}d)"
    else
        echo "Active (${days_since_read}d)"
    fi
}

# Add reverse sort option
REVERSE_SORT=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--directory) MYSQL_DATA_DIR="$2"; shift ;;
        -s|--sort) SORT_BY="$2"; shift ;;
        -r|--reverse) REVERSE_SORT=true ;;
        -f|--filter-db) FILTER_DB="$2"; shift ;;
        -t|--filter-table) FILTER_TABLE="$2"; shift ;;
        -z|--show-size) SHOW_SIZE=true ;;
        -o|--older-than) DAYS_OLD="$2"; shift ;;
        -D|--debug) DEBUG=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# Create temporary file
TEMP_FILE=$(mktemp)
debug "INFO" "Created temporary file: $TEMP_FILE"

# Initial directory check
debug "INFO" "Starting search in directory: $MYSQL_DATA_DIR"
if [ ! -d "$MYSQL_DATA_DIR" ]; then
    debug "ERROR" "Directory does not exist: $MYSQL_DATA_DIR"
    exit 1
fi

# Function to print headers
print_header() {
    local size_column=""
    local size_separator=""
    if [ "$SHOW_SIZE" = true ]; then
        size_column="| %-15s "
        size_separator="+%-17s"
    fi
    
    printf "+%-50s+%-25s+%-21s+%-21s+%-25s${size_separator:+$size_separator}+\n" \
        $(printf '%0.s-' {1..50}) $(printf '%0.s-' {1..25}) \
        $(printf '%0.s-' {1..21}) $(printf '%0.s-' {1..21}) \
        $(printf '%0.s-' {1..25}) ${size_separator:+$(printf '%0.s-' {1..17})}
    
    printf "| %-48s | %-23s | %-19s | %-19s | %-23s ${size_column:+$size_column}|\n" \
        "Table" "Database" "Last Read" "Last Write" "Usage Estimate" ${size_column:+"Size"}
    
    printf "+%-50s+%-25s+%-21s+%-21s+%-25s${size_separator:+$size_separator}+\n" \
        $(printf '%0.s-' {1..50}) $(printf '%0.s-' {1..25}) \
        $(printf '%0.s-' {1..21}) $(printf '%0.s-' {1..21}) \
        $(printf '%0.s-' {1..25}) ${size_separator:+$(printf '%0.s-' {1..17})}
}

# Search for files in the specified directory
debug "INFO" "Searching for .ibd and .MYD files"
if [ "$DEBUG" = true ]; then
    debug "INFO" "Directory contents:"
    ls -la "$MYSQL_DATA_DIR"
fi

# Process files
for file in "$MYSQL_DATA_DIR"/*.{ibd,MYD}; do
    if [ -f "$file" ]; then
        debug "INFO" "Found file: $file"
        
        db_name=$(basename "$(dirname "$file")")
        table_name=$(basename "$file" | sed 's/\.[^.]*$//')
        
        # Get all timestamps
        if ! read_time=$(stat -c '%X' "$file" 2>&1); then
            debug "ERROR" "Could not get access time for file: $file"
            continue
        fi
        if ! write_time=$(stat -c '%Y' "$file" 2>&1); then
            debug "ERROR" "Could not get modify time for file: $file"
            continue
        fi
        
        read_time_fmt=$(date -d "@$read_time" '+%Y-%m-%d %H:%M:%S')
        write_time_fmt=$(date -d "@$write_time" '+%Y-%m-%d %H:%M:%S')
        usage_estimate=$(estimate_usage "$read_time" "$write_time")
        
        # Apply filters
        if [ -n "$FILTER_DB" ] && [ "$db_name" != "$FILTER_DB" ]; then
            debug "DEBUG" "Skipping due to database filter: $db_name != $FILTER_DB"
            continue
        fi
        
        if [ -n "$FILTER_TABLE" ] && [[ "$table_name" != *"$FILTER_TABLE"* ]]; then
            debug "DEBUG" "Skipping due to table filter: $table_name doesn't match $FILTER_TABLE"
            continue
        fi
        
        if [ $DAYS_OLD -gt 0 ]; then
            current_time=$(date +%s)
            days_diff=$(( (current_time - read_time) / 86400 ))
            if [ $days_diff -lt $DAYS_OLD ]; then
                debug "DEBUG" "Skipping due to age filter: $days_diff days < $DAYS_OLD days"
                continue
            fi
        fi
        
        # Get file size if needed
        if [ "$SHOW_SIZE" = true ]; then
            if ! size=$(stat -c '%s' "$file" 2>&1); then
                debug "ERROR" "Could not get size for file: $file"
                continue
            fi
            size_fmt=$(format_size $size)
            echo -e "$table_name\t$db_name\t$read_time\t$read_time_fmt\t$write_time\t$write_time_fmt\t$usage_estimate\t$size\t$size_fmt" >> "$TEMP_FILE"
        else
            echo -e "$table_name\t$db_name\t$read_time\t$read_time_fmt\t$write_time\t$write_time_fmt\t$usage_estimate" >> "$TEMP_FILE"
        fi
    fi
done

# Check if we found any files
if [ ! -s "$TEMP_FILE" ]; then
    debug "WARN" "No matching files found!"
    exit 1
fi

# Update the sort case statement
case $SORT_BY in
    "name") sort_col=1 ;;
    "database") sort_col=2 ;;
    "read") sort_col=3 ;;
    "write") sort_col=5 ;;
    "usage") sort_col=7 ;;
    "size") sort_col=8 ;;
    *) sort_col=0 ;;
esac

# Print results
print_header

if [ $sort_col -gt 0 ]; then
    debug "INFO" "Sorting results by column $sort_col"
    if [ "$REVERSE_SORT" = true ]; then
        sort -r -k${sort_col} -t$'\t' "$TEMP_FILE"
    else
        sort -k${sort_col} -t$'\t' "$TEMP_FILE"
    fi
else
    cat "$TEMP_FILE"
fi | while IFS=$'\t' read -r table db atime atime_fmt mtime mtime_fmt usage size size_fmt; do
    if [ "$SHOW_SIZE" = true ]; then
        printf "| %-48s | %-23s | %-19s | %-19s | %-23s | %-15s |\n" \
            "$table" "$db" "$atime_fmt" "$mtime_fmt" "$usage" "$size_fmt"
    else
        printf "| %-48s | %-23s | %-19s | %-19s | %-23s |\n" \
            "$table" "$db" "$atime_fmt" "$mtime_fmt" "$usage"
    fi
done

# Print footer
if [ "$SHOW_SIZE" = true ]; then
    printf "+%-50s+%-25s+%-21s+%-21s+%-25s+%-17s+\n" \
        $(printf '%0.s-' {1..50}) $(printf '%0.s-' {1..25}) \
        $(printf '%0.s-' {1..21}) $(printf '%0.s-' {1..21}) \
        $(printf '%0.s-' {1..25}) $(printf '%0.s-' {1..17})
else
    printf "+%-50s+%-25s+%-21s+%-21s+%-25s+\n" \
        $(printf '%0.s-' {1..50}) $(printf '%0.s-' {1..25}) \
        $(printf '%0.s-' {1..21}) $(printf '%0.s-' {1..21}) \
        $(printf '%0.s-' {1..25})
fi

# Print summary
total_tables=$(wc -l < "$TEMP_FILE")
echo
echo "$total_tables rows in set"
echo
echo "NOTICE: Timestamps are estimates only to determine likely table usage. This is helpful when analyzing large tablesets instead of querying the database directly. For a more accurate table usage, check MySQL's performance_schema or enable slow query logging."

# Cleanup
debug "INFO" "Cleaning up temporary files"
rm "$TEMP_FILE"
