#!/bin/bash

# Base directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="$PROJECT_ROOT/data"

# Data subdirectories
REPOS_DIR="$DATA_DIR/repositories"
COMP_DIR="$DATA_DIR/comparisons"
LOG_DIR="$DATA_DIR/logs"
DB_DIR="$DATA_DIR/db"

# Database file
DB_FILE="$DB_DIR/db.sqlite"

# Create all directories
initialize_directories() {
    mkdir -p "$REPOS_DIR"
    mkdir -p "$COMP_DIR"
    mkdir -p "$LOG_DIR" 
    mkdir -p "$DB_DIR"
    
    log "[INIT] Initialized directory structure in $DATA_DIR"
}

# Export for use in other scripts
export PROJECT_ROOT
export DATA_DIR
export REPOS_DIR
export COMP_DIR
export LOG_DIR
export DB_DIR
export DB_FILE