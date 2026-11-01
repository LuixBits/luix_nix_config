from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from kimi_statusline import plan_quotas, render, session_usage


class UsageHandler(BaseHTTPRequestHandler):
    payload = {}
    requests = []

    def do_GET(self):
        type(self).requests.append((self.path, self.headers.get("Authorization")))
        body = json.dumps(type(self).payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class KimiStatuslineTests(unittest.TestCase):
    def test_render_only_requested_fields(self):
        self.assertEqual(
            render({"input": 22_223, "output": 351}, {"5h": 0.126, "month": 0.08}),
            "in 22.2k · out 351 · 5h 13% · month 8%",
        )
        self.assertEqual(
            render({"input": 0, "output": 0}, {"5h": 0, "week": 0.34, "month": 0.08}),
            "in 0 · out 0 · 5h 0% · week 34% · month 8%",
        )
        self.assertEqual(render(None, {}), "in — · out — · 5h — · month —")

    def test_session_usage_aggregates_agents_and_only_new_records(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            session = home / "sessions" / "work" / "session_abc"
            main = session / "agents" / "main" / "wire.jsonl"
            worker = session / "agents" / "worker" / "wire.jsonl"
            main.parent.mkdir(parents=True)
            worker.parent.mkdir(parents=True)
            main.write_text(
                '{"type":"usage.record","usage":{"inputOther":1000,"inputCacheRead":500,"output":20}}\n'
                '{"type":"usage.record","usage":{"inputCacheCreation":250,"output":5}}\n'
                '{"type":"other","usage":{"inputOther":9999,"output":9999}}\n'
            )
            worker.write_text('{"type":"usage.record","usage":{"inputOther":1,"output":2}}\n')

            self.assertEqual(session_usage(home, "abc"), {"input": 1751, "output": 27})

            with main.open("a") as file:
                file.write('{"type":"usage.record","usage":{"inputOther":4,"output":3}}\n')
                file.write('{"type":"usage.record","usage":{"inputOther":10,')
            self.assertEqual(session_usage(home, "abc"), {"input": 1755, "output": 30})

            with main.open("a") as file:
                file.write('"output":1}}\n')
            self.assertEqual(session_usage(home, "abc"), {"input": 1765, "output": 31})
            self.assertIsNone(session_usage(home, "missing"))

    def test_plan_quotas_uses_real_http_and_caches_without_token(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            UsageHandler.payload = {
                "usages": {
                    "limit_5h": {"used_ratio": 0.126},
                    "limit_7d": {"used_ratio": "0.34"},
                    "limit_month_total": {"used_ratio": 0.08},
                }
            }
            UsageHandler.requests = []
            server = ThreadingHTTPServer(("127.0.0.1", 0), UsageHandler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                (home / "config.toml").write_text(f'''[providers."managed:kimi-code"]
type = "kimi"
base_url = "http://127.0.0.1:{server.server_port}/coding/v1"
[providers."managed:kimi-code".oauth]
storage = "file"
key = "oauth/kimi-code"
''')
                credentials = home / "credentials" / "kimi-code.json"
                credentials.parent.mkdir()
                credentials.write_text(json.dumps({"access_token": "fake-token", "expires_at": time.time() + 3600}))
                expected = {"5h": 0.126, "week": 0.34, "month": 0.08}
                self.assertEqual(plan_quotas(home), expected)
                self.assertEqual(plan_quotas(home), expected)
                self.assertEqual(
                    UsageHandler.requests,
                    [("/coding/v1/usages", "Bearer fake-token")],
                )
                cache = (home / "cache" / "statusline" / "quotas.json").read_text()
                self.assertNotIn("fake-token", cache)
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_failed_refresh_keeps_cached_quotas(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cache = home / "cache" / "statusline" / "quotas.json"
            cache.parent.mkdir(parents=True)
            cache.write_text('{"checked_at":0,"quotas":{"5h":0.25,"month":0.5}}')
            with patch("kimi_statusline.fetch_quotas", return_value=None):
                self.assertEqual(plan_quotas(home), {"5h": 0.25, "month": 0.5})


if __name__ == "__main__":
    unittest.main()
