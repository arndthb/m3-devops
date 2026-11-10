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
# Sample aggregate CPU counters twice; no extra packages required.
cpu_sample() {
  awk '/^cpu / {
    idle=$5+$6; total=0
    for (i=2; i<=NF; i++) total+=$i
    printf "%.0f %.0f\n", total, idle
    exit
  }' /proc/stat
}
if [[ -r /proc/stat ]]; then
  read -r total1 idle1 < <(cpu_sample)
  sleep 0.35
  read -r total2 idle2 < <(cpu_sample)
  delta=$((total2-total1))
  idle_delta=$((idle2-idle1))
  if ((delta>0)); then
    cpu=$((100*(delta-idle_delta)/delta))
    if ((cpu>=95)); then status FAIL 'CPU' "$cpu% busy (sample)"
    elif ((cpu>=80)); then status WARN 'CPU' "$cpu% busy (sample)"
    else status OK 'CPU' "$cpu% busy (sample)"; fi
  else status INFO 'CPU' 'Usage unavailable'; fi
else status INFO 'CPU' 'Linux /proc/stat unavailable'; fi

# Local network status only: no external requests or DNS queries.
route_iface=''
if command -v ip >/dev/null 2>&1; then
  route_iface=$(ip -4 route show default 2>/dev/null | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
fi
if [[ -n "$route_iface" ]]; then
  if [[ -r "/sys/class/net/$route_iface/operstate" ]]; then
    read -r link_state < "/sys/class/net/$route_iface/operstate"
    case "$link_state" in
      up|unknown) status OK 'Network' "Default route via $route_iface (link: $link_state)" ;;
      *) status WARN 'Network' "Default route via $route_iface (link: $link_state)" ;;
    esac
  else status INFO 'Network' "Default route via $route_iface; link unknown"; fi
elif command -v ip >/dev/null 2>&1; then
  status INFO 'Network' 'No IPv4 default route configured'
else
  status INFO 'Network' 'ip command unavailable'
fi

if [[ -r /proc/meminfo ]]; then
  total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  if [[ "$total" =~ ^[0-9]+$ && "$avail" =~ ^[0-9]+$ ]] && ((total>0)); then
    used=$((100*(total-avail)/total))
    if ((used>=90)); then status WARN 'Memory' "$used% used, $((avail/1048576)) GiB available"; else status OK 'Memory' "$used% used, $((avail/1048576)) GiB available"; fi
  else status WARN 'Memory' 'Usage unavailable'; fi
else status WARN 'Memory' 'Linux /proc unavailable'; fi
disk=$(df -P "$HOME" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
disk_free=$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1048576}')
disk_detail="${disk}% used, ${disk_free:-?} GiB free"
if [[ "$disk" =~ ^[0-9]+$ ]]; then
  if ((disk>=95)); then status FAIL 'Home disk' "$disk_detail"
  elif ((disk>=85)); then status WARN 'Home disk' "$disk_detail"
  else status OK 'Home disk' "$disk_detail"; fi
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
health='HEALTHY'; health_color='32'
if ((fail>0)); then health='CRITICAL'; health_color='31'
elif ((warn>0)); then health='ATTENTION'; health_color='33'
fi
printf '\n  OVERALL HEALTH: \033[%sm%s\033[0m\n' "$health_color" "$health"
printf '  %d OK · %d info · %d warnings · %d critical\n' "$ok" "$info" "$warn" "$fail"
printf '  CPU warning >=80%%, critical >=95%% · RAM warning >=90%%\n'
printf '  Home disk warning >=85%%, critical >=95%%\n'
printf '  Read-only check. No changes made.\n'
