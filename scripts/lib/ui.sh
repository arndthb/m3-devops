#!/usr/bin/env bash
# Shared presentation helpers for m³ terminal menus (no commands, no side effects).

# Only emit Kitty graphics in terminals known to implement the protocol.
# Other terminals retain the Unicode superscript ³ (no raw escape garbage).
m3_ui_kitty_supported() {
  [[ -n "${KITTY_WINDOW_ID:-}${WEZTERM_PANE:-}${GHOSTTY_RESOURCES_DIR:-}" || "${TERM:-}" == xterm-kitty ]] && command -v python3 >/dev/null 2>&1
}

m3_ui_graphic_three() {
  m3_ui_kitty_supported || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 "$M3_UI_LIB_DIR/logo-graphics.py" 2>/dev/null || true
}

M3_UI_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

m3_ui_terminal_size() {
  read -r M3_ROWS M3_COLS < <(stty size 2>/dev/null || printf '24 80\n')
  [[ "${M3_ROWS:-}" =~ ^[0-9]+$ ]] || M3_ROWS=24
  [[ "${M3_COLS:-}" =~ ^[0-9]+$ ]] || M3_COLS=80
  (( M3_ROWS >= 1 )) || M3_ROWS=24
  (( M3_COLS >= 1 )) || M3_COLS=80
}

m3_ui_icon_mode() {
  local config="$HOME/.config/m3/icon-mode"
  if [[ -r "$config" ]] && [[ "$(head -n 1 "$config")" == nerd ]]; then
    printf 'nerd'
  else
    printf 'classic'
  fi
}

m3_ui_clean_text() {
  local value="$1"
  value="${value//$'\033'/}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//$'\t'/ }"
  printf '%s' "$value"
}

# Exactly seven terminal rows so menus can render from row eight onward.
m3_ui_header() {
  local section="$1" subtitle="${2:-READ-ONLY}" cols="${3:-80}"
  section="$(m3_ui_clean_text "$section")"
  subtitle="$(m3_ui_clean_text "$subtitle")"
  printf '\033[?25l\033[H\033[2J'
  if (( cols >= 56 )); then
    local raised_three='³'
    if m3_ui_kitty_supported; then raised_three=' '; fi
    printf '\033[1;32m  ███╗   ███╗%s\033[0m   \033[1;37mDEVOPS\033[0m\n' "$raised_three"
    printf '\033[1;32m  ████╗ ████║ \033[0m   \033[1;37mWORKSTATION\033[0m\n'
    printf '\033[1;32m  ██╔████╔██║ \033[0m   \033[2m%-28.28s\033[0m\n' "$subtitle"
    printf '\033[1;32m  ██║╚██╔╝██║ \033[0m\n'
    printf '\033[1;32m  ╚═╝ ╚═╝ ╚═╝ \033[0m   \033[36m%-28.28s\033[0m\n' "$section"
    m3_ui_graphic_three\n    printf '\033[32m  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n\n'
  else
    printf '\033[1;32m  m³ DEVOPS WORKSTATION\033[0m\n'
    printf '  %-28.28s\n' "$section"
    printf '  %-28.28s\n' "$subtitle"
    printf '\n\n'
    printf '  ━━━━━━━━━━━━━━━━━━━━━━━\n\n'
  fi
}

# Print one selected or unselected row at a fixed position.
m3_ui_row() {
  local row="$1" selected="$2" icon="$3" label="$4"
  label="$(m3_ui_clean_text "$label")"
  printf '\033[%d;1H\033[2K' "$row"
  if (( selected )); then
    printf '  \033[1;30;42m ▸ \033[0m \033[1;32m%s\033[0m  \033[1;37m%s\033[0m' "$icon" "$label"
  else
    printf '      \033[2;36m%s\033[0m  %s' "$icon" "$label"
  fi
}
