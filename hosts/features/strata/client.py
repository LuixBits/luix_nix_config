"""Launch OpenCode against the active Strata model, with separate application state."""

import json
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request


def main():
    executable, *arguments = sys.argv[1:]
    base = os.environ.get("STRATA_BASE_URL", os.environ["STRATA_DEFAULT_BASE_URL"]).rstrip("/")
    try:
        # Ignore web proxy variables for this direct LAN connection.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        deadline = time.monotonic() + 120
        waiting = False
        while True:
            with opener.open(base + "/models", timeout=8) as response:
                models = json.load(response)["data"]
            supported = [m for m in models if m.get("id") in (
                "qwen3.8-flash-next-normal", "qwen3.8-flash-next-abliterated")]
            if len(supported) != 1:
                raise ValueError("expected exactly one active Qwen3.8 profile")
            model = supported[0]["id"]
            context = int(supported[0].get("meta", {}).get("n_ctx", 32768))
            if context >= 4096:
                break
            # Strata briefly reports n_ctx=0 while another request cold-loads it.
            if context != 0 or time.monotonic() >= deadline:
                raise ValueError("the server has not reported a usable context; check its startup log")
            if not waiting:
                print("Strata is loading; waiting for its context settings...", file=sys.stderr)
                waiting = True
            time.sleep(2)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Cannot use Strata at {base}: {error}\n"
              "Start Strata on the main PC and check its LAN connection.", file=sys.stderr)
        return 1

    if arguments == ["--status"]:
        print(f"Endpoint: {base}\nModel: {model}\nContext: {context}")
        return 0

    output = min(8192, context // 4)
    config = {
        "$schema": "https://opencode.ai/config.json",
        "autoupdate": False,
        "share": "disabled",
        "enabled_providers": ["strata"],
        "model": "strata/" + model,
        "small_model": "strata/" + model,
        "provider": {"strata": {
            "npm": "@ai-sdk/openai-compatible",
            "name": "Local Strata",
            "options": {"baseURL": base, "apiKey": "local", "timeout": 1800000},
            "models": {model: {
                "name": "Qwen3.8 Flash-Next " + model.rsplit("-", 1)[-1],
                "tool_call": True,
                "reasoning": True,
                "limit": {"context": context, "output": output},
                "options": {"reasoningEffort": "medium"},
            }},
        }},
        "compaction": {"auto": True, "prune": True, "reserved": output},
    }
    if tools_path := os.environ.get("STRATA_TOOLS_CONFIG"):
        try:
            tools = json.loads(Path(tools_path).read_text())["mcp"]
            if not isinstance(tools, dict):
                raise ValueError("mcp must be an object")
            config["mcp"] = tools
        except (OSError, ValueError, KeyError) as error:
            print(f"Cannot read tools configuration {tools_path}: {error}", file=sys.stderr)
            return 1
    state = Path.home() / ".local/share/opencode-local"
    env = dict(os.environ)
    for key, folder in (("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                        ("XDG_CACHE_HOME", "cache"), ("XDG_STATE_HOME", "state")):
        directory = state / folder
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        env[key] = str(directory)
    # Do not inherit another launcher's config, database, or server connection.
    for key in ("OPENCODE_CONFIG", "OPENCODE_CONFIG_DIR", "OPENCODE_CONFIG_CONTENT",
                "OPENCODE_DB", "OPENCODE_SERVER_PASSWORD", "OPENCODE_SERVER_USERNAME"):
        env.pop(key, None)
    env["OPENCODE_CONFIG_CONTENT"] = json.dumps(config)
    env["OPENCODE_PURE"] = "1"
    env["OPENCODE_DISABLE_AUTOUPDATE"] = "1"
    env["OPENCODE_DISABLE_MODELS_FETCH"] = "1"
    env["OPENCODE_DISABLE_DEFAULT_PLUGINS"] = "1"
    # Keep repository AGENTS.md and project instructions available.
    env.pop("OPENCODE_DISABLE_PROJECT_CONFIG", None)
    print(f"Local Strata: {model} at {base}", file=sys.stderr)
    os.execve(executable, [executable, *arguments], env)


if __name__ == "__main__":
    sys.exit(main())
