#!/usr/bin/env bash
# m³ interactive menu — read-only; confirmation is simulated, no installs.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tools=(git podman distrobox kubectl go terraform)
selected=(0 0 0 0 0 0)

pause_menu() {
  printf '\nPress Enter to return to the menu...'
  IFS= read -r _ || return 1
}

preview_selected() {
  local i tool count=0 missing=0 answer
  local -a pending=()
  printf '\nm³ — Selected tools installation preview (DRY RUN)\n'
  printf 'No software will be installed.\n'
  for i in "${!tools[@]}"; do
    [[ "${selected[i]}" == 1 ]] || continue
    count=$((count + 1))
    tool="${tools[i]}"
    if command -v "$tool" >/dev/null 2>&1; then
      printf '[installed] %s — no action needed\n' "$tool"
    else
      missing=$((missing + 1))
      pending+=("$tool")
      printf '[missing]   %s\n' "$tool"
      if ! command -v brew >/dev/null 2>&1; then
        printf '            Homebrew not detected; installation method needs review.\n'
      elif [[ "$tool" == terraform ]]; then
        printf '            Suggested (NOT executed): brew tap hashicorp/tap\n'
        printf '            Suggested (NOT executed): brew install hashicorp/tap/terraform\n'
      elif [[ "$tool" == podman || "$tool" == distrobox ]]; then
        printf '            System-integrated tool: check Bluefin image; no brew suggestion.\n'
      else
        printf '            Suggested (NOT executed): brew install %s\n' "$tool"
      fi
    fi
  done
  if (( count == 0 )); then
    printf 'No tools selected.\n'
  elif (( missing == 0 )); then
    printf 'All selected tools are already installed.\n'
  else
    printf '\nConfirmation flow test: %d missing tool(s): %s\n' "$missing" "${pending[*]}"
    printf 'Type INSTALL to confirm this plan, or press Enter to cancel: '
    IFS= read -r answer || answer=''
    if [[ "$answer" == INSTALL ]]; then
      printf 'Confirmation accepted (simulation only).\n'
      printf 'Installation execution is not enabled in this version.\n'
    else
      printf 'Cancelled.\n'
    fi
  fi
  printf 'Preview complete. No changes made.\n'
}

select_tools() {
  local i choice key cursor=0
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'Interactive selection requires a terminal.\n'
    return
  fi
  while true; do
    printf '\033[H\033[2J'
    printf 'm³ — Select DevOps tools\n'
    printf '\n'
    for i in "${!tools[@]}"; do
      if (( i == cursor )); then printf ' > '; else printf '   '; fi
      if [[ "${selected[i]}" == 1 ]]; then
        printf '[x] %s\n' "${tools[i]}"
      else
        printf '[ ] %s\n' "${tools[i]}"
      fi
    done
    printf '\n↑/↓ Navigate  Space Toggle  Enter Preview  Esc Back\n'
    IFS= read -rsn1 key || return
    case "$key" in
      $'\033')
        # Arrow keys send ESC [ A/B; a lone ESC returns to the menu.
        if IFS= read -rsn1 -t 0.15 choice; then
          if [[ "$choice" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 choice || continue
            case "$choice" in
              A) cursor=$(( (cursor + ${#tools[@]} - 1) % ${#tools[@]} )) ;;
              B) cursor=$(( (cursor + 1) % ${#tools[@]} )) ;;
            esac
          fi
        else
          printf '\033[H\033[2J'
          return
        fi
        ;;
      ' ') selected[cursor]=$((1 - selected[cursor])) ;;
      '') printf '\033[H\033[2J'; preview_selected; pause_menu || return ;;
    esac
  done
}

show_settings() {
  printf '\nm³ — Settings\n'
  printf 'Current mode: read-only; installation confirmation is simulated.\n'
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
