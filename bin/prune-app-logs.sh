#!/bin/bash
# Deletes old log files from apps that log excessively and offer no setting
# to turn it down. Runs via a LaunchAgent (login + every 4 hours); logs to
# ~/.local/share/chezmoi-logs/prune-app-logs.log.
#
# - Reolink desktop client: SDK.*.log files grow ~3 GB/day (169 GB in two
#   months). Keep the last 24 hours for troubleshooting.
#
# Usage: bin/prune-app-logs.sh

set -euo pipefail

reolink="${HOME}/Library/Logs/reolink"
if [ -d "$reolink" ]; then
  count="$(/usr/bin/find "$reolink" -maxdepth 1 -type f -name 'SDK.*' -mmin +1440 -print -delete | wc -l | tr -d ' ')"
  echo "==> $(date '+%F %T') reolink: removed ${count} SDK log file(s) older than 24h"
fi
