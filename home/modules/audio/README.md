# Samson Q9U audio recovery

## 2026-11-13 Wave:3 silent capture and disconnected EasyEffects

The user reported no Wave:3 signal in EasyEffects or OBS. Both the Wave:3
on `3-7` and Q9U on `5-1.1.1.2` were enumerated in ALSA. Audio services
had zero automatic restarts; WirePlumber responded normally. OBS consumed
EasyEffects, but EasyEffects initially had no upstream microphone links.
Three-second PipeWire tests of both the Wave:3 and EasyEffects returned
144,000 zero samples each. The Wave:3 capture switch was on; the user
reported its light was white. No recent USB errors appeared in the checked
kernel log interval.

Restarting only EasyEffects restored its upstream links. OBS did not
automatically reconnect to the recreated source, so its existing microphone
ports were explicitly relinked. Capture was still all zeros. Toggling the
Wave:3 ALSA capture switch off/on did not restore signal.

The Wave:3 profile was then temporarily set to off, releasing that device
without restarting PipeWire or WirePlumber. A direct FFmpeg test failed
because its requested sample format was unsupported. A subsequent direct
ALSA test with `arecord`, `hw:Wave3,0`, packed `S24_3LE`, mono, 48 kHz,
and three seconds succeeded: 361,206 of 432,000 bytes were nonzero. The
original `output:iec958-stereo+input:mono-fallback` profile was restored
after each test. No recording was saved; sample data was measured in memory.

Afterward, three-second PipeWire captures had 130,362 nonzero samples from
the Wave:3 (peak -11.1 dBFS) and 135,498 from EasyEffects (peak -13.5 dBFS),
out of 144,000 each. The full Wave:3 -> EasyEffects -> OBS route was linked.
This establishes restored capture signal following device reopening/direct
capture, not a proven root cause or permanent repair. User confirmation of
audible speech and sustained reliability remains pending. Discover current
device and port IDs before repeating any runtime operation; IDs change.

### Follow-up: EasyEffects inactivity shutdown

The user immediately reported recurrence: enabling microphone monitoring
restored the meters temporarily, then they stopped again. The previous
short tests were therefore insufficient to establish a lasting recovery.
EasyEffects retained PID 82077, and all four audio services still reported
zero automatic restarts. During the failure, OBS's links to EasyEffects
remained active, but EasyEffects had removed the upstream microphone and
filter links. This was pipeline disconnection, not an observed process crash.

The installed EasyEffects 8.2.4 schema defaults `inactivityTimerEnable` to
true and `inactivityTimeout` to 10 seconds in `[EffectsPipelines]`.
Its `StreamInputEffects::on_link_changed` and `on_link_removed` handlers
disconnect filters when its internal client check reports no active consumer.
Why that check fails to recognize this OBS session has not been established.

With EasyEffects stopped, its writable settings at
`~/.config/easyeffects/db/easyeffectsrc` were backed up beside the original
as `easyeffectsrc.before-inactivity-fix-20261113-180301`, then
`[EffectsPipelines] inactivityTimerEnable=false` was saved. Only EasyEffects
was restarted. Its service reapplies bypass on start; bypass was subsequently
disabled to restore the user's then-current effects-enabled state. OBS's
Mic/Aux ports were relinked to the recreated EasyEffects source. No USB,
PipeWire, or WirePlumber restart was used for this change.

This setting persists in the user's application configuration without a
NixOS rebuild. It keeps processing active when EasyEffects would otherwise
consider the pipeline idle, with an associated idle CPU cost. Do not use
short capture probes alone to verify this failure: they may wake the pipeline.
Observe the graph beyond the timeout without added capture clients first.

Verification: with microphone listening disabled and no diagnostic capture
client, five graph snapshots across 40 seconds retained both active Wave:3
input links and both OBS microphone links. A subsequent five-second capture
of EasyEffects contained nonzero samples in every one-second block (peaks
between -38.8 and -32.2 dBFS). This supports the inactivity workaround;
audible speech and long-session stability still need user confirmation.

The shared Home Manager audio module now also enforces this setting with
`kwriteconfig6` in EasyEffects' `ExecStartPre`. It creates the settings
directory if needed and writes only the inactivity key, keeping microphone
selection and other UI settings writable. This avoids relying on a one-time
manual setting surviving future configuration changes. It takes effect for
managed service starts after the user activates the updated NixOS
configuration; the live application setting is already applied. The existing
PC-specific startup bypass mitigation remains unchanged.

The evaluated startup command was tested against a temporary settings file:
it disabled the timer, preserved a separate input selection, and produced
identical content when run again. The PC service evaluation and root/boot
UUID preflight passed. No system or Home Manager activation was performed.
A further passive two-minute check retained both active microphone links
and both OBS links at every 20-second snapshot, without a diagnostic capture
client keeping the pipeline awake. This verifies routing across repeated
inactivity intervals, not long-session speech quality.

Source: [EasyEffects 8.2.4 input pipeline](https://github.com/wwmm/easyeffects/blob/v8.2.4/src/stream_input_effects.cpp)
and [configuration defaults](https://github.com/wwmm/easyeffects/blob/v8.2.4/src/contents/kcfg/easyeffects_db.kcfg).

## 2026-11-10 USB detection failure

The user confirmed that the Q9U was connected directly to the PC. The live
hostname and evaluated flake hostname were both `pc`, running kernel
`6.18.60`. At boot, USB port `3-3` on controller `0000:54:00.0` failed device
descriptor reads and address setup with error `-71`. The Q9U was absent from
USB, ALSA, and PipeWire. PipeWire, PipeWire-Pulse, and WirePlumber were active,
and the live USB autosuspend setting was already `-1`.

The user unplugged the USB cable from the microphone for 30 seconds, then
reconnected it to the same PC port. At 19:44:23 CET, the kernel identified
`17a0:0243`, `Samson Q9U`, serial `644C2E031A1E3B00`. A second later it logged
sample-rate/control failures and `disabled by hub (EMI?), re-enabling...`,
followed by a USB disconnect. Descriptor and address errors then returned;
the Q9U remained absent from ALSA and PipeWire. This power-cycle attempt did
not restore usable capture. The kernel's `EMI?` message does not establish
electromagnetic interference as the cause.

The user then confirmed connecting a replacement USB data cable. The kernel
logged that connection at 19:45:23 on `3-7`, which still belongs to controller
`0000:54:00.0`. Initialization took several minutes, with sample-rate errors
and mixer-control timeouts (`-110`). This was not a cable-only comparison
because the port changed too, but capture failed with both combinations.
No successful test on a different controller was established. The user
explicitly asked to investigate stuck processes instead of repeating the
cable/replug loop.

### Blocked processes and direct capture test

PipeWire, PipeWire-Pulse, WirePlumber, and EasyEffects had zero automatic
service restarts. The USB hub worker, PID 297 in this boot, waited in this
stack, captured by the user with sudo:

```text
usb_start_wait_urb
usb_control_msg
usb_get_string
usb_cache_string
usb_create_sysfs_intf_files
usb_set_configuration
usb_new_device
hub_event
```

By approximately 19:48:28, ALSA had registered `card4` / `Q9U`. Device
registration alone was not recovery: WirePlumber PID 2990 then blocked in
`usb_start_wait_urb` while probing the microphone. Kernel logs showed
`1:2: usb_set_interface failed (-110)` about every five seconds. `wpctl`
timed out, and a prior `lsusb` query had also stalled reading device strings.
Use bounded diagnostic commands rather than leaving these queries running.

A normal WirePlumber stop did not finish within 15 seconds. A targeted
SIGKILL terminated it, after which both Q9U PCM devices showed `closed`.
With WirePlumber fully stopped, this bounded direct capture test failed:

```sh
timeout --signal=INT --kill-after=2s 12s ffmpeg -nostdin -hide_banner \
  -loglevel info -f alsa -ar 48000 -ac 1 -i hw:Q9U,0 -t 3 \
  -af astats=metadata=0:reset=0 -f null -
```

FFmpeg reported `cannot set parameters (Connection timed out)` and an input
I/O error; the kernel logged `2:2: usb_set_interface failed (-110)` at
19:51:07. No microphone recording was saved. Thus the USB failure persisted
without WirePlumber. Killing the blocked process is not a microphone fix.
WirePlumber was subsequently started again to restore audio management.

No successful recovery or permanent repair had been established at this
point; the subsequent full PC power cycle also failed, as recorded below.
Do not repeat the earlier controller-reset attempts, present
buffer changes as a USB repair, or describe the cable as the established
cause. Once recovery succeeds, record the exact action and verify both
application routing and audible speech before calling it a fix.

### Restoring playback when Q9U discovery blocks WirePlumber

Restarting WirePlumber while the unresponsive Q9U remained attached caused
all other audio devices to disappear. The replacement WirePlumber process
blocked probing the Q9U again. The user reported loss of all audio. Do not
repeat that restart without preparing containment for the failed device.

Playback was restored using this temporary configuration fragment:

```json
{
  "monitor.alsa.rules": [
    {
      "matches": [
        {"device.name": "~alsa_card.usb-Samson_Technologies_Samson_Q9U_.*"}
      ],
      "actions": {"update-props": {"device.disabled": true}}
    }
  ]
}
```

The fragment was written to
`/run/user/1000/q9u-recovery/wireplumber/wireplumber.conf.d/99-q9u-recovery.conf`.
A runtime systemd user drop-in at
`/run/user/1000/systemd/user/wireplumber.service.d/90-q9u-recovery.conf`
prepended `/run/user/1000/q9u-recovery` to the service's `XDG_CONFIG_DIRS`,
preserving its existing directories and Nix-provided `XDG_DATA_DIRS`. Both
files disappear on reboot, so this does not permanently disable the Q9U.
Discover the live user's runtime directory rather than copying UID 1000 on
another account.

After a user daemon reload and replacement of the blocked WirePlumber
process, the log at 19:55:27 confirmed that only the Samson card was disabled.
`wpctl` responded again, the normal HDMI outputs and other sources returned,
and the Star Citizen and OBS links were restored. The user confirmed that
audio playback was back. An initial fragment with the literal key
`actions.update-props` was rejected; use the nested JSON structure above.
This is a verified way to restore other audio while the Q9U is unresponsive,
not a repair of the Q9U.

The OBSBOT fallback still produced only zero-valued raw samples at 48 kHz.
Its ALSA capture switch was on, capture volume was at its maximum (19), and
the PipeWire source was unmuted at volume 1.00. Toggling that capture switch
off and back on did not change the zero-valued result. No recording was
saved. The user's report that microphones still did not work was consistent
with these measurements.

### Result after the full PC power cycle

The user completed the full mains-power cycle and reported that the microphone
was still missing. The new boot ID was
`af075758-2e25-472a-90a3-74e8e31c672a`, with audio services starting at
20:01:47 CET. All three hostname sources still reported `pc`. The running
kernel was now `6.18.62`, compared with `6.18.60` before the power cycle.
Both runtime exclusion files were absent, as intended.

At 20:01:34, the Q9U identified itself on `3-7`, still using controller
`0000:54:00.0`. The same sample-rate and mixer-control timeouts followed.
ALSA initially listed only the three onboard/HDMI cards; later the Q9U and
OBSBOT cards registered, and Q9U interface setup again timed out repeatedly.
The full power cycle and the newly booted kernel did not restore capture.
No audio services were stopped or restarted during these checks.

The user reported that the Q9U records on another computer. This directs the
next isolation test toward this PC's USB controller/driver path; it does not
establish which part of that path is faulty. Do not repeat the same cable,
power-cycle, or audio-service restart loop without new evidence.

### Elgato Wave:3 fallback capture verified

The user replaced the Q9U with an Elgato Wave:3 (`0fd9:0070`) and asked how
the microphones compare. The kernel logged the Samson disconnect at 20:06:36
and the Wave:3 at 20:06:40. Both used the same `3-7` port on controller
`0000:54:00.0`; a move to a different controller was not completed. The
Wave:3 appeared in ALSA and PipeWire without restarting any audio services.

The user selected the Wave:3 as the default input. An initial snapshot showed
it muted; the subsequent check showed it unmuted without an agent mute/gain
change. ALSA reported active 48 kHz, mono, 24-bit capture. A three-second
PipeWire capture test, converted to signed 16-bit samples in memory, contained
141,937 nonzero samples out of 144,000, with a peak of -4.2 dBFS and RMS of
-16.0 dBFS. No samples clipped and no recording was saved. EasyEffects was
linked to the Wave:3 source. No new USB errors appeared for the Wave:3 during
the check.

This establishes an available microphone with actual capture signal on this
PC, rather than only successful device detection. Audible speech quality and
long-session stability were not assessed by that short numerical test. The
Q9U remains unresolved. The Wave:3 succeeding on the same controller and the
user reporting Q9U capture on another computer point toward a Q9U/PC
interaction; they do not establish a specific firmware or driver defect.

### Wave:3 booming sound resolved by the user

The user subsequently reported an echoey, booming sound without noise
reduction, then confirmed that adjusting the level directly on the microphone
fixed it. At diagnosis, ALSA's `Mic Capture Volume` was 80 of 80, corresponding
to its maximum reported 40 dB gain. A later read, during the user's request
for audio-quality advice, still reported 80/40 dB. The precise dial mode and
level changed by the user were not established, so the earlier assumption
that capture gain had been reduced is not confirmed. The Wave:3 dial can
control mic gain, headphone volume, or monitor mix.

No agent gain, routing, or effects changes were made during these checks.
For a recurrence, distinguish those controls and measure actual capture
levels before changing noise reduction, EQ, or audio services. The user
confirmed resolution of the reported sound issue; the Q9U USB failure remains
separate and unresolved.

Configuration references: [WirePlumber configuration locations](https://pipewire.pages.freedesktop.org/wireplumber/daemon/locations.html)
and [ALSA device rules](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html).

## 2026-11-08 voice cutouts under game load

This recurrence affected both Discord and Star Citizen. The Q9U remained
enumerated and capturing at 48 kHz; the previous USB enumeration failure
below is not established as the cause of this incident.

EasyEffects bypass improved speech according to the user, but cutouts
returned even with Discord linked directly to the Q9U. Physical capture and
client xrun counters increased across the session. PipeWire-Pulse also logged
repeated Star Citizen capture-buffer overruns. Playback ran at a 256-frame
quantum while Q9U capture was forced to 1024 frames.

`hosts/pc/default.nix` now configures a 2048-frame minimum processing quantum
and PulseAudio request/capture-buffer minima at 48 kHz, and overrides the
shared Q9U forced quantum to match. This favors timing margin over latency
(about 43 ms per processing block, not total end-to-end latency). The PC also
reapplies EasyEffects bypass after loading the saved preset at service start;
the preset itself is preserved. Other hosts retain their existing settings.

These are persistent mitigations, not a proven root-cause repair. A live
1024-frame trial still recorded one physical microphone xrun over roughly
45 seconds, although the monitored Discord and playback counters stayed
unchanged. The larger-buffer trial must be followed by a sustained spoken
call under game load. In its roughly 45-second sample, physical Q9U errors
increased from 271 to 272 and HDMI errors from 421 to 422; Discord capture
and playback counts stayed unchanged. Thus 2048-frame processing has not
eliminated hardware-node errors and must not be presented as a verified fix.
The kernel also logged an xHCI buffer overrun on controller `0000:54:00.0`
(the Q9U's controller) at 21:01:50. The slot/endpoint was not mapped to a
specific device, so this does not establish that the Q9U caused that warning.
The unused `enp72s0` adapter has repeated r8169 counter timeouts; a proposed
temporary link-down test was not performed because sudo required a password.
Its relation to the audio failures remains unproven.

Silence or short stable counter samples alone do not
prove that audible cutouts are fixed. Runtime `clock.force-quantum` changes
are tests; the declarative settings take effect after the user activates them
and the audio services reload or the user logs in again.

Buffer option semantics: [PipeWire Pulse protocol documentation](https://docs.pipewire.org/1.6/page_module_protocol_pulse.html).

## Earlier USB failure

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

## Full power-cycle procedure and outcome

This procedure was proposed after the earlier incident and tested on
2026-11-10. It did not restore capture on that recurrence. Keep it as a record
of the test rather than prescribing it again as the next untried fix:

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
