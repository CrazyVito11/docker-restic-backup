FROM restic/restic:0.18.1

USER root

# Update the local package cache and install dependencies
RUN apk update
RUN apk add fcron bash envsubst curl

# Prepare the sync script
COPY /docker/sync-now.sh /
RUN chmod +x /sync-now.sh

# Prepare configuration
COPY ./config /config
RUN env > /config/base.env
RUN mv /config/.env /config/user.env

# Prepare SSH configuration
RUN mkdir -p /root/.ssh && cp /config/ssh/known_hosts /root/.ssh/known_hosts
RUN bash -c 'set -o allexport; source /config/user.env; echo -e "Host restic-backup-host\n    Hostname $SFTP_HOST_IP\n    User $SFTP_HOST_USERNAME\n    Port $SFTP_HOST_PORT\n    IdentityFile /config/ssh/$SFTP_HOST_SSH_KEY_NAME" > /etc/ssh/ssh_config.d/restic-backup-host.conf'

# Prepare Restic configuration
RUN bash -c 'set -o allexport; source /config/user.env; echo -e "sftp:restic-backup-host:${SFTP_HOST_DESTINATION_PATH}" > /config/restic-repository'
RUN bash -c 'set -o allexport; source /config/user.env; echo -e "$REPOSITORY_PASSWORD" > /config/.restic-password'

# Configure fcron
RUN bash -c 'set -o allexport; source /config/user.env; echo "$BACKUP_CRON_INTERVAL bash -c \"set -o allexport; source /config/base.env; source /config/user.env; /sync-now.sh\" >> /tmp/cron.log 2>&1" > /tmp/fcron.tab'
RUN fcrontab /tmp/fcron.tab


ENTRYPOINT ["fcron", "--foreground", "--firstsleep", "0"]
