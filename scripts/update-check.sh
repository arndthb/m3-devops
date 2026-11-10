#!/usr/bin/env bash
# Read-only update status: only Homebrew-managed tools can be checked reliably.
set -u
printf '\033[H\033[2J'
printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   %-41.41s  \033[32m│\033[0m\n' 'DevOps Tool Manager / Update Check'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
printf '  Read-only · No updates will be installed.\n\n'
printf '  %-13s %-13s %s\n' 'TOOL' 'SOURCE' 'UPDATE STATUS'
printf '  %s\n' '────────────────────────────────────────────────────────'
brew_list=''
brew_outdated=''
brew_ok=0
if command -v brew >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  if brew_list=$(HOMEBREW_NO_AUTO_UPDATE=1 timeout 12s brew list --formula -1 2>/dev/null); then
    if brew_outdated=$(HOMEBREW_NO_AUTO_UPDATE=1 timeout 20s brew outdated --formula -q 2>/dev/null); then
      brew_ok=1
    fi
  fi
fi
for tool in git podman distrobox kubectl go terraform; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '  %-13s %-13s \033[2m%s\033[0m\n' "$tool" '-' 'Not installed'
  elif [[ "$brew_list" == *$'\n'"$tool"$'\n'* || "$brew_list" == "$tool" || "$brew_list" == "$tool"$'\n'* || "$brew_list" == *$'\n'"$tool" ]]; then
    if ((brew_ok)); then
      if [[ "$brew_outdated" == *$'\n'"$tool"$'\n'* || "$brew_outdated" == "$tool" || "$brew_outdated" == "$tool"$'\n'* || "$brew_outdated" == *$'\n'"$tool" ]]; then
        printf '  %-13s %-13s \033[33m%s\033[0m\n' "$tool" 'Homebrew' 'Update available'
      else
        printf '  %-13s %-13s \033[32m%s\033[0m\n' "$tool" 'Homebrew' 'No update reported'
      fi
    else
      printf '  %-13s %-13s %s\n' "$tool" 'Homebrew' 'Unable to check'
    fi
  else
    printf '  %-13s %-13s %s\n' "$tool" 'Other/unknown' 'Not checked'
  fi
done
printf '\n  Homebrew checks use local package metadata.\n'
printf '  Other installation sources need separate checks.\n'
printf '  No network access or package changes requested.\n'
