#!/usr/bin/env bash
# Fixed, read-only command allowlist for the optional m³ LoupixDeck profile.
set -Eeuo pipefail
if [[ $# -ne 1 ]]; then printf 'Usage: m3-deck <known-action>\n' >&2; exit 64; fi
action="$1"
run_terminal() {
  local command_text="$1" wrapped
  wrapped='printf "\nm³ DevOps · read-only\n\n"; '"$command_text"'; result=$?; printf "\nExit status: %s · Press Enter\n" "$result"; read -r _; exit "$result"'
  if command -v kgx >/dev/null 2>&1; then kgx -- bash -lc "$wrapped"
  elif command -v gnome-terminal >/dev/null 2>&1; then gnome-terminal -- bash -lc "$wrapped"
  elif command -v konsole >/dev/null 2>&1; then konsole -e bash -lc "$wrapped"
  elif command -v xterm >/dev/null 2>&1; then xterm -e bash -lc "$wrapped"
  else printf 'Graphical terminal missing (kgx, gnome-terminal, konsole, xterm).\n' >&2; exit 127; fi
}
case "$action" in
 terminal)         run_terminal 'exec bash' ;;
 m3)               run_terminal 'command -v m3 >/dev/null && m3 || echo "Install the m³ launcher first."' ;;
 codium)
   if command -v codium >/dev/null 2>&1; then codium >/dev/null 2>&1 &
   elif command -v flatpak >/dev/null 2>&1 && flatpak info com.vscodium.codium >/dev/null 2>&1; then
     flatpak run com.vscodium.codium >/dev/null 2>&1 &
   else printf 'VSCodium not installed.\n' >&2; exit 127; fi ;;
 service-*)         python3 "$(dirname -- "$(readlink -f -- "$0")")/open_service.py" "${action#service-}" ;;
 health)          run_terminal 'uptime; free -h; df -h /' ;;
 docker-ps)       run_terminal 'docker ps' ;;
 docker-all)      run_terminal 'docker ps -a' ;;
 docker-images)   run_terminal 'docker image ls' ;;
 docker-compose)  run_terminal 'docker compose ls' ;;
 docker-networks) run_terminal 'docker network ls' ;;
 docker-volumes)  run_terminal 'docker volume ls' ;;
 docker-stats)    run_terminal 'docker stats --no-stream' ;;
 docker-info)     run_terminal 'docker info' ;;
 docker-version)  run_terminal 'docker version' ;;
 k8s-pods)        run_terminal 'kubectl get pods -A' ;;
 k8s-nodes)       run_terminal 'kubectl get nodes' ;;
 k8s-namespaces)  run_terminal 'kubectl get namespaces' ;;
 k8s-deploy)      run_terminal 'kubectl get deployments -A' ;;
 k8s-services)    run_terminal 'kubectl get services -A' ;;
 k8s-events)      run_terminal 'kubectl get events -A' ;;
 k8s-contexts)    run_terminal 'kubectl config get-contexts' ;;
 k8s-current)     run_terminal 'kubectl config current-context' ;;
 helm-list)       run_terminal 'helm list -A' ;;
 helm-repos)      run_terminal 'helm repo list' ;;
 sys-memory)      run_terminal 'free -h' ;;
 sys-disk)        run_terminal 'df -h' ;;
 sys-uptime)      run_terminal 'uptime' ;;
 sys-processes)   run_terminal 'ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -25' ;;
 *) printf 'Unknown action: %s\n' "$action" >&2; exit 64 ;;
esac