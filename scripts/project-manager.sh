#!/usr/bin/env bash
# m³ DevOps Project Manager — read-only project discovery.
set -u
printf '\033[H\033[2J'
printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   %-41.41s  \033[32m│\033[0m\n' 'DevOps Project Manager'
printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
printf '  Local projects · read-only\n\n'

roots=("$HOME/Projects" "$HOME/projects" "$HOME/Developer" "$HOME/Code" "$HOME/Documents/DevOps" "$HOME")
declare -A seen=()
count=0
skipped=0
projects=()
printf '  %-28s %-18s %s\n' 'PROJECT' 'GIT' 'COMPOSE'
printf '  %s\n' '──────────────────────────────────────────────────────────────────────'
for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' dir; do
    [[ -d "$dir/.git" || -f "$dir/.git" || -f "$dir/compose.yaml" || -f "$dir/compose.yml" || -f "$dir/docker-compose.yml" || -f "$dir/docker-compose.yaml" ]] || continue
    [[ -z "${seen[$dir]+yes}" ]] || continue
    seen["$dir"]=1
    name="${dir#"$HOME"/}"
    base="${dir##*/}"
    case "${base,,}" in
      *-backup|*-backup-*|*.bak|*.old) skipped=$((skipped+1)); continue ;;
    esac

    git_state='—'
    if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
      if command -v git >/dev/null 2>&1; then
        branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch='detached'
        if command -v timeout >/dev/null 2>&1; then
          changes=$(timeout 3s git -C "$dir" status --porcelain --untracked-files=normal 2>/dev/null)
          rc=$?
        else
          changes=$(git -C "$dir" status --porcelain --untracked-files=normal 2>/dev/null)
          rc=$?
        fi
        if (( rc != 0 )); then
          git_state="$branch (?)"
        elif [[ -n "$changes" ]]; then
          git_state="$branch *"
        else
          git_state="$branch clean"
        fi
      else
        git_state='git unavailable'
      fi
    fi

    compose='—'
    for file in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
      if [[ -f "$dir/$file" ]]; then compose="$file"; break; fi
    done
    projects+=("$dir")
    printf '  %-28.28s %-18.18s %s\n' "$name" "$git_state" "$compose"
    printf '    Path: %s\n' "$dir"
    count=$((count+1))
  done < <(find "$root" -maxdepth 2 -mindepth 1 -type d \( -name .git -o -name node_modules -o -name .venv -o -name .cache \) -prune -o -type d -print0 2>/dev/null)
done
printf '\n  %d project(s) found; %d backup folder(s) hidden.\n' "$count" "$skipped"
printf '  * = changes (including untracked) · ? = status unavailable\n'
printf '  Scan depth: 2 · No files changed; no containers started.\n'

# Interactive read-only project selection and details.
if [[ -t 0 && -t 1 && ${#projects[@]} -gt 0 ]]; then
  cursor=0
  while true; do
    printf '\033[H\033[2J'
    printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
    printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
    printf '\033[32m  │\033[0m   %-41.41s  \033[32m│\033[0m\n' 'DevOps Project Manager'
    printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
    for i in "${!projects[@]}"; do
      dir="${projects[i]}"
      if (( i == cursor )); then printf '\033[32m >\033[0m '; else printf '   '; fi
      printf '%s\n' "${dir#"$HOME"/}"
    done
    printf '\n  ↑/↓ Select  Enter Details  Esc Back\n'
    IFS= read -rsn1 key || break
    case "$key" in
      $'\033')
        if IFS= read -rsn1 -t 0.15 next; then
          if [[ "$next" == '[' ]]; then
            IFS= read -rsn1 -t 0.15 next || continue
            case "$next" in
              A) cursor=$(( (cursor + ${#projects[@]} - 1) % ${#projects[@]} )) ;;
              B) cursor=$(( (cursor + 1) % ${#projects[@]} )) ;;
            esac
          fi
        else break; fi ;;
      '')
        dir="${projects[cursor]}"
        printf '\033[H\033[2J'
        printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
        printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
        printf '\033[32m  │\033[0m   %-41.41s  \033[32m│\033[0m\n' 'Project details'
        printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
        printf '  Project: %s\n  Path: %s\n' "${dir#"$HOME"/}" "$dir"
        if [[ -d "$dir/.git" || -f "$dir/.git" ]] && command -v git >/dev/null 2>&1; then
          printf '\n  Branch: '
          branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch='detached'
          printf '%s\n' "$branch"
          printf '  Origin: '
          git -C "$dir" remote get-url origin 2>/dev/null || printf '—\n'
          printf '\n  Recent commits:\n'
          git -C "$dir" log -3 --format='    %h %s' 2>/dev/null || true
          printf '\n  Changes (first 12):\n'
          git -C "$dir" status --short --untracked-files=normal 2>/dev/null | head -n 12
        fi
        printf '\n  Compose: '
        found='—'
        for file in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
          if [[ -f "$dir/$file" ]]; then found="$file"; break; fi
        done
        printf '%s\n\n  Top-level entries (first 15):\n' "$found"
        find "$dir" -mindepth 1 -maxdepth 1 -printf '    %f\n' 2>/dev/null | sort | head -n 15
        printf '\n  Read-only · Enter: project list · Esc: main menu\n'
        while true; do
          IFS= read -rsn1 detail_key || break
          case "$detail_key" in
            '') break ;;
            $'\033') exit 0 ;;
          esac
        done ;;
      q|Q) break ;;
    esac
  done
fi
