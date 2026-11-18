# Repository instructions

- Never run `nixos-rebuild`, including its `build`, `test`, `boot`, or `switch`
  actions.
- Never run `home-manager switch` or execute a Home Manager activation package
  directly, including an `activate` script from the Nix store.
- Agents may inspect, edit, and validate configuration without activation.
- Before suggesting any host-specific Nix command, read the live hostname from
  both `hostname` and `/proc/sys/kernel/hostname`; also check `/etc/hostname`
  when available. Never copy a host from an example, repository default, prior
  turn, or previously evaluated configuration.
- Verify that `nixosConfigurations.<hostname>.config.networking.hostName`
  evaluates to the same live hostname. A successful all-host flake check does
  not select an activation target. If identity cannot be verified, do not give
  or run an actionable activation command.
- Before a local activation handoff, also compare the target's configured `/`
  and `/boot` devices with the live mount UUIDs. Use the existing filesystem
  preflight logic as the source of truth and refuse any mismatch.
- After changes that require a rebuild, provide one exact normal NixOS flake
  command containing the verified host and ask the user to run it in their
  terminal. Do not offer alternative host targets or try another activation
  path.

## Graphify knowledge graph

- `graphify-out/graph.json` is a generated local code index and is ignored by
  Git. Use the Graphify MCP tools before broad cross-file, architecture, or
  change-impact exploration when the graph exists.
- Pass this repository's absolute root as `project_path`. Use the merged global
  graph only for intentional cross-project discovery.
- Verify graph results in the source before editing. Graphify 0.9.48 does not
  index Nix, so normal source inspection remains authoritative in this repo.
- After changing supported Lua, shell, or JSON source, refresh the graph with
  `graphify-project update .` before handoff. Do not treat a successful graph
  refresh as a substitute for Nix validation.

## Recurring Samson Q9U microphone failures

- On 2026-11-13, Wave:3 signal repeatedly stopped in EasyEffects/OBS and
  returned temporarily when mic listening was enabled. Processes had not
  crashed: EasyEffects removed its internal input links while OBS remained
  connected. Disabling `[EffectsPipelines] inactivityTimerEnable` in the
  writable `~/.config/easyeffects/db/easyeffectsrc` kept links active for a
  passive 40-second check, followed by five seconds of measured signal.
  This is an inactivity workaround, with audible/long-session confirmation
  pending; distinguish it from the Q9U USB failure. See the audio README.
  The shared audio module now reapplies the disabled inactivity timer before
  each managed EasyEffects start, preserving other writable application
  settings. The live setting is applied; the service change needs activation.

- Read `home/modules/audio/README.md` before troubleshooting the Q9U
  (`17a0:0243`). It records separate USB detection failures and audio cutouts
  under game load, including attempts that did not fix them.
- Check `/proc/asound/cards`, the current boot's kernel USB logs, service
  restart counters, and blocked process/thread wait channels first. Bound USB
  and PipeWire queries with a timeout: both `lsusb` and `wpctl` stalled during
  this incident. If the Q9U is absent from USB and ALSA, investigate USB
  detection before changing PipeWire, EasyEffects, or buffers.
- On 2026-11-10, unplugging the Q9U for 30 seconds and reconnecting the same
  cable to the same port briefly restored its USB identity, then failed again.
  A replacement cable on port `3-7` of the same controller also failed to
  restore capture. Do not repeat this cable/replug loop without new evidence.
- After several minutes the Q9U appeared in ALSA, then WirePlumber blocked in
  `usb_start_wait_urb` while probing it. The audio services had zero automatic
  restarts. Stopping WirePlumber required SIGKILL; direct 48 kHz ALSA capture
  with WirePlumber stopped still failed with a USB interface timeout. Killing
  the process did not fix the mic. A full mains-power cycle also failed:
  the next boot, running kernel `6.18.62`, repeated the USB audio-control
  timeouts on `3-7`. The user reports that the Q9U records on another computer.
  Investigate this PC's controller/driver path rather than repeating the
  same cable changes, power cycle, or audio-service restarts.
- Do not repeat the earlier USB reset or whole-controller unbind/rebind
  attempts as routine recovery. They blocked in the kernel and disrupted the
  Corsair cooling controller on the shared USB controller.
- Do not stop/restart WirePlumber while a Q9U probe is blocked without first
  preparing an exclusion for that failed device. Restarting it on 2026-11-10
  removed all usable audio devices and immediately blocked again. A temporary
  `device.disabled = true` rule matching only the Q9U restored the other
  devices and user-confirmed playback. This is containment, not a mic fix.
  See the audio README for the verified JSON rule and runtime-only paths.
- The OBSBOT Tiny 2 is not a verified backup: raw capture returned only zeros
  despite its capture switch being on and gain at maximum. Listing a source
  or seeing active links does not prove that a microphone works.
- The user's Elgato Wave:3 (`0fd9:0070`) delivered nonzero 48 kHz capture on
  2026-11-10 using the same `3-7` port/controller where the Q9U timed out.
  Prefer this available fallback over further disruptive resets. The short
  capture test established signal, not long-session reliability or a Q9U repair.
- The user fixed the Wave:3's echoey, booming sound by adjusting the level
  directly on the mic. ALSA reported maximum capture gain (40 dB) both before
  and in a later check; the exact dial mode/change was not established.
  Distinguish mic gain from headphone volume and monitor mix, and verify
  recorded levels before retuning noise reduction or EQ.
- Record a successful recovery here and the detailed evidence in the audio
  README. Require stable USB and ALSA detection, the intended application
  receiving the Q9U stream, and an audible speech check before claiming success.
  Distinguish a recovery workaround from a proven repair of the recurring cause.
