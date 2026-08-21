# Repository instructions

- Never run `nixos-rebuild`, including its `build`, `test`, `boot`, or `switch`
  actions.
- Never run `home-manager switch` or execute a Home Manager activation package
  directly, including an `activate` script from the Nix store.
- Agents may inspect, edit, and validate configuration without activation.
- After changes that require a rebuild, provide the exact normal NixOS flake
  command for the target host, such as `sudo nixos-rebuild switch --flake .#l`,
  and ask the user to run it in their terminal. Do not try an alternative
  activation path.

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
