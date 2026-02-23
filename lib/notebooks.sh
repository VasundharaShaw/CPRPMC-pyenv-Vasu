#!/bin/bash

get_notebook_id_from_db() {
    local notebook_name="$1"
    sqlite3 "$DB_FILE" "SELECT id FROM notebooks WHERE name = '$notebook_name';"
}

get_repo_id_from_db() {
    local github_url="$1"

    # Extract owner/repo from GitHub URL
    # https://github.com/ncbi/elastic-blast-demos -> ncbi/elastic-blast-demos
    local repo_path
    repo_path=$(echo "$github_url" | sed -E 's#https?://github.com/##; s#\.git$##')

    #echo "Resolved repo_path: $repo_path"

    sqlite3 "$DB_FILE" \
        "SELECT id FROM repositories WHERE repository = '$repo_path' LIMIT 1;"
}


column_exists() {
    local table="$1"
    local column="$2"
    sqlite3 "$DB_FILE" "PRAGMA table_info($table);" \
        | awk -F'|' '{print $2}' | grep -q "^$column$"
}

compare_notebook_outputs_json() {
    local notebook1="$1"
    local notebook2="$2"
    local comparison_file="$3"

    mkdir -p "$(dirname "$comparison_file")"

    if [ ! -f "$notebook2" ]; then
        log "[ERROR] Executed notebook missing: $notebook2 — skipping comparison"
        return 0
    fi

    python3 -u compare_notebook.py \
        "$notebook1" \
        "$notebook2" \
        "$NOTEBOOK_PATH"  \
        "$REPO_ID" \
        --json "$comparison_file" \
        2>&1 | tee -a "$LOG_FILE"
}

compare_notebook_outputs() {
    # After Docker container finishes executing the notebooks
    log "[NOTEBOOK] Comparing notebook outputs..."
    total_same=0
    total_different=0
    total_code_cells=0
    aggregate_matched_percentage=0
    IFS=";" read -ra NOTEBOOK_ARRAY <<< "$NOTEBOOK_PATHS"
    for NOTEBOOK_PATH in "${NOTEBOOK_ARRAY[@]}"; do
        if [ ! -f "$REPO_NAME/$NOTEBOOK_PATH" ]; then
            log "[ERROR] Notebook not found at path: $REPO_NAME/$NOTEBOOK_PATH, skipping..."
            continue
        fi
        notebook_dir=$(dirname "$NOTEBOOK_PATH")
        base_name=$(basename "$NOTEBOOK_PATH" .ipynb)
        original_notebook="$REPO_NAME/$NOTEBOOK_PATH"
        executed_notebook="$REPO_NAME/${notebook_dir}/${base_name}_output.ipynb"

        NOTEBOOK_ID=$(get_notebook_id_from_db "$NOTEBOOK_PATH")        
        REPO_ID=$(get_repo_id_from_db "$GITHUB_REPO")
        log "[NOTEBOOK] NOTEBOOK_ID: $NOTEBOOK_ID."
        log "[REPO] REPO_ID: $REPO_ID."
        
        if [ -z "$NOTEBOOK_ID" ]; then
            log "[ERROR] No notebook ID found for $NOTEBOOK_PATH in the database. Skipping..."
            continue
        fi

        log "[NOTEBOOK] Processing notebook: $NOTEBOOK_PATH with notebook ID: $NOTEBOOK_ID and repository id: $REPO_ID."

        
        # Compare original and executed notebooks and log the output
        comparison_result_file="${COMP_DIR}/${base_name}_comparison.json"
        # compare_notebook_outputs_json "$original_notebook" "$executed_notebook" "$comparison_result_file"
        #comparison_output=$(compare_notebook_outputs_json "$original_notebook" "$executed_notebook" "$comparison_result_file")

        #comparison_file="$COMP_DIR/${base_name}_comparison.json"

        if [ ! -f "$executed_notebook" ]; then
            log "[ERROR]: Output notebook not created for $NOTEBOOK_PATH"

            cat <<EOF > "$comparison_result_file"
            {
            "notebook": "$NOTEBOOK_PATH",
            "NOTEBOOK_ID": "$NOTEBOOK_ID",
            "REPO_ID": "$REPO_ID",
            "status": "failed",
            "reason": "output_notebook_not_created",
            "original_notebook": "$original_notebook",
            "expected_output_notebook": "$executed_notebook"
            }
EOF

            continue
        fi

        comparison_output=$(compare_notebook_outputs_json "$original_notebook" "$executed_notebook" "$comparison_result_file")
        # log "[NOTEBOOK] Comparison for $base_name saved to $comparison_result_file"
    done

}