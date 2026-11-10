#!/usr/bin/env bash
# m³ installation preview — read-only; never executes installation commands.
set -u

printf 'm³ — DevOps installation preview (dry run)\n'
printf '%s\n' '-----------------------------------------'
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf 'Distribution: %s\n' "${PRETTY_NAME:-unknown}"
fi
printf 'No software will be installed.\n\n'

if command -v brew >/dev/null 2>&1; then
  printf 'Package manager: Homebrew (available)\n'
  brew_available=1
else
  printf 'Package manager: Homebrew (not found)\n'
  brew_available=0
fi

missing=0
for tool in git podman distrobox kubectl go terraform; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '[installed] %s — no action needed\n' "$tool"
  else
    missing=$((missing + 1))
    printf '[missing]   %s\n' "$tool"
    if (( brew_available )); then
      case "$tool" in
        terraform)
          printf '            Suggested (NOT executed): brew tap hashicorp/tap\n'
          printf '            Suggested (NOT executed): brew install hashicorp/tap/terraform\n' ;;
        podman|distrobox)
          printf '            System-integrated tool: check Bluefin image and documentation; no automatic brew suggestion.\n' ;;
        *) printf '            Suggested command (NOT executed): brew install %s\n' "$tool" ;;
      esac
    else
      printf '            No command suggested: Homebrew is not installed.\n'
    fi
  fi
done
printf '\nMissing tools: %d of 6\n' "$missing"
printf 'Preview complete. No changes made.\n'
