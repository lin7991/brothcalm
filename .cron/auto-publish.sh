#!/bin/bash
# BrothCalm auto-publisher — fired by launchd every 6 hours
# Publishes 1 article from .cron/pending/ buffer + catches up on push backlog
# Content generation is handled separately by content-create.sh (02:00 & 05:00)

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
PENDING="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending"
mkdir -p "$PENDING"

log() { echo "$(TZ=Asia/Shanghai date '+%H:%M'): $*" >> "$LOG"; }

log "Tick started"

# ─── Push helper: use token URL (more reliable than keychain) ───
push_with_retry() {
  local max=$1
  local gh_token
  gh_token=$(cat "$HOME/.hermes/profiles/brothcalm/workspace/.cron/.gh_token" 2>/dev/null)
  local push_url="https://github.com/lin7991/brothcalm.git"
  [ -n "$gh_token" ] && push_url="https://${gh_token}@github.com/lin7991/brothcalm.git"
  for attempt in $(seq 1 "$max"); do
    if git push "$push_url" main 2>&1 >> "$LOG"; then
      return 0
    fi
    log "Push attempt $attempt/$max failed, retrying in 20s..."
    sleep 20
  done
  return 1
}

# ─── Catch-up push: try to push any backlogged commits at start of every tick ───
if git log --oneline origin/main..HEAD 2>/dev/null | grep -q .; then
  log "Backlogged commits detected, attempting catch-up push..."
  if push_with_retry 3; then
    log "Catch-up push successful"
  else
    log "Catch-up push failed, will retry next tick"
  fi
fi

# ─── Publish 1 from pending (every 6-hour tick) ───
FIRST=$(ls -t "$PENDING"/*.html 2>/dev/null | head -1)
if [ -n "$FIRST" ]; then
  log "Publishing: $(basename "$FIRST")"
  BROTHCALM_STAGE_ONLY=1 python3 .cron/publish-article.py publish "$FIRST" 2>&1 >> "$LOG"
  rm -f "$FIRST"
  # Push with retry (up to 5 attempts)
  if push_with_retry 5; then
    log "Published + pushed"
  else
    log "⚠️ Push failed after 5 attempts — commit saved locally, will push next tick"
  fi
else
  log "No pending articles to deploy"
fi

log "Tick finished"
