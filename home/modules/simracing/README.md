# Simracing: MOZA, Boxflat, Quest and BeamNG.drive

This module combines MOZA wheel configuration through Boxflat with wired Quest
streaming through WiVRn. The wheel and pedals connect to the PC; the headset
supplies the VR view and head tracking. BeamNG runs on the PC.

Home Manager manages Boxflat's settings flag and installs this guide. The NixOS
companion supplies Steam, the system Flatpak installation, udev permissions,
kernel modules, Android tools and WiVRn's user service. Both parts are needed
because Home Manager cannot install system udev rules or capability wrappers.
Use the normal Boxflat and WiVRn application menus for configuration and startup.

**Enable it in this repository**

The PC already imports and enables both parts. For reuse, import
`hosts/features/simracing` from your NixOS configuration and this directory
from your Home Manager configuration. Set this option in each:

```nix
luix.simracing.enable = true;
```

The companion expects the repository's pinned `inputs.nix-flatpak` in NixOS
`specialArgs`. Home Manager must be integrated through its NixOS module so it
receives `osConfig`. Use the host's normal graphics and audio configuration.
MOZA force feedback also needs a supporting kernel; this PC uses Linux 6.18.
Steam and the Flatpak runtime need their usual graphics driver support.

WiVRn's standard user service starts at login, and the dashboard attaches to the
running server. This applies the NixOS service's priority settings and server
flags. Native Quest USB networking is the default. The module names the Meta
CDC-NCM adapter `wivrn0`, gives it an automatic IPv6 link-local connection through
NetworkManager, and permits WiVRn traffic on that interface. This supports one
USB-networked Meta headset at a time, independently of the USB port or its MAC
address. The USB profile supplies no default route or DNS servers.

NetworkManager and IPv6 must already be enabled on the host. WiVRn publishes its
discovery service through Avahi; streaming ports remain limited to the USB
interface. To enable streaming on LAN interfaces too, set
`luix.simracing.vr.wireless = true` in NixOS. To manage USB networking yourself or
use only the ADB fallback, set `luix.simracing.vr.usbNetworking = false`.
Runtime settings remain writable in WiVRn.

`hosts/features/simracing/wivrn.nix` pins the official WiVRn 26.9 release and its matching Monado source.
Both repository inputs still provide 26.6.2, which cannot connect to the Quest
store's 26.9 client. The override retains the normal NixOS package integration;
remove it when the pinned nixpkgs package matches the headset release.

For wheel-only use, set `luix.simracing.vr.enable = false` in NixOS. This disables
the module's WiVRn and Android tools configuration while keeping Boxflat enabled.

**Boxflat and the wheel**

Open Boxflat from the application menu. Its system Flatpak
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

Update the Quest's system software before using native USB networking. Older
Horizon OS releases such as v69 and v74 predate this connection method. WiVRn
26.9 checks for Horizon OS 2.6 or later when the newer OS version property is
available, but its Quest 3 fallback can display the switch on older firmware.
The switch alone therefore does not establish support. Install the available
system update, restart, and check for further updates. The ADB method below
remains available for older headset firmware.
[WiVRn headset compatibility check](https://github.com/WiVRn/WiVRn/blob/v26.9/client/hmd_traits.cpp)

1. Quit WiVRn on the PC before rebuilding. After the rebuild, fully log out and
   back in so WiVRn runs the new server and Steam inherits the OpenXR environment
   variable. An already running server keeps its old version until restarted.
2. Install [WiVRn on the Quest](https://www.meta.com/experiences/7959676140827574/).
   Match the headset app to the PC's version; this module provides 26.9.
   WiVRn's About page shows the installed PC version.
3. Open **WiVRn Server** on the PC. In the setup wizard, use **Skip**, then
   **Finish** on the connection step. Its **Connect by USB** button belongs to
   the older ADB method and may remain grey with Developer Mode disabled.
   Confirm the server is running and pairing is enabled in the dashboard.
4. Connect the Quest with a USB data cable and open **WiVRn inside the headset**.
   Enable **Settings > USB networking** there. Developer Mode and the USB
   debugging approval are not needed for this method. The headset OS must
   support Meta's USB networking API; updating the WiVRn app alone does not
   update Horizon OS.
5. After the first rebuild, unplug and reconnect USB so the new interface naming
   rule applies. Keep WiVRn open on the headset. The PC should show an active
   **WiVRn Quest USB** network connection.
6. In the headset's WiVRn server list, select the PC's USB connection and enter
   the pairing PIN displayed by WiVRn on the PC. For the first wired test, turn
   off the headset's Wi-Fi to verify the connection uses the cable.
7. Wait for WiVRn to report a working connection before launching the game.

The desktop wizard's grey ADB button does not determine whether native USB
networking is ready. Native USB connection starts from the headset's server list.
[WiVRn 26.9 release](https://github.com/WiVRn/WiVRn/releases/tag/v26.9)
[USB networking requirements](https://github.com/WiVRn/WiVRn/blob/v26.9/client/scenes/gui_settings.cpp)

**ADB fallback**

For headsets without native USB networking, disable **USB networking** in the
headset's WiVRn settings, enable Developer Mode through the Meta Horizon phone
app, and authorize USB debugging in the headset. `adb devices -l` must report
`device`, not `unauthorized`. Then use the PC dashboard's **Connect (wired)**
button. The package supplies ADB and handles USB forwarding and app startup.
WiVRn also offers **Auto connect from USB** for this method.
[Meta device setup](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/)
[WiVRn USB interface](https://github.com/WiVRn/WiVRn/blob/v26.9/dashboard/qml/Main.qml)

**BeamNG.drive**

In Steam's BeamNG properties, leave forcing a Steam Play compatibility tool
disabled to use native Linux. That build uses Vulkan.
[BeamNG Linux setup](https://documentation.beamng.com/support/troubleshooting/steamdeck_linux/)

The NixOS module sets `PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1` for Steam.
After a fresh login, a custom launch option is unnecessary. If you already use
custom launch options, ensure they do not override the OpenXR runtime. WiVRn
manages the active runtime when a headset connects.
[Steam runtime integration](https://github.com/WiVRn/WiVRn/blob/v26.9/docs/steamvr.md)

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

Connect the wheel and Quest, open WiVRn Server on the PC, and open WiVRn on the
headset with **USB networking** enabled. Connect from the headset's server list,
then start BeamNG and center the VR view.

| Symptom | Check |
| --- | --- |
| Grey USB button or Developer Mode warning in the PC wizard | This is the ADB connection method. For native USB, use Skip > Finish, then connect from WiVRn inside the headset |
| No `wivrn0` interface | `ip -brief link`; keep WiVRn open on the Quest, toggle its USB networking setting, replug USB after rebuilding, and check Horizon OS support. `lsusb -t` should show `cdc_ncm` for the headset |
| USB adapter exists but no server appears | `nmcli device status` should show WiVRn Quest USB connected; `ip -6 address show wivrn0` should include a `fe80::` address. Check that the managed WiVRn service has restarted after rebuilding |
| ADB fallback reports unauthorized | Re-enable Developer Mode through the phone app and accept USB debugging in the headset; Linux cannot accept that approval on the headset's behalf |
| Version mismatch | Both sides must show 26.9 with this module; quit the old PC dashboard/server and log out and back in after rebuilding; [official releases](https://github.com/WiVRn/WiVRn/releases) |
| WiVRn does not start | `systemctl --user status wivrn` and `journalctl --user -u wivrn -n 60 --no-pager` |
| Headset waiting to pair | Open WiVRn Server on the PC and follow its pairing flow |
| BeamNG has no VR view | Connect WiVRn before starting BeamNG; check native Linux, fresh Steam login and the game's VR toggle |
| Boxflat has no wheel | Check the base's USB connection and power; verify that the base, not only the stalk, appears in `lsusb -d 346e:` |

If you deliberately stop the server, restart the managed instance with
`systemctl --user start wivrn` before reopening the dashboard. The dashboard can
also start a server directly, but that bypasses the NixOS service's priority
settings. Its **Troubleshoot > Open server logs** action covers dashboard-started
instances.

For a video demonstration, show the two module imports, Boxflat detecting the R3,
the headset's USB networking setting, the WiVRn Quest USB connection on the PC,
pairing from the headset, and a seated BeamNG drive with head tracking and a
wheel-button recenter. Describe the tested hardware and versions separately from
what the reusable module configures.
