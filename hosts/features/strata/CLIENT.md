# OpenCode on MiniLab

For the separate PC launcher with browser control and ZAP, see
[Local Qwen browser and ZAP tools](PENTEST.md).

`opencode-local` is installed in the `luix` user profile on `192.168.18.13`.
It runs OpenCode 1.15.7 on the mini PC and sends inference requests to Strata
on the main PC at `http://192.168.18.10:8080/v1`.

```sh
ssh luix@192.168.18.13
cd ~/local-agent-workspace
opencode-local
```

Run it from a development repository to work on that repository, or pass its
path: `opencode-local /path/to/project`. For a single terminal task, use
`opencode-local run "your task"`. `opencode-local --status` prints the endpoint,
active model, and context size. The main PC must be running and reachable.

The launcher reads `/v1/models` at startup and selects the currently active
normal or abliterated Qwen profile. It waits if Strata temporarily reports zero
context while loading. After switching profiles on the main PC, restart the
client. Changing the model picker does not start a different PC service.

Both the main and small/background model use Strata. The provider allowlist
contains only `strata`; there is no cloud fallback. Medium reasoning effort,
the server's advertised context, and an 8192-token output allowance (or one
quarter of the context when smaller) are configured. `STRATA_BASE_URL` can
override the endpoint for another installation.

OpenCode's configuration, data, cache, and state are isolated beneath
`~/.local/share/opencode-local/`. External plugins and default provider plugins
are disabled; session sharing is disabled. Repository instructions remain
enabled. The existing `opencode` command and its cloud configuration were not
modified. No Greenhouse integration, MCP server, queue, or background service
was added. This is an interactive/task-driven client, not an unattended loop.

The package includes Git, ripgrep, and Python in its command environment.
Project-specific compilers and SDKs still belong to each project's development
environment. Documentation fetching and other agent tools run on the mini PC.

## Validation

On 3 November 2026, the installed client connected to the activated Strata
service using normal Qwen. In a disposable project it completed two file reads,
edited a subtraction bug into addition, and executed `python3 -m unittest -v`.
All three tests passed, including an independent rerun. The resolved client
configuration contained only the Strata provider, no MCP servers, and no
external plugins. Its application paths were verified to use the separate
directory above. No Flyff source or live service was changed.

The example project remains under
`~/local-agent-workspace/connection-test-f3k19kb5` on the mini PC.

## Package sources and removal

The reusable sources are `client-package.nix` and `client.py` beside this guide.
This flake exports the `opencode-local` package. Copies of the source are also
saved on MiniLab under
`~/server_configuration/modules/agents/opencode-local/`, with a package build
link at `~/server_configuration/result-opencode-local`. Installation used the
existing legacy Nix user profile and did not require a NixOS rebuild.

To remove the installed client on MiniLab:

```sh
nix-env -e opencode-local
```

That leaves session history intact. Remove the application-state directory
separately only if you want to erase it. Remove the package build link and
unwanted old user-profile generations before garbage collection if you also
want to reclaim the runtime. The existing cloud `opencode` command is separate.

Reference: [OpenCode custom providers](https://opencode.ai/docs/providers/#custom-provider),
[configuration precedence](https://opencode.ai/docs/config/#precedence-order),
and [CLI usage](https://opencode.ai/docs/cli/).
