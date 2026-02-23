#!/bin/bash

get_notebook_id_from_db() {
    local notebook_name="$1"
    sqlite3 "$DB_FILE" "SELECT id FROM notebooks WHERE name = '$notebook_name';"
}

column_exists() {
    local table="$1"
    local column="$2"
    sqlite3 "$DB_FILE" "PRAGMA table_info($table);" \
        | awk -F'|' '{print $2}' | grep -q "^$column$"
}
