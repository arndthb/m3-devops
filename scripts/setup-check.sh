#!/usr/bin/env bash
# m³ Bluefin workstation readiness - local, read-only checks only.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tool-detect.sh
source "$SCRIPT_DIR/lib/tool-detect.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

if [[ -t 1 ]]; then
  m3_ui_terminal_size
  m3_ui_header 'Workstation readiness' 'BLUEFIN · DEVOPS PROVIDERS' "$M3_COLS"
else
  printf 'm³ Workstation readiness (read-only)\n\n'
fi

ready=0
notice=0
missing=0
report() {
  local state="$1" name="$2" detail="$3"
  case "$state" in
    READY) ready=$((ready + 1)); printf '  \033[32m✓ READY\033[0m  %-15s %s\n' "$name" "$detail" ;;
    INFO) notice=$((notice + 1)); printf '  \033[36m○ INFO \033[0m  %-15s %s\n' "$name" "$detail" ;;
    MISSING) missing=$((missing + 1)); printf '  \033[33m! MISSING\033[0m %-15s %s\n' "$name" "$detail" ;;
  esac
}

# Never create clusters or start/enable services during the readiness check.
probe() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 5s "$@" >/dev/null 2>&1
  else
    "$@" >/dev/null 2>&1
  fi
}

printf '\033[1m  ◆ EDITOR & AI AGENT\033[0m\n'
if m3_tool_present codium; then
  report READY 'VSCodium' "$(m3_tool_source codium)"
else
  report MISSING 'VSCodium' 'No CLI or Flatpak detected'
fi
if m3_tool_present hermes; then
  report READY 'Hermes' "$(m3_tool_source hermes) (login not checked)"
else
  report INFO 'Hermes' 'CLI not detected in current environment'
fi

printf '\n\033[1m  ◆ CONTAINER RUNTIMES\033[0m\n'
podman_ready=0
docker_ready=0
if m3_tool_present podman; then
  if probe podman info --format '{{.Host.Arch}}'; then
    podman_ready=1
    report READY 'Podman' 'Engine reachable'
  else
    report INFO 'Podman' 'CLI installed; engine unavailable'
  fi
else
  report MISSING 'Podman' 'Not on PATH'
fi
if m3_tool_present docker; then
  if probe docker info --format '{{.ServerVersion}}'; then
    docker_ready=1
    report READY 'Docker' 'Engine reachable'
  else
    report INFO 'Docker' 'CLI found, but daemon unavailable'
  fi
else
  report INFO 'Docker' 'No CLI (optional for Podman workflows)'
fi
if m3_tool_present compose; then
  report READY 'Compose' "$(m3_tool_source compose)"
else
  report INFO 'Compose' 'No Docker/Podman Compose provider detected'
fi

printf '\n\033[1m  ◆ KUBERNETES TOOLCHAIN\033[0m\n'
if m3_tool_present kind; then
  report READY 'kind' 'CLI installed; cluster creation not tested'
else
  report MISSING 'kind' 'Install from m³ Tool Manager (approved Homebrew)'
fi
if m3_tool_present kubectl; then
  report READY 'kubectl' 'Client installed (cluster connectivity not checked)'
else
  report MISSING 'kubectl' 'Kubernetes CLI is missing'
fi
if [[ -r /sys/fs/cgroup/cgroup.controllers ]]; then
  report READY 'cgroup v2' 'Kernel interface is present'
else
  report INFO 'cgroup v2' 'Not detected (required for rootless kind)'
fi

printf '\n\033[1m  ◆ RECOMMENDED NEXT STEP\033[0m\n'
if (( podman_ready )); then
  printf '  Provider: Podman. Docker Desktop is not required on Bluefin.\n'
  printf '  When ready, create a test cluster manually with:\n'
  printf '    KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name m3-test --wait 90s\n'
  printf '  Rootless Podman may require additional cgroup delegation.\n'
elif (( docker_ready )); then
  printf '  Provider: Docker. Run kind only after verifying its runtime configuration.\n'
  printf '    KIND_EXPERIMENTAL_PROVIDER=docker kind create cluster --name m3-test --wait 90s\n'
else
  printf '  No working container engine verified; do not create a kind cluster yet.\n'
  printf '  Check Podman or Docker in your host terminal before installing another engine.\n'
fi
if ! m3_tool_present kind; then
  printf '  kind: m³ → DevOps Tool Manager → kind → Space → Enter → INSTALL\n'
fi
printf '\n  %d ready · %d informational · %d missing\n' "$ready" "$notice" "$missing"
printf '  Inspection only: no packages, services or clusters changed.\n'
