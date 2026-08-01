# Repository instructions

- Never execute a Home Manager activation package directly, including an
  `activate` script from the Nix store or `home-manager switch`.
- Apply Home Manager changes only through the normal NixOS flake rebuild for
  the target host, such as `sudo nixos-rebuild switch --flake .#l`.
- If a rebuild requires interactive `sudo`, give the command to the user to
  run in their terminal; do not try an alternative activation path.
