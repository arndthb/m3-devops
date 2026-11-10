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
  local output=''
  case "$1" in
    git) output=$(git --version 2>/dev/null) ;;
    podman) output=$(podman --version 2>/dev/null) ;;
    distrobox) output=$(distrobox --version 2>/dev/null) ;;
    kubectl) output=$(kubectl version --client 2>/dev/null) ;;
    go) output=$(go version 2>/dev/null) ;;
    terraform) output=$(terraform version 2>/dev/null) ;;
  esac
  if [[ "$output" =~ ([0-9]+[.][0-9]+([.][0-9]+)?) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else printf '%s' 'unknown'; fi
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
for tool in git podman distrobox kubectl go terraform; do
  version='-'
  if command -v "$tool" >/dev/null 2>&1; then
    version=$(version_of "$tool")
  fi
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '  %-12s %-12s %-13s \033[2m%s\033[0m\n' "$tool" "$version" '-' 'Not installed'
  elif [[ "$brew_list" == *$'\n'"$tool"$'\n'* || "$brew_list" == "$tool" || "$brew_list" == "$tool"$'\n'* || "$brew_list" == *$'\n'"$tool" ]]; then
    if ((brew_ok)); then
      if [[ "$brew_outdated" == *$'\n'"$tool"$'\n'* || "$brew_outdated" == "$tool" || "$brew_outdated" == "$tool"$'\n'* || "$brew_outdated" == *$'\n'"$tool" ]]; then
        printf '  %-12s %-12s %-13s \033[33m%s\033[0m\n' "$tool" "$version" 'Homebrew' 'Update available'
      else
        printf '  %-12s %-12s %-13s \033[32m%s\033[0m\n' "$tool" "$version" 'Homebrew' 'No update reported'
      fi
    else
      printf '  %-12s %-12s %-13s %s\n' "$tool" "$version" 'Homebrew' 'Unable to check'
    fi
  else
    source='Unmanaged'
    update='No package source found'
    executable=$(command -v "$tool")
    resolved=$(readlink -f "$executable" 2>/dev/null) || resolved="$executable"
    if command -v rpm >/dev/null 2>&1; then
      package=$(rpm -qf --qf '%{NAME}' "$resolved" 2>/dev/null) || package=''
      if [[ -z "$package" && "$resolved" != "$executable" ]]; then
        package=$(rpm -qf --qf '%{NAME}' "$executable" 2>/dev/null) || package=''
      fi
      if [[ -n "$package" ]]; then
        source='RPM / Bluefin'
        update='OS update channel'
        # A staged deployment is evidence of an OS update, not proof this tool changed.
        if [[ "$os_backend" != none ]]; then
          update='OS channel: see below'
        fi
      fi
    fi
    if [[ "$source" == Unmanaged ]]; then
      case "$executable:$resolved" in
        *'/home/linuxbrew/.linuxbrew/'*|*'/.linuxbrew/'*)
          source='Homebrew'; update='Check brew formula';;
        *'/run/host/'*|*'/usr/bin/'*|*'/usr/sbin/'*)
          source='System path'; update='See Bluefin status';;
      esac
    fi
    if [[ "$source" == Unmanaged ]]; then
      case "$executable:$resolved" in
        *'/usr/local/bin/'*|*'/usr/local/sbin/'*|*'/.local/bin/'*)
          source='Manual/local'; update='Check upstream';;
        "$HOME"/.local/share/mise/*|"$HOME"/.local/share/asdf/*)
          source='Version mgr'; update='Check manager';;
        /var/lib/flatpak/*|"$HOME"/.local/share/flatpak/*)
          source='Flatpak'; update='Check flatpak';;
        /usr/local/*|"$HOME"/.local/bin/*)
          source='Manual/local'; update='Check upstream';;
      esac
    fi
    printf '  %-12s %-12s %-13s %s\n' "$tool" "$version" "$source" "$update"
  fi
done
printf '\n  System path: installed in an OS directory; package ownership unknown.\n'
printf '  Bluefin status describes the OS image, not individual tool updates.\n'
printf '\n  BLUEFIN OS UPDATE CHANNEL (%s): %s\n' "$os_backend" "$os_update_state"
if [[ "$os_update_state" == 'Check completed; inspect output' || "$os_update_state" == 'Check failed or timed out' ]]; then
  printf '  %s\n' "$os_update_detail" | head -n 8
fi
printf '  This is an OS-wide check, not a per-tool update verdict.\n'
if [[ "$os_update_state" == 'Requires sudo authorization' ]]; then
  printf '  Check bootc options manually: bootc upgrade --help\n'
fi
printf '\n  Homebrew checks use local package metadata.\n'
printf '  Bluefin OS tools update together via the OS update channel.\n  Source detection does not prove an update is available.\n'
printf '  bootc status is read-only; no upgrade or deployment requested.\n'
