"""Safety checks without writing real hwmon controls."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("fan_control", Path(__file__).with_name("fan-control.py"))
fan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fan)


class FanControlTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.hwmon = self.root / "fan"
        self.core = self.root / "cpu"
        self.hwmon.mkdir()
        self.core.mkdir()
        self.writes = []
        for i in fan.CHANNELS:
            (self.hwmon / f"pwm{i}").write_text("255")
            (self.hwmon / f"pwm{i}_enable").write_text("2")
            (self.hwmon / f"fan{i}_input").write_text("1000")
        for i in range(2, 8):
            (self.hwmon / f"temp{i}_input").write_text("36000")
        (self.hwmon / "fan_control_watchdog").write_text("0")
        (self.core / "temp1_input").write_text("30000")

    def write(self, path, value):
        self.writes.append((path.name, value))
        path.write_text(str(value))
        if path.name.startswith("pwm") and "_" not in path.name:
            path.with_name(path.name + "_enable").write_text("1")

    def assert_restored(self):
        self.assertEqual(fan.read_int(self.hwmon / "fan_control_watchdog"), 0)
        for i in fan.CHANNELS:
            self.assertEqual(fan.read_int(self.hwmon / f"pwm{i}_enable"), 2)

    def test_hot_cpu_or_board_requests_full_speed(self):
        self.assertEqual(fan.desired_pwm(30, 36), fan.MIN_PWM)
        for cpu, board in [(65, 36), (75, 36), (95, 36), (30, 55), (30, 70)]:
            self.assertEqual(set(fan.desired_pwm(cpu, board).values()), {255})

    def test_raises_immediately_and_delays_reduction(self):
        smooth = fan.Smoothing()
        self.assertEqual(smooth.update({1: 255}, 0), {1: 255})
        self.assertEqual(smooth.update({1: 90}, 1), {1: 255})
        self.assertEqual(smooth.update({1: 90}, 30), {1: 255})
        self.assertEqual(smooth.update({1: 90}, 31), {1: 242})
        self.assertEqual(smooth.update({1: 255}, 32), {1: 255})

    def test_stop_restores_firmware(self):
        with patch.object(fan, "write_int", self.write), patch.object(fan.time, "sleep", side_effect=SystemExit):
            with self.assertRaises(SystemExit):
                fan.run(self.hwmon, self.core)
        self.assert_restored()
        self.assertIn(("pwm1", 0), self.writes)

    def test_idle_can_reach_minimum_inside_smoothing_deadband(self):
        smooth = fan.Smoothing()
        self.assertEqual(smooth.update({1: 2}, 0), {1: 2})
        self.assertEqual(smooth.update({1: 0}, 1), {1: 2})
        self.assertEqual(smooth.update({1: 0}, 31), {1: 0})

    def test_slow_case_fan_is_valid(self):
        (self.hwmon / "fan3_input").write_text("250")
        with patch.object(fan, "write_int", self.write), patch.object(fan.time, "sleep", side_effect=SystemExit):
            with self.assertRaises(SystemExit):
                fan.run(self.hwmon, self.core)
        self.assert_restored()
        self.assertIn(("pwm3", 56), self.writes)

    def test_stopped_case_fan_is_rejected(self):
        (self.hwmon / "fan3_input").write_text("0")
        with patch.object(fan, "write_int", self.write):
            with self.assertRaisesRegex(RuntimeError, "RPM outside"):
                fan.run(self.hwmon, self.core)
        self.assert_restored()

    def test_missing_sensor_restores_firmware(self):
        def lose_sensor(_):
            (self.core / "temp1_input").unlink()
        with patch.object(fan, "write_int", self.write), patch.object(fan.time, "sleep", lose_sensor):
            with self.assertRaises(FileNotFoundError):
                fan.run(self.hwmon, self.core)
        self.assert_restored()

    def test_stalled_fan_does_not_enter_manual_control(self):
        (self.hwmon / "fan2_input").write_text("0")
        with patch.object(fan, "write_int", self.write):
            with self.assertRaisesRegex(RuntimeError, "RPM outside"):
                fan.run(self.hwmon, self.core)
        self.assert_restored()
        self.assertFalse(any(name == "pwm1" for name, _ in self.writes))

    def test_expired_lease_cannot_resume_manual_control(self):
        def expire(_):
            (self.hwmon / "fan_control_watchdog").write_text("0")
        with patch.object(fan, "write_int", self.write), patch.object(fan.time, "sleep", expire):
            with self.assertRaisesRegex(RuntimeError, "lease expired"):
                fan.run(self.hwmon, self.core)
        self.assert_restored()
        self.assertEqual(self.writes.count(("pwm1", 0)), 1)

    def test_restore_error_keeps_kernel_fallback_armed(self):
        (self.hwmon / "fan_control_watchdog").write_text("10")
        def fail_one(path, value):
            if path.name == "pwm2_enable":
                raise OSError("Injected write failure")
            self.write(path, value)
        with patch.object(fan, "write_int", fail_one):
            with self.assertRaisesRegex(RuntimeError, "fan2"):
                fan.restore(self.hwmon)
        self.assertEqual(fan.read_int(self.hwmon / "fan_control_watchdog"), 10)
        self.assertIn(("pwm6_enable", 2), self.writes)


if __name__ == "__main__":
    unittest.main()
