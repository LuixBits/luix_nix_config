"""Render Claude's own usage and list-price cost estimates without API calls."""

import json
import math
from pathlib import Path
import sys


def number(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if math.isfinite(value) and value >= 0:
            return value
    return None


def tokens(value):
    value = number(value)
    if value is None:
        return "—"
    if value >= 1_000_000:
        return f"{value / 1_000_000:.2f}M"
    if value >= 1_000:
        return f"{value / 1_000:.1f}k"
    return str(int(value))


def clean(value):
    return "".join(c for c in str(value) if c.isprintable())


def render(data):
    model = data.get("model") or {}
    workspace = data.get("workspace") or {}
    context = data.get("context_window") or {}
    cost = data.get("cost") or {}
    effort = (data.get("effort") or {}).get("level")
    title = clean(model.get("display_name") or model.get("id") or "Claude")
    if effort:
        title += f" ({clean(effort)})"
    directory = workspace.get("current_dir") or data.get("cwd")
    if directory:
        title += f" | {clean(Path(directory).name or directory)}"

    # These are the current context counts, not cumulative session billing
    # tokens. Claude includes cache reads/writes in total_input_tokens.
    usage = f"ctx in {tokens(context.get('total_input_tokens'))} / out {tokens(context.get('total_output_tokens'))}"
    percentage = number(context.get("used_percentage"))
    if percentage is not None:
        usage += f" ({percentage:.0f}% used)"
    estimate = number(cost.get("total_cost_usd"))
    usage += " | API est " + (f"${estimate:.2f}" if estimate is not None else "—")

    duration = number(cost.get("total_duration_ms"))
    if duration is not None:
        minutes = int(duration // 60_000)
        usage += f" | {minutes // 60}h{minutes % 60:02d}m" if minutes >= 60 else f" | {minutes}m"

    limits = []
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        used = number(((data.get("rate_limits") or {}).get(key) or {}).get("used_percentage"))
        if used is not None:
            limits.append(f"{label} {used:.0f}% used")
    if limits:
        title += " | " + " / ".join(limits)

    return title + "\n" + usage


def main():
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            return
    except (ValueError, OSError):
        return
    print(render(data))


if __name__ == "__main__":
    main()
