#!/bin/bash
# BrothCalm content creator — fired at 02:00 & 05:00 Beijing time
# When the queue falls below 10, refills 100 ideas and generates 100 bilingual
# article pairs into .cron/pending/; partial batches resume on the next tick.
# Publishing is handled separately by auto-publish.sh (every hour)

export HERMES_HOME="$HOME/.hermes"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/publish.log"
PENDING="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending"
REVIEW="$HOME/.hermes/profiles/brothcalm/workspace/.cron/pending-review"
BATCH_STATE="$HOME/.hermes/profiles/brothcalm/workspace/.cron/.generation-batch.json"
mkdir -p "$PENDING" "$REVIEW"
LOCK="$HOME/.hermes/profiles/brothcalm/workspace/.cron/.content-create.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  log() { echo "$(TZ=Asia/Shanghai date '+%H:%M'): $*" >> "$LOG"; }
  log "[CREATE] Previous batch still running; skipping overlapping tick"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

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

REFILL=0
if [ "$REMAINING" -lt 10 ] && [ ! -f "$BATCH_STATE" ]; then
  REFILL=1
  log "[CREATE] Queue below 10; asking Hermes to append exactly 100 fresh ideas"
  hermes chat --profile brothcalm -Q -q "
You are in ~/.hermes/profiles/brothcalm/workspace.
Read .content-queue.json and check remaining with python3 .cron/publish-article.py remaining.
If fewer than 10 remain, create exactly 100 new, non-duplicate BrothCalm article ideas across ingredients, teas, recipes, food-therapy guides, and theory. Each item must include title, unique path, type, read_time, and keywords. Add them using JSON piped to python3 .cron/publish-article.py add. Do not generate article HTML in this step. Print the final remaining count.
" --skills brothcalm-content-production 2>&1 >> "$LOG"
  REMAINING=$(python3 .cron/publish-article.py remaining 2>/dev/null)
  log "[CREATE] Queue after refill: $REMAINING remaining"
  python3 - "$BATCH_STATE" <<'PY'
import json, sys
q = json.load(open('.content-queue.json'))
json.dump({'target_index': q['index'] + 100}, open(sys.argv[1], 'w'))
PY
fi

if ! [[ "$REMAINING" =~ ^[0-9]+$ ]] || [ "$REMAINING" -le 0 ]; then
  log "[CREATE] Queue refill failed or queue still empty; stopping safely"
  exit 1
fi

# Generate the remainder of the active 100-pair batch, or a small top-up when
# no low-queue batch is active.
TARGET=4
if [ -f "$BATCH_STATE" ]; then
  TARGET=$(python3 - "$BATCH_STATE" <<'PY'
import json, sys
q = json.load(open('.content-queue.json'))
s = json.load(open(sys.argv[1]))
print(max(0, s['target_index'] - q['index']))
PY
  )
fi
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
You are in ~/.hermes/profiles/brothcalm/workspace. Read .cron/content-quality-policy.md before writing.

STEP 1: Read next item with 'python3 .cron/publish-article.py next'.
Generate the ENGLISH article HTML using article-template.html as template.
Replace ALL placeholders (especially <!--TITLE-->, <!--CONTENT-->, etc.).
Write to /tmp/brothcalm-article.html.

CONTENT QUALITY CONTRACT — write for a curious reader making a real food
 decision, not for a glossary. Select the length range for the queue item's
 type from .cron/content-quality-policy.md; do not pad an article to a generic
 length. Every article must answer the likely question in the first 120 words,
help the reader compare options and try one safe, practical step, and include
an HTML comment like `<!--CONTENT_META: intent=...; audience=...; angle=...; cluster=... -->` (no medical claims in metadata).
Use this structure inside <!--CONTENT--> (adapt headings naturally):
1. Quick answer: 2-4 direct sentences.
2. Is this guide for you? Give realistic situations and when another guide is better.
3. The decision: Choose this if / Consider another option if / Start with.
4. TCM lens: label 性、味、归经, qi, yin, dampness and similar ideas as traditional theory, not anatomy or proven treatment.
5. Modern food lens: distinguish nutrition facts, limited evidence, and unknowns.
6. Compare nearby choices with a useful table or structured comparison when possible.
7. Try it once: ingredients, amounts, preparation, timing, substitutions, and what to observe.
8. Troubleshooting and personalization without diagnosis language.
9. Specific safety boundaries and a concise educational disclaimer.
10. Two or three natural internal links to relevant existing BrothCalm pages.
11. A final “Sources” section with at least two verified, relevant links. Use
    primary or authoritative sources where possible. Never invent a citation or
    URL; label unsourced claims as traditional context or unknowns.
12. If a relevant local JPG/PNG exists, use it for og:image with useful alt
    text; otherwise use https://brothcalm.com/images/default-og.jpg. Never
    point to a guessed article image.

VOICE: warm, specific, sensory, and honest. Aim for useful sections rather than
padding. Do not make medical promises or medication instructions. Words such as
“treatment” may appear in a disclaimer or accurately framed research context,
but never claim that food cures, treats, heals, or prevents disease. Prefer
traditionally used, may support, gentle option, and comforting recipe. Avoid
filler history and repeated generic wellness claims.

ANALOGY: use one main explanatory analogy and at most two supporting analogies;
state that an analogy is not a literal anatomical or physiological equivalence.

DIFFERENTIATION: inspect related pages, parent pillar, and sibling H2 headings
before writing. Do not retitle and reproduce an existing article. Choose a
distinct search intent, audience, time window, ingredient combination, or use
case. Keep ordinary body-H2 overlap below 30% and focused pages below 20%.

Then generate the CHINESE version of the same article:
- Path: /zh + the same path (e.g. /zh/ingredients/goji-berries/)
- Use article-template-zh.html as template (read it first, create if not exists)
- Title and content in Chinese
- lang=\"zh-CN\"
- The toggle button text should auto-switch (this is handled by JS)
Write to /tmp/brothcalm-zh.html.

The Chinese edition is an editorial adaptation, not a literal translation.
Keep the facts and safety boundaries, but use natural Chinese kitchen language,
explain TCM terms in plain language, and preserve the decision, comparison,
practical trial, and safety sections. Use cautious wording such as
“传统上认为”“可能有助于”“可作为日常饮食的一种选择”; never write medical
diagnoses or treatment promises.

SAFETY GATE: Pregnancy, children, chronic disease, medication interaction,
concentrated extracts, surgery, seizures, or other high-risk topics require a
specific professional-care boundary. Do not diagnose, prescribe, give drug-like
dosing, or promise prevention, treatment, detoxification, or cure.

RECIPE REQUIREMENTS: For recipe items, include a real Recipe JSON-LD object
with name, keywords, nutrition, recipeYield, prepTime or cookTime,
recipeIngredient, and recipeInstructions with at least two actual steps. The
visible article must contain the same practical recipe. Non-recipe articles
must not use Recipe schema merely to gain rich results.

Before FILE_READY, reread both files and self-check counts, source links,
safety disclaimer, placeholders, internal links, and schema.

Do NOT run the stage command. Print FILE_READY only after both HTML files have been written.
" --skills brothcalm-content-production 2>&1 >> "$LOG"

  VALIDATE_STATUS=0
  if [ -s /tmp/brothcalm-article.html ] && [ -s /tmp/brothcalm-zh.html ]; then
    python3 .cron/validate-generated-article.py /tmp/brothcalm-article.html /tmp/brothcalm-zh.html >> "$LOG" 2>&1 || VALIDATE_STATUS=$?
  else
    VALIDATE_STATUS=1
  fi
  if [ "$VALIDATE_STATUS" -eq 0 ] && python3 .cron/check-content-overlap.py /tmp/brothcalm-article.html 0.30 >> "$LOG" 2>&1; then
    cp /tmp/brothcalm-article.html "$PENDING/${SLUG}.html"
    rm -f /tmp/brothcalm-article.html
    log "[CREATE] Staged EN: $SLUG"

    cp /tmp/brothcalm-zh.html "$PENDING/zh-${SLUG}.html"
    rm -f /tmp/brothcalm-zh.html
    log "[CREATE] Staged ZH: zh-$SLUG"
    if python3 .cron/publish-article.py stage >> "$LOG" 2>&1; then
      log "[CREATE] Queue advanced after complete EN+ZH staging: $SLUG"
    else
      log "[CREATE] ERROR: queue stage failed for $SLUG"
      exit 1
    fi
  elif [ "$VALIDATE_STATUS" -eq 2 ]; then
    cp /tmp/brothcalm-article.html "$REVIEW/${SLUG}.html"
    cp /tmp/brothcalm-zh.html "$REVIEW/zh-${SLUG}.html"
    rm -f /tmp/brothcalm-article.html /tmp/brothcalm-zh.html
    log "[CREATE] High-risk pair moved to pending-review: $SLUG"
    python3 .cron/publish-article.py stage >> "$LOG" 2>&1 || exit 1
  else
    rm -f /tmp/brothcalm-article.html /tmp/brothcalm-zh.html
    log "[CREATE] ERROR: validation failed or article missing for $SLUG; queue not advanced"
    exit 1
  fi
done

if [ -f "$BATCH_STATE" ]; then
  TARGET_REMAINING=$(python3 - "$BATCH_STATE" <<'PY'
import json, sys
q = json.load(open('.content-queue.json'))
s = json.load(open(sys.argv[1]))
print(max(0, s['target_index'] - q['index']))
PY
  )
  if [ "$TARGET_REMAINING" -eq 0 ]; then
    rm -f "$BATCH_STATE"
    log "[CREATE] 100-pair batch fully staged"
  fi
fi

log "[CREATE] Content creation tick finished"
