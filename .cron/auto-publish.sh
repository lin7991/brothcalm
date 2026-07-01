#!/bin/bash
# BrothCalm auto-publisher — fired by launchd every 3 hours
# Content creation restricted to Beijing time 02:00-07:00
# Queue refill (< 5) also only during content window

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'): Tick started" >> "$LOG"

# Check current hour (Beijing time)
HOUR=$(TZ=Asia/Shanghai date '+%H')
HOUR=${HOUR#0}  # strip leading zero, so 08 → 8

# Content window: 02:00 - 06:59 Beijing time
if [ "$HOUR" -ge 2 ] && [ "$HOUR" -lt 7 ]; then
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): In content window (02:00-07:00 Beijing)" >> "$LOG"

  # Check queue
  REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): Queue has $REMAINING items" >> "$LOG"

  # Run Hermes to refill (< 5) and publish
  hermes chat --profile brothcalm -Q -q "
You are in ~/.hermes/profiles/brothcalm/workspace.

STEP 1: Check queue with 'python3 .cron/publish-article.py remaining'.
If remaining < 5, you need to refill first:
  - Generate 15 new article ideas (mix of: ingredients, teas, recipes, food therapy guides, TCM theory)
  - Each item must have: title, path, type (ingredient/tea/recipe/food-therapy/theory), read_time, keywords
  - Format as JSON array and pipe to: echo '[...]' | python3 .cron/publish-article.py add

STEP 2: Read next item with 'python3 .cron/publish-article.py next'.
Generate a complete HTML article about the topic using article-template.html as template.
Write to /tmp/brothcalm-article.html.
IMPORTANT: Replace ALL template placeholders (<!--TITLE-->, <!--META_DESC-->, <!--CANONICAL_PATH-->, <!--OG_TITLE-->, <!--OG_DESC-->, <!--H1-->, <!--TYPE_LABEL-->, <!--READ_TIME-->, <!--CONTENT-->, <!--FAQ_SCHEMA-->).
Run 'python3 .cron/publish-article.py publish /tmp/brothcalm-article.html'.
Verify the page was committed with 'git log --oneline -1'.
" --skills brothcalm-content-production 2>&1 >> "$LOG"

  echo "$(TZ=Asia/Shanghai date '+%H:%M'): Content window run complete" >> "$LOG"
else
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): Outside content window — sleeping. Next window: 02:00-07:00 Beijing" >> "$LOG"
fi

echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'): Tick finished" >> "$LOG"
