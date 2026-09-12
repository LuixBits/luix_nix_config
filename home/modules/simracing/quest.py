"""Connect your Meta Quest to WiVRn over USB."""

import argparse
import re
import subprocess
import sys
import time

ADB = "@adb@"
SYSTEMCTL = "@systemctl@"
WIVRNCTL = "@wivrnctl@"
WIVRN_VERSION = "@wivrnVersion@"
APPLICATIONS = ("org.meumeu.wivrn", "org.meumeu.wivrn.github")


class SetupError(Exception):
    pass


def run(command, timeout=10):
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=timeout, check=False
        )
    except subprocess.TimeoutExpired as error:
        raise SetupError(f"Command timed out after {timeout}s: {command[0]}") from error
    except OSError as error:
        raise SetupError(f"Cannot run {command[0]}: {error}") from error
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise SetupError(detail or f"Command failed: {command[0]}")
    return result.stdout.strip()


def adb(serial, *arguments):
    return run([ADB, "-s", serial, *arguments])


def devices():
    listing = run([ADB, "devices", "-l"])
    result = {}
    for line in listing.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[1] in ("device", "unauthorized", "offline"):
            result[fields[0]] = fields[1]
    return listing, result


def is_usb_quest(serial):
    if not adb(serial, "get-devpath").startswith("usb:"):
        return False
    manufacturer = adb(serial, "shell", "getprop", "ro.product.manufacturer").lower()
    model = adb(serial, "shell", "getprop", "ro.product.model").lower()
    return ("oculus" in manufacturer or "meta" in manufacturer) and "quest" in model


def select_quest(connected, serial=None):
    if serial is not None:
        state = connected.get(serial, "missing")
        if state != "device":
            raise SetupError(
                f"Quest {serial}: {state}. Connect and unlock the headset, enable "
                "Developer Mode, and accept its USB debugging prompt."
            )
        if not is_usb_quest(serial):
            raise SetupError(f"{serial} is not a Meta/Oculus Quest connected over USB.")
        return serial

    candidates = []
    for candidate, state in connected.items():
        if state != "device":
            continue
        try:
            if is_usb_quest(candidate):
                candidates.append(candidate)
        except SetupError:
            # A disappearing phone must not prevent connecting a usable Quest.
            continue
    if not candidates:
        raise SetupError(
            "No authorized USB Quest found. Use a data cable, unlock the headset, "
            "enable Developer Mode and accept USB debugging. "
            "Run simracing-quest --list to see ADB devices."
        )
    if len(candidates) > 1:
        raise SetupError(
            "Several USB Quests are connected: "
            + ", ".join(candidates)
            + ". Select one with --serial SERIAL."
        )
    return candidates[0]


def select_application(serial):
    installed = set(adb(serial, "shell", "pm", "list", "packages").splitlines())
    versions = []
    for application in APPLICATIONS:
        if f"package:{application}" not in installed:
            continue
        details = adb(serial, "shell", "dumpsys", "package", application)
        match = re.search(r"\bversionName=([^\s]+)", details)
        version = match.group(1) if match else "unknown"
        if version.removeprefix("v") == WIVRN_VERSION.removeprefix("v"):
            return application
        versions.append(f"{application}: {version}")
    if versions:
        raise SetupError(
            f"WiVRn version mismatch. This PC needs headset version {WIVRN_VERSION}; "
            f"found {', '.join(versions)}. Install the matching stable headset release."
        )
    raise SetupError(
        f"Install WiVRn {WIVRN_VERSION} on the Quest from the Meta store or the "
        "matching official GitHub release, then run this command again."
    )


def start_server():
    run([SYSTEMCTL, "--user", "start", "wivrn.service"], timeout=20)
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            run([WIVRNCTL, "list-paired"], timeout=1)
            return
        except SetupError:
            time.sleep(0.25)
    raise SetupError(
        "WiVRn did not become ready. Open WiVRn Server and check its logs, "
        "or run journalctl --user -u wivrn -n 60 --no-pager."
    )


def connect(serial):
    application = select_application(serial)
    start_server()
    adb(serial, "reverse", "tcp:9757", "tcp:9757")
    result = adb(
        serial,
        "shell",
        "am",
        "start",
        "-W",
        "-a",
        "android.intent.action.VIEW",
        "-d",
        "wivrn+tcp://localhost",
        application,
    )
    # Android's activity manager sometimes exits successfully while reporting an error.
    if re.search(r"^\s*Error(?:\b|:)", result, re.MULTILINE | re.IGNORECASE):
        raise SetupError(f"The Quest could not open WiVRn: {result}")
    print(f"USB connection requested for Quest {serial}, WiVRn {WIVRN_VERSION}.")
    print("Put on the headset. If pairing is requested, open WiVRn Server on the PC.")
    print("Wait until WiVRn reports connected before launching BeamNG.drive.")
    print("In BeamNG: Options > Display > VR > Toggle ON; then center your view.")


def main(arguments=None):
    parser = argparse.ArgumentParser(prog="simracing-quest", description=__doc__)
    parser.add_argument("--serial", help="Select a particular USB Quest")
    parser.add_argument(
        "--list", action="store_true", help="List ADB devices without connecting"
    )
    args = parser.parse_args(arguments)
    try:
        listing, connected = devices()
        if args.list:
            print(f"PC WiVRn version: {WIVRN_VERSION}\n{listing}")
            return 0
        connect(select_quest(connected, args.serial))
        return 0
    except SetupError as error:
        print(f"simracing-quest: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
