#!/usr/bin/env python3
"""Keep game input active until Ctrl+Shift+C, with visible terminal status."""

import argparse
from contextlib import ExitStack
import fcntl
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time


# Linux input keycodes, matching the live German (Switzerland) layout.
UMLAUT = 26
MOVEMENT = ((17, "W"), (31, "S"), (30, "A"), (32, "D"))
CTRL = {29, 97}
SHIFT = {42, 54}
KEY_C = 46
STOP_KEYS = CTRL | SHIFT | {KEY_C}
START_DELAY = 5
TAP_SECONDS = 0.08


class StopRequested(Exception):
    pass


def stop_chord(keys):
    return bool(keys & CTRL and keys & SHIFT and KEY_C in keys)


def next_deadline(deadline, now, interval):
    """Keep the cadence, skipping missed ticks instead of sending a burst."""
    return deadline + (int((now - deadline) // interval) + 1) * interval


def status(text, final=False):
    if sys.stdout.isatty():
        print("\r\033[K" + text, end="\n" if final else "", flush=True)
    else:
        print(text, flush=True)


def run_loop(keyboards, keyboard, mouse):
    from evdev import ecodes as e

    pressed = {device.fd: set(device.active_keys()) & STOP_KEYS for device in keyboards}
    held = {}
    start = time.monotonic() + START_DELAY
    next_regular, next_move, next_status = start + 2, start + 10, 0
    umlaut_count = move_count = 0
    mouse_delta = 2
    last_move = "none"

    def tap(code, now):
        held[code] = now + TAP_SECONDS
        keyboard.write(e.EV_KEY, code, 1)
        keyboard.syn()

    try:
        while True:
            readable, _, _ = select.select(keyboards, [], [], 0.02)
            for device in readable:
                # Only modifier/C state is retained; ordinary typing is ignored.
                for event in device.read():
                    if event.type == e.EV_SYN and event.code == e.SYN_DROPPED:
                        raise StopRequested("keyboard event overflow; restart the script")
                    if event.type == e.EV_KEY and event.code in STOP_KEYS:
                        if event.value:
                            pressed[device.fd].add(event.code)
                        else:
                            pressed[device.fd].discard(event.code)
                        if stop_chord(set().union(*pressed.values())):
                            raise StopRequested("Ctrl+Shift+C")
            if stop_chord(set().union(*pressed.values())):
                raise StopRequested("Ctrl+Shift+C")

            now = time.monotonic()
            for code, release_at in list(held.items()):
                if now >= release_at:
                    keyboard.write(e.EV_KEY, code, 0)
                    keyboard.syn()
                    del held[code]

            # Process the stop shortcut before sending any more input.
            if now >= next_regular:
                tap(UMLAUT, now)
                mouse.write(e.EV_REL, e.REL_X, mouse_delta)
                mouse.syn()
                mouse_delta = -mouse_delta
                umlaut_count += 1
                next_regular = next_deadline(next_regular, now, 2)
            if now >= next_move:
                code, last_move = MOVEMENT[move_count % len(MOVEMENT)]
                tap(code, now)
                move_count += 1
                next_move = next_deadline(next_move, now, 10)

            if now >= next_status:
                if now < start:
                    status(f"STARTING in {max(1, int(start - now + 0.99))}s | Focus the game | Stop: Ctrl+Shift+C")
                else:
                    elapsed = int(now - start)
                    status(
                        f"RUNNING | {elapsed // 60:02d}:{elapsed % 60:02d} | "
                        f"ü: {umlaut_count} | movement taps: {move_count} "
                        f"(last: {last_move}) | Stop: Ctrl+Shift+C"
                    )
                next_status = now + 1
    finally:
        for code in held:
            keyboard.write(e.EV_KEY, code, 0)
        keyboard.syn()


def run():
    from evdev import InputDevice, UInput, ecodes as e, list_devices

    # The global shortcut needs access to the physical keyboard event devices.
    if os.geteuid() != 0:
        raise RuntimeError("Run party-break.sh so it can request input access with sudo.")
    with ExitStack() as stack:
        lock = stack.enter_context(open("/run/party-break.lock", "w"))
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Already running. Press Ctrl+Shift+C to stop that instance.") from None
        if not Path("/dev/uinput").exists():
            subprocess.run(["/run/current-system/sw/bin/modprobe", "uinput"], check=True)

        keyboards = []
        for path in list_devices():
            device = InputDevice(path)
            keys = set(device.capabilities().get(e.EV_KEY, []))
            if not device.name.startswith("party-break-") and keys & STOP_KEYS:
                stack.callback(device.close)
                keyboards.append(device)
            else:
                device.close()
        supported = set().union(*(set(d.capabilities().get(e.EV_KEY, [])) for d in keyboards))
        if not stop_chord(supported):
            raise RuntimeError("No readable keyboard for Ctrl+Shift+C; no input was started.")

        # Separate virtual devices let the desktop recognise keyboard and mouse.
        keyboard = stack.enter_context(UInput(name="party-break-keyboard"))
        mouse = stack.enter_context(UInput(
            {e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT], e.EV_REL: [e.REL_X, e.REL_Y]},
            name="party-break-mouse",
        ))
        print("No time limit. Stop with Ctrl+Shift+C anywhere, or Ctrl+C here.", flush=True)
        run_loop(keyboards, keyboard, mouse)


def preview():
    print("DRY RUN: no input devices opened, no keys pressed.")
    print("After a 5-second startup delay; repeats until Ctrl+Shift+C:")
    for tick in range(2, 42, 2):
        movement = f"; tap {MOVEMENT[(tick // 10 - 1) % 4][1]}" if tick % 10 == 0 else ""
        delta = 2 if tick % 4 else -2
        print(f"{tick:2d}s: tap ü; mouse {delta:+d}{movement}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="preview the first 40 seconds without sending input")
    args = parser.parse_args()
    if args.dry_run:
        preview()
        return 0

    def interrupted(signum, _frame):
        raise StopRequested(signal.Signals(signum).name)

    for signum in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, interrupted)
    try:
        run()
    except (StopRequested, KeyboardInterrupt) as exc:
        status(f"STOPPED | {exc or 'Ctrl+C'}", final=True)
        return 0
    except (OSError, RuntimeError, subprocess.CalledProcessError, ImportError) as exc:
        status(f"STOPPED | Error: {exc}", final=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
