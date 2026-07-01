#!/bin/bash
# BrothCalm auto-publisher — fired by launchd every 3 hours
# Uses hermes chat in one-shot mode to generate and publish content

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

# Log start
echo "$(date): Auto-publish tick started" >> "$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"

# Check remaining — if 0, still run Hermes to refill
REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
echo "$(date): Queue has $REMAINING items" >> "$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"

# Run Hermes in one-shot to refill if needed, then publish
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
" --skills brothcalm-content-production 2>&1 >> "$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"

echo "$(date): Auto-publish run complete" >> "$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
