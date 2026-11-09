# Luix server cooling and lighting

Updated 2026-11-07. MSI Z490 PLUS, BIOS 1.30, NCT6687D. Air cooler, two top Chromax and two Thermaltake fans; models/channel mapping unconfirmed.

## Active fan settings

All five motherboard channels are controlled at boot. GPU/PSU fans are outside this controller.

| Channel | Minimum PWM | Approximate idle RPM |
| --- | ---: | ---: |
| 1 | 0% | 600 |
| 2 | 0% | 510 |
| 3 | 22% | 330 |
| 4 | 0% | 525 |
| 6 | 22% | 330 |

All remain spinning. Channels 1/2/4 keep turning at 0% PWM; 3/6 stopped at 20%, so use 22%.

- CPU demand: 35°C→0%, 45→35%, 50→55%, 60→85%, 65→100%.
- Board demand: 40°C→0%, 45→50%, 55→100%.
- Interpolate; use higher demand and each channel's minimum. Poll 1 s; increase immediately, reduce gradually after 30 cooler seconds.
- Sensor/control failure or low RPM restores firmware control. A tested 10-second kernel watchdog also handles a stalled controller.

## Checks and limits

- Idle CPU ~30°C; ten automated checks passed.
- Two-worker/30-second CPU test: peak 64°C, fans reached 97% duty. Earlier eight-worker test stopped at its 78°C guard after six seconds.
- Sustained CPU/GPU cooling unvalidated; GPU temperature unavailable under Nouveau. Check GPU/HDD temperatures under real workloads.
- `btop`: load. `sensors`: temperatures/RPM; its PWM percentages are mis-scaled.

Status: `systemctl status luix-fan-control`. Firmware fallback: `sudo systemctl stop luix-fan-control` on the server.

Source: [controller](../../hosts/nixos-server/fan-control.py), [service](../../hosts/nixos-server/cooling.nix), [driver](../../hosts/nixos-server/nct6687d.nix). Previous settings: `/var/backups/luix-server-fans.Evfa76/`.

## GPU lighting: waiting for cable

- Luix reports the lighting cable is disconnected. Cable type and exact GPU model remain unconfirmed; “auto mode” is unverified.
- OpenRGB detected only motherboard lighting. GPU LEDs unchanged; no persistent OpenRGB service.
- When Luix finds the cable: identify connector/model, check the [Palit ARGB SYNC guide](https://www.palit.com/argbsync.php?lang=en&ver=argbsync), then retry motherboard lighting control. A missing sync cable would prevent motherboard sync; it does not establish why direct GPU detection failed.
