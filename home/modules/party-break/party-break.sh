#!/usr/bin/env bash
set -euo pipefail

script_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
if (( $# > 0 )); then
  exec python3 "$script_dir/party-break.py" "$@"
fi

# Use a self-contained Python environment so imports still work after sudo.
# %q safely quotes the script path for nix-shell's Bash command.
# Python must be resolved inside the temporary Nix shell.
# shellcheck disable=SC2016
printf -v run 'exec sudo -- "$(command -v python3)" -u %q' \
  "$script_dir/party-break.py"
exec nix-shell -p 'python3.withPackages (ps: [ ps.evdev ])' --run "$run"
