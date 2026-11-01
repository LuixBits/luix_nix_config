"""Render Kimi session tokens and managed plan quotas in one status line."""

import json
import math
import os
from pathlib import Path
import sys
import tempfile
import time
import tomllib
import urllib.request


QUOTA_CACHE_SECONDS = 30
QUOTA_TIMEOUT_SECONDS = 0.2


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


def percent(value):
    value = number(value)
    if value is None:
        return "—"
    return f"{math.floor(min(value, 1) * 100 + 0.5)}%"


def render(usage, quotas):
    usage = usage or {}
    quotas = quotas or {}
    parts = [
        f"in {tokens(usage.get('input'))}",
        f"out {tokens(usage.get('output'))}",
        f"5h {percent(quotas.get('5h'))}",
    ]
    if "week" in quotas:
        parts.append(f"week {percent(quotas.get('week'))}")
    parts.append(f"month {percent(quotas.get('month'))}")
    return " · ".join(parts)


def write_atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        try:
            json.dump(value, file, separators=(",", ":"))
            file.write("\n")
            file.flush()
            os.chmod(temporary, 0o600)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def read_json(path):
    try:
        value = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def session_directory(home, session_id):
    if not isinstance(session_id, str) or not session_id:
        return None
    if any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in session_id):
        return None
    name = session_id if session_id.startswith("session_") else f"session_{session_id}"
    matches = [path for path in home.glob(f"sessions/*/{name}") if path.is_dir()]
    return matches[0] if matches else None


def empty_usage():
    return {"input": 0, "output": 0}


def cached_usage(value):
    if not isinstance(value, dict):
        return empty_usage()
    return {
        key: number(value.get(key)) or 0
        for key in ("input", "output")
    }


def add_record(usage, record):
    if record.get("type") != "usage.record" or not isinstance(record.get("usage"), dict):
        return
    raw = record["usage"]
    input_tokens = sum(
        number(raw.get(key)) or 0
        for key in ("inputOther", "inputCacheRead", "inputCacheCreation")
    )
    usage["input"] += input_tokens
    usage["output"] += number(raw.get("output")) or 0


def session_usage(home, session_id):
    directory = session_directory(home, session_id)
    if directory is None:
        return None
    cache_path = home / "cache" / "statusline" / f"{directory.name}.json"
    cache = read_json(cache_path) or {}
    previous_files = cache.get("files") if isinstance(cache.get("files"), dict) else {}
    files = {}
    total = empty_usage()
    changed = False

    for wire in sorted(directory.glob("agents/*/wire.jsonl")):
        try:
            stat = wire.stat()
        except OSError:
            continue
        key = str(wire)
        previous = previous_files.get(key)
        if not isinstance(previous, dict):
            previous = {}
        offset = previous.get("offset")
        if not isinstance(offset, int) or isinstance(offset, bool) or offset < 0:
            offset = 0
        same_file = (
            previous.get("device") == stat.st_dev
            and previous.get("inode") == stat.st_ino
            and offset <= stat.st_size
        )
        usage = cached_usage(previous.get("usage")) if same_file else empty_usage()
        if not same_file:
            offset = 0
            changed = True
        try:
            with wire.open("rb") as file:
                file.seek(offset)
                data = file.read()
        except OSError:
            continue
        complete = data.rfind(b"\n") + 1
        if complete:
            for line in data[:complete].splitlines():
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                if isinstance(record, dict):
                    add_record(usage, record)
            offset += complete
            changed = True
        files[key] = {
            "device": stat.st_dev,
            "inode": stat.st_ino,
            "offset": offset,
            "usage": usage,
        }
        total["input"] += usage["input"]
        total["output"] += usage["output"]

    if changed or set(files) != set(previous_files):
        write_atomic(cache_path, {"files": files})
    return total


def provider_settings(home):
    try:
        with (home / "config.toml").open("rb") as file:
            config = tomllib.load(file)
    except (OSError, tomllib.TOMLDecodeError):
        return None, None
    provider = config.get("providers", {}).get("managed:kimi-code", {})
    if not isinstance(provider, dict):
        return None, None
    base_url = os.environ.get("KIMI_CODE_BASE_URL") or provider.get("base_url") or "https://api.kimi.com/coding/v1"
    token = None
    oauth = provider.get("oauth")
    if isinstance(oauth, dict) and oauth.get("storage", "file") == "file":
        key = oauth.get("key", "oauth/kimi-code")
        if key in ("kimi-code", "oauth/kimi-code"):
            name = "kimi-code"
        elif isinstance(key, str) and key.startswith("oauth/"):
            name = key[6:]
        elif isinstance(key, str) and "/" not in key and not key.startswith("."):
            name = key
        else:
            name = ""
        if name and "/" not in name and not name.startswith("."):
            stored = read_json(home / "credentials" / f"{name}.json") or {}
            expires_at = number(stored.get("expires_at"))
            if expires_at is None or expires_at > time.time() + 30:
                candidate = stored.get("access_token")
                if isinstance(candidate, str) and candidate:
                    token = candidate
    if token is None:
        env_name = provider.get("api_key_env")
        if isinstance(env_name, str) and env_name:
            token = os.environ.get(env_name)
        elif isinstance(provider.get("api_key"), str):
            token = provider["api_key"]
    if not isinstance(base_url, str) or not token:
        return None, None
    return base_url.rstrip("/") + "/usages", token


def fetch_quotas(home):
    url, token = provider_settings(home)
    if url is None:
        return None
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=QUOTA_TIMEOUT_SECONDS) as response:
            payload = json.loads(response.read(1_000_000))
    except (OSError, ValueError):
        return None
    raw = payload.get("usages") if isinstance(payload, dict) else None
    if not isinstance(raw, dict):
        return None
    quotas = {}
    for source, target in (("limit_5h", "5h"), ("limit_7d", "week"), ("limit_month_total", "month")):
        entry = raw.get(source)
        if not isinstance(entry, dict):
            continue
        raw_ratio = entry.get("used_ratio")
        if isinstance(raw_ratio, str):
            try:
                raw_ratio = float(raw_ratio)
            except ValueError:
                raw_ratio = None
        ratio = number(raw_ratio)
        if ratio is not None:
            quotas[target] = ratio
    return quotas


def plan_quotas(home):
    path = home / "cache" / "statusline" / "quotas.json"
    cache = read_json(path) or {}
    quotas = cache.get("quotas") if isinstance(cache.get("quotas"), dict) else {}
    now = time.time()
    checked_at = number(cache.get("checked_at")) or 0
    if now >= checked_at and now - checked_at < QUOTA_CACHE_SECONDS:
        return quotas
    fresh = fetch_quotas(home)
    if fresh is not None:
        quotas = fresh
    try:
        write_atomic(path, {"checked_at": now, "quotas": quotas})
    except OSError:
        pass
    return quotas


def main():
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            return
    except (ValueError, OSError):
        return
    home = Path(os.environ.get("KIMI_CODE_HOME") or Path.home() / ".kimi-code")
    try:
        usage = session_usage(home, data.get("sessionId"))
    except OSError:
        usage = None
    print(render(usage, plan_quotas(home)))


if __name__ == "__main__":
    main()
