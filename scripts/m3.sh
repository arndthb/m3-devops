#!/usr/bin/env bash
# m³ interactive menu — read-only, no installations or configuration changes.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

pause_menu() {
  printf '\nPress Enter to return to the menu...'
  IFS= read -r _ || return 1
}
show_tools() {
  printf '\nm³ — Select DevOps tools (preview only)\n'
  printf 'Tool selection and installation are not implemented yet.\n'
  printf 'Current inventory: Git, Podman, Distrobox, kubectl, Go, Terraform.\n'
  printf 'Use option 2 to preview missing tools and suggested commands.\n'
}
show_settings() {
  printf '\nm³ — Settings\n'
  printf 'Current mode: read-only (fixed).\n'
  printf 'Target platform: Bluefin Linux (initial focus).\n'
  printf 'No settings can be changed in this version.\n'
}
while true; do
  printf '\n%s\n' 'm³ — DevOps Workstation Setup'     '  [1] System diagnostics'     '  [2] Installation preview'     '  [3] Select DevOps tools (coming soon)'     '  [4] Settings (read-only)'     '  [0] Exit'
  printf 'Select an option: '
  IFS= read -r choice || { printf '\n'; break; }
  case "$choice" in
    1) bash "$SCRIPT_DIR/check-system.sh" || printf 'Diagnostics failed.\n'; pause_menu || break ;;
    2) bash "$SCRIPT_DIR/preview-install.sh" || printf 'Preview failed.\n'; pause_menu || break ;;
    3) show_tools; pause_menu || break ;;
    4) show_settings; pause_menu || break ;;
    0) break ;;
    *) printf 'Invalid option. Choose 0–4.\n' ;;
  esac
done
printf 'Goodbye from m³.\n'
