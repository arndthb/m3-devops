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
printf 'Installed: %s -> %s\n' "$target" "$source"