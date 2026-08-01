# Agent instructions

- Never run `nixos-rebuild`, including its `build`, `test`, `boot`, or `switch` actions.
- Never run `home-manager switch` or directly activate a NixOS/Home Manager generation.
- Agents may inspect, edit, and validate configuration without activation. After making changes that require a rebuild, provide the exact command and ask the user to run it.
