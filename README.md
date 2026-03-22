# claudeusage-mcp

An MCP server that gives you real-time visibility into your Claude Pro/Max subscription usage — directly inside Claude Code.

No API keys. No scraping. No browser automation. It reads the OAuth token that Claude Code already stores on your machine and calls Anthropic's usage endpoint to get the exact same data shown on [claude.ai/settings/usage](https://claude.ai/settings/usage).

---

## What it shows

| Metric | Description |
|--------|-------------|
| **Current Session** | 5-hour burst window utilization with reset countdown |
| **Weekly Usage - All Models** | 7-day rolling limit across all models |
| **Weekly Usage - Opus Only** | 7-day Opus-specific usage (Max plans) |
| **Weekly Usage - Sonnet Only** | 7-day Sonnet-specific usage |
| **Extra Usage** | Enabled/disabled, monthly limit, credits used |

### MCP tool output (`get_usage`)

```
=== Claude Plan Usage ===

Current Session (5-hour window)
  ████████░░░░░░░░░░░░  37%
  Resets in 2h 14m (Sat Mar 22 07:59PM)

Weekly Usage - All Models (7-day) [HIGH]
  ██████████████████░░  89%
  Resets in 4d 3h (Wed Mar 26 05:00PM)

Weekly Usage - Opus Only
  N/A (not on your plan)

Weekly Usage - Sonnet Only
  ░░░░░░░░░░░░░░░░░░░░  1%
  Resets in 4d 3h (Wed Mar 26 08:59PM)

Extra Usage: Disabled

--- Color Grading ---
0-49% = GREEN (safe)  |  50-79% = ORANGE (moderate)  |  80-99% = RED (high)  |  100% = RATE LIMITED

(live data)
```

### Rate-limited state

When any metric hits 100%, the output changes to show reset date and time:

```
Weekly Usage - All Models (7-day) [RATE LIMITED]
  XXXXXXXXXXXXXXXXXXXX  100%
  Resets in 1d (Mon Mar 24 05:00PM)
```

### Statusline output

The included statusline script adds a third line to your Claude Code status bar with progress bars and color coding:

```
  Usage: Session █░░░░░░░░░ 13% | Weekly █████████░ 94% | Sonnet █░░░░░░░░░ 8%
```

When rate-limited:

```
  Usage: Session: RATE LIMITED, Resets in: 3h 37m (Sun Mar 22 07:59PM) | Weekly: RATE LIMITED, Resets in: 1d (Mon Mar 23 05:00PM)
```

### Color grading

| Range | Color | Status |
|-------|-------|--------|
| 0-49% | Green | Safe |
| 50-79% | Orange | Moderate |
| 80-99% | Red | High |
| 100% | Red + text | RATE LIMITED with reset datetime |

## Tools

| Tool | Purpose |
|------|---------|
| `get_usage` | Full dashboard — session, weekly, per-model, extra usage with progress bars |
| `get_session_usage` | Current 5-hour session window only |
| `get_weekly_limits` | 7-day limits with per-model breakdown (All, Opus, Sonnet) |
| `check_rate_status` | Am I about to be rate-limited? Returns LOW / MODERATE / HIGH / RATE LIMITED |

## Requirements

- **Node.js** >= 18
- **Claude Code** logged in with a Pro or Max subscription
- **macOS** or **Linux** (reads credentials from Keychain or `~/.claude/.credentials.json`)

## Installation

### Option 1: `claude mcp add` (recommended)

```bash
git clone https://github.com/OrelliusAI/claudeusage-mcp.git
cd claudeusage-mcp
npm install && npm run build

claude mcp add claudeusage -- node $(pwd)/dist/index.js
```

Restart Claude Code. Then ask "what's my usage?" or type `/usage`.

### Option 2: Manual config

```bash
git clone https://github.com/OrelliusAI/claudeusage-mcp.git
cd claudeusage-mcp
npm install && npm run build
```

Add to your MCP config (`.claude.json` or project `.mcp.json`):

```json
{
  "mcpServers": {
    "claudeusage": {
      "command": "node",
      "args": ["/absolute/path/to/claudeusage-mcp/dist/index.js"]
    }
  }
}
```

### Optional: Statusline integration

Add usage data to your Claude Code statusline (always visible at the bottom):

```bash
# If you DON'T have a statusline yet:
cp statusline.sh ~/.claude/usage-statusline.sh
chmod +x ~/.claude/usage-statusline.sh
```

Then set in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/usage-statusline.sh"
  }
}
```

If you already have a statusline, use `statusline-combined.sh` instead — it pipes your existing statusline and appends the usage line.

## How it works

```
Claude Code (your session)
    |
    |-- Reads OAuth token from:
    |   |-- macOS Keychain ("Claude Code-credentials")
    |   +-- ~/.claude/.credentials.json (Linux/WSL)
    |
    |-- Calls: GET https://api.anthropic.com/api/oauth/usage
    |   Headers: Authorization: Bearer <your-oauth-token>
    |            anthropic-beta: oauth-2025-04-20
    |
    |-- Caches response for 60 seconds
    |   +-- On 429 (rate limit): serves stale cache
    |
    +-- Returns formatted usage data via MCP tools
```

**Zero configuration.** The OAuth token is created automatically when you sign into Claude Code with your Pro/Max subscription. No API keys, no environment variables, no `.env` files.

## Authentication

This server uses the **same OAuth token** that Claude Code creates when you log in:

| Platform | Location |
|----------|----------|
| macOS | Keychain (service: `Claude Code-credentials`) |
| Linux / WSL | `~/.claude/.credentials.json` |

Required OAuth scopes: `user:inference`, `user:profile`

### Token issues?

If the server reports authentication errors:

1. Your token may be expired — **restart Claude Code** to trigger a fresh OAuth login
2. Token created via `claude setup-token` or `/login` may have wrong scopes — delete credentials and restart Claude Code

**Do NOT use API keys** (`sk-ant-api...`). This server is for Pro/Max subscribers, not API users.

## Rate limiting

Anthropic's `/api/oauth/usage` endpoint is aggressively rate-limited. This server handles it:

1. **Caching** — responses cached for 60 seconds (MCP) or 120 seconds (statusline)
2. **Stale fallback** — on 429, the last successful response is served
3. **Graceful errors** — clear messages when the API is unavailable

## Who is this for?

Claude **Pro** and **Max** subscribers who use Claude Code and want to see their plan usage without opening a browser. This is **not** for API users — if you have an API key (`sk-ant-api...`), use the [Usage and Cost API](https://platform.claude.com/docs/en/build-with-claude/usage-cost-api) instead.

## License

MIT
