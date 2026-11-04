#!/bin/bash
# Snapshots /mnt/backup, which mirrors the layout of OpenProject's own backups:
#   /mnt/backup/openproject.sql  the database dump written by dump-db.sh
#   /mnt/backup/attachment       attachments
#   /mnt/backup/custom_style     custom logos, icons and fonts
# The directories are subPath mounts of the assets PVC or, if attachments are stored
# in S3, the respective prefixes of the OpenProject bucket mounted via rclone/fuse.
# It's below /mnt as AppArmor's fusermount3 profile (e.g. on Ubuntu nodes) only allows FUSE
# mounts in a few places like /mnt.
set -e
set -o pipefail
set -u

: "$BACKUP_ENDPOINT"
: "$BACKUP_BUCKET"
: "$BACKUP_ACCESS_KEY_ID"
: "$BACKUP_SECRET_ACCESS_KEY"
: "$KOPIA_CACHE_DIRECTORY"
: "$KOPIA_PASSWORD"

BACKUP_MONITOR_HEARTBEAT_URL="${BACKUP_MONITOR_HEARTBEAT_URL:-}"
BACKUP_REGION="${BACKUP_REGION:-}"
# "s3": mount the OpenProject S3 bucket via rclone/fuse then snapshot it
# "local": snapshot the assets PVC directly
ATTACHMENTS_STORAGE="${ATTACHMENTS_STORAGE:-local}"

BACKUP_ENDPOINT_HOST="$(echo "$BACKUP_ENDPOINT" | sed -E 's/^https?:\/\///')"
REPO_OPTS="--endpoint $BACKUP_ENDPOINT_HOST --bucket $BACKUP_BUCKET --access-key $BACKUP_ACCESS_KEY_ID --secret-access-key $BACKUP_SECRET_ACCESS_KEY"
if [ -n "$BACKUP_REGION" ]; then
  REPO_OPTS="$REPO_OPTS --region $BACKUP_REGION"
fi
# An endpoint given with an explicit http:// prefix is accessed without TLS.
if echo "$BACKUP_ENDPOINT" | grep -q '^http://'; then
  REPO_OPTS="$REPO_OPTS --disable-tls"
fi

set +e
kopia repository connect s3 $REPO_OPTS &> /tmp/kopia.output
connect_exit_code=$?
set -e

if [ "$connect_exit_code" -ne 0 ]; then
  if grep -q "repository not initialized" /tmp/kopia.output; then
    # The bucket itself must already exist; it is not created by the chart.
    echo "Initializing kopia repository"
    kopia repository create s3 $REPO_OPTS
  else
    echo "Failed to connect to kopia repo"
    cat /tmp/kopia.output
    exit 1
  fi
fi

if [ "$ATTACHMENTS_STORAGE" = "s3" ]; then
  : "$OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID"
  : "$OPENPROJECT_FOG_CREDENTIALS_AWS__SECRET__ACCESS__KEY"
  : "$OPENPROJECT_FOG_CREDENTIALS_REGION"
  : "$OPENPROJECT_FOG_CREDENTIALS_ENDPOINT"
  : "$OPENPROJECT_FOG_DIRECTORY"

  rclone config create remote-files s3 \
    provider Other \
    env_auth false \
    access_key_id "$OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID" \
    secret_access_key "$OPENPROJECT_FOG_CREDENTIALS_AWS__SECRET__ACCESS__KEY" \
    region "$OPENPROJECT_FOG_CREDENTIALS_REGION" \
    endpoint "$OPENPROJECT_FOG_CREDENTIALS_ENDPOINT" \
    location_constraint "$OPENPROJECT_FOG_CREDENTIALS_REGION" \
    acl private

  # Run in the background rather than with --daemon, which discards the mount's errors, so
  # they end up in the container log. The mounts go away together with the container.
  declare -A mount_pids
  for dir in attachment custom_style; do
    mkdir -p "/mnt/backup/$dir"
    rclone mount --read-only "remote-files:/$OPENPROJECT_FOG_DIRECTORY/uploads/$dir" "/mnt/backup/$dir" &
    mount_pids[$dir]=$!
  done

  for dir in attachment custom_style; do
    for _ in $(seq 1 30); do
      mountpoint -q "/mnt/backup/$dir" && break
      kill -0 "${mount_pids[$dir]}" 2> /dev/null || break
      sleep 1
    done
    if ! mountpoint -q "/mnt/backup/$dir"; then
      echo "Failed to mount $dir from the attachments bucket."
      exit 1
    fi
  done
fi

kopia cache set \
  --cache-directory "$KOPIA_CACHE_DIRECTORY" \
  --metadata-cache-size-mb=250 \
  --content-cache-size-limit-mb=250

kopia policy set --global \
  --keep-annual 0 \
  --keep-hourly 0 \
  --keep-monthly 6 \
  --keep-weekly 24 \
  --keep-daily 168 \
  --keep-latest 42 \
  --compression zstd-fastest

# A fixed source, independent of the user the container runs as (root with FUSE, else the
# OpenProject user) and of where the files are mounted, so all snapshots form one history
# whichever way attachments are mounted.
kopia snapshot create /mnt/backup --override-source "openproject@backup-cronjob:/backup"

echo "[$(date)] Full backup complete"

if [ -n "$BACKUP_MONITOR_HEARTBEAT_URL" ]; then
  curl --insecure "$BACKUP_MONITOR_HEARTBEAT_URL"
fi
