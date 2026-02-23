#!/bin/bash

create_entrypoint() {
    log "[DOCKER] Creating entrypoint.sh..."

    cat <<'EOF' > entrypoint.sh
#!/bin/bash

set -e

echo "[ENTRYPOINT] Starting notebook execution"

LOG_DIR="/logs"
mkdir -p "$LOG_DIR"
EXEC_LOG="$LOG_DIR/notebook_execution_times.log"

if [ -z "$NOTEBOOK_PATHS" ]; then
    echo "[ENTRYPOINT] No notebook paths provided"
    exit 1
fi

export HOME=/tmp
export PATH="$HOME/.local/bin:$PATH"
export PYTHONPATH="$HOME/.local/lib/python3.10/site-packages:$PYTHONPATH"

echo "[ENTRYPOINT] Checking for requirements.txt"
if [ -f "/app/requirements.txt" ]; then
    echo "[ENTRYPOINT] Installing from requirements.txt (one by one)..."
    cat /app/requirements.txt
    
    # Install each package individually to avoid one failure blocking others
    while IFS= read -r package || [ -n "$package" ]; do
        # Skip empty lines and comments
        [[ -z "$package" ]] && continue
        [[ "$package" =~ ^[[:space:]]*# ]] && continue
        
        echo "[ENTRYPOINT] Installing: $package"
        if pip install --user --no-cache-dir "$package"; then
            echo "[ENTRYPOINT] ✓ Successfully installed: $package"
        else
            echo "[ENTRYPOINT] ✗ Failed to install: $package (skipping)"
        fi
    done < /app/requirements.txt
    
    echo "[ENTRYPOINT] Installation complete"
else
    echo "[ENTRYPOINT] No requirements.txt found"
fi

echo "[ENTRYPOINT] Installed packages:"
pip list

if [ -n "$SETUP_PATHS" ]; then
    echo "[ENTRYPOINT] Processing setup.py files"
    IFS=';' read -ra SETUP_FILES <<< "$SETUP_PATHS"
    
    for setup_file in "${SETUP_FILES[@]}"; do
        setup_file=$(echo "$setup_file" | xargs)
        [ -z "$setup_file" ] && continue
        
        setup_dir="/app/$(dirname "$setup_file")"
        
        if [ -d "$setup_dir" ] && [ -f "$setup_dir/setup.py" ]; then
            echo "[ENTRYPOINT] Installing from $setup_dir"
            (cd "$setup_dir" && pip install --user --no-cache-dir .) || \
                echo "[ENTRYPOINT] Failed to install from $setup_dir"
        else
            echo "[ENTRYPOINT] No setup.py found in $setup_dir"
        fi
    done
fi


IFS=';' read -ra NOTEBOOKS <<< "$NOTEBOOK_PATHS"

for notebook in "${NOTEBOOKS[@]}"; do
    if [ ! -f "$notebook" ]; then
        echo "EXEC_FAIL|$notebook|0|NOTEBOOK_NOT_FOUND" | tee -a "$EXEC_LOG"
        continue
    fi

    notebook_dir=$(dirname "$notebook")
    base_name=$(basename "$notebook" .ipynb)
    output_nb="${base_name}_output.ipynb"
    output_nb_path="$notebook_dir/${base_name}_output.ipynb"    

    echo "[ENTRYPOINT] Executing $notebook"

    start_ts=$(date +%s)

    jupyter nbconvert \
        --to notebook \
        --execute \
        --allow-errors \
        "$notebook" \
        --output "$output_nb"

    exit_code=$?
    end_ts=$(date +%s)
    duration=$((end_ts - start_ts))

    if [ ! -f "$output_nb_path" ]; then
        echo "EXEC_FAIL|$REPO_NAME|$notebook|$duration" | tee -a "$EXEC_LOG"
        continue
    fi

    if grep -q '"output_type": "error"' "$output_nb_path"; then
        echo "SUCCESS_WITH_ERRORS|$REPO_NAME|$notebook|$duration" | tee -a "$EXEC_LOG"
    else
        echo "SUCCESS|$REPO_NAME|$notebook|$duration" | tee -a "$EXEC_LOG"
    fi
done

echo "[ENTRYPOINT] Completed notebook execution"
EOF

    chmod +x entrypoint.sh
}
