#!/bin/bash
# BrothCalm auto-publisher — fired by launchd every 3 hours
#
# Content creation (AI writing):  02:00-07:00 Beijing time only
# Publishing (deploy to web):     Every 3 hours, from .cron/pending/ buffer
#
# How it works:
#   02:00 tick → generate article A → store in .cron/pending/ → publish A
#   05:00 tick → generate article B → store in .cron/pending/ → publish B
#   08:00 tick → (no generation) → publish C from pending (if any)
#   11:00 tick → (no generation) → publish D from pending (if any)
#
# The pending buffer ensures articles trickle out every 3 hours
# even though they were all written during 02-07.

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
PENDING="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending"
mkdir -p "$PENDING"

HOUR=$(TZ=Asia/Shanghai date '+%H')
HOUR=${HOUR#0}

log() { echo "$(TZ=Asia/Shanghai date '+%H:%M'): $*" >> "$LOG"; }

log "Tick started (hour=$HOUR)"

# ─── Content creation: only 02:00-07:00 ───
IN_WINDOW=false
if [ "$HOUR" -ge 2 ] && [ "$HOUR" -lt 7 ]; then
  IN_WINDOW=true
  REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
  log "Content window, queue=$REMAINING"
  
  # Generate articles until pending is well-stocked
  PENDING_COUNT=$(ls "$PENDING"/*.html 2>/dev/null | wc -l | tr -d ' ')
  TARGET=$((8 - PENDING_COUNT))  # stock 8 articles for ~24h of publishing
  [ "$TARGET" -lt 0 ] && TARGET=0
  [ "$REMAINING" -lt "$TARGET" ] && TARGET=$REMAINING

  if [ "$TARGET" -gt 0 ]; then
    log "Building buffer: need $TARGET more (pending=$PENDING_COUNT, queue=$REMAINING)"
  fi

  while [ "$TARGET" -gt 0 ] && [ "$REMAINING" -gt 0 ]; do
    # Generate article — save to pending, no deploy yet
    hermes chat --profile brothcalm -Q -q "
You are in ~/.hermes/profiles/brothcalm/workspace.

STEP 1: Check queue with 'python3 .cron/publish-article.py remaining'.
If remaining < 5, refill: generate 15 new article ideas (title/path/type/read_time/keywords), echo as JSON and pipe to 'python3 .cron/publish-article.py add'.

STEP 2: Read next item with 'python3 .cron/publish-article.py next'.
Generate the ENGLISH article HTML using article-template.html as template.
Replace ALL placeholders (especially <!--TITLE-->, <!--CONTENT-->, etc.).
Write to /tmp/brothcalm-article.html.

Then generate the CHINESE version of the same article:
- Path: /zh + the same path (e.g. /zh/ingredients/goji-berries/)
- Use article-template-zh.html as template (read it first, create if not exists)
- Title and content in Chinese
- lang=\"zh-CN\"
- The toggle button text should auto-switch (this is handled by JS)
Write to /tmp/brothcalm-zh.html.

Then run: python3 .cron/publish-article.py stage
Then print FILE_READY.
" --skills brothcalm-content-production 2>&1 >> "$LOG"

    if [ -f /tmp/brothcalm-article.html ]; then
      SLUG=$(python3 -c "
import json
q = json.load(open('.content-queue.json'))
a = q['articles'][q['index']]
print(a['path'].strip('/').replace('/', '-'))
" 2>/dev/null)
      cp /tmp/brothcalm-article.html "$PENDING/${SLUG}.html"
      rm -f /tmp/brothcalm-article.html
      log "Staged EN: $SLUG (will publish on next available tick)"
      
      # Also stage Chinese version if generated
      if [ -f /tmp/brothcalm-zh.html ]; then
        cp /tmp/brothcalm-zh.html "$PENDING/zh-${SLUG}.html"
        rm -f /tmp/brothcalm-zh.html
        log "Staged ZH: zh-$SLUG"
      fi
      REMAINING=$((REMAINING - 1))
      TARGET=$((TARGET - 1))
    else
      log "WARNING: /tmp/brothcalm-article.html not found after hermes chat"
    fi
  done
fi

# ─── Publish 1 from pending (every tick, skip if just generated) ───
FIRST=$(ls -t "$PENDING"/*.html 2>/dev/null | head -1)
if [ -n "$FIRST" ] && [ "$IN_WINDOW" = false ]; then
  log "Publishing: $(basename "$FIRST")"
  BROTHCALM_STAGE_ONLY=1 python3 .cron/publish-article.py publish "$FIRST" 2>&1 >> "$LOG"
  rm -f "$FIRST"
  git push 2>&1 >> "$LOG"
  log "Published + pushed"
else
  if [ -z "$FIRST" ]; then
    log "No pending articles to deploy"
  fi
fi

log "Tick finished"
