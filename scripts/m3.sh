#!/usr/bin/env bash
# m³ interactive menu — read-only; confirmation is simulated, no installs.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tools=(git podman distrobox kubectl go terraform)
selected=(0 0 0 0 0 0)

is_installed() {
  command -v "$1" >/dev/null 2>&1
}

print_header() {
  local section="${1:-DevOps Workstation Setup}"
  printf '\033[1;32m'
  printf '  m³  '
  printf '\033[0m\033[1m%s\033[0m\n' "$section"
  printf '  \033[32m────────────────────────────────────\033[0m\n\n'
}

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
    if is_installed "$tool"; then
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
    # Recheck on every redraw so newly available tools are locked immediately.
    for i in "${!tools[@]}"; do
      if is_installed "${tools[i]}"; then selected[i]=0; fi
    done
    printf '\033[H\033[2J'
    print_header 'Select DevOps tools'
    printf '   %-3s %-14s %s\n' '' 'TOOL' 'STATUS'
    for i in "${!tools[@]}"; do
      if (( i == cursor )); then printf ' > '; else printf '   '; fi
      if is_installed "${tools[i]}"; then
        printf '[-] %-14s (\033[32minstalled\033[0m)\n' "${tools[i]}"
      elif [[ "${selected[i]}" == 1 ]]; then
        printf '[x] %-14s (missing)\n' "${tools[i]}"
      else
        printf '[ ] %-14s (missing)\n' "${tools[i]}"
      fi
    done
    printf '\n'
    if (( cursor == ${#tools[@]} )); then
      printf '\033[32m >\033[0m     Back to main menu\n'
    else
      printf '       Back to main menu\n'
    fi
    printf '\n[-] Installed / locked   [x] Selected   [ ] Available\n'
    printf '↑/↓ Navigate  Space Toggle  Enter Select\n'
    IFS= read -rsn1 key || return
    case "$key" in
      $'\033')
        # Arrow keys send ESC [ A/B; a lone ESC returns to the menu.
        if IFS= read -rsn1 -t 0.15 choice; then
          if [[ "$choice" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 choice || continue
            case "$choice" in
              A) cursor=$(( (cursor + ${#tools[@]}) % (${#tools[@]} + 1) )) ;;
              B) cursor=$(( (cursor + 1) % (${#tools[@]} + 1) )) ;;
            esac
          fi
        else
          printf '\033[H\033[2J'
          return
        fi
        ;;
      ' ')
        if (( cursor < ${#tools[@]} )) && ! is_installed "${tools[cursor]}"; then
          selected[cursor]=$((1 - selected[cursor]))
        fi
        ;;
      '')
        if (( cursor == ${#tools[@]} )); then return; fi
        printf '\033[H\033[2J'; preview_selected; pause_menu || return
        ;;
    esac
  done
}

show_settings() {
  printf '\nm³ — Settings\n'
  printf 'Current mode: read-only; installation confirmation is simulated.\n'
  printf 'Target platform: Bluefin Linux (initial focus).\n'
  printf 'No settings can be changed in this version.\n'
}


main_menu() {
  local cursor=0 key next
  local -a items=('System diagnostics' 'Installation preview' 'Select DevOps tools' 'Settings' 'Exit')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  while true; do
    printf '\033[H\033[2J'
    print_header 'DevOps Workstation Setup'
    for i in "${!items[@]}"; do
      if (( i == cursor )); then
        printf '\033[32m >\033[0m  %s\n' "${items[i]}"
      else
        printf '    %s\n' "${items[i]}"
      fi
    done
    printf '\n↑/↓ Navigate  Enter Select\n'
    IFS= read -rsn1 key || return 0
    case "$key" in
      $'\033')
        if IFS= read -rsn1 -t 0.15 next; then
          if [[ "$next" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 next || continue
            case "$next" in
              A) cursor=$(( (cursor + ${#items[@]} - 1) % ${#items[@]} )) ;;
              B) cursor=$(( (cursor + 1) % ${#items[@]} )) ;;
            esac
          fi
        else
          return 0
        fi
        ;;
      '')
        printf '\033[H\033[2J'
        case "$cursor" in
          0) bash "$SCRIPT_DIR/check-system.sh" || printf 'Diagnostics failed.\n'; pause_menu || return 0 ;;
          1) bash "$SCRIPT_DIR/preview-install.sh" || printf 'Preview failed.\n'; pause_menu || return 0 ;;
          2) select_tools ;;
          3) show_settings; pause_menu || return 0 ;;
          4) return 0 ;;
        esac
        ;;
    esac
  done
}

main_menu
printf 'Goodbye from m³.\n'
