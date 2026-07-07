#!/bin/bash
# BrothCalm Weekly Newsletter — run by launchd every Monday
# Gathers this week's articles + subscribers → generates + sends email
# Requires: Resend API key configured

export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"
cd "$HOME/.hermes/profiles/brothcalm/workspace" || exit 1

LOG="$HOME/.hermes/profiles/brothcalm/workspace/.cron/newsletter.log"
echo "$(date): Newsletter tick started" >> "$LOG"

# 1. Get subscribers from Cloudflare KV
echo "$(date): Fetching subscribers..." >> "$LOG"
SUBSCRIBERS=$(curl -s "https://api.cloudflare.com/client/v4/accounts/1ab16cdc3d0d43621d7a6b5307b9c94b/storage/kv/namespaces/c660adf76b5e4f7fa080d6a42b97cb8f/keys" \
  -H "X-Auth-Email: 5004378@qq.com" \
  -H "X-Auth-Key: cfk_IxQmjwOsVOhCwVrMCAdxCJC5FR1mnxB8qKxcBAeS48b5059d" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); [print(k['name']) for k in d.get('result',[])]" 2>/dev/null)

SUB_COUNT=$(echo "$SUBSCRIBERS" | grep -c '@' || echo 0)
echo "  $SUB_COUNT subscribers" >> "$LOG"

if [ "$SUB_COUNT" -eq 0 ]; then
  echo "$(date): No subscribers, skipping" >> "$LOG"
  exit 0
fi

# 2. Get this week's published articles
echo "$(date): Gathering articles..." >> "$LOG"
ARTICLES=$(git log --since="7 days ago" --oneline --no-decorate | grep "Publish:" | head -20)

if [ -z "$ARTICLES" ]; then
  echo "$(date): No articles this week, skipping" >> "$LOG"
  exit 0
fi

# 3. Build HTML newsletter
NEWSLETTER_DATE=$(TZ=Asia/Shanghai date '+%Y-%m-%d')
HTML_CONTENT=""
while IFS= read -r line; do
  commit=$(echo "$line" | awk '{print $1}')
  path=$(echo "$line" | awk '{print $NF}' | sed 's/^Publish://')
  title=$(git log --format=%s -1 "$commit" 2>/dev/null | sed 's/^Publish: //')
  
  if [ -n "$path" ]; then
    HTML_CONTENT="${HTML_CONTENT}
    <tr>
      <td style=\"padding:12px 0;border-bottom:1px solid #eee;\">
        <a href=\"https://brothcalm.com${path}/\" style=\"color:#EA580C;font-weight:600;font-size:16px;text-decoration:none;\">${title}</a>
        <br><span style=\"color:#888;font-size:13px;\">${path}</span>
      </td>
    </tr>"
  fi
done <<< "$ARTICLES"

HTML_BODY="<!DOCTYPE html>
<html>
<head><meta charset=\"UTF-8\"></head>
<body style=\"font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#F5EDE3;padding:20px;\">
<table width=\"600\" cellpadding=\"0\" cellspacing=\"0\" style=\"margin:0 auto;background:white;border-radius:12px;overflow:hidden;\">
<tr><td style=\"background:#EA580C;padding:30px;text-align:center;\">
  <h1 style=\"color:white;margin:0;font-size:24px;\">🍵 BrothCalm Weekly</h1>
  <p style=\"color:#FFEDD5;margin:5px 0 0;font-size:14px;\">${NEWSLETTER_DATE}</p>
</td></tr>
<tr><td style=\"padding:30px;\">
  <h2 style=\"color:#333;font-size:20px;margin-top:0;\">This Week on BrothCalm</h2>
  <p style=\"color:#666;font-size:15px;\">New articles exploring Chinese food therapy wisdom:</p>
  <table width=\"100%\" cellpadding=\"0\" cellspacing=\"0\">
    ${HTML_CONTENT}
  </table>
</td></tr>
<tr><td style=\"background:#FFF3E0;padding:20px;text-align:center;font-size:13px;color:#666;\">
  <p>You're receiving this because you subscribed at BrothCalm.com</p>
  <p>© 2026 BrothCalm · <a href=\"https://brothcalm.com/\" style=\"color:#EA580C;\">Visit our site</a></p>
</td></tr>
</table>
</body>
</html>"

echo "$(date): Generated newsletter ($(echo "$HTML_BODY" | wc -c) bytes)" >> "$LOG"

# 4. Send via Resend API
RESEND_KEY="re_5ifEDKmg_5gVfK9C4JytmLvwzV5T6cqRQ"
RECIPIENTS=$(echo "$SUBSCRIBERS" | paste -sd "," -)

echo "$(date): Sending to $SUB_COUNT recipients via Resend..." >> "$LOG"

# Resend supports up to 50 recipients via BCC
# For batch sending, send one email with all in BCC
# Build JSON array for bcc
BCC_JSON=$(echo "$SUBSCRIBERS" | python3 -c "import json,sys; emails=[e.strip() for e in sys.stdin.read().split() if '@' in e]; print(json.dumps(emails))")

RESPONSE=$(curl -s -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer $RESEND_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"from\": \"BrothCalm <contact@symptomcalm.com>\",
    \"to\": [\"contact@brothcalm.com\"],
    \"bcc\": $BCC_JSON,
    \"subject\": \"BrothCalm Weekly — This Week's Food Therapy Articles\",
    \"html\": $(echo "$HTML_BODY" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")
  }")
echo "$RESPONSE" >> "$LOG"

echo "$(date): Newsletter sent!" >> "$LOG"
echo "$(date): Tick finished" >> "$LOG"
