"""Offline checks for collection scope, URL privacy, and WASM evidence parsing."""

import importlib.util
from pathlib import Path
import unittest
import urllib.request

spec = importlib.util.spec_from_file_location("flyff_client", Path(__file__).with_name("flyff-client.py"))
client = importlib.util.module_from_spec(spec)
spec.loader.exec_module(client)


class PublicClientChecks(unittest.TestCase):
    def test_scope_rejects_credentials_other_hosts_and_ports(self):
        self.assertTrue(client.allowed("https://cdn-universe.flyff.com/client/filemap.bin"))
        for url in ("http://universe.flyff.com/play", "https://universe.flyff.com.attacker.test/play",
                    "https://user:secret@universe.flyff.com/play", "https://universe.flyff.com:8443/play"):
            with self.subTest(url=url):
                self.assertFalse(client.allowed(url))

    def test_inventory_removes_credentials_and_preserves_static_versions(self):
        self.assertEqual(client.public_url("https://universe.flyff.com/login?token=private#state"), "https://universe.flyff.com/login")
        self.assertEqual(client.public_url("https://universe.flyff.com/login?abcdef123456"), "https://universe.flyff.com/login")
        self.assertEqual(client.public_url("https://cdn-universe.flyff.com/main.js?token=private"), "https://cdn-universe.flyff.com/main.js")
        self.assertEqual(client.public_url("https://cdn-universe.flyff.com/main.js?v1.2.3"), "https://cdn-universe.flyff.com/main.js?v1.2.3")

    def test_cross_host_redirect_is_rejected_before_following(self):
        with self.assertRaises(ValueError):
            client.Redirects().redirect_request(urllib.request.Request(client.ENTRY), None, 302, "Found", {}, "https://external.example/login")

    def test_reads_real_wasm_export_shape_without_execution(self):
        # Version-1 module with one exported memory, index 0.
        module = b"\x00asm\x01\x00\x00\x00\x07\x07\x01\x03mem\x02\x00"
        result = client.wasm_metadata(module)
        self.assertEqual(result["exports"], [{"name": "mem", "kind": 2, "index": 0}])
        self.assertNotIn("parse_note", result)
        self.assertIn("error", client.wasm_metadata(b"not wasm"))


if __name__ == "__main__":
    unittest.main()
