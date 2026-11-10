#!/usr/bin/env bash
# m³ Container Manager — Podman inspection only. No system changes.
set -u

if [[ -t 1 ]]; then
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
items=('Containers' 'Images' 'Volumes' 'Networks' 'System disk usage' 'Back')
icons=('[ C ]' '[ I ]' '[ V ]' '[ N ]' '[ D ]' '[ ← ]')
nerd_icons=('[ 󰡨 ]' '[ 󰋊 ]' '[ 󰕫 ]' '[ 󰖟 ]' '[ 󰋊 ]' '[ ← ]')
cursor=0
row_step=1
term_rows=24
term_cols=80

pause() {
  printf '\n  Press Enter to return...'
  IFS= read -r _ || true
}

run_podman() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 8s podman "$@"
  else
    podman "$@"
  fi
}

icon_mode() {
  m3_ui_icon_mode
}

terminal_size() {
  m3_ui_terminal_size
  term_rows="$M3_ROWS"
  term_cols="$M3_COLS"
  row_step=1
  if (( term_rows >= 29 && term_cols >= 65 )); then row_step=2; fi
}

header() {
  m3_ui_header 'Container Manager' 'CONTAINERS · READ-ONLY' "$term_cols"
}

render_menu_row() {
  local index="$1" selected=0
  (( index == cursor )) && selected=1
  m3_ui_row "$((8 + index * row_step))" "$selected" "${icons[index]}" "${items[index]}"
}

render_menu() {
  terminal_size
  if [[ "$(icon_mode)" == nerd ]]; then
    icons=("${nerd_icons[@]}")
  else
    icons=('[ C ]' '[ I ]' '[ V ]' '[ N ]' '[ D ]' '[ ← ]')
  fi
  header
  for i in "${!items[@]}"; do
    render_menu_row "$i"
    if (( row_step == 2 )); then printf '\n\n'; else printf '\n'; fi
  done
  printf '\n\033[2m  ↑ / ↓ Navigate    •    Enter Select    •    Esc Back\033[0m\n'
}

show_volumes() {
  local output volume display kind total=0 anonymous=0
  printf '  %-34s %s\n' 'VOLUME NAME' 'TYPE'
  printf '  ──────────────────────────────────────────────\n'

  if ! output="$(run_podman volume ls --format '{{.Name}}' 2>/dev/null)"; then
    printf '  Could not retrieve volumes from Podman.\n'
    return 1
  fi
  if [[ -z "$output" ]]; then
    printf '  No local Podman volumes found.\n'
    return 0
  fi

  while IFS= read -r volume; do
    [[ -n "$volume" ]] || continue
    total=$((total + 1))
    kind='Named'
    display="$volume"
    # Podman may generate long hexadecimal names for anonymous volumes.
    if [[ "$volume" =~ ^[[:xdigit:]]{32,}$ ]]; then
      kind='Auto-generated'
      anonymous=$((anonymous + 1))
      display="${volume:0:16}..."
    elif (( ${#volume} > 32 )); then
      display="${volume:0:29}..."
    fi
    printf '  %-34s %s\n' "$display" "$kind"
  done <<< "$output"

  printf '\n  %d volume(s), %d automatically named.\n' "$total" "$anonymous"
  printf '  Long IDs are shortened for readability; no volumes are deleted.\n'
  printf '  For full details use: podman volume inspect <volume-name>\n'
}

show_details() {
  local selection="$1"
  header
  printf '\033[1m  ◆ %s\033[0m\n' "${items[selection]}"
  printf '  ──────────────────────────────────────────────\n\n'
  case "$selection" in
    0) run_podman ps --all --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' ;;
    1) run_podman images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' ;;
    2) show_volumes ;;
    3) run_podman network ls ;;
    4) run_podman system df ;;
  esac || printf '\n  Could not retrieve Podman data.\n'
  printf '\n  Inspection only · No containers or volumes changed.\n'
  pause
}

terminal_size
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

render_menu
while true; do
  IFS= read -rsn1 key || break
  case "$key" in
    $'\033')
      if IFS= read -rsn1 -t 0.15 next; then
        if [[ "$next" == '[' ]]; then
          IFS= read -rsn1 -t 0.15 next || continue
          old_cursor=$cursor
          case "$next" in
            A) cursor=$(( (cursor + ${#items[@]} - 1) % ${#items[@]} )) ;;
            B) cursor=$(( (cursor + 1) % ${#items[@]} )) ;;
          esac
          if (( old_cursor != cursor )); then
            render_menu_row "$old_cursor"
            render_menu_row "$cursor"
          fi
        fi
      else
        break
      fi
      ;;
    '')
      (( cursor == ${#items[@]} - 1 )) && break
      show_details "$cursor"
      render_menu
      ;;
    q|Q) break ;;
  esac
done
