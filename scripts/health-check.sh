#!/usr/bin/env bash
# Read-only Linux workstation health checks.
set -u
ok=0; warn=0; fail=0; info=0
status() {
  case "$1" in
    INFO) printf '  \033[33m○ INFO\033[0m'; info=$((info+1));;
    OK) printf '  \033[32m✓ OK  \033[0m'; ok=$((ok+1));;
    WARN) printf '  \033[33m! WARN\033[0m'; warn=$((warn+1));;
    FAIL) printf '  \033[31m✗ FAIL\033[0m'; fail=$((fail+1));;
  esac
  printf '  %-16s %s\n' "$2" "$3"
}
printf '\033[H\033[2J'
printf '\033[32m  ╭──────────────────────────────────────────────╮\033[0m\n'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   \033[1;32mm³\033[0m   \033[1mDEVOPS WORKSTATION\033[0m                    \033[32m│\033[0m\n'
printf '\033[32m  │\033[0m   %-41s  \033[32m│\033[0m\n' 'Workstation Health Check'
printf '\033[32m  │\033[0m                                              \033[32m│\033[0m\n'
printf '\033[32m  ╰──────────────────────────────────────────────╯\033[0m\n\n'
if [[ -r /proc/meminfo ]]; then
  total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  if [[ "$total" =~ ^[0-9]+$ && "$avail" =~ ^[0-9]+$ ]] && ((total>0)); then
    used=$((100*(total-avail)/total))
    if ((used>=90)); then status WARN 'Memory' "$used% used"; else status OK 'Memory' "$used% used"; fi
  else status WARN 'Memory' 'Usage unavailable'; fi
else status WARN 'Memory' 'Linux /proc unavailable'; fi
disk=$(df -P "$HOME" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if [[ "$disk" =~ ^[0-9]+$ ]]; then
  if ((disk>=95)); then status FAIL 'Home disk' "$disk% used"
  elif ((disk>=85)); then status WARN 'Home disk' "$disk% used"
  else status OK 'Home disk' "$disk% used"; fi
else status WARN 'Home disk' 'Usage unavailable'; fi
if command -v podman >/dev/null 2>&1; then
  if command -v timeout >/dev/null 2>&1 && timeout 4s podman info --format '{{.Host.Arch}}' >/dev/null 2>&1; then
    status OK 'Podman' 'Engine reachable'
  else status WARN 'Podman' 'Installed; engine unverified'; fi
else status WARN 'Podman' 'Not installed'; fi
if command -v kubectl >/dev/null 2>&1; then
  context=$(kubectl config current-context 2>/dev/null) || context=''
  if [[ -n "$context" ]]; then status OK 'Kubernetes' "Context: $context"
  else status INFO 'Kubernetes' 'Not configured (no active context)'; fi
else status WARN 'Kubernetes' 'kubectl not installed'; fi
if command -v git >/dev/null 2>&1; then status OK 'Git' 'Installed'
else status WARN 'Git' 'Not installed'; fi
if command -v gh >/dev/null 2>&1; then status OK 'GitHub CLI' 'Installed; auth not checked'
else status WARN 'GitHub CLI' 'Not installed'; fi
printf '\n  %d OK · %d info · %d warnings · %d critical\n' "$ok" "$info" "$warn" "$fail"
printf '  Read-only check. No changes made.\n'
