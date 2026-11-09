# Local Qwen comparison with Strata

This module installs Strata 0.2.10, its HIP engine 0.1.56 for AMD gfx1100/1101/1102,
and two Qwen3.8-Flash-Next variants at the same IQ3_XXS precision. Strata is the
inference runtime; the normal and abliterated Qwen checkpoints are the models.
An abliterated checkpoint changes refusal behavior. That does not establish
better coding or security-review accuracy.

The PC configuration imports this module and enables both variants. It replaces
the old Ollama service; existing Ollama data is retained. The default profile is
`normal`. The PC configuration requests a 64K context for Hermes compatibility
(the initial validated deployment used 32K). Both use int8 KV cache, 15 CPU workers on this PC, 3 GiB
of VRAM reserve, and at least 8 GiB of RAM headroom when sizing the resident
expert cache. A systemd limit caps each service at 50 GiB of RAM. Adjust context
and reserves if the desktop is busy. Only one profile runs at a time.

The API starts without loading the GPU. The first inference loads the model;
15 idle minutes unload it again. Drafting, vision, and server-side MCP execution
are disabled for the initial comparison. These settings are not intended to
reproduce upstream speculative-decoding speed benchmarks.

## Install and remove

The reusable entry point is `default.nix`, also exported as `nixosModules.strata`.
Import it and set `services.strata.enable = true`. Options include `models`,
`defaultModel`, `gpuDevice`, `contextSize`, `cpuWorkers`, `vramReserveMiB`,
`idleUnloadSeconds`, `host`, `port`, `lanInterface`, and `allowedClients`.
Defaults bind to localhost. This package currently targets x86_64 Linux with an
RX 7900-class GPU; it is not an automatic package selector for other GPUs.

In this repository, the machine settings are in `hosts/pc/default.nix`. Set
`services.strata.enable = false` there to remove the services, installed commands,
generated profiles, and module firewall rules on your next normal rebuild.
Repository policy requires you to run activation yourself after host/filesystem
verification. Builds and evaluations do not activate the system.

The two weight shards plus their shared lookup shard total 123.18 GB (decimal),
plus small derived packs and runtime dependencies. Downloads are pinned by
Hugging Face revision and SHA256 in `models.nix`. Each variant gets its own
native pack; reusing the normal pack with abliterated weights is incorrect.
No second copy of the expert matrices is made. Build/download interruption
may require a fresh download of the interrupted shard.

Disabling the module does not immediately erase model data. Nix retains models
while old system generations or other GC roots reference them. Remove unwanted
old generations and use normal Nix garbage collection when you want that space
back. Logs/state under `/var/lib/strata` and previous Ollama data also remain
until you deliberately remove them.

The initial build keeps a GC root at `hosts/features/strata/result` so the large
downloads survive garbage collection before activation. Remove that symlink
after activating, or when uninstalling, so it no longer retains the models.
The flake's `strata-models` package can also prebuild both model packs.

## Use after activation

The PC endpoint is `http://127.0.0.1:8080/v1`. MiniLab can use
`http://192.168.18.10:8080/v1`; the firewall admits `192.168.18.13/32` through
`enp75s0`. A service network filter also restricts access to localhost and that
client. The trusted LAN API has no key. Keep these rules narrow; changing a
client address requires updating the configuration. The PC address must remain
stable in your router/DHCP configuration.

```sh
curl http://127.0.0.1:8080/v1/models
sudo systemctl start strata-abliterated
curl http://127.0.0.1:8080/v1/models
sudo systemctl start strata-normal
journalctl -u strata-normal -f
```

Starting either profile stops the other before acquiring the GPU/port. Model
switching interrupts active requests, so switch between tasks. The configured
`defaultModel` starts on reboot; switching services does not rewrite that option.
Engine details are in `/var/lib/strata/<variant>/engine.log`.

Configure an OpenAI-compatible agent client with the base URL above and the
model ID from `/v1/models`: `qwen3.8-flash-next-normal` or
`qwen3.8-flash-next-abliterated`. A client that requires an API-key field can use
`local`; the service does not validate it. Repository search, edits, terminal,
tests, database access, and web search belong to that agent client. This module
does not start an unattended coding loop or connect a tool runner to Flyff.

MiniLab now has a separate, tested [OpenCode launcher](CLIENT.md) named
`opencode-local`. It connects to the active Strata model without Greenhouse.

## Compare

The [initial local comparison](results/2026-11-03/README.md) passed all three
checks for both variants; it does not establish a broader quality winner.

After activation, run each profile against the same suite:

```sh
sudo systemctl start strata-normal
strata-compare --label normal --output ./strata-comparison
sudo systemctl start strata-abliterated
strata-compare --label abliterated --output ./strata-comparison
sudo systemctl start strata-normal
```

The runner checks the advertised model ID to prevent mislabeled runs. It saves
the complete requests, answers, compiler diagnostics, and test results, and
refuses to overwrite an existing report. Both use temperature 0, seed 42,
4096 output tokens, and thinking disabled. Requests include two C++17 tasks:
length-prefixed packet parsing and overflow-safe currency transfers. Generated
code compiles with undefined-behavior sanitization and runs inside Bubblewrap
with no network, home directory, credentials, or game-server files. A third
check verifies a structured `read_file` tool call; it never executes that call.
Elapsed request times include any cold model load and queue time; they are not
steady-state generation-speed measurements.

These are small functional smoke tests, not a general ranking or a penetration
test. Use identical, isolated Flyff development worktrees and the project's
actual build/integration tests for a meaningful larger comparison. The live
server at `/home/luix/homelab-agents/FlyffServer` is outside this suite.

## Sources

- [Strata release](https://github.com/Niko1221/Strata/releases/tag/v0.2.10)
- [AMD HIP documentation](https://github.com/Niko1221/Strata/blob/v0.2.10/docs/AMD_HIP.md)
- [Normal checkpoint](https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF)
- [Abliterated checkpoint](https://huggingface.co/SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF)
- [Abliterated pack requirements](https://huggingface.co/SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF/blob/main/strata/README.md)
