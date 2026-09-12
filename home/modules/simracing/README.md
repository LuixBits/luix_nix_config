# Simracing: MOZA, Boxflat, Quest and BeamNG.drive

This module combines MOZA wheel configuration through Boxflat with wired Quest
streaming through WiVRn. The wheel and pedals connect to the PC; the headset
supplies the VR view and head tracking. BeamNG runs on the PC.

Home Manager manages the user environment, Boxflat's settings flag, the `boxflat`
command and the `simracing-quest` launcher. The NixOS companion supplies Steam,
the system Flatpak installation, udev permissions, kernel modules and WiVRn's
user service. Both parts are needed because Home Manager cannot install system
udev rules or capability wrappers.

**Enable it in this repository**

The PC already imports and enables both parts. For reuse, import `nixos.nix`
from your NixOS configuration and this directory from your Home Manager
configuration. Set this option in each:

```nix
luix.simracing.enable = true;
```

The companion expects the repository's pinned `inputs.nix-flatpak` in NixOS
`specialArgs`. Home Manager must be integrated through its NixOS module so it
receives `osConfig`. Use the host's normal graphics and audio configuration.
MOZA force feedback also needs a supporting kernel; this PC uses Linux 6.18.
Steam and the Flatpak runtime need their usual graphics driver support.

WiVRn starts on demand. Activation does not connect USB devices, pair a headset,
start a VR game or wait for hardware. Wired streaming is the default. To enable
LAN streaming later, set `luix.simracing.vr.wireless = true` in NixOS.

For wheel-only use, set `luix.simracing.vr.enable = false` in NixOS; the Home
Manager default follows it. To choose among multiple USB Quests, set
`luix.simracing.quest.serial = "YOUR_QUEST_SERIAL"` in Home Manager or pass
`--serial` to the launcher.

**Boxflat and the wheel**

Open Boxflat from the application menu or run `boxflat`. Its system Flatpak
installation is retained. Existing presets and calibration stay writable under
`~/.var/app/io.github.lawstorant.boxflat/`.

The early `70-boxflat.rules` grants the active local session access to MOZA
serial devices and uinput. A `99-boxflat.rules` alias satisfies Boxflat's filename
check. Home Manager merges only `rules-version: 2` into the existing settings
file, preserving other settings and any newer rules version. This addresses
Boxflat's repeated request to install rules into NixOS's read-only configuration.
The compatibility check was reviewed against installed Boxflat v1.36.2.
[Upstream Boxflat rules](https://github.com/Lawstorant/boxflat/blob/main/udev/99-boxflat.rules)

For the current road-driving setup, use 1080 degrees in Boxflat and BeamNG, with
steering linearity 1. Calibrate the pedals in Boxflat and check BeamNG's input
bindings. These are physical setup steps, not values forcibly rewritten at login.

**First Quest connection after rebuilding**

1. Fully log out and back in so Steam inherits the OpenXR environment variable.
2. Install [WiVRn on the Quest](https://www.meta.com/experiences/7959676140827574/).
   Match the headset app to the PC's version; the current flake provides 26.6.2.
   `simracing-quest --list` also prints the PC version.
3. Enable Developer Mode for the Quest in the Meta Horizon phone app. If it is
   unavailable, complete Meta's developer account/team setup first. Connect a
   USB data cable and accept the USB debugging prompt inside the headset.
   [Meta device setup](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/)
4. Open **WiVRn Server** from the application menu and complete its setup wizard.
5. Run `simracing-quest`, or open **Simracing — Connect Quest USB** from the menu.
6. Complete any pairing prompt in WiVRn. Wait for the headset to report a working
   connection before launching the game.

The launcher identifies an authorized USB Meta/Oculus Quest, checks the installed
WiVRn app version, starts the NixOS WiVRn user service, forwards USB TCP port 9757
and opens the headset app using `wivrn+tcp://localhost`. It supports both the Meta
store and matching stable GitHub APK. Every device-specific command includes the
selected serial, so a tethered phone is not selected for streaming. Commands have
timeouts and the launcher refuses ambiguous headset selection.
[WiVRn USB setup](https://github.com/WiVRn/WiVRn/blob/v26.6.2/README.md#troubleshooting)

**BeamNG.drive**

In Steam's BeamNG properties, leave forcing a Steam Play compatibility tool
disabled to use native Linux. That build uses Vulkan.
[BeamNG Linux setup](https://documentation.beamng.com/support/troubleshooting/steamdeck_linux/)

The NixOS module sets `PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1` for Steam.
After a fresh login, a custom launch option is unnecessary. If you already use
custom launch options, ensure they do not override the OpenXR runtime. WiVRn
manages the active runtime when a headset connects.
[Steam runtime integration](https://github.com/WiVRn/WiVRn/blob/v26.6.2/docs/steamvr.md)

Load one vehicle, select the Driver camera, and enable Options > Display > VR >
Toggle ON. Sit normally and center the view through that menu or Ctrl + Numpad 5.
Bind VR centering to a convenient wheel button. Hide VR controllers if they
obstruct the view. Select the WiVRn output in desktop audio settings.
[BeamNG VR setup](https://documentation.beamng.com/support/vr/)

Suggested first test: 72 Hz if offered, WiVRn's default resolution and encoder,
Normal graphics, one vehicle, no AI traffic and dynamic reflections off. Increase
quality after checking smooth head movement. Free GPU memory used by an Ollama
model before testing; this PC runs inference on the same Radeon. BeamNG VR is
experimental and a successful Nix evaluation does not establish headset latency
or in-game performance.

**Daily use and troubleshooting**

Connect the wheel and Quest, run `simracing-quest`, confirm the connection inside
the headset, then start BeamNG and center the VR view. Rerun the launcher after
reconnecting USB. It re-establishes the selected headset's forwarding rule.

| Symptom | Check |
| --- | --- |
| Quest missing or unauthorized | `simracing-quest --list`; data cable, Developer Mode, USB debugging prompt |
| Several Quests connected | `simracing-quest --serial YOUR_QUEST_SERIAL` |
| Version mismatch | Match the headset app to the version printed by the launcher; [official releases](https://github.com/WiVRn/WiVRn/releases) |
| WiVRn does not start | `systemctl --user status wivrn` and `journalctl --user -u wivrn -n 60 --no-pager` |
| Headset waiting to pair | Open WiVRn Server on the PC and follow its pairing flow |
| BeamNG has no VR view | Connect WiVRn before starting BeamNG; check native Linux, fresh Steam login and the game's VR toggle |
| Boxflat has no wheel | Check the base's USB connection and power; verify that the base, not only the stalk, appears in `lsusb -d 346e:` |

The launcher reports that a USB connection was requested; successful pairing and
headset rendering must be confirmed inside WiVRn. It does not claim to have tested
the headset merely because ADB accepted a command.

For a video demonstration, show the two module imports, the one-time USB
authorization, Boxflat detecting the R3, the Quest launcher, and finally a seated
BeamNG drive with head tracking and a wheel-button recenter. Describe the tested
hardware and versions separately from what the reusable module configures.
