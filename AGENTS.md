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
