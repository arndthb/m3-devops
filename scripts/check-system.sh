#!/usr/bin/env bash
# m³ v0.1: read-only inventory, no elevated privileges required.
set -u

printf 'm³ — Linux DevOps workstation diagnostics\n'
printf '%s\n' '-----------------------------------------'
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf 'Distribution: %s\n' "${PRETTY_NAME:-unknown}"
else
  printf 'Distribution: unknown (/etc/os-release unavailable)\n'
fi
printf 'Kernel: %s\n' "$(uname -r)"
printf '\n%-12s %-12s %s\n' 'Tool' 'Status' 'Version'
printf '%s\n' '------------------------------------------------------------'

# Version checks use local CLI flags only; kubectl does not contact a cluster.
get_version() {
  local tool="$1" output
  local -a args
  case "$tool" in
    git) args=(--version) ;;
    podman) args=(--version) ;;
    distrobox) args=(--version) ;;
    kubectl) args=(version --client=true --output=yaml) ;;
    go) args=(version) ;;
    terraform) args=(version) ;;
    *) return 1 ;;
  esac
  if command -v timeout >/dev/null 2>&1; then
    output="$(timeout 5s "$tool" "${args[@]}" 2>&1)" || return 1
  else
    output="$("$tool" "${args[@]}" 2>&1)" || return 1
  fi
  case "$tool" in
    kubectl)
      output="$(printf '%s\n' "$output" | grep -m1 -E '^[[:space:]]*gitVersion:' | sed -E 's/^[[:space:]]*gitVersion:[[:space:]]*//')" ;;
    terraform)
      output="$(printf '%s\n' "$output" | head -n 1)" ;;
    *)
      output="$(printf '%s\n' "$output" | head -n 1)" ;;
  esac
  [[ -n "$output" ]] || return 1
  printf '%s' "$output"
}

missing=0
for tool in git podman distrobox kubectl go terraform; do
  if command -v "$tool" >/dev/null 2>&1; then
    version="$(get_version "$tool")" || version="unknown (version check failed)"
    printf '%-12s %-12s %s\n' "$tool" 'available' "$version"
  else
    printf '%-12s %-12s %s\n' "$tool" 'missing' '-'
    missing=$((missing + 1))
  fi
done
printf '\nMissing tools: %d of 6\n' "$missing"
printf 'Read-only check complete. No changes made.\n'
