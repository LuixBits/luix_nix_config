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
