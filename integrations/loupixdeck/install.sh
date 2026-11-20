#!/usr/bin/env bash
set -Eeuo pipefail
root="$(cd -- "$(dirname -- "$0")" && pwd)"
target="$HOME/.local/bin/m3-deck"
source="$root/scripts/m3-deck.sh"
mkdir -p -- "$HOME/.local/bin"
if [[ -e "$target" || -L "$target" ]]; then
  if [[ "$(readlink -f -- "$target")" != "$(readlink -f -- "$source")" ]]; then
    printf 'Refusing to overwrite existing %s\n' "$target" >&2; exit 1
  fi
fi
ln -sfn -- "$source" "$target"
config_dir="$HOME/.config/m3-devops"
config_file="$config_dir/services.json"
mkdir -p -- "$config_dir"
if [[ ! -e "$config_file" ]]; then
  cp -- "$root/services.example.json" "$config_file"
  printf 'Created optional URL configuration: %s\n' "$config_file"
fi
printf 'Installed: %s -> %s\n' "$target" "$source"