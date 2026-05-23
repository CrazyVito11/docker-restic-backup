#!/bin/bash

##############################################################
#                                                            #
#  This script is responsible for checking the health of     #
#   the Restic repository and logging the result.            #
#                                                            #
##############################################################

set -e
set -o allexport;

source /config/base.env;
source /config/user.env;

TIMESTAMP=$(date +"%Y-%m-%d-%H%M")

LOG_DIR="/logs"
LOG_FILE="${LOG_DIR}/${TIMESTAMP}-restic-health-check.log"

SUCCESS_SCRIPT="/config/hooks/health-check-success.sh"
FAILURE_SCRIPT="/config/hooks/health-check-failure.sh"

export RESTIC_REPOSITORY_FILE="/config/restic-repository"
export RESTIC_PASSWORD_FILE="/config/.restic-password"

run_script_if_exists() {
    local script_path="$1"

    if [[ -f "$script_path" ]]; then
        echo "Executing script: $script_path"

        if ! bash "$script_path"; then
            echo "Warning: Execution of $script_path failed"
        fi
    fi
}

echo "---------------[ Docker Restic Health Check ]---------------" >  $LOG_FILE
echo "Timestamp:  $(date)"                                           >> $LOG_FILE
echo "SFTP IP:    ${SFTP_HOST_IP}"                                   >> $LOG_FILE
echo "SFTP Port:  ${SFTP_HOST_PORT}"                                 >> $LOG_FILE
echo "SFTP User:  ${SFTP_HOST_USERNAME}"                             >> $LOG_FILE
echo "SFTP Path:  ${SFTP_HOST_DESTINATION_PATH}"                     >> $LOG_FILE
echo "------------------------------------------------------------"  >> $LOG_FILE
echo -e "\n"                                                         >> $LOG_FILE

if restic check 2>&1 | tee -a $LOG_FILE; then
    echo "Health check successful" | tee -a $LOG_FILE
    run_script_if_exists "$SUCCESS_SCRIPT"
else
    echo "Health check failed. Check the log file at $LOG_FILE for details." | tee -a $LOG_FILE
    run_script_if_exists "$FAILURE_SCRIPT"
    exit 1
fi
