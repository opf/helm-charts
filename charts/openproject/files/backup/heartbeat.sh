#!/bin/bash
# Pings a heartbeat monitor (e.g. UptimeRobot) after a job succeeded. Does nothing without a URL.
#
# Never fails the job: its work is already done, and a failed job would only be run again by the
# CronJob. If the monitor can't be reached or responds with an error, this prints a warning and the
# monitor alerts about the missing heartbeat. The URL is not printed as it may contain a token.
set -u

url="${1:-}"
[ -n "$url" ] || exit 0

if ! curl --fail --silent --show-error --insecure --output /dev/null \
  --max-time 30 --retry 3 --retry-all-errors "$url"; then
  echo "Warning: failed to send the heartbeat to the monitor."
fi
exit 0
