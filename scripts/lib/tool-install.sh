#!/usr/bin/env bash
# Curated opt-in installs for Fedora and Bluefin; never install without confirmation.
# This library never installs without an explicit call to m3_install_tool.

m3_tool_formula() {
  case "$1" in
    git) printf 'git' ;;
    go) printf 'go' ;;
    kubectl) printf 'kubernetes-cli' ;;
    kind) printf 'kind' ;;
    terraform) printf 'hashicorp/tap/terraform' ;;
    *) return 1 ;;
  esac
}

m3_package_manager() {
  if [[ -r /etc/os-release ]]; then
    local ID ID_LIKE
    . /etc/os-release
    if [[ "${ID:-}" == fedora || " ${ID_LIKE:-} " == *" fedora "* ]]; then
      if command -v rpm-ostree >/dev/null 2>&1; then printf 'immutable'; return; fi
      if command -v dnf >/dev/null 2>&1; then printf 'dnf'; return; fi
    fi
  fi
  if command -v brew >/dev/null 2>&1; then printf 'brew'; return; fi
  printf 'unsupported'
}

m3_fedora_package() {
  case "$1" in
    git) printf 'git' ;;
    go) printf 'golang' ;;
    kubectl) printf 'kubernetes-client' ;;
    terraform) return 1 ;; # Requires verified HashiCorp RPM repository
    *) return 1 ;;
  esac
}

m3_install_environment() {
  if (( EUID == 0 )); then
    printf 'Root execution is not supported'
    return 1
  fi
  if [[ -n "${DISTROBOX_ENTER_PATH:-}" || -n "${CONTAINER_ID:-}" || -e /run/.containerenv || -e /.dockerenv ]]; then
    printf 'Container/Distrobox detected: open the host terminal'
    return 1
  fi
  case "$(m3_package_manager)" in
    brew) printf 'Homebrew available on host' ;;
    dnf) printf 'Fedora DNF available on host' ;;
    immutable) printf 'Immutable Fedora detected: host package installation blocked'; return 1 ;;
    *) printf 'No supported host package manager'; return 1 ;;
  esac
}

m3_install_command() {
  if [[ "$1" == nerdfont ]]; then
    printf 'Install JetBrainsMono Nerd Font to ~/.local/share/fonts (curl, unzip, fc-cache)'
    return 0
  fi
  if [[ "$(m3_package_manager)" == dnf ]]; then
    local package
    package="$(m3_fedora_package "$1")" || return 1
    printf 'sudo dnf install %s' "$package"
    return
  fi
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
  if [[ "$tool" == nerdfont ]]; then
    environment="$(m3_install_environment)" || {
      printf '  Nerd Font: installation blocked: %s.\n' "$environment"
      return 2
    }
    if command -v fc-list >/dev/null 2>&1 && fc-list : family 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font'; then
      printf '  JetBrainsMono Nerd Font already installed.\n'
      return 0
    fi
    local tmpdir target
    for cmd in curl unzip fc-cache; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        printf '  Missing prerequisite: %s (Fedora: sudo dnf install -y curl unzip fontconfig)\n' "$cmd"
        return 2
      fi
    done
    tmpdir="$(mktemp -d)" || return 1
    target="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    if ! curl -fLsS --retry 2 --connect-timeout 10 --max-time 180 \
      'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -o "$tmpdir/font.zip"; then
      rm -rf -- "$tmpdir"; return 1
    fi
    mkdir -p "$target" || { rm -rf -- "$tmpdir"; return 1; }
    if ! unzip -oq "$tmpdir/font.zip" '*.ttf' -d "$target"; then
      rm -rf -- "$tmpdir"; return 1
    fi
    rm -rf -- "$tmpdir"
    fc-cache -f "$target"
    printf '  Nerd Font installed. Select JetBrainsMono Nerd Font in terminal preferences.\n'
    return 0
  fi
  if [[ "$(m3_package_manager)" == dnf ]]; then
    formula="$(m3_fedora_package "$tool")" || {
      printf '  %s: no approved Fedora installer; manual review needed.\n' "$tool"
      return 2
    }
  else
    formula="$(m3_tool_formula "$tool")" || {
      printf '  %s: no approved installer; manual review needed.\n' "$tool"
      return 2
    }
  fi

  if command -v "$tool" >/dev/null 2>&1; then
    printf '  %s is already installed. Skipped.\n' "$tool"
    return 0
  fi
  environment="$(m3_install_environment)" || {
    printf '  %s: installation blocked: %s.\n' "$tool" "$environment"
    return 2
  }
  if [[ "$(m3_package_manager)" == dnf ]]; then
    printf '  Installing %s with DNF (%s)...\n' "$tool" "$formula"
    sudo dnf install -y "$formula" || return 1
    return 0
  fi
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
