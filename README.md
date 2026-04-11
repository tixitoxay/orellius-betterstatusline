# orellius-claudetracker

**MCP server for Claude Pro/Max subscription usage — real-time, inside Claude Code.**

<p>
  <img src="https://img.shields.io/badge/status-archived-red?style=flat-square" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" />
</p>

---

> [!WARNING]
> **This project is archived and no longer maintained.**
> No further updates, fixes, or support will be provided. The code is left
> here as-is under the MIT license — fork it, modify it, ship it, do whatever
> you want with it. No warranty, no promises.

---

## What it was

An MCP server that exposed real-time Claude subscription usage to Claude Code — session window, weekly rolling limits, per-model breakdown, extra credits. No API key, no scraping, no browser automation: it read the OAuth token that Claude Code already stored locally and called Anthropic's usage endpoint directly (same data as the [claude.ai/settings/usage](https://claude.ai/settings/usage) page).

Ships with a statusline script that adds a third line to the Claude Code status bar with progress bars and color coding.

## MCP tool: `get_usage`

Returns:

| Metric | Description |
|---|---|
| **Current Session** | 5-hour burst window utilization with reset countdown |
| **Weekly (All Models)** | 7-day rolling limit across all models |
| **Weekly (Opus)** | 7-day Opus-specific usage (Max plans) |
| **Weekly (Sonnet)** | 7-day Sonnet-specific usage |
| **Extra Usage** | Enabled/disabled, monthly limit, credits used |

Color-graded: 0–49% green, 50–79% orange, 80–99% red, 100% rate-limited.

### Sample output

```
=== Claude Plan Usage ===

Current Session (5-hour window)
  ████████░░░░░░░░░░░░  37%
  Resets in 2h 14m

Weekly Usage - All Models (7-day) [HIGH]
  ██████████████████░░  89%
  Resets in 4d 3h
```

## Quickstart

```bash
git clone https://github.com/Orellius/orellius-betterstatusline
cd orellius-betterstatusline
npm install
npm run build
```

Add to your Claude Code MCP config pointing at the built server entrypoint.

## License

MIT. Do whatever you want with it.
