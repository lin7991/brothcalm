#!/bin/bash
# Weekly read-only site audit. It reports real issues; it does not rewrite pages.
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"
cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1
LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/weekly-audit.log"
{
  echo "=== $(TZ=Asia/Shanghai date '+%F %T %Z') weekly site audit ==="
  python3 /Users/xj/.hermes/profiles/brothcalm/skills/product/brothcalm-content-production/scripts/audit-site-health.py .
  python3 .cron/check-topic-cadence.py
} >> "$LOG" 2>&1
status=$?
echo "weekly audit exit=$status" >> "$LOG"
exit "$status"
