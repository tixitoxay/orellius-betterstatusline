#!/bin/bash
# Combined statusline: existing 2-line + usage data on line 3
# Line 1: Session: Model | Plan | Duration | +Lines -Lines
# Line 2: Context: Folder | Branch | [Bar] % | Tokens/Compact
# Line 3: Usage:   Session [bar] xx% | Weekly [bar] xx% | Sonnet [bar] xx%
# Color grading: 0-49% GREEN | 50-79% ORANGE | 80-99% RED | 100% RATE LIMITED

input=$(cat)

# ── Run existing statusline (pass input via stdin) ──
echo "$input" | bash /Users/orelohayon/.claude/statusline-command.sh

# ── ANSI helpers ──
RST=$(printf '\033[0m')
DIM=$(printf '\033[2m')
BLD=$(printf '\033[1m')
GRN=$(printf '\033[0;32m')
YLW=$(printf '\033[0;33m')
RED=$(printf '\033[0;31m')
CYN=$(printf '\033[0;36m')
SEP="${DIM} | ${RST}"
L3="${DIM}  Usage${RST}${DIM}:${RST} "

pick_color() {
  if   [ "$1" -ge 100 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 80 ];  then printf '%s' "$RED"
  elif [ "$1" -ge 50 ];  then printf '%s' "$YLW"
  else                         printf '%s' "$GRN"
  fi
}

# ── Usage data (cached 120s) ──
CACHE_FILE="/tmp/claudeusage-statusline-cache.json"
CACHE_TTL=120
USAGE_JSON=""

if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$cache_age" -lt "$CACHE_TTL" ]; then
    USAGE_JSON=$(cat "$CACHE_FILE")
  fi
fi

if [ -z "$USAGE_JSON" ]; then
  TOKEN=""
  if [ "$(uname)" = "Darwin" ]; then
    TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null)
  else
    CREDS="$HOME/.claude/.credentials.json"
    [ -f "$CREDS" ] && TOKEN=$(python3 -c "import json; print(json.load(open('$CREDS'))['claudeAiOauth']['accessToken'])" 2>/dev/null)
  fi

  if [ -n "$TOKEN" ]; then
    USAGE_JSON=$(curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
      -H "Authorization: Bearer $TOKEN" \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "Content-Type: application/json" 2>/dev/null)

    if [ -n "$USAGE_JSON" ] && ! echo "$USAGE_JSON" | grep -q '"error"'; then
      echo "$USAGE_JSON" > "$CACHE_FILE"
    elif [ -f "$CACHE_FILE" ]; then
      USAGE_JSON=$(cat "$CACHE_FILE")
    fi
  fi
fi

if [ -z "$USAGE_JSON" ]; then
  printf '%s%s\n' "$L3" "${DIM}no token${RST}"
  exit 0
fi

# ── Mini progress bar (10 chars wide for compact fit) ──
mini_bar() {
  local pct="$1"
  local color="$2"
  local bar_w=10
  local filled=$(( (pct * bar_w + 50) / 100 ))
  [ "$filled" -gt "$bar_w" ] && filled=$bar_w
  [ "$filled" -lt 0 ] && filled=0
  local empty=$((bar_w - filled))
  printf '%s%s%s%s' "$color" "$(printf '%0.s█' $(seq 1 $filled 2>/dev/null || echo ""))" "${DIM}$([ "$empty" -gt 0 ] && printf '%0.s░' $(seq 1 $empty 2>/dev/null))" "$RST"
}

# ── Format reset datetime ──
fmt_reset() {
  local ts="$1"
  [ -z "$ts" ] && return
  python3 -c "
from datetime import datetime, timezone
ts = '$ts'
dt = datetime.fromisoformat(ts)
now = datetime.now(timezone.utc)
diff = dt - now
total_min = int(diff.total_seconds() / 60)
if total_min <= 0:
    print('now')
else:
    d = total_min // 1440
    h = (total_min % 1440) // 60
    m = total_min % 60
    parts = []
    if d > 0: parts.append(f'{d}d')
    if h > 0: parts.append(f'{h}h')
    if m > 0 and d == 0: parts.append(f'{m}m')
    countdown = ' '.join(parts) if parts else '<1m'
    date_str = dt.strftime('%a %b %d %I:%M%p')
    print(f'{countdown} ({date_str})')
" 2>/dev/null
}

# ── Parse usage data ──
s_pct=$(echo "$USAGE_JSON" | jq -r '.five_hour.utilization // 0' 2>/dev/null)
w_pct=$(echo "$USAGE_JSON" | jq -r '.seven_day.utilization // 0' 2>/dev/null)
so_pct=$(echo "$USAGE_JSON" | jq -r '.seven_day_sonnet.utilization // empty' 2>/dev/null)
op_pct=$(echo "$USAGE_JSON" | jq -r '.seven_day_opus.utilization // empty' 2>/dev/null)
extra_on=$(echo "$USAGE_JSON" | jq -r '.extra_usage.is_enabled // false' 2>/dev/null)
s_reset=$(echo "$USAGE_JSON" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
w_reset=$(echo "$USAGE_JSON" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)
so_reset=$(echo "$USAGE_JSON" | jq -r '.seven_day_sonnet.resets_at // empty' 2>/dev/null)
op_reset=$(echo "$USAGE_JSON" | jq -r '.seven_day_opus.resets_at // empty' 2>/dev/null)

s_int=$(printf "%.0f" "$s_pct" 2>/dev/null || echo 0)
w_int=$(printf "%.0f" "$w_pct" 2>/dev/null || echo 0)

s_color=$(pick_color "$s_int")
w_color=$(pick_color "$w_int")

# ── Format: label [bar] pct%  OR  label: RATE LIMITED, Resets in: datetime ──
fmt_usage_item() {
  local label="$1" pct_int="$2" color="$3" reset_ts="$4"
  if [ "$pct_int" -ge 100 ]; then
    local reset_str=$(fmt_reset "$reset_ts")
    printf '%s%s%s%s%s: RATE LIMITED%s' "$RED" "$BLD" "$label" "$RST" "$RED" "$RST"
    if [ -n "$reset_str" ]; then
      printf '%s, Resets in: %s%s%s' "$DIM" "$RST" "$reset_str" "$RST"
    fi
  else
    printf '%s%s%s %s %s%s%s%%%s' "$DIM" "$label" "$RST" "$(mini_bar "$pct_int" "$color")" "$color" "$BLD" "$pct_int" "$RST"
  fi
}

parts="$(fmt_usage_item "Session" "$s_int" "$s_color" "$s_reset")${SEP}$(fmt_usage_item "Weekly" "$w_int" "$w_color" "$w_reset")"

if [ -n "$so_pct" ] && [ "$so_pct" != "0" ]; then
  so_int=$(printf "%.0f" "$so_pct" 2>/dev/null || echo 0)
  so_color=$(pick_color "$so_int")
  parts="${parts}${SEP}$(fmt_usage_item "Sonnet" "$so_int" "$so_color" "$so_reset")"
fi

if [ -n "$op_pct" ] && [ "$op_pct" != "0" ]; then
  op_int=$(printf "%.0f" "$op_pct" 2>/dev/null || echo 0)
  op_color=$(pick_color "$op_int")
  parts="${parts}${SEP}$(fmt_usage_item "Opus" "$op_int" "$op_color" "$op_reset")"
fi

if [ "$extra_on" = "true" ]; then
  parts="${parts}${SEP}${CYN}Extra Usage${RST}"
fi

printf '%s%s\n' "$L3" "$parts"
