#!/bin/bash
# Script to back up Jenkins

BACKUP_DIR="/var/backups/jenkins"
TIMESTAMP=$(date +"%Y%m%d%H%M")
BACKUP_FILE="${BACKUP_DIR}/jenkins_backup_${TIMESTAMP}.tar.gz"

# Ensure backup directory exists
mkdir -p ${BACKUP_DIR}

# Backup Jenkins home directory
tar -czvf ${BACKUP_FILE} /var/lib/jenkins

# Remove backups older than 7 days
find ${BACKUP_DIR} -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;
