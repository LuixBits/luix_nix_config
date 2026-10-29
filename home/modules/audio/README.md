# Samson Q9U audio recovery

The USB failure investigated on 2026-10-28 and 2026-10-29 is unresolved.
Restarting audio services, resetting the microphone, and rebinding its USB
controller did not restore capture. Do not describe those attempts as a fix.

## Existing configuration

The previous mitigations were still active during the failure:

- `hosts/features/audio.nix` gives Q9U capture 2048 frames of ALSA headroom
  and forces a 1024-frame processing quantum. It also disables capture-device
  suspension and keeps selected USB devices awake.
- `hosts/pc/default.nix` disables USB autosuspend on the desktop and keeps
  AMD xHCI controllers awake.
- `presets/luix-voice.json` has RNNoise bypassed. The live EasyEffects settings
  also had RNNoise bypassed.

These settings address buffering, processing, and power management. They
cannot restore a USB device that is not responding to enumeration requests.

## Evidence from this incident

The microphone is a Samson Q9U, USB ID `17a0:0243`. The running kernel was
`6.18.57`, with PipeWire `1.6.6` and WirePlumber `0.5.14`.

The microphone originally used the CalDigit TS4 path `5-1.1.1.2`. After moving
it directly to the PC, Linux logged failed sample-rate requests and USB
control timeouts on `3-6`. After reboot, that port logged descriptor errors
`-71`. A subsequent connection on `3-3` again timed out during initialization.
Both direct ports belonged to AMD USB controller `0000:54:00.0`.

Representative errors:

```text
device descriptor read/64, error -71
cannot set freq 96000 to ep 0x1
cannot set freq 96000 to ep 0x82
failed to get current value for ch 0 (-110)
usb_set_interface failed (-110)
```

The failed USB reset then produced controller errors:

```text
ERROR unknown event type 2
ERROR mismatched command completion event
INFO: task usbreset blocked for more than 122 seconds
```

The blocked reset was waiting in `xhci_setup_device` inside the kernel.
A guarded controller unbind/rebind attempt also blocked. Even reading the
port's `disable` attribute blocked after this. Further service restarts cannot
release these kernel waits.

This establishes a USB communication and controller failure. It does not
identify whether the initial trigger was the cable, microphone firmware or
electronics, controller, or kernel driver. It also does not prove that the
earlier robotic sound on the dock had the same cause.

## Docking station behavior

Luix reported robotic, glitchy microphone audio through a docking station.
The dock identified during this investigation was a CalDigit TS4. The live
USB topology placed the Q9U behind three USB hub levels at `5-1.1.1.2`.
The OBSBOT camera and other peripherals shared parts of that upstream USB
path. The Q9U itself enumerated as a full-speed USB device, at 12 Mbit/s.

That shared hub path is a possible contributor to timing problems. Its
presence does not establish that the dock ran out of bandwidth, supplied
insufficient power, or is incompatible with the microphone. Those conditions
were not measured in this incident. A controller buffer-overrun warning was
present at startup, but the log alone did not establish which device caused it.

USB autosuspend was already disabled. The dock hubs inspected during the
failure were active and had negative autosuspend delays. Adding another
keep-awake rule would not explain or resolve the failure observed then.

Moving the Q9U to the PC removed the dock from its USB path, but the microphone
still failed USB initialization, including after a reboot. The confirmed
failure therefore extends beyond the dock connection. The dock may contribute
to the original distortion, but it is not a sufficient explanation for the
later loss of capture. There is also no evidence here that the microphone's
capsule is the cause.

The previous audio changes addressed buffering and device suspension. They
did not establish that this particular microphone, cable, dock, and controller
combination remains reliable during long recordings. Those configuration
changes cannot be treated as a verified fix for every recurrence.

After recovering USB enumeration, compare the same microphone and cable
directly on the PC and through the TS4. Test the dock first with its camera
idle, then with the camera active. Compare raw capture with EasyEffects
capture, keeping the sample rate and recording application the same. A spoken
recording and the corresponding kernel and PipeWire errors are needed to
identify where the distortion first appears. Only the TS4 was identified in
this session; other docking stations have not been tested here.

## Recovery attempts and resulting state

WirePlumber was restarted during the first investigation. After reboot, a
targeted Q9U USB reset and guarded controller rebind were attempted. Neither
completed successfully; do not repeat them while the controller is stuck.

A temporary OBSBOT microphone route was tested through EasyEffects and
directly with EasyEffects stopped. Both tests returned zero-valued samples,
so a working backup microphone was not established. The original Q9U input
selection and configured default source were restored. OBS was reopened
normally while idle to reconnect its audio clients after the service tests.

The audio investigation did not change Nix configuration, kernel parameters,
or driver quirks. The later system rebuild was started by the user. The
temporary recovery script is not a validated repair tool.

## Rebuild stall on 2026-10-29

The user started a rebuild at 00:39 CET. The system build finished, but the
switch waited for `openlinkhub.service` to stop. This is the Corsair cooling
and lighting controller, whose USB devices share controller `0000:54:00.0`
with the directly connected Q9U.

Systemd sent SIGKILL after its stop timeout, but an OpenLinkHub thread remained
in uninterruptible kernel sleep. Its stack was blocked in `usb_kill_urb`,
called from `usbhid_close` and `hidraw_release`. At the same time, the Q9U reset
was blocked in `xhci_setup_device`, and the controller rebind was blocked in
`xhci_stop`. The USB problem was therefore affecting more than microphone
capture.

After further stop timeouts, activation proceeded and updated
`/run/current-system`, but the switch exited with status 4 at 00:46:06 CET.
The old blocked threads remained. The replacement OpenLinkHub process also
failed to start its REST server and retained a blocked USB thread. A systemd
status of `active` did not establish that this service was healthy.

The new system contains kernel `6.18.59`; `uname -r` still reported `6.18.57`
in the running session. Switching the system configuration had not replaced
the running kernel. The Q9U was still absent from ALSA and PipeWire.

### Deprecated dock setting

The warning observed at 00:45:32 CET was:

```text
dock.monitors: dock monitors is deprecated; use per-monitor enabled overrides
```

It came from Noctalia's `~/.config/noctalia/config.toml`. This refers to the
desktop application's on-screen dock and its monitor-selection settings. It
does not refer to the CalDigit docking station or explain the USB failure.

## Next recovery step

A full power cycle remains to be tested. A restart alone did not recover this
incident. This procedure does not require opening the case:

1. Save work and shut down the PC normally.
2. Once it is off, disconnect its mains power or switch off its power strip
   for 30 seconds. Confirm that the directly connected microphone loses power.
3. Restore power and boot the PC.
4. Check device detection and new kernel errors before changing audio settings.

```sh
cat /proc/asound/cards
timeout 5 wpctl status -n
journalctl -k -b --no-pager | rg -i 'samson|cannot set freq|usb_set_interface|descriptor read|xhci.*(error|warn)|blocked for more'
```

A successful recovery needs all of the following: the Q9U appears as an ALSA
card and PipeWire source, EasyEffects receives the Q9U input, OBS receives its
microphone stream, and a spoken recording is audible without distortion.
Device enumeration alone is not an audio-quality test.

If the same USB errors return after power is fully removed, a different USB
data cable or a connection through a different controller is needed to isolate
the failing component. Record the successful action and verification here
when that test is complete.

## References

- [Linux USB error codes](https://docs.kernel.org/driver-api/usb/error-codes.html)
- [Linux USB port power-control implementation](https://github.com/torvalds/linux/blob/v6.18/drivers/usb/core/port.c)
