#!/bin/bash
# BrothCalm auto-publisher — fired by launchd every 3 hours
# 02:00-07:00 Beijing = Generate content (heavy AI work)
# Every tick regardless = Publish 1 article from staging
# Queue auto-refill when < 5

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
PENDING="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending"
HOUR=$(TZ=Asia/Shanghai date '+%H')
HOUR=${HOUR#0}

echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'): Tick started (hour=$HOUR)" >> "$LOG"

# ─── STEP 1: Content generation (only 02:00-07:00 Beijing) ───
if [ "$HOUR" -ge 2 ] && [ "$HOUR" -lt 7 ]; then
  REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): In content window, queue=$REMAINING" >> "$LOG"

  # Generate ONE article using Hermes
  hermes chat --profile brothcalm -Q -q "
You are in ~/.hermes/profiles/brothcalm/workspace.

STEP 1: Check queue with 'python3 .cron/publish-article.py remaining'.
If remaining < 5, refill: generate 15 new article ideas (title/path/type/read_time/keywords), echo as JSON and pipe to 'python3 .cron/publish-article.py add'.

STEP 2: Read next item with 'python3 .cron/publish-article.py next'.
Generate complete HTML using article-template.html as template.
Replace ALL placeholders.
Write to /tmp/brothcalm-article.html.
Print FILE_READY.
" --skills brothcalm-content-production 2>&1 >> "$LOG"

  mkdir -p "$PENDING"
  if [ -f /tmp/brothcalm-article.html ]; then
    SLUG=$(python3 -c "
import json
q = json.load(open('.content-queue.json'))
a = q['articles'][q['index']]
print(a['path'].strip('/').replace('/', '-'))
" 2>/dev/null)
    cp /tmp/brothcalm-article.html "$PENDING/${SLUG}.html"
    echo "$(TZ=Asia/Shanghai date '+%H:%M'): Generated + staged: $SLUG" >> "$LOG"
  fi
fi

# ─── STEP 2: Publish 1 article from pending (every tick) ───
mkdir -p "$PENDING"
FIRST=$(ls -t "$PENDING"/*.html 2>/dev/null | head -1)

if [ -n "$FIRST" ]; then
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): Publishing $(basename "$FIRST")" >> "$LOG"
  
  # Publish using the existing pipeline
  python3 .cron/publish-article.py publish "$FIRST" 2>&1 >> "$LOG"
  
  # Remove from pending on success
  if [ -f "$FIRST" ]; then
    rm "$FIRST"
    echo "$(TZ=Asia/Shanghai date '+%H:%M'): Published + cleaned up" >> "$LOG"
  fi
else
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): No pending articles to publish" >> "$LOG"
fi

echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'): Tick finished" >> "$LOG"
