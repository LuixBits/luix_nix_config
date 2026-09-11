"""Offline protocol, secret-handling, and NetworkManager profile checks."""

import base64
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

module_path = os.environ.get(
    "PIA_SETUP_MODULE", str(Path(__file__).with_name("pia_setup.py"))
)
spec = importlib.util.spec_from_file_location("pia_setup", module_path)
pia = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pia)
if pia.NMCLI == "@nmcli@":
    pia.NMCLI = shutil.which("nmcli")

PRIVATE = base64.b64encode(bytes(range(32))).decode()
PUBLIC = base64.b64encode(bytes(reversed(range(32)))).decode()
RESPONSE = {
    "server_key": PUBLIC,
    "peer_ip": "10.12.0.2",
    "server_port": 1337,
    "dns_servers": ["10.0.0.242"],
    "status": "OK",
}
CREDENTIALS = {
    "username": "test-user",
    "password": 'secret"\\password',
    "dip_token": "DIP-test",
}


class SetupTests(unittest.TestCase):
    def test_profile_parses_in_real_networkmanager_without_connecting(self):
        profile = pia.make_profile("192.0.2.5", PRIVATE, RESPONSE)
        normalized = pia.run(
            [
                pia.NMCLI,
                "--offline",
                "connection",
                "modify",
                "connection.autoconnect",
                "no",
            ],
            profile,
        )
        for setting in (
            "autoconnect=false",
            "allowed-ips=0.0.0.0/0;::/0;",
            "dns-search=~.;",
            "dns-priority=-100",
            f"private-key={PRIVATE}",
        ):
            self.assertIn(setting, normalized)
        self.assertNotIn("DIP-test", normalized)

    def test_api_values_cannot_inject_keyfile_settings(self):
        for field, value in (
            ("peer_ip", "10.0.0.2\nautoconnect=true"),
            ("server_key", PUBLIC + "\n[connection]"),
            ("server_port", 65536),
            ("dns_servers", []),
        ):
            with (
                self.subTest(field=field),
                self.assertRaises((ValueError, pia.SetupError)),
            ):
                pia.make_profile("192.0.2.5", PRIVATE, {**RESPONSE, field: value})

    def test_login_and_dedicated_token_flow(self):
        replies = [
            {"token": "temporary-token"},
            [{"status": "active", "ip": "192.0.2.5", "cn": "test.privacy.network"}],
        ]
        with patch.object(pia, "request_json", side_effect=replies) as request:
            self.assertEqual(
                pia.dedicated_endpoint(CREDENTIALS),
                ("192.0.2.5", "test.privacy.network"),
            )
            options = request.call_args_list[1].args[1]
            self.assertIn(("header", "Authorization: Token temporary-token"), options)
            self.assertEqual(
                json.loads(dict(options)["data"]), {"tokens": ["DIP-test"]}
            )

    def test_inactive_token_stops_setup(self):
        with patch.object(
            pia,
            "request_json",
            side_effect=[{"token": "test"}, [{"status": "expired"}]],
        ):
            with self.assertRaises(pia.SetupError):
                pia.dedicated_endpoint(CREDENTIALS)

    def test_dedicated_registration_verifies_tls_and_uses_dip_auth(self):
        with patch.object(pia, "request_json", return_value=RESPONSE) as request:
            pia.register_key(CREDENTIALS, "192.0.2.5", "test.privacy.network", PUBLIC)
            options = request.call_args.args[1]
            self.assertIn(("cacert", pia.CERTIFICATE), options)
            self.assertIn(("user", "dedicated_ip_DIP-test:192.0.2.5"), options)
            self.assertNotIn("insecure", dict(options))

    def test_secrets_use_stdin_and_are_escaped(self):
        secret = 'private"\\value\nnext'
        with patch.object(pia, "run", return_value='{"ok": true}') as run:
            pia.request_json("Test", [("user", secret)])
            command, data, _ = run.call_args.args
            self.assertNotIn(secret, " ".join(command))
            self.assertIn('user = "private\\"\\\\value\\nnext"', data)

    def test_secret_file_is_private_even_with_permissive_umask(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "credentials.json"
            pia.atomic_write(target, "test-secret")
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            self.assertEqual(target.read_text(), "test-secret")

    def test_failed_profile_load_restores_previous_file(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "pia.nmconnection"
            target.write_text("previous-profile")
            with (
                patch.object(pia, "PROFILE", target),
                patch.object(
                    pia,
                    "run",
                    side_effect=["new-profile", pia.SetupError("load failed")],
                ),
            ):
                with self.assertRaises(pia.SetupError):
                    pia.install_profile("input-profile")
            self.assertEqual(target.read_text(), "previous-profile")


if __name__ == "__main__":
    unittest.main()
