#!/usr/bin/env bash
# m³ interactive menu — diagnostics read-only; selected package installs require confirmation.
set -u

# Keep the terminal cursor out of the interactive menu.
if [[ -t 1 ]]; then
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT HUP INT TERM
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tool-install.sh
source "$SCRIPT_DIR/lib/tool-install.sh"
# shellcheck source=lib/tool-detect.sh
source "$SCRIPT_DIR/lib/tool-detect.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
mapfile -t tools < <(m3_tool_catalog)
selected=()
for tool in "${tools[@]}"; do selected+=(0); done

is_installed() {
  m3_tool_present "$1"
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
}

m3_open_terminal() {
  local executable="$1" terminal=""
  if command -v ptyxis >/dev/null 2>&1; then
    terminal=ptyxis
  elif command -v gnome-terminal >/dev/null 2>&1; then
    terminal=gnome-terminal
  elif command -v kgx >/dev/null 2>&1; then
    terminal=kgx
  elif command -v xterm >/dev/null 2>&1; then
    terminal=xterm
  else
    printf '  No supported terminal emulator found (Ptyxis, GNOME Terminal, Console or xterm).\n'
    return 1
  fi
  # Pass the executable as an argument, never interpolate it into a shell command.
  case "$terminal" in
    ptyxis) ptyxis --new-window -- "$executable" >/dev/null 2>&1 & ;;
    gnome-terminal) gnome-terminal -- "$executable" >/dev/null 2>&1 & ;;
    kgx) kgx -- "$executable" >/dev/null 2>&1 & ;;
    xterm) xterm -e "$executable" >/dev/null 2>&1 & ;;
  esac
  disown
  printf '  Opened %s in a separate terminal window.\n' "$(basename "$executable")"
}

m3_launch_tool() {
  local tool="$1" cmd=""
  if ! m3_tool_present "$tool"; then
    printf '  %s is not installed. Select it with Space to install.\n' "$(m3_tool_label "$tool")"
    return 1
  fi
  printf '  %s\n\n' "$(m3_tool_label "$tool")"
  case "$tool" in
    codium)
      if command -v codium >/dev/null 2>&1; then
        nohup codium >/dev/null 2>&1 </dev/null & disown
      elif command -v flatpak >/dev/null 2>&1; then
        nohup flatpak run com.vscodium.codium >/dev/null 2>&1 </dev/null & disown
      else
        printf '  VSCodium launcher not found.\n'; return 1
      fi
      printf '  VSCodium launch requested.\n' ;;
    chatgpt)
      if command -v chatgpt >/dev/null 2>&1; then
        nohup chatgpt >/dev/null 2>&1 </dev/null & disown
        printf '  ChatGPT launch requested.\n'
      elif command -v gtk-launch >/dev/null 2>&1 && [[ -f /usr/share/applications/chatgpt.desktop ]]; then
        nohup gtk-launch chatgpt >/dev/null 2>&1 </dev/null & disown
        printf '  ChatGPT launch requested.\n'
      else
        printf '  ChatGPT is detected, but no supported launcher was found.\n'; return 1
      fi ;;
    hermes)
      if command -v hermes >/dev/null 2>&1; then cmd="$(command -v hermes)"
      elif [[ -x "$HOME/.local/bin/hermes" ]]; then cmd="$HOME/.local/bin/hermes"
      elif command -v hermes-agent >/dev/null 2>&1; then cmd="$(command -v hermes-agent)"
      else printf '  Hermes launcher not found.\n'; return 1; fi
      m3_open_terminal "$cmd" ;;
    codex)
      if command -v codex >/dev/null 2>&1; then cmd="$(command -v codex)"
      elif [[ -x "$HOME/.local/bin/codex" ]]; then cmd="$HOME/.local/bin/codex"
      else printf '  Codex launcher not found.\n'; return 1; fi
      m3_open_terminal "$cmd" ;;
    git) git --version ;;
    podman) podman --version ;;
    distrobox) distrobox --version ;;
    kubectl) kubectl version --client ;;
    go) go version ;;
    terraform)
      if command -v terraform >/dev/null 2>&1; then terraform version
      else "$HOME/.local/bin/terraform" version; fi ;;
    docker) docker --version ;;
    compose)
      if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then docker compose version
      elif command -v docker-compose >/dev/null 2>&1; then docker-compose version
      elif command -v podman-compose >/dev/null 2>&1; then podman-compose --version
      else printf '  Compose launcher not found.\n'; return 1; fi ;;
    kind)
      if command -v kind >/dev/null 2>&1; then kind version
      else "$HOME/.local/bin/kind" version; fi ;;
    make) make --version | head -n 1 ;;
    curl) curl --version | head -n 1 ;;
    nerdfont) printf '  A font cannot be launched. Select it in your terminal font preferences.\n' ;;
    *) printf '  No launch action configured for this tool.\n'; return 1 ;;
  esac
}

select_tools() {
  local key next i cursor=0 page_size rows cols page_start row index total
  local name state line checked tool old_cursor old_page_start redraw=1
  local -a actions=('Install selected' 'Automatic installation preview' 'Update Check' 'Workstation readiness' 'Docker & Compose' 'Back to main menu')
  total=$(( ${#tools[@]} + ${#actions[@]} ))
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'Interactive selection requires a terminal.\n'
    return
  fi
  render_tool_rows() {
    for index in "$@"; do
      ((index>=page_start && index<page_start+page_size)) || continue
      row=$((10+index-page_start))
      printf '\033[%d;1H\033[2K' "$row"
      ((index<total)) || continue
      if (( index < ${#tools[@]} )); then
        tool="${tools[index]}"
        if is_installed "$tool"; then
          selected[index]=0
          checked='[-]'
          state="\033[32mInstalled\033[0m ($(m3_tool_source "$tool"))"
        elif [[ "${selected[index]}" == 1 ]]; then
          checked='[x]'; state="\033[33mSelected\033[0m"
        else
          checked='[ ]'; state='Missing'
        fi
        name="$(m3_tool_label "$tool")"
        printf -v line '%s %-16s %b' "$checked" "$name" "$state"
      else
        checked=' ◆ '
        name="${actions[index-${#tools[@]}]}"
        line="$checked $name"
      fi
      # Avoid terminal autowrap: strip ANSI only for measuring visible width.
      local plain="$line" maxwidth=$((cols-9))
      plain="$(printf '%b' "$plain" | sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g')"
      if (( ${#plain} > maxwidth )); then
        # Render a compact, uncolored row instead of overflowing.
        line="${plain:0:maxwidth}"
      fi
      if ((index==cursor)); then
        printf '  \033[1;30;42m ▸ \033[0m  \033[1m%b\033[0m' "$line"
      else
        printf '       %b' "$line"
      fi
    done
  }
  while true; do
    # Pagination keeps every menu action reachable on a 24-row terminal.
    m3_ui_terminal_size
    rows="$M3_ROWS"; cols="$M3_COLS"
    page_size=$((rows-14)); ((page_size>0)) || page_size=1
    page_start=$((cursor/page_size*page_size))

    if (( redraw )); then
    m3_ui_header 'DevOps Tool Manager' 'TOOLCHAIN · HOST INVENTORY' "$cols"
    printf '\033[8;1H\033[2K     SELECT  %-16s  %s' 'TOOL' 'STATUS'
    printf '\033[9;1H\033[2K  ──────────────────────────────────────────'
    for ((i=page_start; i<page_start+page_size && i<total; i++)); do
      render_tool_rows "$i"
    done
    printf '\033[%d;1H\033[2K  %d–%d / %d entries' "$((rows-3))" \
      "$((page_start+1))" "$((page_start+page_size<total?page_start+page_size:total))" "$total"
    printf '\033[%d;1H\033[2K  [-] Installed · [x] Selected · [ ] Missing' "$((rows-2))"
    printf '\033[%d;1H\033[2K  ↑/↓ Navigate  Space Select  Enter Launch/Open  Esc Back' "$((rows-1))"
    redraw=0
    fi

    IFS= read -rsn1 key || return
    old_cursor=$cursor
    old_page_start=$page_start
    case "$key" in
      "$(printf '\033')")
        # CSI (ESC [ A/B) and SS3 (ESC O A/B) arrow sequences.
        # Read the entire sequence before repainting; never echo leftover bytes.
        if IFS= read -rsn1 -t 0.5 next; then
          if [[ "$next" == '[' || "$next" == 'O' ]]; then
            if IFS= read -rsn1 -t 0.5 next; then
              case "$next" in
                A) cursor=$(( (cursor+total-1) % total )) ;;
                B) cursor=$(( (cursor+1) % total )) ;;
              esac
            fi
          fi
        else
          return
        fi ;;
      ' ')
        if ((cursor<${#tools[@]})) && ! is_installed "${tools[cursor]}"; then
          selected[cursor]=$((1-selected[cursor]))
        fi ;;
      '')
        if ((cursor==total-1)); then return; fi
        printf '\033[H\033[2J'
        if ((cursor<${#tools[@]})); then
          m3_launch_tool "${tools[cursor]}" || true
        elif ((cursor==${#tools[@]})); then
          preview_selected
        elif ((cursor==${#tools[@]}+1)); then
          bash "$SCRIPT_DIR/preview-install.sh" || printf 'Preview failed.\n'
        elif ((cursor==${#tools[@]}+2)); then
          bash "$SCRIPT_DIR/update-check.sh" || printf 'Update check failed.\n'
        elif ((cursor==${#tools[@]}+3)); then
          bash "$SCRIPT_DIR/setup-check.sh" || printf 'Readiness check failed.\n'
        elif ((cursor==${#tools[@]}+4)); then
          bash "$SCRIPT_DIR/docker-check.sh" || printf 'Docker check failed.\n'
        else
          return
        fi
        pause_menu || return
        redraw=1 ;;
      q|Q) return ;;
    esac
    if ((cursor/page_size*page_size != old_page_start)); then
      redraw=1
    elif (( ! redraw )); then
      render_tool_rows "$old_cursor" "$cursor"
    fi
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
  printf '  %-15s %s\n' 'Version' 'v0.2 (development)'
  printf '  %-15s %s\n' 'Revision' "$revision"
  printf '  %-15s %s\n' 'Platform' 'Linux · Fedora / Bluefin'
  printf '  %-15s %s\n' 'Mode' 'Inspection / confirmed package installs'
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
  local key mode config="$HOME/.config/m3/icon-mode" confirmation
  while true; do
    printf '\033[H\033[2J'
    print_header 'Settings'
    mode="$(m3_icon_mode)"
    printf '  Icon style: %s\n' "$mode"
    if m3_tool_present nerdfont; then
      printf '  JetBrainsMono Nerd Font: installed (fontconfig).\n'
    else
      printf '  JetBrainsMono Nerd Font: missing.\n'
    fi
    printf '  Uses compatible Nerd Font icons (BMP / Font Awesome).\n'\n    printf '  Terminal font may still need to be selected in terminal preferences.\n\n'
    printf '  [n] Nerd Font icons (install font if missing)\n'
    printf '  [c] Classic markers   [Enter] Back\n'
    IFS= read -rsn1 key || return 0
    case "$key" in
      n|N)
        if ! m3_tool_present nerdfont; then
          printf '\n  JetBrainsMono Nerd Font is missing.\n'
          printf '  Install to ~/.local/share/fonts/JetBrainsMonoNerd from Nerd Fonts GitHub.\n'
          printf '  Type INSTALL to proceed (Enter cancels): '
          IFS= read -r confirmation || return 1
          if [[ "$confirmation" != INSTALL ]]; then
            printf '  Installation cancelled.\n'
            pause_menu
            continue
          fi
          if ! m3_install_tool nerdfont "$confirmation" || ! m3_tool_present nerdfont; then
            printf '  Font installation failed or font not detected.\n'
            pause_menu
            continue
          fi
        fi
        mkdir -p "$HOME/.config/m3" || return 1
        printf 'nerd\n' > "$config" || return 1
        printf '  Nerd Font icons enabled.\n'
        ;;
      c|C)
        mkdir -p "$HOME/.config/m3" || return 1
        printf 'classic\n' > "$config" || return 1 ;;
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
    git --no-pager -C "$repo" log -1 --format='    %h  %s' HEAD 2>/dev/null
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
  git --no-pager -C "$repo" log -8 --format='  %h  %s' HEAD..FETCH_HEAD 2>/dev/null
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
  local cursor=0 old_cursor key next secret_count=0 row_step=1 term_rows=24 term_cols=80 app_index=0
  local -a app_names=('Hermes Agent' 'Codex CLI' 'VSCodium' 'ChatGPT Desktop')
  local -a app_tools=('hermes' 'codex' 'codium' 'chatgpt')
  local -a items=('System diagnostics' 'Workstation health check' 'DevOps Tool Manager' 'DevOps Project Manager' 'Container Manager' 'Applications' 'Update m³' 'Settings' 'Info' 'Exit')
  local -a icons=('[ S ]' '[ H ]' '[ T ]' '[ P ]' '[ C ]' '[ A ]' '[ U ]' '[ G ]' '[ i ]' '[ X ]')
  local -a nerd_icons=('[  ]' '[  ]' '[  ]' '[  ]' '[  ]' '[  ]' '[  ]' '[  ]' '[  ]' '[  ]')
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'm³ requires an interactive terminal for arrow-key navigation.\n' >&2
    return 1
  fi
  # The terminal owns font size; use block lettering, bold text and framed icons.
  print_main_banner() {
    if (( term_cols >= 56 )); then
      printf '\033[1;32m  ███╗   ███╗³\033[0m   \033[1;37mDEVOPS\033[0m\n'
      printf '\033[1;32m  ████╗ ████║ \033[0m   \033[1;37mWORKSTATION\033[0m\n'
      printf '\033[1;32m  ██╔████╔██║ \033[0m   \033[2mBUILD · RUN · SHIP\033[0m\n'
      printf '\033[1;32m  ██║╚██╔╝██║ \033[0m   \033[2mLinux / Fedora\033[0m\n'
      printf '\033[1;32m  ╚═╝ ╚═╝ ╚═╝ \033[0m   \033[36mDevOps Workstation Setup\033[0m\n'
      printf '\033[32m  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n\n'
    else
      printf '\033[1;32m  m³ DEVOPS WORKSTATION\033[0m\n'
      printf '  DevOps Workstation Setup\n\n\n\n'
      printf '  ━━━━━━━━━━━━━━━━━━━━━━━\n\n'
    fi
  }
  render_menu_row() {
    local index="$1"
    local row=$((8 + index * row_step + (index > 5 ? 1 : 0)))
    printf '\033[%d;1H\033[2K' "$row"
    if (( index == cursor )); then
      printf '  \033[1;30;42m ▸ \033[0m \033[1;32m%s\033[0m  \033[1;37m%s\033[0m' "${icons[index]}" "${items[index]}"
    else
      printf '      \033[2;36m%s\033[0m  %s' "${icons[index]}" "${items[index]}"
    fi
  }
  render_app_choice() {
    local row=$((8 + 5 * row_step + 1))
    local i label
    printf '\033[%d;1H\033[2K' "$row"
    printf '       '
    for i in "${!app_names[@]}"; do
      label="${app_names[i]}"
      if (( term_cols < 76 )); then
        case "$i" in
          0) label='Hermes' ;;
          1) label='Codex' ;;
          2) label='VSCodium' ;;
          3) label='ChatGPT' ;;
        esac
      fi
      if (( i == app_index && cursor == 5 )); then
        printf '\033[1;30;42m %s \033[0m' "$label"
      elif (( i == app_index )); then
        printf '\033[1;32m %s \033[0m' "$label"
      else
        printf '\033[2m %s \033[0m' "$label"
      fi
      if (( i < ${#app_names[@]} - 1 )); then printf ' '; fi
    done
  }
  render_main_menu() {
    read -r term_rows term_cols < <(stty size 2>/dev/null || printf '24 80\n')
    (( term_rows > 0 )) || term_rows=24
    (( term_cols > 0 )) || term_cols=80
    row_step=1
    if (( term_rows >= 32 && term_cols >= 65 )); then row_step=2; fi
    printf '\033[?25l\033[H\033[2J'
    print_main_banner
    if [[ "$(m3_icon_mode)" == nerd ]]; then
      icons=("${nerd_icons[@]}")
    else
      icons=('[ S ]' '[ H ]' '[ T ]' '[ P ]' '[ C ]' '[ A ]' '[ U ]' '[ G ]' '[ i ]' '[ X ]')
    fi
    for i in "${!items[@]}"; do
      render_menu_row "$i"
    done
    render_app_choice
    printf '\033[%d;1H\033[2K\033[2m  ↑/↓ Menu  ←/→ Applications  Enter Launch/Open  Esc Exit\033[0m' "$((8 + ${#items[@]} * row_step + 2))"
  }
  render_main_menu
  while true; do
    IFS= read -rsn1 key || return 0
    if [[ "$key" == m ]]; then
      secret_count=$((secret_count + 1))
      if (( secret_count == 3 )); then
        matrix_easter_egg
        secret_count=0
        render_main_menu
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
              A) old_cursor=$cursor; cursor=$(( (cursor + ${#items[@]} - 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor"; render_app_choice ;;
              B) old_cursor=$cursor; cursor=$(( (cursor + 1) % ${#items[@]} )); render_menu_row "$old_cursor"; render_menu_row "$cursor"; render_app_choice ;;
              C) if (( cursor == 5 )); then app_index=$(( (app_index+1) % ${#app_names[@]} )); render_app_choice; fi ;;
              D) if (( cursor == 5 )); then app_index=$(( (app_index+${#app_names[@]}-1) % ${#app_names[@]} )); render_app_choice; fi ;;
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
          5) m3_launch_tool "${app_tools[app_index]}" || true; pause_menu || return 0 ;;
          6) if update_m3; then for seconds in 3 2 1; do printf '\r  Returning to main menu in %s... ' "$seconds"; sleep 1; done; printf '\n'; if [[ "${M3_RESTART_REQUIRED:-0}" == 1 ]]; then exec bash "$SCRIPT_DIR/m3.sh"; fi; else pause_menu || return 0; fi ;;
          7) show_settings_page ;;
          8) show_settings; pause_menu || return 0 ;;
          9) return 0 ;;
        esac
        render_main_menu
        ;;
    esac
  done
}


preview_selected() {
  local i tool count=0 formula environment failures=0 cols width status hint
  m3_ui_terminal_size
  cols="$M3_COLS"
  width=$((cols-6))
  ((width>12)) || width=12
  local -a ready=() manual=()
  printf '\n\033[1m  ◆ SELECTED TOOLS — REVIEW\033[0m\n'
  printf '  Only tools explicitly selected with Space are considered.\n'
  printf '  Install selected starts installation for READY tools.\n\n'

  environment="$(m3_install_environment)" || true
  for i in "${!tools[@]}"; do
    [[ "${selected[i]}" == 1 ]] || continue
    tool="${tools[i]}"
    count=$((count + 1))
    if is_installed "$tool"; then
      printf '  %-14s Already installed; skipped\n' "$(m3_tool_label "$tool")"
    elif formula="$(m3_install_command "$tool")"; then
      if m3_install_environment >/dev/null; then
        printf '  %-14s \033[1;32mREADY\033[0m\n' "$(m3_tool_label "$tool")"
        printf '      %s\n' "${formula:0:width}"
        ready+=("$tool")
      else
        printf '  %-14s \033[1;33mBLOCKED\033[0m\n' "$(m3_tool_label "$tool")"
        printf '      %s\n' "${environment:0:width}"
      fi
    else
      hint="$(m3_tool_hint "$tool")"
      printf '  %-14s \033[1;33mMANUAL\033[0m\n' "$(m3_tool_label "$tool")"
      printf '      %s\n' "${hint:0:width}"
      manual+=("$tool")
    fi
  done

  if (( count == 0 )); then
    printf '  Nothing selected. Use Space on a missing tool first.\n'
    return 0
  fi
  printf '\n  %d selected · %d approved for installation\n' "$count" "${#ready[@]}"
  if (( ${#ready[@]} == 0 )); then
    if [[ " ${manual[*]} " == *" docker "* ]]; then
      printf '  Docker needs an OS-specific installation procedure.\n'
      printf '  Opening Docker & Compose guidance...\n\n'
      bash "$SCRIPT_DIR/docker-check.sh" || printf '  Docker guide could not be opened.\n'
      return 0
    fi
    printf '  No supported installation actions. Nothing changed.\n'
    return 0
  fi
  printf '\n\033[1m  ◆ SELECTED TOOL INSTALLATION\033[0m\n'
  for tool in "${ready[@]}"; do
    if ! m3_install_tool "$tool" INSTALL; then
      failures=$((failures + 1))
      printf '  Stopping: remaining tools will not be attempted.\n'
      break
    fi
  done
  printf '\n  Installation run finished · %d failed/blocked.\n' "$failures"
  printf '  Recheck tool status after returning to the menu.\n'
  (( failures == 0 ))
}

main_menu
printf 'Goodbye from m³.\n'
