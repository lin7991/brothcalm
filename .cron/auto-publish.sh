#!/bin/bash
# BrothCalm auto-publisher — fired by launchd every hour
# Publishes 1 bilingual article pair (EN + ZH) from .cron/pending/ every hour
# Content generation is handled separately by content-create.sh (02:00 & 05:00)

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
PENDING="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending"
mkdir -p "$PENDING"

log() { echo "$(TZ=Asia/Shanghai date '+%H:%M'): $*" >> "$LOG"; }

log "Tick started"

# Generate FAQ only from real question H2s and following answers.
python3 .cron/generate-faq-schema.py >> "$LOG" 2>&1 || log "⚠️ FAQ schema pass failed; continuing safely"
# Keep staged pages GEO/SEO-ready before they enter the published tree.
python3 .cron/seo-geo-optimize.py >> "$LOG" 2>&1 || log "⚠️ SEO/GEO pass failed; continuing safely"

# ─── Push helper: use GitHub REST API (github.com is blocked by GFW; api.github.com works) ───
push_with_retry() {
  local max=$1
  for attempt in $(seq 1 "$max"); do
    if python3 .cron/api_push.py >> "$LOG" 2>&1; then
      return 0
    fi
    log "API push attempt $attempt/$max failed, retrying in 20s..."
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

# ─── Hourly bilingual publishing cadence ───
PAIR=$(python3 - "$PENDING" <<'PY'
from pathlib import Path
import sys
pending = Path(sys.argv[1])
english = sorted((p for p in pending.glob('*.html') if not p.name.startswith('zh-')), key=lambda p: p.stat().st_mtime)
for en in english:
    zh = pending / f'zh-{en.name}'
    if zh.is_file():
        print(en)
        print(zh)
        break
PY
)
if [ -n "$PAIR" ]; then
  EN_FILE=$(printf '%s\n' "$PAIR" | sed -n '1p')
  ZH_FILE=$(printf '%s\n' "$PAIR" | sed -n '2p')
  log "Publishing EN+ZH pair: $(basename "$EN_FILE") + $(basename "$ZH_FILE")"
  if BROTHCALM_STAGE_ONLY=1 python3 .cron/publish-article.py publish "$EN_FILE" >> "$LOG" 2>&1; then
    if BROTHCALM_STAGE_ONLY=1 python3 .cron/publish-article.py publish "$ZH_FILE" >> "$LOG" 2>&1; then
      rm -f "$EN_FILE"
      rm -f "$ZH_FILE"
      if push_with_retry 5; then
        log "Published + pushed bilingual pair"
      else
        log "⚠️ Pair committed locally; push failed after 5 attempts — will retry next tick"
      fi
    else
      log "❌ ZH publish failed; keeping ZH pending file for retry"
      if push_with_retry 5; then log "EN published + pushed; ZH retained for retry"; fi
    fi
  else
    log "❌ EN publish failed; keeping both pending files for retry"
  fi
else
  log "No complete EN+ZH pair to deploy"
fi

log "Tick finished"
