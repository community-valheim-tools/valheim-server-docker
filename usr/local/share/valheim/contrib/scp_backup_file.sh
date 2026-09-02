#!/bin/bash
#
# Example POST_BACKUP_HOOK script.
# Use by running container with
#  -e POST_BACKUP_HOOK="/usr/local/share/valheim/contrib/scp_backup_file.sh @BACKUP_FILE@"
# and volume mount any ssh key and/or known_hosts file into the container's /root/.ssh/
#
# Mandatory variables:
# BACKUP_SCP_USER user used to authenticate with the remote host
# BACKUP_SCP_HOST remote hostname or IP address
# BACKUP_SCP_PATH remote path where the zip file will be stored
# 
# Optional variables:
# BACKUP_SCP_STRICT_KEY_CHECK (yes/no)
# BACKUP_SCP_PORT defaults to 22
# BACKUP_SCP_KEY path to a private key file

# Full path to the worlds_local backup ZIP we just created
# e.g. /config/backups/worlds_local-20210303-144536.zip
backup_file=$1

: "${BACKUP_SCP_USER:=}" "${BACKUP_SCP_HOST:=}" "${BACKUP_SCP_PATH:=}"

if [ -z "$BACKUP_SCP_USER" ] || [ -z "$BACKUP_SCP_HOST" ] || [ -z "$BACKUP_SCP_PATH" ]; then
    echo "One of BACKUP_SCP_USER, BACKUP_SCP_HOST or BACKUP_SCP_PATH not set - quitting"
    exit 1
fi

BACKUP_SCP_STRICT_KEY_CHECK=${BACKUP_SCP_STRICT_KEY_CHECK:-yes}
BACKUP_SCP_PORT=${BACKUP_SCP_PORT:-22}
BACKUP_SCP_KEY=${BACKUP_SCP_KEY:-}

scp_args=(-o "StrictHostKeyChecking=$BACKUP_SCP_STRICT_KEY_CHECK" -p "$BACKUP_SCP_PORT")
if [ -n "$BACKUP_SCP_KEY" ]; then
    scp_args+=(-i "$BACKUP_SCP_KEY")
fi

# remove trailing slash if any
BACKUP_SCP_PATH=${BACKUP_SCP_PATH%/}

destination="$BACKUP_SCP_USER@$BACKUP_SCP_HOST:$BACKUP_SCP_PATH/$(basename "$backup_file")"

echo "Using scp to copy $backup_file to $destination"
timeout 300 scp "${scp_args[@]}" "$backup_file" "$destination"
