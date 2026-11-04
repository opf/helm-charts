#!/bin/bash
set -e
set -o pipefail
set -u

: "$BACKUP_ENDPOINT"
: "$BACKUP_BUCKET"
: "$BACKUP_ACCESS_KEY_ID"
: "$BACKUP_SECRET_ACCESS_KEY"
: "$REPLICA_ENDPOINT"
: "$REPLICA_BUCKET"
: "$REPLICA_ACCESS_KEY_ID"
: "$REPLICA_SECRET_ACCESS_KEY"
: "$KOPIA_CACHE_DIRECTORY"
: "$KOPIA_PASSWORD"

BACKUP_REGION="${BACKUP_REGION:-}"
REPLICA_REGION="${REPLICA_REGION:-}"

BACKUP_ENDPOINT_HOST="$(echo "$BACKUP_ENDPOINT" | sed -E 's/^https?:\/\///')"
REPLICA_ENDPOINT_HOST="$(echo "$REPLICA_ENDPOINT" | sed -E 's/^https?:\/\///')"

BACKUP_REPO_OPTS="--endpoint $BACKUP_ENDPOINT_HOST --bucket $BACKUP_BUCKET --access-key $BACKUP_ACCESS_KEY_ID --secret-access-key $BACKUP_SECRET_ACCESS_KEY"
REPLICA_SYNC_OPTS="--endpoint $REPLICA_ENDPOINT_HOST --bucket $REPLICA_BUCKET --access-key $REPLICA_ACCESS_KEY_ID --secret-access-key $REPLICA_SECRET_ACCESS_KEY --delete"
if [ -n "$BACKUP_REGION" ]; then
  BACKUP_REPO_OPTS="$BACKUP_REPO_OPTS --region $BACKUP_REGION"
fi
if [ -n "$REPLICA_REGION" ]; then
  REPLICA_SYNC_OPTS="$REPLICA_SYNC_OPTS --region $REPLICA_REGION"
fi
# Endpoints given with an explicit http:// prefix are accessed without TLS.
if echo "$BACKUP_ENDPOINT" | grep -q '^http://'; then
  BACKUP_REPO_OPTS="$BACKUP_REPO_OPTS --disable-tls"
fi
if echo "$REPLICA_ENDPOINT" | grep -q '^http://'; then
  REPLICA_SYNC_OPTS="$REPLICA_SYNC_OPTS --disable-tls"
fi

set +e
kopia repository connect s3 $BACKUP_REPO_OPTS &> /tmp/kopia.output
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

kopia repository sync-to s3 $REPLICA_SYNC_OPTS

echo "[$(date)] Sync of backup replica complete"
