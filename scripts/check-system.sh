#!/usr/bin/env bash
# m³ v0.1: read-only inventory, no elevated privileges required.
set -u

printf 'm³ — Linux DevOps workstation diagnostics\n'
printf '%s\n' '-----------------------------------------'
if [[ -r /etc/os-release ]]; then
  # Standard Linux distribution metadata.
  . /etc/os-release
  printf 'Distribution: %s\n' "${PRETTY_NAME:-unknown}"
else
  printf 'Distribution: unknown (/etc/os-release unavailable)\n'
fi
printf 'Kernel: %s\n' "$(uname -r)"
printf '\n%-12s %s\n' 'Tool' 'Status'
printf '%s\n' '-------------------------------'
missing=0
for tool in git podman distrobox kubectl go terraform; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$tool" 'available'
  else
    printf '%-12s %s\n' "$tool" 'missing'
    missing=$((missing + 1))
  fi
done
printf '\nMissing tools: %d of 6\n' "$missing"
printf 'Read-only check complete. No changes made.\n'
