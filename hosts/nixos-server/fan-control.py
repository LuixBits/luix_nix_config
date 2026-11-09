"""Temperature control for the verified NCT6687D, with a kernel restore lease."""

import argparse
import fcntl
import json
import logging
import math
from pathlib import Path
import signal
import sys
import time

LOG = logging.getLogger("luix-fan-control")
LEASE_SECONDS = 10
INTERVAL_SECONDS = 1
CHANNELS = (1, 2, 3, 4, 6)
# Measured on this host: channels 1/2/4 keep spinning at zero duty.
# Channels 3/6 stop at 51/255, but remain stable around 330 RPM at 56/255.
MIN_PWM = {1: 0, 2: 0, 3: 56, 4: 0, 6: 56}
MIN_RPM = {1: 300, 2: 300, 3: 200, 4: 300, 6: 200}
CPU_CURVE = ((35, 0), (45, 35), (50, 55), (60, 85), (65, 100))
BOARD_CURVE = ((40, 0), (45, 50), (55, 100))


def interpolate(temperature, curve):
    if temperature <= curve[0][0]:
        return curve[0][1]
    for (low_t, low_pwm), (high_t, high_pwm) in zip(curve, curve[1:]):
        if temperature <= high_t:
            return low_pwm + (high_pwm - low_pwm) * (temperature - low_t) / (high_t - low_t)
    return curve[-1][1]


def desired_pwm(cpu_c, board_c):
    percent = max(interpolate(cpu_c, CPU_CURVE), interpolate(board_c, BOARD_CURVE))
    demand = math.ceil(percent * 255 / 100)
    return {channel: max(floor, demand) for channel, floor in MIN_PWM.items()}


class Smoothing:
    """Raise immediately; require 30 cooler seconds before gradually lowering."""

    def __init__(self):
        self.current = {}
        self.cool_since = {}

    def update(self, target, now):
        for channel, demand in target.items():
            current = self.current.get(channel, demand)
            if demand >= current:
                current = demand
                self.cool_since.pop(channel, None)
            elif current - demand >= 8 or demand == MIN_PWM[channel]:
                since = self.cool_since.setdefault(channel, now)
                if now - since >= 30:
                    current = max(demand, current - 13)
            else:
                self.cool_since.pop(channel, None)
            self.current[channel] = current
        return self.current.copy()


def hwmon_named(name):
    matches = [p for p in Path("/sys/class/hwmon").glob("hwmon*")
               if (p / "name").read_text().strip() == name]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one {name} sensor, found {len(matches)}")
    return matches[0].resolve()


def read_int(path):
    return int(path.read_text())


def write_int(path, value):
    path.write_text(f"{value}\n")


def max_temperature(paths):
    values = [read_int(p) / 1000 for p in paths]
    if not values or any(not 0 <= value <= 125 for value in values):
        raise RuntimeError(f"Missing or invalid temperature readings: {values}")
    return max(values)


def restore(hwmon):
    failures = []
    for channel in CHANNELS:
        try:
            write_int(hwmon / f"pwm{channel}_enable", 2)
            if read_int(hwmon / f"pwm{channel}_enable") != 2:
                raise RuntimeError("Firmware mode readback failed")
        except (OSError, ValueError, RuntimeError) as error:
            failures.append(f"fan{channel}: {error}")
    if failures:
        # Keep the kernel lease armed so it can retry restoring saved state.
        raise RuntimeError("; ".join(failures))
    write_int(hwmon / "fan_control_watchdog", 0)
    LOG.info("Restored firmware fan control")


def run(hwmon, coretemp):
    # Fixed paths make a sensor disappearing a failure rather than silently
    # accepting a smaller set of readings on the next iteration.
    cpu_inputs = sorted(coretemp.glob("temp*_input"))
    board_inputs = [hwmon / f"temp{i}_input" for i in range(2, 8)]
    smoothing = Smoothing()
    previous = {}
    next_log = 0
    started = False
    try:
        if read_int(hwmon / "fan_control_watchdog") != 0:
            raise RuntimeError("Another fan controller already owns the lease")
        if any(read_int(hwmon / f"pwm{i}_enable") != 2 for i in CHANNELS):
            raise RuntimeError("Expected firmware control before starting")
        started = True
        while True:
            now = time.monotonic()
            cpu = max_temperature(cpu_inputs)
            board = max_temperature(board_inputs)
            rpms = {i: read_int(hwmon / f"fan{i}_input") for i in CHANNELS}
            if any(rpm < MIN_RPM[i] or rpm > 15000 for i, rpm in rpms.items()):
                raise RuntimeError(f"Fan RPM outside allowed range: {rpms}")
            if previous:
                if read_int(hwmon / "fan_control_watchdog") == 0:
                    raise RuntimeError("Kernel lease expired; refusing to resume manual control")
                if any(read_int(hwmon / f"pwm{i}_enable") != 1 for i in CHANNELS):
                    raise RuntimeError("Unexpected fan control mode")
            targets = smoothing.update(desired_pwm(cpu, board), now)
            write_int(hwmon / "fan_control_watchdog", LEASE_SECONDS)
            for channel, target in targets.items():
                if previous.get(channel) != target:
                    write_int(hwmon / f"pwm{channel}", target)
            if now >= next_log or targets != previous:
                LOG.info(json.dumps({"cpu_c": cpu, "board_c": board,
                                     "rpm": rpms, "target_pwm": targets}))
                next_log = now + 60
            previous = targets
            time.sleep(INTERVAL_SECONDS)
    finally:
        if started:
            restore(hwmon)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    with open("/run/luix-fan-control.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        hwmon = hwmon_named("nct6687")
        if "nct6687.2592" not in hwmon.parts:
            raise RuntimeError(f"Unexpected fan controller device: {hwmon}")
        if not (hwmon / "fan_control_watchdog").exists():
            raise RuntimeError("Required kernel fan watchdog is unavailable")
        if args.restore:
            restore(hwmon)
            return
        def stop(_signum, _frame):
            raise SystemExit(0)
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        run(hwmon, hwmon_named("coretemp"))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        LOG.exception("Fan controller stopped")
        sys.exit(1)
