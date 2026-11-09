"""Connect local Qwen directly to the persistent shared Chromium browser."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.request


STATE = Path.home() / ".local/share/opencode-pentest"
UNIT = "opencode-pentest-browser.service"
CDP = "http://127.0.0.1:9222"
HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def active():
    return subprocess.run(["systemctl", "--user", "is-active", "--quiet", UNIT], check=False).returncode == 0


def version():
    with HTTP.open(CDP + "/json/version", timeout=3) as response:
        return json.load(response)


def start():
    for path in (STATE, STATE / "shared-browser-profile", STATE / "shared-artifacts"):
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        path.chmod(0o700)
    reused = active()
    if not reused:
        try:
            version()
        except OSError:
            pass
        else:
            raise RuntimeError("Port 9222 belongs to another browser; refusing to attach to an unrelated profile.")
        command = ["systemd-run", "--user", "--collect", "--unit=" + UNIT, "--property=MemoryMax=3G"]
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "XDG_SESSION_TYPE"):
            if os.environ.get(key):
                command.append("--setenv=" + key + "=" + os.environ[key])
        command += [os.environ["PENTEST_CHROMIUM"], "--user-data-dir=" + str(STATE / "shared-browser-profile"),
                    "--remote-debugging-address=127.0.0.1", "--remote-debugging-port=9222",
                    "--no-first-run", "--no-default-browser-check", "--new-window", "about:blank"]
        subprocess.run(command, check=True)
    deadline = time.monotonic() + 30
    while True:
        try:
            info = version()
            break
        except (OSError, ValueError):
            if time.monotonic() >= deadline:
                raise RuntimeError(f"Shared Chromium did not become ready; inspect journalctl --user -u {UNIT}")
            time.sleep(1)
    message = "Existing tabs and login state preserved; no reload requested." if reused else "Complete login manually in its window if needed."
    print(f"Shared browser ready: {info['Browser']} at {CDP}. {message}", file=sys.stderr)


def browser_command():
    return [os.environ["PENTEST_PLAYWRIGHT"], "--cdp-endpoint", CDP,
            "--caps", "vision", "--image-responses", "omit",
            "--output-dir", str(STATE / "shared-artifacts")]


def workspace_config(project):
    project.mkdir(parents=True, exist_ok=True, mode=0o700)
    config = {
        "$schema": "https://opencode.ai/config.json",
        "mcp": {"shared": {"type": "local", "command": browser_command(),
                           "enabled": True, "timeout": 60000}},
        "default_agent": "browser",
        "agent": {"browser": {
            "description": "Use the shared Chromium browser",
            "mode": "primary",
            "prompt": "Carry out the user's task using the connected browser tools.",
            "permission": {"*": "deny", "shared_*": "allow"},
        }},
    }
    config_path = project / "opencode.json"
    config_path.write_text(json.dumps(config, indent=2) + "\n")
    return config_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["start", "stop", "status", "open", "test", "_mcp", "_tester_mcp"])
    parser.add_argument("project", type=Path, nargs="?")
    args = parser.parse_args()
    # Keep old launcher names working; both now use the same direct connection.
    if args.action in ("_mcp", "_tester_mcp"):
        if not active():
            raise RuntimeError("Start the shared browser with opencode-pentest browser-start first.")
        command = browser_command()
        os.execv(command[0], command)
    if args.action == "stop":
        subprocess.run(["systemctl", "--user", "stop", UNIT], check=True)
        print("Shared Chromium stopped. Its profile and model service remain saved.")
        return
    if args.action == "status":
        print(f"Shared browser: {'active' if active() else 'stopped'}\nLocal connection: {CDP}\nProfile: {STATE / 'shared-browser-profile'}")
        if active():
            print("Browser:", version()["Browser"])
        return
    start()
    if args.action == "start":
        return
    project = (args.project or Path.home() / "browser-workspace").expanduser().resolve()
    workspace_config(project)
    os.chdir(project)
    env = dict(os.environ, OPENCODE_DISABLE_CLAUDE_CODE="1", OPENCODE_DISABLE_EXTERNAL_SKILLS="1")
    env.pop("STRATA_TOOLS_CONFIG", None)
    os.execve(os.environ["PENTEST_CLIENT"], [os.environ["PENTEST_CLIENT"], "--agent", "browser"], env)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Shared browser: {error}", file=sys.stderr)
        sys.exit(1)
