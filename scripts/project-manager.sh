#!/usr/bin/env bash
# m³ DevOps Project Manager — read-only discovery, search and browsing.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

if [[ -t 1 ]]; then
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT
fi

roots=("$HOME/Projects" "$HOME/projects" "$HOME/Developer" "$HOME/Code" "$HOME/Documents/DevOps" "$HOME")
projects=()
project_names=()
project_git=()
project_compose=()
project_has_git=()
project_dirty=()
matches=()
filters=('All' 'Git' 'Compose' 'Changed')
filter_index=0
query=''
cursor=0
page_start=0
page_size=1
skipped=0
name_width=24
git_width=15
compose_width=12
icon='[ P ]'

scan_projects() {
  local root dir base name state branch changes rc compose file has_git dirty
  local -A seen=()
  projects=()
  project_names=()
  project_git=()
  project_compose=()
  project_has_git=()
  project_dirty=()
  skipped=0

  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' dir; do
      [[ -d "$dir/.git" || -f "$dir/.git" || -f "$dir/compose.yaml" || -f "$dir/compose.yml" || -f "$dir/docker-compose.yml" || -f "$dir/docker-compose.yaml" ]] || continue
      [[ -z "${seen[$dir]+yes}" ]] || continue
      seen["$dir"]=1
      base="${dir##*/}"
      case "${base,,}" in
        *-backup|*-backup-*|*.bak|*.old) skipped=$((skipped+1)); continue ;;
      esac
      name="${dir#"$HOME"/}"
      [[ "$dir" == "$HOME" ]] && name='~'

      state='—'
      has_git=0
      dirty=0
      if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
        has_git=1
        if command -v git >/dev/null 2>&1; then
          branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)" || branch='detached'
          if command -v timeout >/dev/null 2>&1; then
            changes="$(GIT_OPTIONAL_LOCKS=0 timeout 3s git -C "$dir" status --porcelain --untracked-files=normal 2>/dev/null)"
            rc=$?
          else
            changes="$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" status --porcelain --untracked-files=normal 2>/dev/null)"
            rc=$?
          fi
          if (( rc != 0 )); then
            state="$branch (?)"
          elif [[ -n "$changes" ]]; then
            state="$branch *"
            dirty=1
          else
            state="$branch clean"
          fi
        else
          state='git unavailable'
        fi
      fi

      compose='—'
      for file in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
        if [[ -f "$dir/$file" ]]; then compose="$file"; break; fi
      done
      projects+=("$dir")
      project_names+=("$name")
      project_git+=("$state")
      project_compose+=("$compose")
      project_has_git+=("$has_git")
      project_dirty+=("$dirty")
    done < <(find "$root" -maxdepth 2 -mindepth 1 -type d \( -name .git -o -name node_modules -o -name .venv -o -name .cache \) -prune -o -type d -print0 2>/dev/null)
  done
}

apply_filter() {
  local i haystack
  matches=()
  for i in "${!projects[@]}"; do
    case "${filters[filter_index]}" in
      Git) (( project_has_git[i] )) || continue ;;
      Compose) [[ "${project_compose[i]}" != '—' ]] || continue ;;
      Changed) (( project_dirty[i] )) || continue ;;
    esac
    if [[ -n "$query" ]]; then
      haystack="${project_names[i],,} ${projects[i],,}"
      [[ "$haystack" == *"${query,,}"* ]] || continue
    fi
    matches+=("$i")
  done
  cursor=0
  page_start=0
}

layout() {
  m3_ui_terminal_size
  page_size=$(( M3_ROWS - 13 ))
  (( page_size >= 1 )) || page_size=1
  if (( M3_COLS >= 96 )); then
    name_width=33; git_width=19; compose_width=19
  elif (( M3_COLS >= 76 )); then
    name_width=24; git_width=15; compose_width=15
  else
    name_width=15; git_width=12; compose_width=9
  fi
  if [[ "$(m3_ui_icon_mode)" == nerd ]]; then icon='[ 󰉋 ]'; else icon='[ P ]'; fi
}

render_row() {
  local position="$1" slot index label selected=0
  slot=$((position - page_start))
  (( slot >= 0 && slot < page_size )) || return 0
  index="${matches[position]}"
  printf -v label '%-*.*s  %-*.*s  %-*.*s' \
    "$name_width" "$name_width" "${project_names[index]}" \
    "$git_width" "$git_width" "${project_git[index]}" \
    "$compose_width" "$compose_width" "${project_compose[index]}"
  (( position == cursor )) && selected=1
  m3_ui_row "$((10 + slot))" "$selected" "$icon" "$label"
}

render_list() {
  local i at row header_line
  layout
  m3_ui_header 'DevOps Project Manager' 'LOCAL PROJECTS · READ-ONLY' "$M3_COLS"

  printf -v header_line '%-*.*s  %-*.*s  %-*.*s' \
    "$name_width" "$name_width" 'PROJECT' \
    "$git_width" "$git_width" 'GIT STATUS' \
    "$compose_width" "$compose_width" 'COMPOSE'
  printf '\033[8;1H\033[2K      %s\n' "$header_line"
  printf '\033[9;1H\033[2K  ────────────────────────────────────────────────────\n'

  for ((i=0; i<page_size; i++)); do
    at=$((page_start + i))
    row=$((10+i))
    printf '\033[%d;1H\033[2K' "$row"
    if (( at < ${#matches[@]} )); then render_row "$at"; fi
  done

  if (( ${#matches[@]} == 0 )); then
    printf '\033[10;1H\033[2K  No projects match this search/filter.'
  fi
  printf '\033[%d;1H\033[2K  %d of %d shown · Filter: %s · Search: %s\n' \
    "$((M3_ROWS-2))" "${#matches[@]}" "${#projects[@]}" \
    "${filters[filter_index]}" "${query:-(none)}"
  printf '\033[%d;1H\033[2K  ↑/↓ Select  Enter Details  / Search  F Filter  C Clear  R Rescan  Esc Back' \
    "$((M3_ROWS-1))"
}

navigate() {
  local old="$cursor" old_page="$page_start" step="$1" count="${#matches[@]}"
  (( count > 0 )) || return 0
  cursor=$(( (cursor + step + count) % count ))
  page_start=$(( (cursor / page_size) * page_size ))
  if (( old_page != page_start )); then
    render_list
  else
    render_row "$old"
    render_row "$cursor"
  fi
}

details=()
build_details() {
  local index="$1" branch origin compose line
  local dir="${projects[index]}"
  details=()
  details+=("Project: ${project_names[index]}")
  details+=("Path: $dir")
  details+=("Compose: ${project_compose[index]}")
  details+=('')
  if (( project_has_git[index] )) && command -v git >/dev/null 2>&1; then
    branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)" || branch='detached'
    origin="$(git -C "$dir" remote get-url origin 2>/dev/null)" || origin='—'
    details+=("Branch: $branch" "Origin: $origin" '')
    details+=('Recent commits:')
    while IFS= read -r line; do details+=("  $line"); done \
      < <(git --no-pager -C "$dir" log -3 --format='%h  %s' 2>/dev/null)
    details+=('' 'Local changes (first 12):')
    while IFS= read -r line; do details+=("  $line"); done \
      < <(GIT_OPTIONAL_LOCKS=0 git -C "$dir" status --short --untracked-files=normal 2>/dev/null | head -n 12)
    details+=('')
  fi
  details+=('Top-level entries (first 15):')
  while IFS= read -r line; do details+=("  $line"); done \
    < <(find "$dir" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort | head -n 15)
}

render_details() {
  local top="$1" available i position value
  m3_ui_terminal_size
  available=$(( M3_ROWS - 11 ))
  (( available >= 1 )) || available=1
  m3_ui_header 'Project details' 'GIT · COMPOSE · FILES' "$M3_COLS"
  for ((i=0; i<available; i++)); do
    position=$((top + i))
    printf '\033[%d;1H\033[2K' "$((8 + i))"
    if (( position < ${#details[@]} )); then
      value="$(m3_ui_clean_text "${details[position]}")"
      printf '  %s' "${value:0:M3_COLS-4}"
    fi
  done
  printf '\033[%d;1H\033[2K  Details %d–%d of %d · read-only' \
    "$((M3_ROWS-2))" "$((top+1))" "$((top+available < ${#details[@]} ? top+available : ${#details[@]}))" "${#details[@]}"
  printf '\033[%d;1H\033[2K  ↑/↓ Scroll  Enter Project list  Esc Main menu' "$((M3_ROWS-1))"
}

show_details() {
  local index="$1" top=0 avail max_top key next
  build_details "$index"
  while true; do
    m3_ui_terminal_size
    avail=$((M3_ROWS-11)); (( avail >= 1 )) || avail=1
    max_top=$((${#details[@]} - avail)); (( max_top >= 0 )) || max_top=0
    (( top <= max_top )) || top="$max_top"
    render_details "$top"
    IFS= read -rsn1 key || return 0
    case "$key" in
      '') return 0 ;;
      $'\033')
        if IFS= read -rsn1 -t 0.15 next; then
          if [[ "$next" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 next || continue
            case "$next" in
              A) (( top > 0 )) && top=$((top-1)) ;;
              B) (( top < max_top )) && top=$((top+1)) ;;
            esac
          fi
        else return 1; fi ;;
      q|Q) return 0 ;;
    esac
  done
}

if [[ ! -t 0 || ! -t 1 ]]; then
  scan_projects
  printf 'm³ Project Manager (read-only): %d project(s) found\n' "${#projects[@]}"
  exit 0
fi

scan_projects
apply_filter
render_list

while true; do
  IFS= read -rsn1 key || break
  case "$key" in
    $'\033')
      if IFS= read -rsn1 -t 0.15 next; then
        if [[ "$next" == '[' ]]; then
          IFS= read -rsn1 -t 0.15 next || continue
          case "$next" in
            A) navigate -1 ;;
            B) navigate 1 ;;
          esac
        fi
      else
        break
      fi ;;
    '')
      if (( ${#matches[@]} > 0 )); then
        if ! show_details "${matches[cursor]}"; then break; fi
        render_list
      fi ;;
    /)
      printf '\033[%d;1H\033[2K\033[?25h  Search (name or path): ' "$M3_ROWS"
      IFS= read -r query || query=''
      printf '\033[?25l'
      query="$(m3_ui_clean_text "$query")"
      apply_filter
      render_list
      ;;
    f|F)
      filter_index=$(( (filter_index + 1) % ${#filters[@]} ))
      apply_filter
      render_list
      ;;
    c|C)
      query=''
      apply_filter
      render_list
      ;;
    r|R)
      scan_projects
      apply_filter
      render_list
      ;;
    q|Q) break ;;
  esac
done
