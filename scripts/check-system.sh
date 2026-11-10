#!/usr/bin/env bash
# m³ system diagnostics — read-only, no elevated privileges.
set -u

GREEN=$'\033[32m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'
printf '\033[H\033[2J'
printf '%s\n' "${GREEN}  ╭──────────────────────────────────────────────╮${RESET}"
printf '%s\n' "${GREEN}  │${RESET}                                              ${GREEN}│${RESET}"
printf '%s\n' "${GREEN}  │${RESET}   ${BOLD}${GREEN}m³${RESET}   ${BOLD}DEVOPS WORKSTATION${RESET}                    ${GREEN}│${RESET}"
printf '%s\n' "${GREEN}  │${RESET}   ${DIM}System diagnostics${RESET}                         ${GREEN}│${RESET}"
printf '%s\n' "${GREEN}  │${RESET}                                              ${GREEN}│${RESET}"
printf '%s\n\n' "${GREEN}  ╰──────────────────────────────────────────────╯${RESET}"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  distro="${PRETTY_NAME:-unknown}"
else
  distro='unknown'
fi
printf '%s\n' "${BOLD}  SYSTEM${RESET}"
printf '  %-15s %s\n' 'Distribution' "$distro"
printf '  %-15s %s\n\n' 'Kernel' "$(uname -r)"
printf '%s\n' "${BOLD}  DEVOPS TOOLS${RESET}"
printf '  %-13s %-14s %s\n' 'TOOL' 'STATUS' 'VERSION'
printf '  %s\n' '────────────────────────────────────────────────────────────'
# Version checks use local CLI flags only; kubectl does not contact a cluster.
get_version() {
  local tool="$1" output
  local -a args
  case "$tool" in
    git) args=(--version) ;;
    podman) args=(--version) ;;
    distrobox) args=(--version) ;;
    kubectl) args=(version --client=true --output=yaml) ;;
    go) args=(version) ;;
    terraform) args=(version) ;;
    *) return 1 ;;
  esac
  if command -v timeout >/dev/null 2>&1; then
    output="$(timeout 5s "$tool" "${args[@]}" 2>&1)" || return 1
  else
    output="$("$tool" "${args[@]}" 2>&1)" || return 1
  fi
  case "$tool" in
    kubectl)
      output="$(printf '%s\n' "$output" | grep -m1 -E '^[[:space:]]*gitVersion:' | sed -E 's/^[[:space:]]*gitVersion:[[:space:]]*//')" ;;
    terraform)
      output="$(printf '%s\n' "$output" | head -n 1)" ;;
    *)
      output="$(printf '%s\n' "$output" | head -n 1)" ;;
  esac
  [[ -n "$output" ]] || return 1
  printf '%s' "$output"
}

missing=0
available=0
for tool in git podman distrobox kubectl go terraform; do
  if command -v "$tool" >/dev/null 2>&1; then
    version="$(get_version "$tool")" || version="version unavailable"
    printf '  %-13s %b%-14s%b %s\n' "$tool" "$GREEN" '✓ installed' "$RESET" "$version"
    available=$((available + 1))
  else
    printf '  %-13s %-14s %s\n' "$tool" '○ missing' '—'
    missing=$((missing + 1))
  fi
done
printf '\n  %s\n' '────────────────────────────────────────────────────────────'
printf '  %b%d of 6%b tools installed  ·  %d missing\n' "$GREEN" "$available" "$RESET" "$missing"
printf '  %bRead-only check · No changes made%b\n' "$DIM" "$RESET"
