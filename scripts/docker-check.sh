#!/usr/bin/env bash
# m³ Docker & Compose Guide — local, read-only. Never changes the host.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tool-detect.sh
source "$SCRIPT_DIR/lib/tool-detect.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

m3_docker_probe() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 5s "$@" >/dev/null 2>&1
  else
    "$@" >/dev/null 2>&1
  fi
}

m3_docker_status() {
  local state="$1" label="$2" info="$3"
  case "$state" in
    OK) printf '  \033[32m✓ READY\033[0m  %-17s %s\n' "$label" "$info" ;;
    WARN) printf '  \033[33m! CHECK\033[0m  %-17s %s\n' "$label" "$info" ;;
    INFO) printf '  \033[36m○ INFO \033[0m  %-17s %s\n' "$label" "$info" ;;
  esac
}

if [[ -t 1 ]]; then
  m3_ui_terminal_size
  m3_ui_header 'Docker & Compose' 'BLUEFIN · SAFE SETUP GUIDE' "$M3_COLS"
else
  printf 'm³ Docker & Compose (read-only)\n\n'
fi

printf '\033[1m  ◆ DOCKER ENGINE\033[0m\n'
docker_ready=0
if command -v docker >/dev/null 2>&1; then
  m3_docker_status OK 'Docker CLI' 'Available'
  context="$(docker context show 2>/dev/null)" || context='unavailable'
  context="$(m3_ui_clean_text "$context")"
  m3_docker_status INFO 'Docker context' "$context"
  if m3_docker_probe docker info --format '{{.ServerVersion}}'; then
    docker_ready=1
    m3_docker_status OK 'Docker daemon' 'Reachable (container operations not attempted)'
  else
    m3_docker_status WARN 'Docker daemon' 'Not reachable from current user/context'
  fi
else
  m3_docker_status WARN 'Docker CLI' 'Not found in this terminal'
  m3_docker_status INFO 'Docker daemon' 'Cannot check without CLI'
fi

printf '\n\033[1m  ◆ COMPOSE & ALTERNATIVES\033[0m\n'
docker_compose=0
if command -v docker >/dev/null 2>&1 && m3_docker_probe docker compose version; then
  docker_compose=1
  m3_docker_status OK 'Docker Compose' 'Docker CLI plugin available'
elif command -v docker-compose >/dev/null 2>&1; then
  docker_compose=1
  m3_docker_status OK 'Docker Compose' 'Standalone docker-compose command'
else
  m3_docker_status WARN 'Docker Compose' 'No Docker Compose plugin/standalone CLI'
fi
if command -v podman >/dev/null 2>&1; then
  if m3_docker_probe podman info --format '{{.Host.Arch}}'; then
    m3_docker_status OK 'Podman engine' 'Reachable (does not imply Docker)'
  else
    m3_docker_status INFO 'Podman engine' 'CLI present, engine not reachable'
  fi
else
  m3_docker_status INFO 'Podman engine' 'Not detected'
fi
if command -v podman-compose >/dev/null 2>&1; then
  m3_docker_status INFO 'Podman Compose' 'Available; separate from Docker Compose'
fi

printf '\n\033[1m  ◆ BLUEFIN SETUP GUIDANCE\033[0m\n'
if (( docker_ready && docker_compose )); then
  printf '  Docker Engine and Compose are available for DevOps projects.\n'
  printf '  Verify your project manually with: docker compose config\n'
elif (( docker_ready )); then
  printf '  Docker Engine is reachable; Docker Compose is still missing.\n'
  printf '  Use the Bluefin DX-supported Compose integration; do not layer\n'
  printf '  a generic Fedora Docker installation over the immutable image.\n'
else
  printf '  Bluefin DX includes Docker Engine in its developer image.\n'
  printf '  First verify your current image and whether Developer Mode is enabled.\n'
  printf '  Bluefin desktop guide: https://docs.projectbluefin.io/bluefin-dx/\n'
  printf '  For *regular* Bluefin, ujust devmode toggles DX mode and needs reboot.\n'
  printf '  Use ujust dx-group only as documented, then reboot if necessary.\n'
  printf '  Do NOT run ujust devmode blindly if DX is already enabled.\n'
  printf '  Check the user service/socket and docker context before changing setup.\n'
fi
if command -v systemctl >/dev/null 2>&1; then
  for service in docker.service bluefin-docker.service; do
    if m3_docker_probe systemctl --user is-active --quiet "$service"; then
      m3_docker_status INFO "User $service" 'Active'
    fi
  done
fi
printf '\n  No packages installed, services changed or containers started.\n'
