#!/bin/bash
# BrothCalm content creator — fired at 02:00 & 05:00 Beijing time
# Generates 2 articles (EN + ZH) into .cron/pending/ buffer each run
# Publishing is handled separately by auto-publish.sh (every 6 hours)

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
PENDING="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending"
mkdir -p "$PENDING"

log() { echo "$(TZ=Asia/Shanghai date '+%H:%M'): $*" >> "$LOG"; }

log "[CREATE] Content creation tick started"

# ─── Catch-up push (if backlogged from previous failures) ───
if git log --oneline origin/main..HEAD 2>/dev/null | grep -q .; then
  log "[CREATE] Backlogged commits, catch-up push..."
  gh_token=$(cat "$HOME/.hermes/profiles/brothcalm/workspace/.cron/.gh_token" 2>/dev/null)
  push_url="https://github.com/lin7991/brothcalm.git"
  [ -n "$gh_token" ] && push_url="https://${gh_token}@github.com/lin7991/brothcalm.git"
  for attempt in 1 2 3; do
    if git push "$push_url" main 2>&1 >> "$LOG"; then
      log "[CREATE] Catch-up push successful"
      break
    fi
    sleep 20
  done
fi

# Check queue
REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
log "[CREATE] Queue: $REMAINING remaining"

if [ "$REMAINING" -le 0 ]; then
  log "[CREATE] Queue empty, nothing to generate"
  exit 0
fi

# Generate exactly 2 articles this run
TARGET=2
if [ "$REMAINING" -lt "$TARGET" ]; then
  TARGET=$REMAINING
fi

log "[CREATE] Generating $TARGET article(s)"

for i in $(seq 1 "$TARGET"); do
  REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
  [ "$REMAINING" -le 0 ] && break

  # Compute SLUG BEFORE hermes chat — agent runs `stage` (index+1)
  SLUG=$(python3 -c "
import json
q = json.load(open('.content-queue.json'))
a = q['articles'][q['index']]
print(a['path'].strip('/').replace('/', '-'))
" 2>/dev/null)

  log "[CREATE] Generating article $i: $SLUG"

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
    cp /tmp/brothcalm-article.html "$PENDING/${SLUG}.html"
    rm -f /tmp/brothcalm-article.html
    log "[CREATE] Staged EN: $SLUG"

    if [ -f /tmp/brothcalm-zh.html ]; then
      cp /tmp/brothcalm-zh.html "$PENDING/zh-${SLUG}.html"
      rm -f /tmp/brothcalm-zh.html
      log "[CREATE] Staged ZH: zh-$SLUG"
    else
      log "[CREATE] ⚠️ ZH NOT generated for $SLUG — will need manual backfill"
    fi
  else
    log "[CREATE] WARNING: article not generated for $SLUG"
  fi
done

log "[CREATE] Content creation tick finished"
