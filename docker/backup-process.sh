#!/bin/bash

################################################################
#                                                              #
#  This script is responsible for actually making the backup.  #
#   It should not be ran manually, use sync-now.sh instead.    #
#                                                              #
################################################################


set -e

LOCK_FILE="/var/lock/sync-now.lock"
RESTIC_EXCLUDES_FILE="/config/excludes.txt"

SUCCESS_SCRIPT="/config/hooks/backup-success.sh"
FAILURE_SCRIPT="/config/hooks/backup-failure.sh"
LOCK_PRESENT_SCRIPT="/config/hooks/lock-present.sh"

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



# Should we initialize the repository?
if ${FLAG_CREATE_REPOSITORY:-false}; then
    restic init
fi


# Build up the restic backup arguments
RESTIC_BACKUP_ARGS=(
    'backup' # Backup command
    '.'      # Run backup in current directory
)

if ${FLAG_DRY_RUN:-false}; then
    RESTIC_BACKUP_ARGS+=( '--dry-run' )
fi

if [ -f "${RESTIC_EXCLUDES_FILE}" ]; then
    RESTIC_BACKUP_ARGS+=( '--exclude-file' "${RESTIC_EXCLUDES_FILE}" )
fi


echo "Running restic with the following arguments: ${RESTIC_BACKUP_ARGS[@]}"

touch "$LOCK_FILE"

cd /data
if restic "${RESTIC_BACKUP_ARGS[@]}"; then
    echo "Backup successful"
    run_script_if_exists "$SUCCESS_SCRIPT"

    echo "Listing changes between the new snapshot and previous:"
    restic diff $(restic snapshots --json latest | jq -r ".[0].parent, .[0].id")

    echo "Listing Restic statistics:"
    restic stats latest --mode restore-size
    restic stats latest --mode raw-data
else
    echo "Backup failed. Check the log file at $LOG_FILE for details."
    run_script_if_exists "$FAILURE_SCRIPT"
    exit 1
fi