"""Offline protocol, secret-handling, and NetworkManager profile checks."""

import base64
import configparser
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
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
if pia.WG_QUICK == "@wg-quick@":
    pia.WG_QUICK = shutil.which("wg-quick")

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
            "allowed-ips=0.0.0.0/0;",
            f"private-key={PRIVATE}",
        ):
            self.assertIn(setting, normalized)
        settings = configparser.ConfigParser(interpolation=None)
        settings.read_string(normalized)
        self.assertEqual(settings["ipv4"]["method"], "manual")
        self.assertEqual(settings["ipv4"]["address1"], "10.12.0.2/32")
        self.assertEqual(settings["ipv6"]["method"], "disabled")
        self.assertEqual(settings["wireguard"]["ip4-auto-default-route"], "1")
        self.assertEqual(settings["wireguard"]["ip6-auto-default-route"], "0")
        for family in ("ipv4", "ipv6"):
            self.assertFalse(settings[family].get("dns"))
            self.assertFalse(settings[family].get("dns-search"))
            self.assertEqual(settings[family].getint("dns-priority", 0), 0)
        self.assertNotIn("address1", settings["ipv6"])
        self.assertNotIn("DIP-test", normalized)

    def test_profile_does_not_require_or_use_pia_dns(self):
        response = {
            key: value for key, value in RESPONSE.items() if key != "dns_servers"
        }
        expected = pia.make_profile("192.0.2.5", PRIVATE, response)
        for dns in ([], None, ["10.0.0.242"], ["invalid\n[connection]"]):
            with self.subTest(dns=dns):
                self.assertEqual(
                    pia.make_profile(
                        "192.0.2.5", PRIVATE, {**response, "dns_servers": dns}
                    ),
                    expected,
                )

    def test_api_values_cannot_inject_keyfile_settings(self):
        for field, value in (
            ("peer_ip", "10.0.0.2\nautoconnect=true"),
            ("server_key", PUBLIC + "\n[connection]"),
            ("server_port", 65536),
        ):
            with (
                self.subTest(field=field),
                self.assertRaises((ValueError, pia.SetupError)),
            ):
                pia.make_profile("192.0.2.5", PRIVATE, {**RESPONSE, field: value})
            with (
                self.subTest(field=field, format="manual"),
                self.assertRaises((ValueError, pia.SetupError)),
            ):
                pia.make_manual_config("192.0.2.5", PRIVATE, {**RESPONSE, field: value})

    def test_manual_config_has_only_ipv4_wireguard_settings(self):
        config = pia.make_manual_config("192.0.2.5", PRIVATE, RESPONSE)
        settings = configparser.ConfigParser(interpolation=None)
        settings.read_string(config)
        self.assertEqual(set(settings["Interface"]), {"address", "privatekey"})
        self.assertEqual(settings["Interface"]["Address"], "10.12.0.2/32")
        self.assertEqual(settings["Interface"]["PrivateKey"], PRIVATE)
        self.assertEqual(settings["Peer"]["PublicKey"], PUBLIC)
        self.assertEqual(settings["Peer"]["Endpoint"], "192.0.2.5:1337")
        self.assertEqual(settings["Peer"]["AllowedIPs"], "0.0.0.0/0")
        self.assertIn("Address = 10.12.0.2/32", config)
        self.assertNotIn("DNS", config)
        self.assertNotIn("MTU", config)
        self.assertNotIn("::", config)

    def test_manual_connection_saves_private_config_and_verifies_after_starting(self):
        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(pia, "STATE", Path(directory)),
            patch.object(pia, "MANUAL_CONFIG", Path(directory) / "pia-manual.conf"),
            patch.object(pia, "disconnect") as disconnect,
            patch.object(
                pia,
                "prepare_connection",
                return_value=(CREDENTIALS, "192.0.2.5", PRIVATE, RESPONSE),
            ) as prepare,
            patch.object(pia, "run") as run,
            patch.object(pia, "verify_connection") as verify,
            patch.object(pia, "disconnect_manual") as cleanup,
            redirect_stdout(io.StringIO()),
        ):

            def verify_after_start(*args):
                run.assert_called_once_with(
                    [pia.WG_QUICK, "up", str(pia.MANUAL_CONFIG)],
                    label="Connecting manual PIA",
                )

            verify.side_effect = verify_after_start
            pia.connect(False)
            disconnect.assert_called_once_with()
            prepare.assert_called_once_with(False)
            verify.assert_called_once_with("192.0.2.5", PUBLIC)
            cleanup.assert_not_called()
            self.assertEqual(pia.MANUAL_CONFIG.stat().st_mode & 0o777, 0o600)
            self.assertIn(PRIVATE, pia.MANUAL_CONFIG.read_text())
            self.assertEqual(
                json.loads((Path(directory) / "credentials.json").read_text()),
                CREDENTIALS,
            )

    def test_failed_or_interrupted_connection_removes_its_tunnel(self):
        for error in (
            pia.SetupError("No handshake"),
            KeyboardInterrupt(),
            OSError("probe failed"),
            subprocess.TimeoutExpired("probe", 8),
        ):
            with (
                self.subTest(error=type(error).__name__),
                tempfile.TemporaryDirectory() as directory,
                patch.object(pia, "STATE", Path(directory)),
                patch.object(pia, "MANUAL_CONFIG", Path(directory) / "pia-manual.conf"),
                patch.object(pia, "disconnect"),
                patch.object(
                    pia,
                    "prepare_connection",
                    return_value=(CREDENTIALS, "192.0.2.5", PRIVATE, RESPONSE),
                ),
                patch.object(pia, "run"),
                patch.object(pia, "verify_connection", side_effect=error),
                patch.object(pia, "disconnect_manual") as cleanup,
                redirect_stdout(io.StringIO()),
            ):
                with self.assertRaises(type(error)):
                    pia.connect(False)
                cleanup.assert_called_once_with()

    def test_failed_startup_also_attempts_cleanup(self):
        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(pia, "STATE", Path(directory)),
            patch.object(pia, "MANUAL_CONFIG", Path(directory) / "pia-manual.conf"),
            patch.object(pia, "disconnect"),
            patch.object(
                pia,
                "prepare_connection",
                return_value=(CREDENTIALS, "192.0.2.5", PRIVATE, RESPONSE),
            ),
            patch.object(pia, "run", side_effect=pia.SetupError("wg-quick failed")),
            patch.object(pia, "verify_connection") as verify,
            patch.object(pia, "disconnect_manual") as cleanup,
            redirect_stdout(io.StringIO()),
        ):
            with self.assertRaises(pia.SetupError):
                pia.connect(False)
            cleanup.assert_called_once_with()
            verify.assert_not_called()

    def test_failed_registration_never_starts_a_tunnel(self):
        with (
            patch.object(pia, "disconnect"),
            patch.object(
                pia, "prepare_connection", side_effect=pia.SetupError("PIA unavailable")
            ),
            patch.object(pia, "atomic_write") as write,
            patch.object(pia, "run") as run,
            redirect_stdout(io.StringIO()),
        ):
            with self.assertRaises(pia.SetupError):
                pia.connect(False)
            write.assert_not_called()
            run.assert_not_called()

    def test_plain_setup_saves_profile_without_activating(self):
        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(pia, "STATE", Path(directory)),
            patch.object(pia, "networkmanager_active", return_value=False),
            patch.object(pia, "manual_active", return_value=False),
            patch.object(
                pia,
                "prepare_connection",
                return_value=(CREDENTIALS, "192.0.2.5", PRIVATE, RESPONSE),
            ),
            patch.object(pia, "install_profile") as install,
            patch.object(pia, "run") as run,
            redirect_stdout(io.StringIO()),
        ):
            pia.setup(False)
            install.assert_called_once()
            run.assert_not_called()

    def test_setup_refuses_to_replace_an_active_manual_connection(self):
        with (
            patch.object(pia, "networkmanager_active", return_value=False),
            patch.object(pia, "manual_active", return_value=True),
            patch.object(pia, "prepare_connection") as prepare,
        ):
            with self.assertRaises(pia.SetupError):
                pia.setup(False)
            prepare.assert_not_called()

    def test_disconnect_leaves_unrelated_wireguard_interfaces_alone(self):
        with patch.object(pia, "run", return_value="wg0 pia-manual-other\n") as run:
            pia.disconnect_manual()
            run.assert_called_once_with(
                [pia.WG, "show", "interfaces"], label="Checking WireGuard"
            )

    def test_verification_checks_handshake_dns_and_default_route(self):
        with (
            patch.object(
                pia,
                "connection_probe",
                side_effect=[pia.SetupError("starting"), "ip=192.0.2.5\n", "192.0.2.5"],
            ) as probe,
            patch.object(pia, "has_handshake", side_effect=[False, True]),
        ):
            pia.verify_connection("192.0.2.5", PUBLIC)
            self.assertEqual(probe.call_count, 3)
            self.assertEqual(
                probe.call_args_list[0].kwargs, {"interface": pia.MANUAL_INTERFACE}
            )
            self.assertEqual(probe.call_args_list[-1].args, ("https://api.ipify.org",))
            self.assertEqual(probe.call_args_list[-1].kwargs, {})

    def test_missing_handshake_has_a_bounded_failure(self):
        with (
            patch.object(
                pia, "connection_probe", side_effect=pia.SetupError("timeout")
            ) as probe,
            patch.object(pia, "has_handshake", return_value=False),
        ):
            with self.assertRaisesRegex(pia.SetupError, "No WireGuard handshake"):
                pia.verify_connection("192.0.2.5", PUBLIC)
            self.assertEqual(probe.call_count, 3)

    def test_dns_failure_is_distinguished_from_a_failed_handshake(self):
        with (
            patch.object(
                pia,
                "connection_probe",
                side_effect=["ip=192.0.2.5\n", pia.SetupError("DNS failed")],
            ),
            patch.object(pia, "has_handshake", return_value=True),
        ):
            with self.assertRaisesRegex(
                pia.SetupError, "normal DNS/HTTPS check failed"
            ):
                pia.verify_connection("192.0.2.5", PUBLIC)

    def test_wrong_exit_ip_is_not_reported_as_success(self):
        for replies in (
            ["ip=198.51.100.4\n"],
            ["ip=192.0.2.5\n", "198.51.100.4"],
        ):
            with (
                self.subTest(replies=replies),
                patch.object(pia, "connection_probe", side_effect=replies),
                patch.object(pia, "has_handshake", return_value=True),
            ):
                with self.assertRaises(pia.SetupError):
                    pia.verify_connection("192.0.2.5", PUBLIC)

    def test_handshake_must_belong_to_the_registered_server(self):
        for output, expected in (
            (f"{PUBLIC}\t0\n{PRIVATE}\t1789000000\n", False),
            (f"{PUBLIC}\t1789000000\n", True),
            ("", False),
        ):
            with (
                self.subTest(output=output),
                patch.object(pia, "run", return_value=output),
            ):
                self.assertEqual(pia.has_handshake(PUBLIC), expected)

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
