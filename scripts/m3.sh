#!/usr/bin/env bash
# m³ interactive menu — read-only; confirmation is simulated, no installs.
set -u

# Keep the terminal cursor out of the interactive menu.
if [[ -t 1 ]]; then
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT HUP INT TERM
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tools=(git podman distrobox kubectl go terraform)
selected=(0 0 0 0 0 0)

is_installed() {
  command -v "$1" >/dev/null 2>&1
}

print_header() {
  local section="${1:-DevOps Workstation Setup}"
  printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
  printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
  printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
  # Bash printf field widths can count UTF-8 bytes; pad by character count instead.
  # Use ASCII in section labels so padding is stable even with a C locale.
  section="${section//³/3}"
  local label="${section:0:41}" pad
  pad=$((41 - ${#label}))
  printf '\033[32m  │\033[0m   \033[2m%s\033[0m%*s  \033[32m│\033[0m\n' "$label" "$pad" ''
  printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
  printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
}

pause_menu() {
  printf '\nPress Enter to return to the menu...'
  IFS= read -r _ || return 1
}select_tools() {
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
    print_header 'DevOps Tool Manager'
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
      printf '\033[32m >\033[0m     Automatic installation preview\n'
    else
      printf '       Automatic installation preview\n'
    fi
    if (( cursor == ${#tools[@]} + 1 )); then
      printf '\033[32m >\033[0m     Update Check\n'
    else
      printf '       Update Check\n'
    fi
    if (( cursor == ${#tools[@]} + 2 )); then
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
              A) cursor=$(( (cursor + ${#tools[@]}) % (${#tools[@]} + 3) )) ;;
              B) cursor=$(( (cursor + 1) % (${#tools[@]} + 3) )) ;;
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
        if (( cursor == ${#tools[@]} + 2 )); then return; fi
        printf '\033[H\033[2J'
        if (( cursor == ${#tools[@]} )); then
          bash "$SCRIPT_DIR/preview-install.sh" || printf 'Preview failed.\n'
        elif (( cursor == ${#tools[@]} + 1 )); then
          bash "$SCRIPT_DIR/update-check.sh" || printf 'Update check failed.\n'
        else
          preview_selected
        fi
        pause_menu || return
        ;;
    esac
  done
}

print_link() {
  local url="$1"
  # Plain URLs work consistently across terminal emulators.
  printf '\033[4;34m%s\033[0m' "$url"
}

show_settings() {
  local revision='unavailable'
  if command -v git >/dev/null 2>&1; then
    revision="$(git -C "$SCRIPT_DIR/.." rev-parse --short HEAD 2>/dev/null)" || revision='unavailable'
  fi
  print_header 'Info'
  printf '\033[1m  ABOUT m³\033[0m\n'
  printf '  %-15s %s\n' 'Version' 'v0.1 (development)'
  printf '  %-15s %s\n' 'Revision' "$revision"
  printf '  %-15s %s\n' 'Platform' 'Linux · Bluefin first'
  printf '  %-15s %s\n' 'Mode' 'Read-only / installation simulation'
  printf '  %-15s %s\n\n' 'License' 'MIT'
  printf '\033[1m  PROJECT\033[0m\n'
  printf '  %-15s ' 'Repository'
  print_link 'https://github.com/arndthb/m3-devops'
  printf '\n'
  printf '  %-15s %s\n\n' 'Updates' 'm3 update'
  printf '\033[1m  AUTHOR\033[0m\n'
  printf '  Arndt H. Bohrenkämper\n'
  printf '  GitHub: '
  print_link 'https://github.com/arndthb'
  printf '\n'
  printf '  Independent open-source project · 2026\n\n'
  printf '\033[2m  No configuration changes are available yet.\033[0m\n'
}


m3_icon_mode() {
  local config="$HOME/.config/m3/icon-mode"
  if [[ -r "$config" ]] && [[ "$(head -n 1 "$config")" == nerd ]]; then
    printf nerd
  else
    printf classic
  fi
}

show_settings_page() {
  local key mode config="$HOME/.config/m3/icon-mode"
  while true; do
    printf '\033[H\033[2J'
    print_header 'Settings'
    mode="$(m3_icon_mode)"
    printf '  Icon style: %s\n' "$mode"
    printf '  Nerd Font mode requires a Nerd Font selected in your terminal.\n'
    printf '  No fonts are downloaded or installed by m³.\n\n'
    printf '  [n] Nerd Font icons   [c] Classic markers   [Enter] Back\n'
    IFS= read -rsn1 key || return 0
    case "$key" in
      n|N|c|C)
        mkdir -p "$HOME/.config/m3" || return 1
        if [[ "$key" == n || "$key" == N ]]; then printf 'nerd\n' > "$config"
        else printf 'classic\n' > "$config"; fi ;;
      '') return 0 ;;
      $'\033') return 0 ;;
    esac
  done
}


matrix_easter_egg() {
  local frame row col char
  printf '\033[?25l'
  for ((frame=0; frame<28; frame++)); do
    printf '\033[H\033[2J\033[1;32m  m³ // THE MATRIX\033[0m\n\n'
    for ((row=0; row<12; row++)); do
      printf '  '
      for ((col=0; col<48; col++)); do
        if (( (row + frame + col * 7) % 13 < 5 )); then
          char=$((RANDOM % 2))
          printf '\033[32m%s' "$char"
        else
          printf ' '
        fi
      done
      printf '\033[0m\n'
    done
    sleep 0.09
  done
  printf '\033[H\033[2J\033[?25h'
  print_header 'Secret mode unlocked'
  printf '\033[1;32m  WAKE UP, DEVOPS.\033[0m\n\n'
  printf '%s\n' '  There is no cloud.' "  It's just someone else's computer."
  sleep 7
}

update_m3() {
  M3_RESTART_REQUIRED=0
  local repo branch local_rev remote_rev answer status count
  repo="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  printf '\033[H\033[2J'
  print_header 'Check m³ Updates'
  printf '\033[1m  ◆ M3 UPDATE CENTER\033[0m\n'
  printf '  Channel: \033[36mmain\033[0m   Source: GitHub\n'
  printf '  ──────────────────────────────────────────────\n'
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$repo/.git" ]]; then
    printf '  \033[31m✗ Git checkout unavailable.\033[0m\n'; return 1
  fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=''
  if [[ "$branch" != main ]]; then
    printf '  \033[31m✗ Expected main; current: %s\033[0m\n' "${branch:-detached}"; return 1
  fi
  local_rev=$(git -C "$repo" rev-parse --short=7 HEAD 2>/dev/null) || return 1
  printf '\n  \033[36m◌ Checking for updates...\033[0m\n'
  if ! git -C "$repo" fetch --quiet origin main; then
    printf '  \033[31m✗ Could not check for updates.\033[0m\n'; return 1
  fi
  remote_rev=$(git -C "$repo" rev-parse --short=7 FETCH_HEAD 2>/dev/null) || return 1
  printf '\n\033[1m  ◆ VERSION COMPARISON\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '  Installed     \033[36m%s\033[0m\n' "$local_rev"
  printf '  Available     \033[1;32m%s\033[0m\n' "$remote_rev"
  printf '\n\033[1m  ◆ CHANGELOG\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  if [[ "$local_rev" == "$remote_rev" ]]; then
    printf '    No new commits.\n\n'
    printf '    Latest commit\n'
    git -C "$repo" log -1 --format='    %h  %s' HEAD 2>/dev/null
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ ALL UP TO DATE\033[0m                        │\n'
    printf '  │  No new updates available.               │\n'
    printf '  └──────────────────────────────────────────┘\n'
    return 0
  fi
  if ! git -C "$repo" merge-base --is-ancestor HEAD FETCH_HEAD; then
    printf '  \033[31m✗ Branches diverged or local revision is ahead.\033[0m\n'
    printf '  No automatic update.\n'; return 1
  fi
  count=$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null) || return 1
  printf '  \033[1;32m%s new commit(s)\033[0m · newest first\n\n' "$count"
  git -C "$repo" log -8 --format='  %h  %s' HEAD..FETCH_HEAD 2>/dev/null
  if (( count > 8 )); then printf '  ... and %s more\n' "$((count - 8))"; fi
  printf '\n  ┌──────────────────────────────────────────┐\n'
  printf '  │  \033[1;33m● UPDATE AVAILABLE\033[0m                      │\n'
  printf '  └──────────────────────────────────────────┘\n'
  printf '  Install this update now? [y/N] '
  IFS= read -r answer || return 1
  if [[ "$answer" != y && "$answer" != Y ]]; then
    printf '  Update skipped.\n'; return 0
  fi
  status=$(git -C "$repo" status --porcelain 2>/dev/null) || { printf '  Could not check local changes.\n'; return 1; }
  if [[ -n "$status" ]]; then
    printf '  \033[31m✗ Local changes detected. Update cancelled.\033[0m\n'; return 1
  fi
  printf '\n\033[1m  ◆ INSTALLATION PROGRESS\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '    \033[1;32m✓\033[0m  [1/3] Repository checked\n'
  printf '    \033[1;32m✓\033[0m  [2/3] %s commit(s) ready\n' "$count"
  printf '    \033[36m●\033[0m  [3/3] Installing %s → %s ...\n' "$local_rev" "$remote_rev"
  local merge_output
  if merge_output=$(git -C "$repo" merge --quiet --ff-only FETCH_HEAD 2>&1); then
    printf '\r\033[2K    \033[1;32m✓\033[0m  [3/3] Installation complete\n'
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ UPDATE INSTALLED\033[0m                      │\n'
    printf '  │  New revision: \033[1;32m%-7s\033[0m                   │\n' "$remote_rev"
    printf '  │  Reloading m³ with the new version...    │\n'
    printf '  └──────────────────────────────────────────┘\n'
    M3_RESTART_REQUIRED=1
  else
    printf '    \033[31m✗\033[0m  [3/3] Installation failed\n'
    printf '    %s\n' "$merge_output"
    return 1
  fi
}

main_menu() {
  local cursor=0 old_cursor key next secret_count=0
  local -a items=('System diagnostics' 'Workstation health check' 'DevOps Tool Manager' 'DevOps Project Manager' 'Container Manager' 'Update m³' 'Settings' 'Info' 'Exit')
  local -a icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]')
  local -a nerd_icons=('󰍹' '󰓅' '󰒓' '󰉋' '󰡨' '󰚰' '󰒓' '󰋼' '󰈆')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  render_menu_row() {
    local index="$1"
    local row=$((8 + index))
    printf '\033[%d;1H\033[2K' "$row"
    if (( index == cursor )); then
      printf '\033[32m >\033[0m  \033[36m%s\033[0m  %s' "${icons[index]}" "${items[index]}"
    else
      printf '    \033[2m%s\033[0m  %s' "${icons[index]}" "${items[index]}"
    fi
  }
  printf '\033[H\033[2J'
  print_header 'DevOps Workstation Setup'
  if [[ "$(m3_icon_mode)" == nerd ]]; then icons=("${nerd_icons[@]}"); else icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]'); fi
  for i in "${!items[@]}"; do render_menu_row "$i"; printf '\n'; done
  printf '\n↑/↓ Navigate  Enter Select\n'
  while true; do
    IFS= read -rsn1 key || return 0
    if [[ "$key" == m ]]; then
      secret_count=$((secret_count + 1))
      if (( secret_count == 3 )); then
        matrix_easter_egg
        secret_count=0
      fi
      continue
    fi
    secret_count=0
    case "$key" in
      $'\033')
        if IFS= read -rsn1 -t 0.15 next; then
          if [[ "$next" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 next || continue
            case "$next" in
              A) old_cursor=$cursor; cursor=$(( (cursor + ${#items[@]} - 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor" ;;
              B) old_cursor=$cursor; cursor=$(( (cursor + 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor" ;;
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
          1) bash "$SCRIPT_DIR/health-check.sh" || printf 'Health check failed.\n'; pause_menu || return 0 ;;
          2) select_tools ;;
          3) bash "$SCRIPT_DIR/project-manager.sh" || printf 'Project scan failed.\n' ;;
          4) bash "$SCRIPT_DIR/container-manager.sh" || { printf "Container Manager failed.\n"; pause_menu; } ;;
          5) if update_m3; then for seconds in 3 2 1; do printf '\r  Returning to main menu in %s... ' "$seconds"; sleep 1; done; printf '\n'; if [[ "${M3_RESTART_REQUIRED:-0}" == 1 ]]; then exec bash "$SCRIPT_DIR/m3.sh"; fi; else pause_menu || return 0; fi ;;
          6) show_settings_page ;;
          7) show_settings; pause_menu || return 0 ;;
          8) return 0 ;;
        esac
        ;;
    esac
  done
}

main_menu
printf 'Goodbye from m³.\n'
\033') return 0 ;;
    esac
  done
}



matrix_easter_egg() {
  local frame row col char
  printf '\033[?25l'
  for ((frame=0; frame<28; frame++)); do
    printf '\033[H\033[2J\033[1;32m  m³ // THE MATRIX\033[0m\n\n'
    for ((row=0; row<12; row++)); do
      printf '  '
      for ((col=0; col<48; col++)); do
        if (( (row + frame + col * 7) % 13 < 5 )); then
          char=$((RANDOM % 2))
          printf '\033[32m%s' "$char"
        else
          printf ' '
        fi
      done
      printf '\033[0m\n'
    done
    sleep 0.09
  done
  printf '\033[H\033[2J\033[?25h'
  print_header 'Secret mode unlocked'
  printf '\033[1;32m  WAKE UP, DEVOPS.\033[0m\n\n'
  printf '%s\n' '  There is no cloud.' "  It's just someone else's computer."
  sleep 7
}

update_m3() {
  M3_RESTART_REQUIRED=0
  local repo branch local_rev remote_rev answer status count
  repo="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  printf '\033[H\033[2J'
  print_header 'Check m³ Updates'
  printf '\033[1m  ◆ M3 UPDATE CENTER\033[0m\n'
  printf '  Channel: \033[36mmain\033[0m   Source: GitHub\n'
  printf '  ──────────────────────────────────────────────\n'
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$repo/.git" ]]; then
    printf '  \033[31m✗ Git checkout unavailable.\033[0m\n'; return 1
  fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=''
  if [[ "$branch" != main ]]; then
    printf '  \033[31m✗ Expected main; current: %s\033[0m\n' "${branch:-detached}"; return 1
  fi
  local_rev=$(git -C "$repo" rev-parse --short=7 HEAD 2>/dev/null) || return 1
  printf '\n  \033[36m◌ Checking for updates...\033[0m\n'
  if ! git -C "$repo" fetch --quiet origin main; then
    printf '  \033[31m✗ Could not check for updates.\033[0m\n'; return 1
  fi
  remote_rev=$(git -C "$repo" rev-parse --short=7 FETCH_HEAD 2>/dev/null) || return 1
  printf '\n\033[1m  ◆ VERSION COMPARISON\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '  Installed     \033[36m%s\033[0m\n' "$local_rev"
  printf '  Available     \033[1;32m%s\033[0m\n' "$remote_rev"
  printf '\n\033[1m  ◆ CHANGELOG\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  if [[ "$local_rev" == "$remote_rev" ]]; then
    printf '    No new commits.\n\n'
    printf '    Latest commit\n'
    git -C "$repo" log -1 --format='    %h  %s' HEAD 2>/dev/null
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ ALL UP TO DATE\033[0m                        │\n'
    printf '  │  No new updates available.               │\n'
    printf '  └──────────────────────────────────────────┘\n'
    return 0
  fi
  if ! git -C "$repo" merge-base --is-ancestor HEAD FETCH_HEAD; then
    printf '  \033[31m✗ Branches diverged or local revision is ahead.\033[0m\n'
    printf '  No automatic update.\n'; return 1
  fi
  count=$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null) || return 1
  printf '  \033[1;32m%s new commit(s)\033[0m · newest first\n\n' "$count"
  git -C "$repo" log -8 --format='  %h  %s' HEAD..FETCH_HEAD 2>/dev/null
  if (( count > 8 )); then printf '  ... and %s more\n' "$((count - 8))"; fi
  printf '\n  ┌──────────────────────────────────────────┐\n'
  printf '  │  \033[1;33m● UPDATE AVAILABLE\033[0m                      │\n'
  printf '  └──────────────────────────────────────────┘\n'
  printf '  Install this update now? [y/N] '
  IFS= read -r answer || return 1
  if [[ "$answer" != y && "$answer" != Y ]]; then
    printf '  Update skipped.\n'; return 0
  fi
  status=$(git -C "$repo" status --porcelain 2>/dev/null) || { printf '  Could not check local changes.\n'; return 1; }
  if [[ -n "$status" ]]; then
    printf '  \033[31m✗ Local changes detected. Update cancelled.\033[0m\n'; return 1
  fi
  printf '\n\033[1m  ◆ INSTALLATION PROGRESS\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '    \033[1;32m✓\033[0m  [1/3] Repository checked\n'
  printf '    \033[1;32m✓\033[0m  [2/3] %s commit(s) ready\n' "$count"
  printf '    \033[36m●\033[0m  [3/3] Installing %s → %s ...\n' "$local_rev" "$remote_rev"
  local merge_output
  if merge_output=$(git -C "$repo" merge --quiet --ff-only FETCH_HEAD 2>&1); then
    printf '\r\033[2K    \033[1;32m✓\033[0m  [3/3] Installation complete\n'
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ UPDATE INSTALLED\033[0m                      │\n'
    printf '  │  New revision: \033[1;32m%-7s\033[0m                   │\n' "$remote_rev"
    printf '  │  Reloading m³ with the new version...    │\n'
    printf '  └──────────────────────────────────────────┘\n'
    M3_RESTART_REQUIRED=1
  else
    printf '    \033[31m✗\033[0m  [3/3] Installation failed\n'
    printf '    %s\n' "$merge_output"
    return 1
  fi
}

main_menu() {
  local cursor=0 key next secret_count=0
  local -a items=('System diagnostics' 'Workstation health check' 'DevOps Tool Manager' 'DevOps Project Manager' 'Container Manager' 'Update m³' 'Settings' 'Info' 'Exit')
  local -a icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  while true; do
    printf '\033[H\033[2J'
    print_header 'DevOps Workstation Setup'
    for i in "${!items[@]}"; do
      if (( i == cursor )); then
        printf '\033[32m >\033[0m  \033[36m%s\033[0m  %s\n' "${icons[i]}" "${items[i]}"
      else
        printf '    \033[2m%s\033[0m  %s\n' "${icons[i]}" "${items[i]}"
      fi
    done
    printf '\n↑/↓ Navigate  Enter Select\n'
    IFS= read -rsn1 key || return 0
    if [[ "$key" == m ]]; then
      secret_count=$((secret_count + 1))
      if (( secret_count == 3 )); then
        matrix_easter_egg
        secret_count=0
      fi
      continue
    fi
    secret_count=0
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
          1) bash "$SCRIPT_DIR/health-check.sh" || printf 'Health check failed.\n'; pause_menu || return 0 ;;
          2) select_tools ;;
          3) bash "$SCRIPT_DIR/project-manager.sh" || printf 'Project scan failed.\n' ;;
          4) bash "$SCRIPT_DIR/container-manager.sh" || { printf "Container Manager failed.\n"; pause_menu; } ;;
          5) if update_m3; then for seconds in 3 2 1; do printf '\r  Returning to main menu in %s... ' "$seconds"; sleep 1; done; printf '\n'; if [[ "${M3_RESTART_REQUIRED:-0}" == 1 ]]; then exec bash "$SCRIPT_DIR/m3.sh"; fi; else pause_menu || return 0; fi ;;
          6) show_settings_page; pause_menu || return 0 ;;
          7) show_settings; pause_menu || return 0 ;;
          8) return 0 ;;
        esac
        ;;
    esac
  done
}

main_menu
printf 'Goodbye from m³.\n'
\n' || "$key" == 

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
    print_header 'DevOps Tool Manager'
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
      printf '\033[32m >\033[0m     Automatic installation preview\n'
    else
      printf '       Automatic installation preview\n'
    fi
    if (( cursor == ${#tools[@]} + 1 )); then
      printf '\033[32m >\033[0m     Update Check\n'
    else
      printf '       Update Check\n'
    fi
    if (( cursor == ${#tools[@]} + 2 )); then
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
              A) cursor=$(( (cursor + ${#tools[@]}) % (${#tools[@]} + 3) )) ;;
              B) cursor=$(( (cursor + 1) % (${#tools[@]} + 3) )) ;;
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
        if (( cursor == ${#tools[@]} + 2 )); then return; fi
        printf '\033[H\033[2J'
        if (( cursor == ${#tools[@]} )); then
          bash "$SCRIPT_DIR/preview-install.sh" || printf 'Preview failed.\n'
        elif (( cursor == ${#tools[@]} + 1 )); then
          bash "$SCRIPT_DIR/update-check.sh" || printf 'Update check failed.\n'
        else
          preview_selected
        fi
        pause_menu || return
        ;;
    esac
  done
}

print_link() {
  local url="$1"
  # OSC 8 hyperlinks are clickable in supporting terminal emulators.
  # The full URL remains visible and can be copied in other terminals.
  if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
    printf '\033]8;;%s\033\\033[4;34m%s\033[0m\033]8;;\033\\' "$url" "$url"
  else
    printf '%s' "$url"
  fi
}

show_settings() {
  local revision='unavailable'
  if command -v git >/dev/null 2>&1; then
    revision="$(git -C "$SCRIPT_DIR/.." rev-parse --short HEAD 2>/dev/null)" || revision='unavailable'
  fi
  print_header 'Info'
  printf '\033[1m  ABOUT m³\033[0m\n'
  printf '  %-15s %s\n' 'Version' 'v0.1 (development)'
  printf '  %-15s %s\n' 'Revision' "$revision"
  printf '  %-15s %s\n' 'Platform' 'Linux · Bluefin first'
  printf '  %-15s %s\n' 'Mode' 'Read-only / installation simulation'
  printf '  %-15s %s\n\n' 'License' 'MIT'
  printf '\033[1m  PROJECT\033[0m\n'
  printf '  %-15s ' 'Repository'
  print_link 'https://github.com/arndthb/m3-devops'
  printf '\n'
  printf '  %-15s %s\n\n' 'Updates' 'm3 update'
  printf '\033[1m  AUTHOR\033[0m\n'
  printf '  Arndt H. Bohrenkämper\n'
  printf '  GitHub: '
  print_link 'https://github.com/arndthb'
  printf '\n'
  printf '  Independent open-source project · 2026\n\n'
  printf '\033[2m  No configuration changes are available yet.\033[0m\n'
}


m3_icon_mode() {
  local config="$HOME/.config/m3/icon-mode"
  if [[ -r "$config" ]] && [[ "$(head -n 1 "$config")" == nerd ]]; then
    printf nerd
  else
    printf classic
  fi
}

show_settings_page() {
  local key mode config="$HOME/.config/m3/icon-mode"
  while true; do
    printf '\033[H\033[2J'
    print_header 'Settings'
    mode="$(m3_icon_mode)"
    printf '  Icon style: %s\n' "$mode"
    printf '  Nerd Font mode requires a Nerd Font selected in your terminal.\n'
    printf '  No fonts are downloaded or installed by m³.\n\n'
    printf '  [n] Nerd Font icons   [c] Classic markers   [Enter] Back\n'
    IFS= read -rsn1 key || return 0
    case "$key" in
      n|N|c|C)
        mkdir -p "$HOME/.config/m3" || return 1
        if [[ "$key" == n || "$key" == N ]]; then printf 'nerd\n' > "$config"
        else printf 'classic\n' > "$config"; fi ;;
      '') return 0 ;;
      $'\033') return 0 ;;
    esac
  done
}


matrix_easter_egg() {
  local frame row col char
  printf '\033[?25l'
  for ((frame=0; frame<28; frame++)); do
    printf '\033[H\033[2J\033[1;32m  m³ // THE MATRIX\033[0m\n\n'
    for ((row=0; row<12; row++)); do
      printf '  '
      for ((col=0; col<48; col++)); do
        if (( (row + frame + col * 7) % 13 < 5 )); then
          char=$((RANDOM % 2))
          printf '\033[32m%s' "$char"
        else
          printf ' '
        fi
      done
      printf '\033[0m\n'
    done
    sleep 0.09
  done
  printf '\033[H\033[2J\033[?25h'
  print_header 'Secret mode unlocked'
  printf '\033[1;32m  WAKE UP, DEVOPS.\033[0m\n\n'
  printf '%s\n' '  There is no cloud.' "  It's just someone else's computer."
  sleep 7
}

update_m3() {
  M3_RESTART_REQUIRED=0
  local repo branch local_rev remote_rev answer status count
  repo="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  printf '\033[H\033[2J'
  print_header 'Check m³ Updates'
  printf '\033[1m  ◆ M3 UPDATE CENTER\033[0m\n'
  printf '  Channel: \033[36mmain\033[0m   Source: GitHub\n'
  printf '  ──────────────────────────────────────────────\n'
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$repo/.git" ]]; then
    printf '  \033[31m✗ Git checkout unavailable.\033[0m\n'; return 1
  fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=''
  if [[ "$branch" != main ]]; then
    printf '  \033[31m✗ Expected main; current: %s\033[0m\n' "${branch:-detached}"; return 1
  fi
  local_rev=$(git -C "$repo" rev-parse --short=7 HEAD 2>/dev/null) || return 1
  printf '\n  \033[36m◌ Checking for updates...\033[0m\n'
  if ! git -C "$repo" fetch --quiet origin main; then
    printf '  \033[31m✗ Could not check for updates.\033[0m\n'; return 1
  fi
  remote_rev=$(git -C "$repo" rev-parse --short=7 FETCH_HEAD 2>/dev/null) || return 1
  printf '\n\033[1m  ◆ VERSION COMPARISON\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '  Installed     \033[36m%s\033[0m\n' "$local_rev"
  printf '  Available     \033[1;32m%s\033[0m\n' "$remote_rev"
  printf '\n\033[1m  ◆ CHANGELOG\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  if [[ "$local_rev" == "$remote_rev" ]]; then
    printf '    No new commits.\n\n'
    printf '    Latest commit\n'
    git -C "$repo" log -1 --format='    %h  %s' HEAD 2>/dev/null
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ ALL UP TO DATE\033[0m                        │\n'
    printf '  │  No new updates available.               │\n'
    printf '  └──────────────────────────────────────────┘\n'
    return 0
  fi
  if ! git -C "$repo" merge-base --is-ancestor HEAD FETCH_HEAD; then
    printf '  \033[31m✗ Branches diverged or local revision is ahead.\033[0m\n'
    printf '  No automatic update.\n'; return 1
  fi
  count=$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null) || return 1
  printf '  \033[1;32m%s new commit(s)\033[0m · newest first\n\n' "$count"
  git -C "$repo" log -8 --format='  %h  %s' HEAD..FETCH_HEAD 2>/dev/null
  if (( count > 8 )); then printf '  ... and %s more\n' "$((count - 8))"; fi
  printf '\n  ┌──────────────────────────────────────────┐\n'
  printf '  │  \033[1;33m● UPDATE AVAILABLE\033[0m                      │\n'
  printf '  └──────────────────────────────────────────┘\n'
  printf '  Install this update now? [y/N] '
  IFS= read -r answer || return 1
  if [[ "$answer" != y && "$answer" != Y ]]; then
    printf '  Update skipped.\n'; return 0
  fi
  status=$(git -C "$repo" status --porcelain 2>/dev/null) || { printf '  Could not check local changes.\n'; return 1; }
  if [[ -n "$status" ]]; then
    printf '  \033[31m✗ Local changes detected. Update cancelled.\033[0m\n'; return 1
  fi
  printf '\n\033[1m  ◆ INSTALLATION PROGRESS\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '    \033[1;32m✓\033[0m  [1/3] Repository checked\n'
  printf '    \033[1;32m✓\033[0m  [2/3] %s commit(s) ready\n' "$count"
  printf '    \033[36m●\033[0m  [3/3] Installing %s → %s ...\n' "$local_rev" "$remote_rev"
  local merge_output
  if merge_output=$(git -C "$repo" merge --quiet --ff-only FETCH_HEAD 2>&1); then
    printf '\r\033[2K    \033[1;32m✓\033[0m  [3/3] Installation complete\n'
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ UPDATE INSTALLED\033[0m                      │\n'
    printf '  │  New revision: \033[1;32m%-7s\033[0m                   │\n' "$remote_rev"
    printf '  │  Reloading m³ with the new version...    │\n'
    printf '  └──────────────────────────────────────────┘\n'
    M3_RESTART_REQUIRED=1
  else
    printf '    \033[31m✗\033[0m  [3/3] Installation failed\n'
    printf '    %s\n' "$merge_output"
    return 1
  fi
}

main_menu() {
  local cursor=0 old_cursor key next secret_count=0
  local -a items=('System diagnostics' 'Workstation health check' 'DevOps Tool Manager' 'DevOps Project Manager' 'Container Manager' 'Update m³' 'Settings' 'Info' 'Exit')
  local -a icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]')
  local -a nerd_icons=('󰍹' '󰓅' '󰒓' '󰉋' '󰡨' '󰚰' '󰒓' '󰋼' '󰈆')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  render_menu_row() {
    local index="$1"
    local row=$((8 + index))
    printf '\033[%d;1H\033[2K' "$row"
    if (( index == cursor )); then
      printf '\033[32m >\033[0m  \033[36m%s\033[0m  %s' "${icons[index]}" "${items[index]}"
    else
      printf '    \033[2m%s\033[0m  %s' "${icons[index]}" "${items[index]}"
    fi
  }
  printf '\033[H\033[2J'
  print_header 'DevOps Workstation Setup'
  if [[ "$(m3_icon_mode)" == nerd ]]; then icons=("${nerd_icons[@]}"); else icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]'); fi
  for i in "${!items[@]}"; do render_menu_row "$i"; printf '\n'; done
  printf '\n↑/↓ Navigate  Enter Select\n'
  while true; do
    IFS= read -rsn1 key || return 0
    if [[ "$key" == m ]]; then
      secret_count=$((secret_count + 1))
      if (( secret_count == 3 )); then
        matrix_easter_egg
        secret_count=0
      fi
      continue
    fi
    secret_count=0
    case "$key" in
      $'\033')
        if IFS= read -rsn1 -t 0.15 next; then
          if [[ "$next" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 next || continue
            case "$next" in
              A) old_cursor=$cursor; cursor=$(( (cursor + ${#items[@]} - 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor" ;;
              B) old_cursor=$cursor; cursor=$(( (cursor + 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor" ;;
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
          1) bash "$SCRIPT_DIR/health-check.sh" || printf 'Health check failed.\n'; pause_menu || return 0 ;;
          2) select_tools ;;
          3) bash "$SCRIPT_DIR/project-manager.sh" || printf 'Project scan failed.\n' ;;
          4) bash "$SCRIPT_DIR/container-manager.sh" || { printf "Container Manager failed.\n"; pause_menu; } ;;
          5) if update_m3; then for seconds in 3 2 1; do printf '\r  Returning to main menu in %s... ' "$seconds"; sleep 1; done; printf '\n'; if [[ "${M3_RESTART_REQUIRED:-0}" == 1 ]]; then exec bash "$SCRIPT_DIR/m3.sh"; fi; else pause_menu || return 0; fi ;;
          6) show_settings_page ;;
          7) show_settings; pause_menu || return 0 ;;
          8) return 0 ;;
        esac
        ;;
    esac
  done
}

main_menu
printf 'Goodbye from m³.\n'
\033') return 0 ;;
    esac
  done
}



matrix_easter_egg() {
  local frame row col char
  printf '\033[?25l'
  for ((frame=0; frame<28; frame++)); do
    printf '\033[H\033[2J\033[1;32m  m³ // THE MATRIX\033[0m\n\n'
    for ((row=0; row<12; row++)); do
      printf '  '
      for ((col=0; col<48; col++)); do
        if (( (row + frame + col * 7) % 13 < 5 )); then
          char=$((RANDOM % 2))
          printf '\033[32m%s' "$char"
        else
          printf ' '
        fi
      done
      printf '\033[0m\n'
    done
    sleep 0.09
  done
  printf '\033[H\033[2J\033[?25h'
  print_header 'Secret mode unlocked'
  printf '\033[1;32m  WAKE UP, DEVOPS.\033[0m\n\n'
  printf '%s\n' '  There is no cloud.' "  It's just someone else's computer."
  sleep 7
}

update_m3() {
  M3_RESTART_REQUIRED=0
  local repo branch local_rev remote_rev answer status count
  repo="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  printf '\033[H\033[2J'
  print_header 'Check m³ Updates'
  printf '\033[1m  ◆ M3 UPDATE CENTER\033[0m\n'
  printf '  Channel: \033[36mmain\033[0m   Source: GitHub\n'
  printf '  ──────────────────────────────────────────────\n'
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$repo/.git" ]]; then
    printf '  \033[31m✗ Git checkout unavailable.\033[0m\n'; return 1
  fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=''
  if [[ "$branch" != main ]]; then
    printf '  \033[31m✗ Expected main; current: %s\033[0m\n' "${branch:-detached}"; return 1
  fi
  local_rev=$(git -C "$repo" rev-parse --short=7 HEAD 2>/dev/null) || return 1
  printf '\n  \033[36m◌ Checking for updates...\033[0m\n'
  if ! git -C "$repo" fetch --quiet origin main; then
    printf '  \033[31m✗ Could not check for updates.\033[0m\n'; return 1
  fi
  remote_rev=$(git -C "$repo" rev-parse --short=7 FETCH_HEAD 2>/dev/null) || return 1
  printf '\n\033[1m  ◆ VERSION COMPARISON\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '  Installed     \033[36m%s\033[0m\n' "$local_rev"
  printf '  Available     \033[1;32m%s\033[0m\n' "$remote_rev"
  printf '\n\033[1m  ◆ CHANGELOG\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  if [[ "$local_rev" == "$remote_rev" ]]; then
    printf '    No new commits.\n\n'
    printf '    Latest commit\n'
    git -C "$repo" log -1 --format='    %h  %s' HEAD 2>/dev/null
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ ALL UP TO DATE\033[0m                        │\n'
    printf '  │  No new updates available.               │\n'
    printf '  └──────────────────────────────────────────┘\n'
    return 0
  fi
  if ! git -C "$repo" merge-base --is-ancestor HEAD FETCH_HEAD; then
    printf '  \033[31m✗ Branches diverged or local revision is ahead.\033[0m\n'
    printf '  No automatic update.\n'; return 1
  fi
  count=$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null) || return 1
  printf '  \033[1;32m%s new commit(s)\033[0m · newest first\n\n' "$count"
  git -C "$repo" log -8 --format='  %h  %s' HEAD..FETCH_HEAD 2>/dev/null
  if (( count > 8 )); then printf '  ... and %s more\n' "$((count - 8))"; fi
  printf '\n  ┌──────────────────────────────────────────┐\n'
  printf '  │  \033[1;33m● UPDATE AVAILABLE\033[0m                      │\n'
  printf '  └──────────────────────────────────────────┘\n'
  printf '  Install this update now? [y/N] '
  IFS= read -r answer || return 1
  if [[ "$answer" != y && "$answer" != Y ]]; then
    printf '  Update skipped.\n'; return 0
  fi
  status=$(git -C "$repo" status --porcelain 2>/dev/null) || { printf '  Could not check local changes.\n'; return 1; }
  if [[ -n "$status" ]]; then
    printf '  \033[31m✗ Local changes detected. Update cancelled.\033[0m\n'; return 1
  fi
  printf '\n\033[1m  ◆ INSTALLATION PROGRESS\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '    \033[1;32m✓\033[0m  [1/3] Repository checked\n'
  printf '    \033[1;32m✓\033[0m  [2/3] %s commit(s) ready\n' "$count"
  printf '    \033[36m●\033[0m  [3/3] Installing %s → %s ...\n' "$local_rev" "$remote_rev"
  local merge_output
  if merge_output=$(git -C "$repo" merge --quiet --ff-only FETCH_HEAD 2>&1); then
    printf '\r\033[2K    \033[1;32m✓\033[0m  [3/3] Installation complete\n'
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ UPDATE INSTALLED\033[0m                      │\n'
    printf '  │  New revision: \033[1;32m%-7s\033[0m                   │\n' "$remote_rev"
    printf '  │  Reloading m³ with the new version...    │\n'
    printf '  └──────────────────────────────────────────┘\n'
    M3_RESTART_REQUIRED=1
  else
    printf '    \033[31m✗\033[0m  [3/3] Installation failed\n'
    printf '    %s\n' "$merge_output"
    return 1
  fi
}

main_menu() {
  local cursor=0 key next secret_count=0
  local -a items=('System diagnostics' 'Workstation health check' 'DevOps Tool Manager' 'DevOps Project Manager' 'Container Manager' 'Update m³' 'Settings' 'Info' 'Exit')
  local -a icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  while true; do
    printf '\033[H\033[2J'
    print_header 'DevOps Workstation Setup'
    for i in "${!items[@]}"; do
      if (( i == cursor )); then
        printf '\033[32m >\033[0m  \033[36m%s\033[0m  %s\n' "${icons[i]}" "${items[i]}"
      else
        printf '    \033[2m%s\033[0m  %s\n' "${icons[i]}" "${items[i]}"
      fi
    done
    printf '\n↑/↓ Navigate  Enter Select\n'
    IFS= read -rsn1 key || return 0
    if [[ "$key" == m ]]; then
      secret_count=$((secret_count + 1))
      if (( secret_count == 3 )); then
        matrix_easter_egg
        secret_count=0
      fi
      continue
    fi
    secret_count=0
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
          1) bash "$SCRIPT_DIR/health-check.sh" || printf 'Health check failed.\n'; pause_menu || return 0 ;;
          2) select_tools ;;
          3) bash "$SCRIPT_DIR/project-manager.sh" || printf 'Project scan failed.\n' ;;
          4) bash "$SCRIPT_DIR/container-manager.sh" || { printf "Container Manager failed.\n"; pause_menu; } ;;
          5) if update_m3; then for seconds in 3 2 1; do printf '\r  Returning to main menu in %s... ' "$seconds"; sleep 1; done; printf '\n'; if [[ "${M3_RESTART_REQUIRED:-0}" == 1 ]]; then exec bash "$SCRIPT_DIR/m3.sh"; fi; else pause_menu || return 0; fi ;;
          6) show_settings_page; pause_menu || return 0 ;;
          7) show_settings; pause_menu || return 0 ;;
          8) return 0 ;;
        esac
        ;;
    esac
  done
}

main_menu
printf 'Goodbye from m³.\n'
\r' ]] && break
  done
  printf '\n'
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
    print_header 'DevOps Tool Manager'
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
      printf '\033[32m >\033[0m     Automatic installation preview\n'
    else
      printf '       Automatic installation preview\n'
    fi
    if (( cursor == ${#tools[@]} + 1 )); then
      printf '\033[32m >\033[0m     Update Check\n'
    else
      printf '       Update Check\n'
    fi
    if (( cursor == ${#tools[@]} + 2 )); then
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
              A) cursor=$(( (cursor + ${#tools[@]}) % (${#tools[@]} + 3) )) ;;
              B) cursor=$(( (cursor + 1) % (${#tools[@]} + 3) )) ;;
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
        if (( cursor == ${#tools[@]} + 2 )); then return; fi
        printf '\033[H\033[2J'
        if (( cursor == ${#tools[@]} )); then
          bash "$SCRIPT_DIR/preview-install.sh" || printf 'Preview failed.\n'
        elif (( cursor == ${#tools[@]} + 1 )); then
          bash "$SCRIPT_DIR/update-check.sh" || printf 'Update check failed.\n'
        else
          preview_selected
        fi
        pause_menu || return
        ;;
    esac
  done
}

print_link() {
  local url="$1"
  # OSC 8 hyperlinks are clickable in supporting terminal emulators.
  # The full URL remains visible and can be copied in other terminals.
  if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
    printf '\033]8;;%s\033\\033[4;34m%s\033[0m\033]8;;\033\\' "$url" "$url"
  else
    printf '%s' "$url"
  fi
}

show_settings() {
  local revision='unavailable'
  if command -v git >/dev/null 2>&1; then
    revision="$(git -C "$SCRIPT_DIR/.." rev-parse --short HEAD 2>/dev/null)" || revision='unavailable'
  fi
  print_header 'Info'
  printf '\033[1m  ABOUT m³\033[0m\n'
  printf '  %-15s %s\n' 'Version' 'v0.1 (development)'
  printf '  %-15s %s\n' 'Revision' "$revision"
  printf '  %-15s %s\n' 'Platform' 'Linux · Bluefin first'
  printf '  %-15s %s\n' 'Mode' 'Read-only / installation simulation'
  printf '  %-15s %s\n\n' 'License' 'MIT'
  printf '\033[1m  PROJECT\033[0m\n'
  printf '  %-15s ' 'Repository'
  print_link 'https://github.com/arndthb/m3-devops'
  printf '\n'
  printf '  %-15s %s\n\n' 'Updates' 'm3 update'
  printf '\033[1m  AUTHOR\033[0m\n'
  printf '  Arndt H. Bohrenkämper\n'
  printf '  GitHub: '
  print_link 'https://github.com/arndthb'
  printf '\n'
  printf '  Independent open-source project · 2026\n\n'
  printf '\033[2m  No configuration changes are available yet.\033[0m\n'
}


m3_icon_mode() {
  local config="$HOME/.config/m3/icon-mode"
  if [[ -r "$config" ]] && [[ "$(head -n 1 "$config")" == nerd ]]; then
    printf nerd
  else
    printf classic
  fi
}

show_settings_page() {
  local key mode config="$HOME/.config/m3/icon-mode"
  while true; do
    printf '\033[H\033[2J'
    print_header 'Settings'
    mode="$(m3_icon_mode)"
    printf '  Icon style: %s\n' "$mode"
    printf '  Nerd Font mode requires a Nerd Font selected in your terminal.\n'
    printf '  No fonts are downloaded or installed by m³.\n\n'
    printf '  [n] Nerd Font icons   [c] Classic markers   [Enter] Back\n'
    IFS= read -rsn1 key || return 0
    case "$key" in
      n|N|c|C)
        mkdir -p "$HOME/.config/m3" || return 1
        if [[ "$key" == n || "$key" == N ]]; then printf 'nerd\n' > "$config"
        else printf 'classic\n' > "$config"; fi ;;
      '') return 0 ;;
      $'\033') return 0 ;;
    esac
  done
}


matrix_easter_egg() {
  local frame row col char
  printf '\033[?25l'
  for ((frame=0; frame<28; frame++)); do
    printf '\033[H\033[2J\033[1;32m  m³ // THE MATRIX\033[0m\n\n'
    for ((row=0; row<12; row++)); do
      printf '  '
      for ((col=0; col<48; col++)); do
        if (( (row + frame + col * 7) % 13 < 5 )); then
          char=$((RANDOM % 2))
          printf '\033[32m%s' "$char"
        else
          printf ' '
        fi
      done
      printf '\033[0m\n'
    done
    sleep 0.09
  done
  printf '\033[H\033[2J\033[?25h'
  print_header 'Secret mode unlocked'
  printf '\033[1;32m  WAKE UP, DEVOPS.\033[0m\n\n'
  printf '%s\n' '  There is no cloud.' "  It's just someone else's computer."
  sleep 7
}

update_m3() {
  M3_RESTART_REQUIRED=0
  local repo branch local_rev remote_rev answer status count
  repo="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  printf '\033[H\033[2J'
  print_header 'Check m³ Updates'
  printf '\033[1m  ◆ M3 UPDATE CENTER\033[0m\n'
  printf '  Channel: \033[36mmain\033[0m   Source: GitHub\n'
  printf '  ──────────────────────────────────────────────\n'
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$repo/.git" ]]; then
    printf '  \033[31m✗ Git checkout unavailable.\033[0m\n'; return 1
  fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=''
  if [[ "$branch" != main ]]; then
    printf '  \033[31m✗ Expected main; current: %s\033[0m\n' "${branch:-detached}"; return 1
  fi
  local_rev=$(git -C "$repo" rev-parse --short=7 HEAD 2>/dev/null) || return 1
  printf '\n  \033[36m◌ Checking for updates...\033[0m\n'
  if ! git -C "$repo" fetch --quiet origin main; then
    printf '  \033[31m✗ Could not check for updates.\033[0m\n'; return 1
  fi
  remote_rev=$(git -C "$repo" rev-parse --short=7 FETCH_HEAD 2>/dev/null) || return 1
  printf '\n\033[1m  ◆ VERSION COMPARISON\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '  Installed     \033[36m%s\033[0m\n' "$local_rev"
  printf '  Available     \033[1;32m%s\033[0m\n' "$remote_rev"
  printf '\n\033[1m  ◆ CHANGELOG\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  if [[ "$local_rev" == "$remote_rev" ]]; then
    printf '    No new commits.\n\n'
    printf '    Latest commit\n'
    git -C "$repo" log -1 --format='    %h  %s' HEAD 2>/dev/null
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ ALL UP TO DATE\033[0m                        │\n'
    printf '  │  No new updates available.               │\n'
    printf '  └──────────────────────────────────────────┘\n'
    return 0
  fi
  if ! git -C "$repo" merge-base --is-ancestor HEAD FETCH_HEAD; then
    printf '  \033[31m✗ Branches diverged or local revision is ahead.\033[0m\n'
    printf '  No automatic update.\n'; return 1
  fi
  count=$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null) || return 1
  printf '  \033[1;32m%s new commit(s)\033[0m · newest first\n\n' "$count"
  git -C "$repo" log -8 --format='  %h  %s' HEAD..FETCH_HEAD 2>/dev/null
  if (( count > 8 )); then printf '  ... and %s more\n' "$((count - 8))"; fi
  printf '\n  ┌──────────────────────────────────────────┐\n'
  printf '  │  \033[1;33m● UPDATE AVAILABLE\033[0m                      │\n'
  printf '  └──────────────────────────────────────────┘\n'
  printf '  Install this update now? [y/N] '
  IFS= read -r answer || return 1
  if [[ "$answer" != y && "$answer" != Y ]]; then
    printf '  Update skipped.\n'; return 0
  fi
  status=$(git -C "$repo" status --porcelain 2>/dev/null) || { printf '  Could not check local changes.\n'; return 1; }
  if [[ -n "$status" ]]; then
    printf '  \033[31m✗ Local changes detected. Update cancelled.\033[0m\n'; return 1
  fi
  printf '\n\033[1m  ◆ INSTALLATION PROGRESS\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '    \033[1;32m✓\033[0m  [1/3] Repository checked\n'
  printf '    \033[1;32m✓\033[0m  [2/3] %s commit(s) ready\n' "$count"
  printf '    \033[36m●\033[0m  [3/3] Installing %s → %s ...\n' "$local_rev" "$remote_rev"
  local merge_output
  if merge_output=$(git -C "$repo" merge --quiet --ff-only FETCH_HEAD 2>&1); then
    printf '\r\033[2K    \033[1;32m✓\033[0m  [3/3] Installation complete\n'
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ UPDATE INSTALLED\033[0m                      │\n'
    printf '  │  New revision: \033[1;32m%-7s\033[0m                   │\n' "$remote_rev"
    printf '  │  Reloading m³ with the new version...    │\n'
    printf '  └──────────────────────────────────────────┘\n'
    M3_RESTART_REQUIRED=1
  else
    printf '    \033[31m✗\033[0m  [3/3] Installation failed\n'
    printf '    %s\n' "$merge_output"
    return 1
  fi
}

main_menu() {
  local cursor=0 old_cursor key next secret_count=0
  local -a items=('System diagnostics' 'Workstation health check' 'DevOps Tool Manager' 'DevOps Project Manager' 'Container Manager' 'Update m³' 'Settings' 'Info' 'Exit')
  local -a icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]')
  local -a nerd_icons=('󰍹' '󰓅' '󰒓' '󰉋' '󰡨' '󰚰' '󰒓' '󰋼' '󰈆')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  render_menu_row() {
    local index="$1"
    local row=$((8 + index))
    printf '\033[%d;1H\033[2K' "$row"
    if (( index == cursor )); then
      printf '\033[32m >\033[0m  \033[36m%s\033[0m  %s' "${icons[index]}" "${items[index]}"
    else
      printf '    \033[2m%s\033[0m  %s' "${icons[index]}" "${items[index]}"
    fi
  }
  printf '\033[H\033[2J'
  print_header 'DevOps Workstation Setup'
  if [[ "$(m3_icon_mode)" == nerd ]]; then icons=("${nerd_icons[@]}"); else icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]'); fi
  for i in "${!items[@]}"; do render_menu_row "$i"; printf '\n'; done
  printf '\n↑/↓ Navigate  Enter Select\n'
  while true; do
    IFS= read -rsn1 key || return 0
    if [[ "$key" == m ]]; then
      secret_count=$((secret_count + 1))
      if (( secret_count == 3 )); then
        matrix_easter_egg
        secret_count=0
      fi
      continue
    fi
    secret_count=0
    case "$key" in
      $'\033')
        if IFS= read -rsn1 -t 0.15 next; then
          if [[ "$next" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 next || continue
            case "$next" in
              A) old_cursor=$cursor; cursor=$(( (cursor + ${#items[@]} - 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor" ;;
              B) old_cursor=$cursor; cursor=$(( (cursor + 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor" ;;
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
          1) bash "$SCRIPT_DIR/health-check.sh" || printf 'Health check failed.\n'; pause_menu || return 0 ;;
          2) select_tools ;;
          3) bash "$SCRIPT_DIR/project-manager.sh" || printf 'Project scan failed.\n' ;;
          4) bash "$SCRIPT_DIR/container-manager.sh" || { printf "Container Manager failed.\n"; pause_menu; } ;;
          5) if update_m3; then for seconds in 3 2 1; do printf '\r  Returning to main menu in %s... ' "$seconds"; sleep 1; done; printf '\n'; if [[ "${M3_RESTART_REQUIRED:-0}" == 1 ]]; then exec bash "$SCRIPT_DIR/m3.sh"; fi; else pause_menu || return 0; fi ;;
          6) show_settings_page ;;
          7) show_settings; pause_menu || return 0 ;;
          8) return 0 ;;
        esac
        ;;
    esac
  done
}

main_menu
printf 'Goodbye from m³.\n'
\033') return 0 ;;
    esac
  done
}



matrix_easter_egg() {
  local frame row col char
  printf '\033[?25l'
  for ((frame=0; frame<28; frame++)); do
    printf '\033[H\033[2J\033[1;32m  m³ // THE MATRIX\033[0m\n\n'
    for ((row=0; row<12; row++)); do
      printf '  '
      for ((col=0; col<48; col++)); do
        if (( (row + frame + col * 7) % 13 < 5 )); then
          char=$((RANDOM % 2))
          printf '\033[32m%s' "$char"
        else
          printf ' '
        fi
      done
      printf '\033[0m\n'
    done
    sleep 0.09
  done
  printf '\033[H\033[2J\033[?25h'
  print_header 'Secret mode unlocked'
  printf '\033[1;32m  WAKE UP, DEVOPS.\033[0m\n\n'
  printf '%s\n' '  There is no cloud.' "  It's just someone else's computer."
  sleep 7
}

update_m3() {
  M3_RESTART_REQUIRED=0
  local repo branch local_rev remote_rev answer status count
  repo="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  printf '\033[H\033[2J'
  print_header 'Check m³ Updates'
  printf '\033[1m  ◆ M3 UPDATE CENTER\033[0m\n'
  printf '  Channel: \033[36mmain\033[0m   Source: GitHub\n'
  printf '  ──────────────────────────────────────────────\n'
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$repo/.git" ]]; then
    printf '  \033[31m✗ Git checkout unavailable.\033[0m\n'; return 1
  fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=''
  if [[ "$branch" != main ]]; then
    printf '  \033[31m✗ Expected main; current: %s\033[0m\n' "${branch:-detached}"; return 1
  fi
  local_rev=$(git -C "$repo" rev-parse --short=7 HEAD 2>/dev/null) || return 1
  printf '\n  \033[36m◌ Checking for updates...\033[0m\n'
  if ! git -C "$repo" fetch --quiet origin main; then
    printf '  \033[31m✗ Could not check for updates.\033[0m\n'; return 1
  fi
  remote_rev=$(git -C "$repo" rev-parse --short=7 FETCH_HEAD 2>/dev/null) || return 1
  printf '\n\033[1m  ◆ VERSION COMPARISON\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '  Installed     \033[36m%s\033[0m\n' "$local_rev"
  printf '  Available     \033[1;32m%s\033[0m\n' "$remote_rev"
  printf '\n\033[1m  ◆ CHANGELOG\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  if [[ "$local_rev" == "$remote_rev" ]]; then
    printf '    No new commits.\n\n'
    printf '    Latest commit\n'
    git -C "$repo" log -1 --format='    %h  %s' HEAD 2>/dev/null
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ ALL UP TO DATE\033[0m                        │\n'
    printf '  │  No new updates available.               │\n'
    printf '  └──────────────────────────────────────────┘\n'
    return 0
  fi
  if ! git -C "$repo" merge-base --is-ancestor HEAD FETCH_HEAD; then
    printf '  \033[31m✗ Branches diverged or local revision is ahead.\033[0m\n'
    printf '  No automatic update.\n'; return 1
  fi
  count=$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null) || return 1
  printf '  \033[1;32m%s new commit(s)\033[0m · newest first\n\n' "$count"
  git -C "$repo" log -8 --format='  %h  %s' HEAD..FETCH_HEAD 2>/dev/null
  if (( count > 8 )); then printf '  ... and %s more\n' "$((count - 8))"; fi
  printf '\n  ┌──────────────────────────────────────────┐\n'
  printf '  │  \033[1;33m● UPDATE AVAILABLE\033[0m                      │\n'
  printf '  └──────────────────────────────────────────┘\n'
  printf '  Install this update now? [y/N] '
  IFS= read -r answer || return 1
  if [[ "$answer" != y && "$answer" != Y ]]; then
    printf '  Update skipped.\n'; return 0
  fi
  status=$(git -C "$repo" status --porcelain 2>/dev/null) || { printf '  Could not check local changes.\n'; return 1; }
  if [[ -n "$status" ]]; then
    printf '  \033[31m✗ Local changes detected. Update cancelled.\033[0m\n'; return 1
  fi
  printf '\n\033[1m  ◆ INSTALLATION PROGRESS\033[0m\n'
  printf '  ──────────────────────────────────────────────\n'
  printf '    \033[1;32m✓\033[0m  [1/3] Repository checked\n'
  printf '    \033[1;32m✓\033[0m  [2/3] %s commit(s) ready\n' "$count"
  printf '    \033[36m●\033[0m  [3/3] Installing %s → %s ...\n' "$local_rev" "$remote_rev"
  local merge_output
  if merge_output=$(git -C "$repo" merge --quiet --ff-only FETCH_HEAD 2>&1); then
    printf '\r\033[2K    \033[1;32m✓\033[0m  [3/3] Installation complete\n'
    printf '\n  ┌──────────────────────────────────────────┐\n'
    printf '  │  \033[1;32m✓ UPDATE INSTALLED\033[0m                      │\n'
    printf '  │  New revision: \033[1;32m%-7s\033[0m                   │\n' "$remote_rev"
    printf '  │  Reloading m³ with the new version...    │\n'
    printf '  └──────────────────────────────────────────┘\n'
    M3_RESTART_REQUIRED=1
  else
    printf '    \033[31m✗\033[0m  [3/3] Installation failed\n'
    printf '    %s\n' "$merge_output"
    return 1
  fi
}

main_menu() {
  local cursor=0 key next secret_count=0
  local -a items=('System diagnostics' 'Workstation health check' 'DevOps Tool Manager' 'DevOps Project Manager' 'Container Manager' 'Update m³' 'Settings' 'Info' 'Exit')
  local -a icons=('[S]' '[H]' '[T]' '[P]' '[C]' '[U]' '[G]' '[i]' '[X]')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  while true; do
    printf '\033[H\033[2J'
    print_header 'DevOps Workstation Setup'
    for i in "${!items[@]}"; do
      if (( i == cursor )); then
        printf '\033[32m >\033[0m  \033[36m%s\033[0m  %s\n' "${icons[i]}" "${items[i]}"
      else
        printf '    \033[2m%s\033[0m  %s\n' "${icons[i]}" "${items[i]}"
      fi
    done
    printf '\n↑/↓ Navigate  Enter Select\n'
    IFS= read -rsn1 key || return 0
    if [[ "$key" == m ]]; then
      secret_count=$((secret_count + 1))
      if (( secret_count == 3 )); then
        matrix_easter_egg
        secret_count=0
      fi
      continue
    fi
    secret_count=0
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
          1) bash "$SCRIPT_DIR/health-check.sh" || printf 'Health check failed.\n'; pause_menu || return 0 ;;
          2) select_tools ;;
          3) bash "$SCRIPT_DIR/project-manager.sh" || printf 'Project scan failed.\n' ;;
          4) bash "$SCRIPT_DIR/container-manager.sh" || { printf "Container Manager failed.\n"; pause_menu; } ;;
          5) if update_m3; then for seconds in 3 2 1; do printf '\r  Returning to main menu in %s... ' "$seconds"; sleep 1; done; printf '\n'; if [[ "${M3_RESTART_REQUIRED:-0}" == 1 ]]; then exec bash "$SCRIPT_DIR/m3.sh"; fi; else pause_menu || return 0; fi ;;
          6) show_settings_page; pause_menu || return 0 ;;
          7) show_settings; pause_menu || return 0 ;;
          8) return 0 ;;
        esac
        ;;
    esac
  done
}

main_menu
printf 'Goodbye from m³.\n'
