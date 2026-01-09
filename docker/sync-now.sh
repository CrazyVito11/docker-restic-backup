#!/bin/bash

set -e

TIMESTAMP=$(date +"%Y-%m-%d-%H%M")

LOG_DIR="/logs"
LOG_FILE="${LOG_DIR}/${TIMESTAMP}-restic.log"

LOCK_FILE="/var/lock/sync-now.lock"
SUCCESS_SCRIPT="/hooks/backup-success.sh"
FAILURE_SCRIPT="/hooks/backup-failure.sh"
LOCK_PRESENT_SCRIPT="/hooks/lock-present.sh"

export RESTIC_REPOSITORY_FILE="/config/restic-repository"
export RESTIC_PASSWORD_FILE="/config/.restic-password"

# Parse any flags that we received
for arg in "$@"; do
    if [[ "$arg" == "--create-repository" ]]; then
        echo "Flag --create-repository detected, will attempt to initialize the repository"

        FLAG_CREATE_REPOSITORY=true
    fi

    if [[ "$arg" == "--dry-run" ]]; then
        echo "Flag --dry-run detected, will execute as a dry run"

        FLAG_DRY_RUN=true
    fi
done

run_script_if_exists() {
    local script_path="$1"

    if [[ -f "$script_path" ]]; then
        echo "Executing script: $script_path"

        if ! bash "$script_path"; then
            echo "Warning: Execution of $script_path failed"
        fi
    fi
}

# Function to clean up lock file on exit
cleanup() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
}


# Ensure no other instance is running
if [[ -f "$LOCK_FILE" ]]; then
    echo "Another instance of sync-now.sh is running. Exiting."
    run_script_if_exists "$LOCK_PRESENT_SCRIPT"
    exit 1
fi


# Run cleanup on exit
trap cleanup EXIT


touch "$LOCK_FILE"


# Should we initialize the repository?
if ${FLAG_CREATE_REPOSITORY:-false}; then
    restic init
fi


# TODO: Add support for running as a dry-run
# TODO: Implement checking if /config/excludes.txt exists and if so, add "--exclude-file /config/excludes.txt" to restic
# TODO: Implement logs
# TODO: Implement running hook scripts on success or failure


echo "Starting backup..."
cd /data && restic backup .
