"""Regression checks for the shared browser launcher."""

import importlib.util
import json
from pathlib import Path
import unittest
from tempfile import TemporaryDirectory
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("shared_browser", Path(__file__).with_name("shared-browser.py"))
browser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser)


class SharedBrowser(unittest.TestCase):
    def test_reuses_browser_without_launching_or_reloading(self):
        with TemporaryDirectory() as folder, patch.object(browser, "STATE", Path(folder)), \
                patch.object(browser, "active", return_value=True), \
                patch.object(browser, "version", return_value={"Browser": "test"}), \
                patch.object(browser.subprocess, "run") as run:
            browser.start()
            run.assert_not_called()

    def test_workspace_replaces_observer_with_direct_browser_access(self):
        with TemporaryDirectory() as folder, patch.dict(browser.os.environ, {"PENTEST_PLAYWRIGHT": "/bin/playwright-mcp"}):
            project = Path(folder)
            (project / "opencode.json").write_text(json.dumps({
                "default_agent": "browser-observer",
                "agent": {"browser-observer": {"steps": 5}, "browser-tester": {"steps": 8}},
            }))
            config = json.loads(browser.workspace_config(project).read_text())
            self.assertEqual(config["default_agent"], "browser")
            self.assertEqual(set(config["agent"]), {"browser"})
            agent = config["agent"]["browser"]
            self.assertNotIn("steps", agent)
            self.assertEqual(agent["permission"]["shared_*"], "allow")
            command = config["mcp"]["shared"]["command"]
            self.assertEqual(command[0], "/bin/playwright-mcp")
            self.assertIn(browser.CDP, command)
            self.assertNotIn("--allowed-origins", command)
            self.assertEqual(list(project.iterdir()), [project / "opencode.json"])


if __name__ == "__main__":
    unittest.main()
