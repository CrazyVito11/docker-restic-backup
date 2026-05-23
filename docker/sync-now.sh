#!/bin/bash

##############################################################
#                                                            #
#  This script is responsible for preparing the environment  #
#   for backup-process.sh, it also handles creating logs.    #
#                                                            #
##############################################################

set -e
set -o allexport;

source /config/base.env;
source /config/user.env; 

TIMESTAMP=$(date +"%Y-%m-%d-%H%M")

LOG_DIR="/logs"
LOG_FILE="${LOG_DIR}/${TIMESTAMP}-restic.log"

echo "---------------[ Docker Restic Backup ]---------------" >  $LOG_FILE
echo "Timestamp:  $(date)"                                    >> $LOG_FILE
echo "Source dir: ${BACKUP_DIRECTORY}"                        >> $LOG_FILE
echo "SFTP IP:    ${SFTP_HOST_IP}"                            >> $LOG_FILE
echo "SFTP Port:  ${SFTP_HOST_PORT}"                          >> $LOG_FILE
echo "SFTP User:  ${SFTP_HOST_USERNAME}"                      >> $LOG_FILE
echo "SFTP Path:  ${SFTP_HOST_DESTINATION_PATH}"              >> $LOG_FILE
echo "------------------------------------------------------" >> $LOG_FILE
echo -e "\n"                                                  >> $LOG_FILE


bash /app/scripts/backup-process.sh "$@" | tee -a $LOG_FILE
