#!/usr/bin/env bash
# Curated, opt-in Homebrew installs for the Bluefin workstation host.
# This library never installs without an explicit call to m3_install_tool.

m3_tool_formula() {
  case "$1" in
    git) printf 'git' ;;
    go) printf 'go' ;;
    kubectl) printf 'kubernetes-cli' ;;
    terraform) printf 'hashicorp/tap/terraform' ;;
    *) return 1 ;;
  esac
}

m3_install_environment() {
  if (( EUID == 0 )); then
    printf 'Root execution is not supported'
    return 1
  fi
  if [[ -n "${DISTROBOX_ENTER_PATH:-}" || -n "${CONTAINER_ID:-}" || -e /run/.containerenv || -e /.dockerenv ]]; then
    printf 'Container/Distrobox detected: open the Bluefin host terminal'
    return 1
  fi
  if ! command -v brew >/dev/null 2>&1; then
    printf 'Homebrew not installed on this host'
    return 1
  fi
  printf 'Homebrew available on host'
}

m3_install_command() {
  local formula
  formula="$(m3_tool_formula "$1")" || return 1
  if [[ "$1" == terraform ]]; then
    printf 'brew tap hashicorp/tap && '
  fi
  printf 'brew install --formula %s' "$formula"
}

# The only function permitted to invoke a package manager.
# Require confirmation at the operation boundary as well as at the menu.
# Do not rely on callers to have checked an answer previously.
m3_install_tool() {
  local tool="${1:-}" confirmation="${2:-}" formula environment
  if [[ "$confirmation" != INSTALL ]]; then
    printf '  No installation performed: exact INSTALL confirmation required.\n'
    return 2
  fi
  formula="$(m3_tool_formula "$tool")" || {
    printf '  %s: no approved installer; manual review needed.\n' "$tool"
    return 2
  }
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  %s is already installed. Skipped.\n' "$tool"
    return 0
  fi
  environment="$(m3_install_environment)" || {
    printf '  %s: installation blocked: %s.\n' "$tool" "$environment"
    return 2
  }
  if [[ "$tool" == terraform ]]; then
    printf '  Adding verified HashiCorp Homebrew tap (hashicorp/tap)...\n'
    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew tap hashicorp/tap; then
      printf '  Terraform: failed to add HashiCorp tap; installation not attempted.\n'
      return 1
    fi
  fi
  printf '  Installing %s with Homebrew (%s)...\n' "$tool" "$formula"
  if HOMEBREW_NO_AUTO_UPDATE=1 brew install --formula "$formula"; then
    printf '  %s: Homebrew completed successfully.\n' "$tool"
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf '  Note: %s is not on PATH yet; open a new terminal if needed.\n' "$tool"
    fi
    return 0
  fi
  printf '  %s: Homebrew failed; no fallback installer was attempted.\n' "$tool"
  return 1
}
