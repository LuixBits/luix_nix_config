#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sync-easyeffects-preset.sh <preset-name> [input|output] [source-file]

Examples:
  sync-easyeffects-preset.sh luix-voice input
  sync-easyeffects-preset.sh luix-voice input ~/.config/easyeffects/input/luix-voice.json
EOF
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

preset_name="${1:-}"
preset_kind="${2:-input}"
source_file="${3:-}"

if [[ -z "$preset_name" ]]; then
  usage
  exit 1
fi

if [[ "$preset_kind" != "input" && "$preset_kind" != "output" ]]; then
  die "preset kind must be 'input' or 'output', got '$preset_kind'"
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_file="${script_dir}/presets/${preset_name}.json"

if [[ -z "$source_file" ]]; then
  xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  candidates=(
    "${xdg_data_home}/easyeffects/${preset_kind}/${preset_name}.json"
    "${xdg_config_home}/easyeffects/${preset_kind}/${preset_name}.json"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -e "$candidate" ]]; then
      source_file="$candidate"
      break
    fi
  done
fi

if [[ -z "$source_file" ]]; then
  die "could not find ${preset_kind} preset '${preset_name}' in easyeffects data/config paths. Pass source-file explicitly."
fi

if [[ ! -e "$source_file" ]]; then
  die "source file does not exist: $source_file"
fi

resolved_source="$(readlink -f -- "$source_file")"
if [[ "$resolved_source" == /nix/store/* ]]; then
  printf 'warning: source resolves to Nix store path: %s\n' "$resolved_source" >&2
  printf 'warning: this is usually an immutable Home Manager-generated preset.\n' >&2
fi

tmp_file="$(mktemp)"
trap 'rm -f -- "$tmp_file"' EXIT
cp --dereference -- "$source_file" "$tmp_file"

PRESET_FILE="$tmp_file" PRESET_KIND="$preset_kind" nix eval --impure --raw --expr '
  let
    p = builtins.getEnv "PRESET_FILE";
    kind = builtins.getEnv "PRESET_KIND";
    value = builtins.fromJSON (builtins.readFile p);
  in
    if !builtins.isAttrs value then
      builtins.throw "Preset must be a JSON object."
    else if !(builtins.hasAttr kind value) then
      builtins.throw "Missing top-level key: ${kind}"
    else
      "ok"
' >/dev/null

mkdir -p -- "$(dirname -- "$target_file")"
mv -- "$tmp_file" "$target_file"
trap - EXIT

printf 'Synced %s preset "%s"\n' "$preset_kind" "$preset_name"
printf '  from: %s\n' "$source_file"
printf '    to: %s\n' "$target_file"
