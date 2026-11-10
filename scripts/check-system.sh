#!/usr/bin/env bash
# m³ system diagnostics — read-only, no elevated privileges.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tool-detect.sh
source "$SCRIPT_DIR/lib/tool-detect.sh"

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
  local tool="$1" output='' bin
  bin="$tool"
  local -a args=()
  case "$tool" in
    git|podman|distrobox|docker|curl|make|codium) args=(--version) ;;
    kubectl) args=(version --client=true --output=yaml) ;;
    go|terraform|kind) args=(version) ;;
    hermes) m3_tool_source "$tool"; return 0 ;;
    compose)
      if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        bin=docker; args=(compose version)
      elif command -v docker-compose >/dev/null 2>&1; then
        bin=docker-compose; args=(--version)
      else
        bin=podman-compose; args=(--version)
      fi ;;
    *) return 1 ;;
  esac
  if [[ "$tool" == codium ]] && ! command -v codium >/dev/null 2>&1; then
    bin=flatpak; args=(info --show-version com.vscodium.codium)
  fi
  if command -v timeout >/dev/null 2>&1; then
    output="$(timeout 5s "$bin" "${args[@]}" 2>&1)" || return 1
  else
    output="$("$bin" "${args[@]}" 2>&1)" || return 1
  fi
  if [[ "$tool" == kubectl ]]; then
    output="$(printf '%s\n' "$output" | grep -m1 -E '^[[:space:]]*gitVersion:' | sed -E 's/^[[:space:]]*gitVersion:[[:space:]]*//')"
  else
    output="$(printf '%s\n' "$output" | head -n 1)"
  fi
  [[ -n "$output" ]] || return 1
  printf '%s' "$output"
}

missing=0
available=0
total=0
while IFS= read -r tool; do
  total=$((total+1))
  if m3_tool_present "$tool"; then
    version="$(get_version "$tool")" || version="version unavailable"
    printf '  %-13s %b%-14s%b %s\n' "$(m3_tool_label "$tool")" "$GREEN" '✓ installed' "$RESET" "$version"
    available=$((available + 1))
  else
    printf '  %-13s %-14s %s\n' "$(m3_tool_label "$tool")" '○ missing' '—'
    missing=$((missing + 1))
  fi
done < <(m3_tool_catalog)
printf '\n  %s\n' '────────────────────────────────────────────────────────────'
printf '  %b%d of %d%b tools installed  ·  %d missing\n' "$GREEN" "$available" "$total" "$RESET" "$missing"
printf '  %bRead-only check · No changes made%b\n' "$DIM" "$RESET"
