#!/usr/bin/env bash
# m³ interactive menu — read-only; no installation commands are executed.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tools=(git podman distrobox kubectl go terraform)
selected=(0 0 0 0 0 0)

pause_menu() {
  printf '\nPress Enter to return to the menu...'
  IFS= read -r _ || return 1
}

preview_selected() {
  local i tool count=0
  printf '\nm³ — Selected tools installation preview (DRY RUN)\n'
  printf 'No software will be installed.\n'
  for i in "${!tools[@]}"; do
    [[ "${selected[i]}" == 1 ]] || continue
    count=$((count + 1))
    tool="${tools[i]}"
    if command -v "$tool" >/dev/null 2>&1; then
      printf '[installed] %s — no action needed\n' "$tool"
    else
      printf '[missing]   %s\n' "$tool"
      if ! command -v brew >/dev/null 2>&1; then
        printf '            Homebrew not detected; installation method needs review.\n'
      elif [[ "$tool" == terraform ]]; then
        printf '            Terraform: verify the supported Homebrew tap/formula before installing.\n'
      else
        printf '            Suggested (NOT executed): brew install %s\n' "$tool"
      fi
    fi
  done
  if (( count == 0 )); then
    printf 'No tools selected.\n'
  fi
  printf 'Preview complete. No changes made.\n'
}

select_tools() {
  local i choice
  while true; do
    printf '\nm³ — Select DevOps tools\n'
    printf 'Toggle a tool by entering its number.\n'
    for i in "${!tools[@]}"; do
      if [[ "${selected[i]}" == 1 ]]; then
        printf '  [%d] [x] %s\n' "$((i + 1))" "${tools[i]}"
      else
        printf '  [%d] [ ] %s\n' "$((i + 1))" "${tools[i]}"
      fi
    done
    printf '  [p] Preview selected tools\n  [0] Back\nChoice: '
    IFS= read -r choice || return
    case "$choice" in
      [1-6])
        i=$((choice - 1))
        selected[i]=$((1 - selected[i]))
        ;;
      p|P) preview_selected; pause_menu || return ;;
      0) return ;;
      *) printf 'Invalid choice.\n' ;;
    esac
  done
}

show_settings() {
  printf '\nm³ — Settings\n'
  printf 'Current mode: read-only (fixed).\n'
  printf 'Target platform: Bluefin Linux (initial focus).\n'
  printf 'No settings can be changed in this version.\n'
}

while true; do
  printf '\n%s\n' 'm³ — DevOps Workstation Setup' \
    '  [1] System diagnostics' \
    '  [2] Installation preview (all missing tools)' \
    '  [3] Select DevOps tools' \
    '  [4] Settings (read-only)' \
    '  [0] Exit'
  printf 'Select an option: '
  IFS= read -r choice || { printf '\n'; break; }
  case "$choice" in
    1) bash "$SCRIPT_DIR/check-system.sh" || printf 'Diagnostics failed.\n'; pause_menu || break ;;
    2) bash "$SCRIPT_DIR/preview-install.sh" || printf 'Preview failed.\n'; pause_menu || break ;;
    3) select_tools ;;
    4) show_settings; pause_menu || break ;;
    0) break ;;
    *) printf 'Invalid option. Choose 0–4.\n' ;;
  esac
done
printf 'Goodbye from m³.\n'
