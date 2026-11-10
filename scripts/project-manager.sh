#!/usr/bin/env bash
# m³ local project inventory. Read-only, bounded scan.
set -u
printf '\033[H\033[2J'
printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   %-41.41s  \033[32m│\033[0m\n' 'DevOps Project Manager'
printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
printf '  Local project inventory · read-only\n\n'
roots=("$HOME/Projects" "$HOME/projects" "$HOME/Developer" "$HOME/Code" "$HOME/Documents/DevOps" "$HOME")
declare -A seen=()
count=0
printf '  %-30s %-15s %s\n' 'PROJECT' 'GIT' 'COMPOSE'
printf '  %s\n' '────────────────────────────────────────────────────────────────────'
for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' dir; do
    [[ -d "$dir/.git" || -f "$dir/.git" || -f "$dir/compose.yaml" || -f "$dir/compose.yml" || -f "$dir/docker-compose.yml" || -f "$dir/docker-compose.yaml" ]] || continue
    [[ -z "${seen[$dir]+yes}" ]] || continue
    seen["$dir"]=1
    name="${dir#"$HOME"/}"
    git_state='-'
    if [[ -d "$dir/.git" || -f "$dir/.git" ]] && command -v git >/dev/null 2>&1; then
      branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch='detached'
      if [[ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
        git_state="$branch *"
      else
        git_state="$branch"
      fi
    fi
    compose='-'
    for file in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
      if [[ -f "$dir/$file" ]]; then compose='Found'; break; fi
    done
    printf '  %-30.30s %-15.15s %s\n' "$name" "$git_state" "$compose"
    count=$((count+1))
  done < <(find "$root" -maxdepth 2 -mindepth 1 -type d \( -name .git -o -name node_modules -o -name .venv -o -name .cache \) -prune -o -type d -print0 2>/dev/null)
done
printf '\n  %d project(s) detected. * = tracked changes\n' "$count"
printf '  Scanned common directories (max depth 2); no files changed.\n'
printf '  Git status excludes untracked files. Compose files are detected, not run.\n'
