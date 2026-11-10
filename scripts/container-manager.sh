#!/usr/bin/env bash
# m³ Container Manager — Podman inspection only; no mutations.
set -u

# Keep the terminal cursor out of the interactive menu.
if [[ -t 1 ]]; then
  printf '\\033[?25l'
  trap 'printf "\\033[?25h"' EXIT HUP INT TERM
fi
header() {
  printf '\033[H\033[2J'
  printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
  printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
  printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
  printf '\033[32m  │\033[0m   %-41s  \033[32m│\033[0m\n' 'Container Manager'
  printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
  printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
  printf '  Podman · read-only\n\n'
}
pause() { printf '\n  Press Enter to return...'; IFS= read -r _ || true; }
run_podman() {
  if command -v timeout >/dev/null 2>&1; then timeout 8s podman "$@"; else podman "$@"; fi
}
if ! command -v podman >/dev/null 2>&1; then
  header
  printf '  Podman is not installed or unavailable in PATH.\n'
  pause
  exit 0
fi
if ! run_podman info --format '{{.Host.Arch}}' >/dev/null 2>&1; then
  header
  printf '  Podman is installed, but its engine is unavailable.\n'
  printf '  Check your Podman connection or user session.\n'
  pause
  exit 0
fi
items=('Containers' 'Images' 'Volumes' 'Networks' 'System disk usage' 'Back')
cursor=0
while true; do
  header
  for i in "${!items[@]}"; do
    if (( i == cursor )); then printf '  \033[32m>\033[0m %s\n' "${items[i]}"
    else printf '    %s\n' "${items[i]}"; fi
  done
  printf '\n  ↑/↓ Navigate  Enter Select  Esc Back\n'
  IFS= read -rsn1 key || break
  case "$key" in
    $'\033')
      if IFS= read -rsn1 -t 0.15 next; then
        if [[ "$next" == '[' ]]; then
          IFS= read -rsn1 -t 0.15 next || continue
          case "$next" in
            A) cursor=$(( (cursor + ${#items[@]} - 1) % ${#items[@]} ));;
            B) cursor=$(( (cursor + 1) % ${#items[@]} ));;
          esac
        fi
      else break; fi ;;
    '')
      (( cursor == 5 )) && break
      header
      printf '  ◆ %s\n  ──────────────────────────────────────────────\n\n' "${items[cursor]}"
      case "$cursor" in
        0) run_podman ps --all --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' ;;
        1) run_podman images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' ;;
        2) run_podman volume ls ;;
        3) run_podman network ls ;;
        4) run_podman system df ;;
      esac || printf '\n  Could not retrieve Podman data.\n'
      pause ;;
    q|Q) break ;;
  esac
done
