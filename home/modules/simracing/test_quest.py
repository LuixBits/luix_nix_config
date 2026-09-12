"""Offline checks for device selection, version compatibility and failure handling."""

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

source = os.environ.get(
    "SIMRACING_QUEST_MODULE", str(Path(__file__).with_name("quest.py"))
)
spec = importlib.util.spec_from_file_location("quest", source)
quest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quest)


class QuestTests(unittest.TestCase):
    def setUp(self):
        self.addCleanup(patch.stopall)
        patch.object(quest, "WIVRN_VERSION", "26.6.2").start()
        self.actions = []
        self.hardware = {
            "phone": ("usb:1-2", "samsung", "SM-S918B"),
            "quest": ("usb:3-1", "Oculus", "Quest 3"),
            "quest2": ("usb:3-2", "Meta", "Quest 3"),
            "wireless": ("192.0.2.1:5555", "Oculus", "Quest 3"),
        }
        self.packages = {"org.meumeu.wivrn": "26.6.2"}
        self.activity_result = "Status: ok"

    def adb(self, serial, *args):
        self.actions.append((serial, args))
        if args == ("get-devpath",):
            return self.hardware[serial][0]
        if args == ("shell", "getprop", "ro.product.manufacturer"):
            return self.hardware[serial][1]
        if args == ("shell", "getprop", "ro.product.model"):
            return self.hardware[serial][2]
        if args == ("shell", "pm", "list", "packages"):
            return "\n".join(f"package:{name}" for name in self.packages)
        if args[:3] == ("shell", "dumpsys", "package"):
            return f"versionName={self.packages[args[3]]}"
        if args == ("reverse", "tcp:9757", "tcp:9757"):
            return "9757"
        if args[:3] == ("shell", "am", "start"):
            return self.activity_result
        self.fail(f"Unexpected ADB operation: {serial} {args}")

    def test_phone_and_wireless_headset_are_skipped(self):
        with patch.object(quest, "adb", side_effect=self.adb):
            serial = quest.select_quest(
                dict.fromkeys(self.hardware, "device") | {"quest2": "offline"}
            )
        self.assertEqual(serial, "quest")

    def test_explicit_serial_cannot_select_phone_or_wireless_headset(self):
        with patch.object(quest, "adb", side_effect=self.adb):
            for serial in ("phone", "wireless"):
                with self.subTest(serial=serial), self.assertRaises(quest.SetupError):
                    quest.select_quest({serial: "device"}, serial)

    def test_missing_or_unauthorized_headset_never_gets_commands(self):
        with patch.object(quest, "adb") as adb:
            for devices in ({}, {"quest": "unauthorized"}, {"quest": "offline"}):
                with self.subTest(devices=devices), self.assertRaises(quest.SetupError):
                    quest.select_quest(devices)
            with self.assertRaisesRegex(quest.SetupError, "unauthorized"):
                quest.select_quest({"quest": "unauthorized"}, "quest")
            adb.assert_not_called()

    def test_two_headsets_require_selection(self):
        devices = {"quest": "device", "quest2": "device"}
        with patch.object(quest, "adb", side_effect=self.adb):
            with self.assertRaisesRegex(quest.SetupError, "Several"):
                quest.select_quest(devices)
            self.assertEqual(quest.select_quest(devices, "quest2"), "quest2")

    def test_disappearing_phone_does_not_block_quest(self):
        def disappearing(serial, *args):
            if serial == "phone":
                raise quest.SetupError("device disconnected")
            return self.adb(serial, *args)

        with patch.object(quest, "adb", side_effect=disappearing):
            self.assertEqual(
                quest.select_quest({"phone": "device", "quest": "device"}), "quest"
            )

    def test_connection_changes_only_selected_headsets_port_and_app(self):
        with (
            patch.object(quest, "adb", side_effect=self.adb),
            patch.object(quest, "start_server") as start,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            quest.connect("quest")
        start.assert_called_once()
        self.assertTrue(all(serial == "quest" for serial, _ in self.actions))
        self.assertIn(("quest", ("reverse", "tcp:9757", "tcp:9757")), self.actions)
        self.assertEqual(self.actions[-1][1][-1], "org.meumeu.wivrn")
        self.assertIn("wivrn+tcp://localhost", self.actions[-1][1])

    def test_version_mismatch_or_missing_app_prevents_service_and_usb_changes(self):
        for packages in ({}, {"org.meumeu.wivrn": "26.6.1"}):
            self.packages = packages
            self.actions.clear()
            with (
                self.subTest(packages=packages),
                patch.object(quest, "adb", side_effect=self.adb),
                patch.object(quest, "start_server") as start,
                self.assertRaises(quest.SetupError),
            ):
                quest.connect("quest")
            start.assert_not_called()
            self.assertTrue(
                all(
                    args[0] != "reverse" and args[:2] != ("shell", "am")
                    for _, args in self.actions
                )
            )

    def test_matching_github_app_is_supported(self):
        self.packages = {
            "org.meumeu.wivrn": "26.6.1",
            "org.meumeu.wivrn.github": "v26.6.2",
        }
        with patch.object(quest, "adb", side_effect=self.adb):
            self.assertEqual(
                quest.select_application("quest"), "org.meumeu.wivrn.github"
            )

    def test_android_error_with_successful_exit_is_reported(self):
        self.activity_result = "Error: Activity not started, unable to resolve Intent"
        with (
            patch.object(quest, "adb", side_effect=self.adb),
            patch.object(quest, "start_server"),
            self.assertRaisesRegex(quest.SetupError, "could not open"),
        ):
            quest.connect("quest")

    def test_failed_usb_forward_does_not_launch_app(self):
        def fail_reverse(serial, *args):
            if args[0] == "reverse":
                raise quest.SetupError("USB disconnected")
            return self.adb(serial, *args)

        with (
            patch.object(quest, "adb", side_effect=fail_reverse),
            patch.object(quest, "start_server"),
            self.assertRaisesRegex(quest.SetupError, "disconnected"),
        ):
            quest.connect("quest")
        self.assertFalse(any(args[:2] == ("shell", "am") for _, args in self.actions))

    def test_subprocess_timeout_becomes_actionable_error(self):
        with (
            patch.object(
                quest.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired("adb", 10),
            ),
            self.assertRaisesRegex(quest.SetupError, "timed out"),
        ):
            quest.run(["adb", "devices"])

    def test_server_readiness_wait_is_bounded(self):
        with (
            patch.object(quest, "run", side_effect=["", quest.SetupError("not ready")]),
            patch.object(quest.time, "monotonic", side_effect=[0, 0, 11]),
            patch.object(quest.time, "sleep"),
            self.assertRaisesRegex(quest.SetupError, "did not become ready"),
        ):
            quest.start_server()

    def test_list_only_does_not_connect(self):
        with (
            patch.object(
                quest,
                "run",
                return_value="List of devices attached\nphone device model:Samsung\nquest unauthorized",
            ) as run,
            patch.object(quest, "connect") as connect,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(quest.main(["--list"]), 0)
        run.assert_called_once_with([quest.ADB, "devices", "-l"])
        connect.assert_not_called()


if __name__ == "__main__":
    unittest.main()
