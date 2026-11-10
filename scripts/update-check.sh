#!/usr/bin/env bash
# Read-only update inventory for every tool in the shared m³ catalog.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/tool-detect.sh"
printf '\033[H\033[2J'
printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   %-41.41s  \033[32m│\033[0m\n' 'DevOps Tool Manager / Update Check'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
printf '  Read-only · No updates will be installed.\n\n'

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
version_of() {
  local tool="$1" output=''
  case "$tool" in
    git|podman|distrobox|kind|terraform|docker|make|curl|helm|k9s) output=$("$tool" --version 2>/dev/null | head -n 1) ;;
    kubectl) output=$(kubectl version --client 2>/dev/null | head -n 1) ;;
    go) output=$(go version 2>/dev/null) ;;
    compose)
      if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then output=$(docker compose version 2>/dev/null)
      elif command -v docker-compose >/dev/null 2>&1; then output=$(docker-compose --version 2>/dev/null)
      elif command -v podman-compose >/dev/null 2>&1; then output=$(podman-compose --version 2>/dev/null); fi ;;
    codium)
      if command -v codium >/dev/null 2>&1; then output=$(codium --version 2>/dev/null | head -n 1)
      elif command -v flatpak >/dev/null 2>&1; then output=$(flatpak info --show-version com.vscodium.codium 2>/dev/null); fi ;;
    hermes)
      if command -v hermes >/dev/null 2>&1; then output=$(hermes --version 2>/dev/null | head -n 1)
      elif command -v hermes-agent >/dev/null 2>&1; then output=$(hermes-agent --version 2>/dev/null | head -n 1); fi ;;
  esac
  if [[ "$output" =~ ([0-9]+[.][0-9]+([.][0-9]+)?) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else printf '-'; fi
}
# Read-only OS image update check; bootc preferred on Bluefin.
os_update_state='Not checked'
os_update_detail=''
os_backend='none'
if command -v timeout >/dev/null 2>&1; then
  if command -v bootc >/dev/null 2>&1; then
    os_backend='bootc'
    printf '\n  Reading Bluefin bootc deployment status (no upgrade check)...\n'
    bootc_status=''
    if bootc_status=$(timeout 12s bootc status 2>/dev/null) || bootc_status=$(timeout 12s sudo -n bootc status 2>/dev/null); then
      if [[ "$bootc_status" == *'Staged image:'* ]] || [[ "$bootc_status" == *'staged:'* ]]; then
        os_update_state='Update staged - reboot pending'
      else
        os_update_state='Deployment readable; availability not checked'
      fi
    else
      os_update_state='Deployment status unavailable'
    fi
    os_update_detail='bootc upgrade is intentionally not invoked; check-only support is unverified.'
  elif command -v rpm-ostree >/dev/null 2>&1; then
    os_backend='rpm-ostree'
    printf '\n  Checking rpm-ostree update channel (up to 45 seconds)...\n'
    if os_update_detail=$(timeout 45s rpm-ostree upgrade --check 2>&1); then
      case "${os_update_detail,,}" in
        *'no upgrade available'*|*'no updates available'*) os_update_state='No OS update reported';;
        *'availableupdate'*|*'available update'*|*'update available'*|*'diff:'*) os_update_state='OS update available';;
        *) os_update_state='Check completed; inspect output';;
      esac
    else
      os_update_state='Check failed or timed out'
    fi
  fi
fi
printf '\n  %-12s %-12s %-13s %s\n' 'TOOL' 'VERSION' 'SOURCE' 'UPDATE STATUS'
printf '  %s\n' '────────────────────────────────────────────────────────'
mapfile -t inventory < <(m3_tool_catalog)
for tool in "${inventory[@]}"; do
  version='-'
  if ! m3_tool_present "$tool"; then
    printf '  %-12s %-12s %-17s %s\n' "$(m3_tool_label "$tool")" '-' '-' 'Not installed'
    continue
  fi
  version=$(version_of "$tool")
  source='Manual / other'
  update='Check upstream'
  if [[ "$tool" == codium ]] && command -v flatpak >/dev/null 2>&1 && flatpak info com.vscodium.codium >/dev/null 2>&1; then
    source='Flatpak'; update='flatpak remote-ls --updates'
  elif [[ "$tool" == compose ]] && command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    source='Docker plugin'; update='Check package owner'
  elif command -v "$tool" >/dev/null 2>&1; then
    executable=$(command -v "$tool")
    resolved=$(readlink -f "$executable" 2>/dev/null) || resolved="$executable"
    package=''
    if command -v rpm >/dev/null 2>&1; then
      package=$(rpm -qf --qf '%{NAME}' "$resolved" 2>/dev/null) || package=''
    fi
    if [[ -n "$package" ]]; then
      if command -v rpm-ostree >/dev/null 2>&1 || command -v bootc >/dev/null 2>&1; then
        source='RPM / image'; update='OS image channel'
      else
        source='RPM / DNF'; update='Check with dnf check-update'
      fi
    elif [[ "$executable" == *'/.linuxbrew/'* || "$resolved" == *'/.linuxbrew/'* ]]; then
      source='Homebrew'; update='Check brew outdated'
    elif [[ "$executable" == /usr/local/* || "$executable" == "$HOME"/.local/* ]]; then
      source='Manual / local'; update='Check upstream'
    fi
  fi
  printf '  %-12s %-12s %-17s %s\n' "$(m3_tool_label "$tool")" "$version" "$source" "$update"
done

printf '\n  Inventory: %d tools from the m³ Tool Manager.\n' "${#inventory[@]}"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf '  Host: %s\n' "${PRETTY_NAME:-Linux}"
fi
if [[ "$os_backend" != none ]]; then
  printf '  OS image status (%s): %s\n' "$os_backend" "$os_update_state"
else
  printf '  RPM tools on regular Fedora: use sudo dnf check-update to check available updates.\n'
fi
printf '  Read-only inventory; no packages were changed.\n'
