#!/bin/bash
# Performs a full verification of the latest kopia snapshot by downloading
# and decrypting all stored content.
set -e
set -o pipefail
set -u

: "$BACKUP_ENDPOINT"
: "$BACKUP_BUCKET"
: "$BACKUP_ACCESS_KEY_ID"
: "$BACKUP_SECRET_ACCESS_KEY"
: "$KOPIA_CACHE_DIRECTORY"
: "$KOPIA_PASSWORD"

BACKUP_VERIFICATION_MONITOR_HEARTBEAT_URL="${BACKUP_VERIFICATION_MONITOR_HEARTBEAT_URL:-}"
BACKUP_REGION="${BACKUP_REGION:-}"

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
  echo "Failed to connect to kopia repo"
  cat /tmp/kopia.output
  exit 1
fi

kopia cache set \
  --cache-directory "$KOPIA_CACHE_DIRECTORY" \
  --metadata-cache-size-mb=250 \
  --content-cache-size-limit-mb=250

echo "[$(date)] Starting verification of latest snapshot"

kopia snapshot verify --verify-files-percent=100 --file-parallelism=10 --parallel=10

echo "[$(date)] Verification of backup complete"

if [ -n "$BACKUP_VERIFICATION_MONITOR_HEARTBEAT_URL" ]; then
  curl --insecure "$BACKUP_VERIFICATION_MONITOR_HEARTBEAT_URL"
fi
