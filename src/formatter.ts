import type { UsageResponse, UsageWindow, ExtraUsage } from "./types.js";
import { getCacheAge } from "./cache.js";

const BAR_WIDTH = 20;

function progressBar(pct: number): string {
  const filled = Math.round((pct / 100) * BAR_WIDTH);
  const empty = BAR_WIDTH - filled;
  return "\u2588".repeat(filled) + "\u2591".repeat(empty);
}

function formatResetDateTime(resetsAt: string | null): string {
  if (!resetsAt) return "";

  const resetDate = new Date(resetsAt);
  const now = new Date();
  const diffMs = resetDate.getTime() - now.getTime();

  if (diffMs <= 0) return "Resetting now";

  const totalMinutes = Math.floor(diffMs / 60_000);
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;

  const parts: string[] = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0 && days === 0) parts.push(`${minutes}m`);

  const countdown = parts.length > 0 ? parts.join(" ") : "<1m";

  const dateStr = resetDate.toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
  const timeStr = resetDate.toLocaleTimeString("en-US", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  });

  return `Resets in ${countdown} (${dateStr} ${timeStr})`;
}

function colorGrade(pct: number): string {
  if (pct >= 100) return "RATE_LIMITED";
  if (pct >= 80) return "RED";
  if (pct >= 50) return "ORANGE";
  return "GREEN";
}

function statusTag(pct: number): string {
  const grade = colorGrade(pct);
  if (grade === "RATE_LIMITED") return " [RATE LIMITED]";
  if (grade === "RED") return " [HIGH]";
  if (grade === "ORANGE") return " [MODERATE]";
  return "";
}

function formatWindow(label: string, window: UsageWindow | null): string {
  if (!window) return `${label}\n  N/A (not on your plan)`;

  const pct = window.utilization;
  const grade = colorGrade(pct);

  if (grade === "RATE_LIMITED") {
    const resetInfo = formatResetDateTime(window.resets_at);
    return `${label} [RATE LIMITED]\n  ${"X".repeat(BAR_WIDTH)}  100%\n  ${resetInfo || "Reset time unknown"}`;
  }

  const bar = progressBar(pct);
  const tag = statusTag(pct);
  const resetInfo = formatResetDateTime(window.resets_at);
  const resetLine = resetInfo ? `\n  ${resetInfo}` : "";

  return `${label}${tag}\n  ${bar}  ${pct.toFixed(0)}%${resetLine}`;
}

export function formatFullUsage(data: UsageResponse, source: string): string {
  const lines: string[] = [];

  lines.push("=== Claude Plan Usage ===");
  lines.push("");

  lines.push(formatWindow("Current Session (5-hour window)", data.five_hour));
  lines.push("");

  lines.push(formatWindow("Weekly Usage - All Models (7-day)", data.seven_day));
  lines.push("");

  if (data.seven_day_opus !== undefined) {
    lines.push(formatWindow("Weekly Usage - Opus Only", data.seven_day_opus));
    lines.push("");
  }

  if (data.seven_day_sonnet !== undefined) {
    lines.push(formatWindow("Weekly Usage - Sonnet Only", data.seven_day_sonnet));
    lines.push("");
  }

  if (data.seven_day_oauth_apps) {
    lines.push(formatWindow("Weekly Usage - OAuth Apps", data.seven_day_oauth_apps));
    lines.push("");
  }

  if (data.seven_day_cowork) {
    lines.push(formatWindow("Weekly Usage - Cowork", data.seven_day_cowork));
    lines.push("");
  }

  lines.push(formatExtraUsage(data.extra_usage));
  lines.push("");
  lines.push("--- Color Grading ---");
  lines.push("0-49% = GREEN (safe)  |  50-79% = ORANGE (moderate)  |  80-99% = RED (high)  |  100% = RATE LIMITED");
  lines.push("");

  const cacheAge = getCacheAge();
  if (source === "cache" && cacheAge !== null) {
    lines.push(`(cached ${cacheAge}s ago)`);
  } else if (source === "stale" && cacheAge !== null) {
    lines.push(`(stale cache from ${cacheAge}s ago)`);
  } else {
    lines.push("(live data)");
  }

  return lines.join("\n");
}

export function formatSessionUsage(data: UsageResponse): string {
  const lines: string[] = [];
  lines.push("=== Current Session (5-hour window) ===");
  lines.push("");
  lines.push(formatWindow("Current Session", data.five_hour));
  return lines.join("\n");
}

export function formatWeeklyLimits(data: UsageResponse): string {
  const lines: string[] = [];
  lines.push("=== Weekly Limits (7-day) ===");
  lines.push("");

  lines.push(formatWindow("All Models", data.seven_day));
  lines.push("");

  if (data.seven_day_opus !== undefined) {
    lines.push(formatWindow("Opus Only", data.seven_day_opus));
    lines.push("");
  }

  if (data.seven_day_sonnet !== undefined) {
    lines.push(formatWindow("Sonnet Only", data.seven_day_sonnet));
    lines.push("");
  }

  if (data.seven_day_oauth_apps) {
    lines.push(formatWindow("OAuth Apps", data.seven_day_oauth_apps));
    lines.push("");
  }

  if (data.seven_day_cowork) {
    lines.push(formatWindow("Cowork", data.seven_day_cowork));
    lines.push("");
  }

  return lines.join("\n").trimEnd();
}

function formatExtraUsage(extra: ExtraUsage | null): string {
  if (!extra) return "Extra Usage: N/A";

  if (!extra.is_enabled) return "Extra Usage: Disabled";

  const parts = ["Extra Usage: Enabled"];
  if (extra.monthly_limit !== null) {
    parts.push(`  Monthly limit: $${extra.monthly_limit.toFixed(2)}`);
  }
  if (extra.used_credits !== null) {
    parts.push(`  Used: $${extra.used_credits.toFixed(2)}`);
  }
  if (extra.utilization !== null) {
    parts.push(`  ${progressBar(extra.utilization)}  ${extra.utilization.toFixed(0)}%`);
  }

  return parts.join("\n");
}

export function formatRateStatus(data: UsageResponse): string {
  const lines: string[] = [];
  lines.push("=== Rate Limit Status ===");
  lines.push("");

  const sessionPct = data.five_hour.utilization;
  const weeklyPct = data.seven_day.utilization;
  const sessionGrade = colorGrade(sessionPct);
  const weeklyGrade = colorGrade(weeklyPct);

  if (sessionGrade === "RATE_LIMITED" || weeklyGrade === "RATE_LIMITED") {
    lines.push("STATUS: RATE LIMITED");
    lines.push("You have hit your usage limit.");
    if (weeklyGrade === "RATE_LIMITED") {
      const reset = formatResetDateTime(data.seven_day.resets_at);
      lines.push(`Weekly limit reached. ${reset}`);
    }
    if (sessionGrade === "RATE_LIMITED") {
      const reset = formatResetDateTime(data.five_hour.resets_at);
      lines.push(`Session limit reached. ${reset}`);
    }
  } else if (sessionGrade === "RED" || weeklyGrade === "RED") {
    lines.push("STATUS: HIGH USAGE (80%+)");
    lines.push("You are likely to experience rate limiting soon.");
  } else if (sessionGrade === "ORANGE" || weeklyGrade === "ORANGE") {
    lines.push("STATUS: MODERATE USAGE (50-79%)");
    lines.push("You have headroom but are approaching limits.");
  } else {
    lines.push("STATUS: LOW USAGE (<50%)");
    lines.push("Plenty of capacity available.");
  }

  lines.push("");
  lines.push(`Current Session: ${progressBar(sessionPct)}  ${sessionPct.toFixed(0)}%`);
  lines.push(`Weekly Usage:    ${progressBar(weeklyPct)}  ${weeklyPct.toFixed(0)}%`);

  if (sessionPct >= 80 && sessionGrade !== "RATE_LIMITED") {
    const reset = formatResetDateTime(data.five_hour.resets_at);
    lines.push(`\nSession limit approaching. ${reset}`);
  }
  if (weeklyPct >= 80 && weeklyGrade !== "RATE_LIMITED") {
    const reset = formatResetDateTime(data.seven_day.resets_at);
    lines.push(`Weekly limit approaching. ${reset}`);
  }

  return lines.join("\n");
}
