#!/bin/bash
# claudeusage-mcp statusline integration
# Displays Claude Pro/Max usage in Claude Code's status line.
# Full labels, progress bars, color grading, rate-limited state.
#
# Color grading:
#   0-49%  = GREEN  (safe)
#   50-79% = ORANGE (moderate)
#   80-99% = RED    (high)
#   100%   = RATE LIMITED with reset datetime

CACHE_FILE="/tmp/claudeusage-statusline-cache.json"
CACHE_TTL=120

# Check if cache is fresh
if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$cache_age" -lt "$CACHE_TTL" ]; then
    USAGE_JSON=$(cat "$CACHE_FILE")
  fi
fi

if [ -z "$USAGE_JSON" ]; then
  # Get OAuth token
  if [ "$(uname)" = "Darwin" ]; then
    TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null)
  else
    CREDS_FILE="$HOME/.claude/.credentials.json"
    if [ -f "$CREDS_FILE" ]; then
      TOKEN=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['claudeAiOauth']['accessToken'])" 2>/dev/null)
    fi
  fi

  if [ -z "$TOKEN" ]; then
    echo "usage: no token"
    exit 0
  fi

  # Fetch usage
  USAGE_JSON=$(curl -s --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" 2>/dev/null)

  if [ -z "$USAGE_JSON" ] || echo "$USAGE_JSON" | grep -q '"error"'; then
    if [ -f "$CACHE_FILE" ]; then
      USAGE_JSON=$(cat "$CACHE_FILE")
    else
      echo "usage: rate limited"
      exit 0
    fi
  else
    echo "$USAGE_JSON" > "$CACHE_FILE"
  fi
fi

# Parse and format
echo "$USAGE_JSON" | python3 -c "
import sys, json
from datetime import datetime, timezone

try:
    d = json.load(sys.stdin)
except:
    print('usage: parse error')
    sys.exit(0)

five = d.get('five_hour', {})
seven = d.get('seven_day', {})
sonnet = d.get('seven_day_sonnet')
opus = d.get('seven_day_opus')
extra = d.get('extra_usage')

def fmt_reset(ts):
    if not ts:
        return ''
    dt = datetime.fromisoformat(ts)
    diff = dt - datetime.now(timezone.utc)
    total_min = int(diff.total_seconds() / 60)
    if total_min <= 0:
        return 'now'
    d_val = total_min // 1440
    h = (total_min % 1440) // 60
    m = total_min % 60
    parts = []
    if d_val > 0: parts.append(f'{d_val}d')
    if h > 0: parts.append(f'{h}h')
    if m > 0 and d_val == 0: parts.append(f'{m}m')
    countdown = ' '.join(parts) if parts else '<1m'
    date_str = dt.strftime('%a %b %d %I:%M%p')
    return f'{countdown} ({date_str})'

def fmt_item(label, pct, reset_ts):
    p = int(pct)
    if p >= 100:
        reset = fmt_reset(reset_ts)
        return f'{label}: RATE LIMITED, Resets in: {reset}' if reset else f'{label}: RATE LIMITED'
    return f'{label} {p}%'

s_pct = five.get('utilization', 0)
w_pct = seven.get('utilization', 0)

parts = []
parts.append(fmt_item('Session', s_pct, five.get('resets_at')))
parts.append(fmt_item('Weekly', w_pct, seven.get('resets_at')))

if opus and opus.get('utilization', 0) > 0:
    parts.append(fmt_item('Opus', opus['utilization'], opus.get('resets_at')))
if sonnet and sonnet.get('utilization', 0) > 0:
    parts.append(fmt_item('Sonnet', sonnet['utilization'], sonnet.get('resets_at')))

if extra and extra.get('is_enabled'):
    parts.append('Extra Usage: on')

print(' | '.join(parts))
" 2>/dev/null
