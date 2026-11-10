#!/usr/bin/env bash
# Shared read-only inventory for m³. Presence is not the same as a working service.
m3_tool_catalog() {
  printf '%s\n' git podman distrobox kubectl go terraform codium hermes docker compose kind make curl
}

m3_tool_label() {
  case "$1" in
    codium) printf 'VSCodium' ;;
    compose) printf 'Compose' ;;
    hermes) printf 'Hermes' ;;
    *) printf '%s' "$1" ;;
  esac
}

m3_tool_present() {
  case "$1" in
    codium)
      command -v codium >/dev/null 2>&1 && return 0
      if command -v flatpak >/dev/null 2>&1; then
        flatpak info com.vscodium.codium >/dev/null 2>&1 && return 0
      fi
      return 1 ;;
    hermes)
      command -v hermes >/dev/null 2>&1 ||
      command -v hermes-agent >/dev/null 2>&1 ||
      [[ -x "$HOME/.local/bin/hermes" ]] ;;
    compose)
      if command -v docker >/dev/null 2>&1; then
        docker compose version >/dev/null 2>&1 && return 0
      fi
      command -v docker-compose >/dev/null 2>&1 ||
      command -v podman-compose >/dev/null 2>&1 ;;
    *)
      command -v "$1" >/dev/null 2>&1 ;;
  esac
}

m3_tool_source() {
  case "$1" in
    codium)
      if command -v codium >/dev/null 2>&1; then printf 'CLI'
      else printf 'Flatpak'; fi ;;
    hermes)
      if command -v hermes >/dev/null 2>&1; then printf 'CLI'
      elif command -v hermes-agent >/dev/null 2>&1; then printf 'hermes-agent'
      else printf 'local executable'; fi ;;
    compose)
      if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        printf 'Docker plugin'
      elif command -v docker-compose >/dev/null 2>&1; then printf 'docker-compose'
      else printf 'podman-compose'; fi ;;
    docker) printf 'CLI (engine not checked)' ;;
    *) printf 'CLI' ;;
  esac
}

m3_tool_hint() {
  case "$1" in
    codium) printf 'Review VSCodium Flatpak (com.vscodium.codium)' ;;
    hermes) printf 'Review Hermes agent installation and PATH' ;;
    docker) printf 'Docker engine/CLI differs from Bluefin Podman' ;;
    compose) printf 'Install Docker Compose plugin or Podman Compose provider' ;;
    kind) printf 'Needs a working Docker/Podman container provider' ;;
    make|curl) printf 'Review host packages or an approved Homebrew formula' ;;
    podman|distrobox) printf 'Bluefin-integrated; review OS-managed setup' ;;
    *) printf 'No approved install recipe yet' ;;
  esac
}
