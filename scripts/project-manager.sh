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
    printf '  %-28.28s %-18.18s %s\n' "$name" "$git_state" "$compose"
    printf '    Path: %s\n' "$dir"
    count=$((count+1))
  done < <(find "$root" -maxdepth 2 -mindepth 1 -type d \( -name .git -o -name node_modules -o -name .venv -o -name .cache \) -prune -o -type d -print0 2>/dev/null)
done
printf '\n  %d project(s) found; %d backup folder(s) hidden.\n' "$count" "$skipped"
printf '  * = changes (including untracked) · ? = status unavailable\n'
printf '  Scan depth: 2 · No files changed; no containers started.\n'
