#!/bin/sh
# Runs as an init container (postgres image) before backup.sh.
# Writes the database dump into an emptyDir which is mounted into the backup container
# as /backup/openproject.sql, so the dump is gone together with the pod.
# Same format as in OpenProject's own backups: plain SQL without privileges and owners.
set -eu

: "$DATABASE_URL"

pg_dump --version
pg_dump -x -O -f /backup/db/openproject.sql "$(echo "$DATABASE_URL" | cut -f 1 -d '?')"
ls -al /backup/db
