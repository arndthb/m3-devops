#!/usr/bin/env bash
# m³ automatic installation preview — read-only, never installs software.
set -u
green=$'\033[32m'
yellow=$'\033[33m'
dim=$'\033[2m'
reset=$'\033[0m'
tools=(git podman distrobox kubectl go terraform)
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
  if command -v "$tool" >/dev/null 2>&1; then
    installed=$((installed+1))
    printf '  %-16s %s%-12s%s %s\n' "$tool" "$green"'✓ Installed'"$reset" 'None'
  else
    missing+=("$tool")
    printf '  %-16s %s%-12s%s %s\n' "$tool" "$yellow"'○ Missing'"$reset" 'Review'
  fi
done
printf '\n  %sSUMMARY%s\n' "$green" "$reset"
printf '  %d installed  ·  %d missing  ·  %d total\n' "$installed" "${#missing[@]}" "${#tools[@]}"
if (( ${#missing[@]} > 0 )); then
  printf '\n  %sSUGGESTED NEXT STEPS (NOT EXECUTED)%s\n' "$green" "$reset"
  for tool in "${missing[@]}"; do
    printf '  %s\n' "$tool"
    case "$tool" in
      podman|distrobox)
        printf '    %sBluefin-integrated tool: review OS documentation%s\n' "$dim" "$reset" ;;
      terraform)
        if (( brew_available )); then
          printf '    brew tap hashicorp/tap\n'
          printf '    brew install hashicorp/tap/terraform\n'
        else
          printf '    %sReview Bluefin-compatible installation method%s\n' "$dim" "$reset"
        fi ;;
      *)
        if (( brew_available )); then
          printf '    brew install %s\n' "$tool"
        else
          printf '    %sReview Bluefin-compatible installation method%s\n' "$dim" "$reset"
        fi ;;
    esac
  done
else
  printf '\n  %sAll checked tools are available.%s\n' "$green" "$reset"
fi
printf '\n  %sRead-only preview · No changes made%s\n' "$dim" "$reset"
