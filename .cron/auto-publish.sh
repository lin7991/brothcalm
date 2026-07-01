#!/bin/bash
# BrothCalm auto-publisher — fired by launchd every 3 hours
# 
# 02:00-07:00 Beijing time:
#   - Generate article HTML, store in .cron/pending/ (no git, no deploy)
#   - Auto-refill queue when < 5
# Every 3 hours:
#   - Take 1 article from .cron/pending/ → deploy (git add + commit + push)
#   - Advance queue index

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
PENDING="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending"
mkdir -p "$PENDING"

HOUR=$(TZ=Asia/Shanghai date '+%H')
HOUR=${HOUR#0}

echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'): Tick started (hour=$HOUR)" >> "$LOG"

# ────────────────────────────────────────────
# STEP 1: Content generation (02:00-07:00 only)
# ────────────────────────────────────────────
if [ "$HOUR" -ge 2 ] && [ "$HOUR" -lt 7 ]; then
  REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): Content window, queue=$REMAINING" >> "$LOG"

  if [ "$REMAINING" -le 0 ]; then
    echo "$(TZ=Asia/Shanghai date '+%H:%M'): Queue empty, nothing to generate" >> "$LOG"
  else
    # Generate article via Hermes — capture HTML output
    hermes chat --profile brothcalm -Q -q "
You are in ~/.hermes/profiles/brothcalm/workspace.

IMPORTANT: Do NOT use publish-article.py. Do NOT run git commands. Do NOT commit anything.

STEP 1: Check queue with 'python3 .cron/publish-article.py remaining'.
If remaining < 5, refill: generate 15 new article ideas (title/path/type/read_time/keywords), echo as JSON to stdout and pipe to 'python3 .cron/publish-article.py add'.

STEP 2: Read next item with 'python3 .cron/publish-article.py next'.
Extract the path, type label, read time.

STEP 3: Generate the COMPLETE article HTML using article-template.html as template.
Replace ALL placeholders.
IMPORTANT: Write the file to DISK using write_file or terminal: cat > /tmp/brothcalm-built.html << 'HEREDOC_EOF'
...full html...
HEREDOC_EOF

After writing, verify: 'head -3 /tmp/brothcalm-built.html' shows the doctype.
Then print: FILE_WRITTEN
" --skills brothcalm-content-production 2>&1 >> "$LOG"

    # Check if article was written to tmp
    if [ -f /tmp/brothcalm-built.html ]; then
      # Get slug from queue
      SLUG=$(python3 -c "
import json
q = json.load(open('.content-queue.json'))
a = q['articles'][q['index']]
print(a['path'].strip('/').replace('/', '-'))
" 2>/dev/null)
      
      # Copy to pending (raw HTML, no git yet)
      cp /tmp/brothcalm-built.html "$PENDING/${SLUG}.html"
      echo "$(TZ=Asia/Shanghai date '+%H:%M'): Staged: $SLUG" >> "$LOG"
      rm -f /tmp/brothcalm-built.html
    else
      echo "$(TZ=Asia/Shanghai date '+%H:%M'): WARNING: No article file generated" >> "$LOG"
    fi
  fi
fi

# ────────────────────────────────────────────
# STEP 2: Publish 1 article from staging
# ────────────────────────────────────────────
FIRST=$(ls -t "$PENDING"/*.html 2>/dev/null | head -1)

if [ -n "$FIRST" ]; then
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): Deploying $(basename "$FIRST")" >> "$LOG"
  
  # Publish using pipeline (now skips push with BROTHCALM_STAGE_ONLY=1)
  BROTHCALM_STAGE_ONLY=1 python3 .cron/publish-article.py publish "$FIRST" 2>&1 >> "$LOG"
  
  # Remove from pending
  rm -f "$FIRST"
  
  # Push the single commit
  git push 2>&1 >> "$LOG"
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): Deployed + pushed" >> "$LOG"
else
  echo "$(TZ=Asia/Shanghai date '+%H:%M'): No pending articles to deploy" >> "$LOG"
fi

echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'): Tick finished" >> "$LOG"
