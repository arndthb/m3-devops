#!/usr/bin/env bash
# m³ automatic installation preview — read-only, never installs software.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tool-detect.sh
source "$SCRIPT_DIR/lib/tool-detect.sh"
# shellcheck source=lib/tool-install.sh
source "$SCRIPT_DIR/lib/tool-install.sh"
green=$'\033[32m'
yellow=$'\033[33m'
dim=$'\033[2m'
reset=$'\033[0m'
mapfile -t tools < <(m3_tool_catalog)
missing=()
installed=0
printf '\033[H\033[2J'
printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   %-41.41s  \033[32m│\033[0m\n' 'Automatic Installation Preview'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
printf '  %sDRY RUN%s  ·  No software will be installed\n\n' "$yellow" "$reset"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf '  Platform  %s\n' "${PRETTY_NAME:-Linux}"
fi
if command -v brew >/dev/null 2>&1; then
  brew_available=1
  printf '  Packages  Homebrew available\n'
else
  brew_available=0
  printf '  Packages  Homebrew not detected\n'
fi
printf '\n  %-16s %-12s %s\n' 'TOOL' 'STATUS' 'ACTION'
printf '  %s\n' '──────────────────────────────────────────────────────'
for tool in "${tools[@]}"; do
  if m3_tool_present "$tool"; then
    installed=$((installed+1))
    printf '  %-16s %s%-12s%s  %s\n' "$(m3_tool_label "$tool")" "$green" '✓ Installed' "$reset" "$(m3_tool_source "$tool")"
  else
    missing+=("$tool")
    printf '  %-16s %s%-12s%s  %s\n' "$(m3_tool_label "$tool")" "$yellow" '○ Missing' "$reset" 'Review'
  fi
done
printf '\n  %sSUMMARY%s\n' "$green" "$reset"
printf '  %d installed  ·  %d missing  ·  %d total\n' "$installed" "${#missing[@]}" "${#tools[@]}"
if (( ${#missing[@]} > 0 )); then
  printf '\n  %sSUGGESTED NEXT STEPS (NOT EXECUTED)%s\n' "$green" "$reset"
  for tool in "${missing[@]}"; do
    printf '  %s\n' "$(m3_tool_label "$tool")"
    if (( brew_available )) && command="$(m3_install_command "$tool")"; then
      printf '    %s\n' "$command"
    else
      printf '    %s%s%s\n' "$dim" "$(m3_tool_hint "$tool")" "$reset"
    fi
  done
else
  printf '\n  %sAll checked tools are available.%s\n' "$green" "$reset"
fi
printf '\n  %sRead-only preview · No changes made%s\n' "$dim" "$reset"
