#!/usr/bin/env bash
# Infrastructure discovery — libvirt, Proxmox, VMware, ssh-scan, csv + optional SSH validation

discover::_emit() {
  local -n _nodes_ref="$1"
  local validations_json="${2:-[]}"
  if [[ "${HC_JSON:-0}" == "1" ]]; then
    printf '%s\n' "${_nodes_ref[@]}" | DISCOVER_VALIDATIONS="$validations_json" python3 -c '
import json, os, sys
nodes = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split("|")
    while len(parts) < 10:
        parts.append("")
    name, ip, source, gpu, vcpu, mem, storage, virt, nics, numa = parts[:10]
    n = {"name": name, "ip": ip, "source": source}
    if gpu == "1":
        n["gpu"] = True
    if vcpu:
        n["vcpu"] = int(vcpu)
    if mem:
        n["memoryMb"] = int(mem)
    if storage:
        n["storageGb"] = int(storage)
    if virt == "1":
        n["virtualization"] = True
    elif virt == "0":
        n["virtualization"] = False
    if nics:
        n["nicCount"] = int(nics)
    if numa == "1":
        n["numa"] = True
    nodes.append(n)
try:
    validations = json.loads(os.environ.get("DISCOVER_VALIDATIONS", "[]"))
except json.JSONDecodeError:
    validations = []
out = {"nodes": nodes}
if validations:
    out["validations"] = validations
print(json.dumps(out))
'
  else
    local n name ip source
    for n in "${_nodes_ref[@]}"; do
      IFS='|' read -r name ip source _g _v _m <<<"$n"
      printf '  %-24s %-16s (%s)\n' "$name" "$ip" "$source"
    done
  fi
}

discover::_ssh_opts() {
  local -n _ref="$1"
  local key="${DISCOVER_SSH_KEY:-$HOME/.ssh/id_rsa}"
  key="${key/#\~/$HOME}"
  _ref=(
    -i "$key"
    -o BatchMode=yes
    -o ConnectTimeout=10
    -o StrictHostKeyChecking=accept-new
  )
  [[ -n "${DISCOVER_SSH_PORT:-}" && "${DISCOVER_SSH_PORT}" != "22" ]] && _ref+=(-p "$DISCOVER_SSH_PORT")
}

discover::_probe_host() {
  local ip="$1"
  local user="${DISCOVER_SSH_USER:-root}"
  local opts=()
  discover::_ssh_opts opts
  # shellcheck disable=SC2029
  ssh "${opts[@]}" "${user}@${ip}" 'bash -s' <<'REMOTE' 2>/dev/null || true
set -euo pipefail
vcpu=$(nproc 2>/dev/null || echo 0)
mem_mb=$(awk "/MemTotal/ {print int(\$2/1024)}" /proc/meminfo 2>/dev/null || echo 0)
storage_gb=0
if command -v lsblk >/dev/null; then
  storage_gb=$(lsblk -b -d -o SIZE -n 2>/dev/null | awk "{s+=\$1} END {print int(s/1024/1024/1024)}")
fi
gpu=0
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then gpu=1; fi
virt=0
[[ -c /dev/kvm ]] && virt=1
nics=$(ls /sys/class/net 2>/dev/null | grep -vcE '^lo$' || echo 0)
numa=0
[[ -d /sys/devices/system/node/node1 ]] && numa=1
echo "${vcpu}|${mem_mb}|${storage_gb}|${gpu}|${virt}|${nics}|${numa}"
REMOTE
}

discover::_validate_host() {
  local ip="$1"
  local user="${DISCOVER_SSH_USER:-root}"
  local opts=()
  discover::_ssh_opts opts
  local -a checks=()
  local out ok detail

  if out=$(ssh "${opts[@]}" "${user}@${ip}" "test -c /dev/kvm && echo pass || echo fail" 2>/dev/null); then
    [[ "$out" == *pass* ]] && ok=true || ok=false
    checks+=("kvm|${ok}|/dev/kvm present")
  else
    checks+=("kvm|false|SSH unreachable")
  fi

  if out=$(ssh "${opts[@]}" "${user}@${ip}" "grep -Eq '(vmx|svm)' /proc/cpuinfo && echo pass || echo fail" 2>/dev/null); then
    [[ "$out" == *pass* ]] && ok=true || ok=false
    checks+=("vtx|${ok}|VT-x/AMD-V in cpuinfo")
  fi

  if out=$(ssh "${opts[@]}" "${user}@${ip}" "[[ -d /sys/module/kvm_intel ]] || [[ -d /sys/module/kvm_amd ]] && echo pass || echo fail" 2>/dev/null); then
    [[ "$out" == *pass* ]] && ok=true || ok=false
    checks+=("kvm_module|${ok}|KVM kernel module loaded")
  fi

  if out=$(ssh "${opts[@]}" "${user}@${ip}" "dmesg 2>/dev/null | grep -qi iommu && echo pass || echo skip" 2>/dev/null); then
    if [[ "$out" == *pass* ]]; then ok=true; detail="IOMMU messages in dmesg"
    elif [[ "$out" == *skip* ]]; then ok=true; detail="IOMMU not detected (optional)"
    else ok=false; detail="No IOMMU"; fi
    checks+=("iommu|${ok}|${detail}")
  fi

  if out=$(ssh "${opts[@]}" "${user}@${ip}" "cat /sys/module/kvm/parameters/nested 2>/dev/null || echo 0" 2>/dev/null); then
    [[ "$out" == "1" || "$out" == "Y" ]] && ok=true || ok=false
    checks+=("nested_virt|${ok}|Nested virtualization: ${out}")
  fi

  if out=$(ssh "${opts[@]}" "${user}@${ip}" "grep -q Huge /proc/meminfo && echo pass || echo fail" 2>/dev/null); then
    [[ "$out" == *pass* ]] && ok=true || ok=false
    checks+=("hugepages|${ok}|HugePages configured")
  fi

  printf '%s\n' "${checks[@]}"
}

discover::_enrich_and_validate() {
  local -n _nodes_ref="$1"
  local -a enriched=()
  local -a validations=()
  local line name ip source rest probe vcpu mem storage gpu virt nics numa
  for line in "${_nodes_ref[@]}"; do
    IFS='|' read -r name ip source gpu vcpu mem storage virt nics numa <<<"$line"
    if [[ "${DISCOVER_PROBE:-0}" == "1" && -n "$ip" ]]; then
      if probe="$(discover::_probe_host "$ip")"; then
        IFS='|' read -r vcpu mem storage gpu virt nics numa <<<"$probe"
      fi
    fi
    enriched+=("${name}|${ip}|${source}|${gpu:-0}|${vcpu:-}|${mem:-}|${storage:-}|${virt:-}|${nics:-}|${numa:-}")
    if [[ "${DISCOVER_VALIDATE:-0}" == "1" && -n "$ip" ]]; then
      while IFS='|' read -r cname cok cdetail; do
        [[ -n "$cname" ]] || continue
        validations+=("${ip}|${cname}|${cok}|${cdetail}")
      done < <(discover::_validate_host "$ip")
    fi
  done
  _nodes_ref=("${enriched[@]}")
  if [[ "${DISCOVER_VALIDATE:-0}" == "1" && ${#validations[@]} -gt 0 ]]; then
    local vjson
    vjson="$(printf '%s\n' "${validations[@]}" | python3 -c '
import json, sys
by_ip = {}
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    ip, name, ok, detail = line.split("|", 3)
    by_ip.setdefault(ip, []).append({"name": name, "passed": ok == "true", "detail": detail})
print(json.dumps([{"ip": ip, "checks": checks} for ip, checks in by_ip.items()]))
')"
    discover::_emit enriched "$vjson"
  else
    discover::_emit enriched "[]"
  fi
}

discover::_libvirt() {
  command -v virsh >/dev/null 2>&1 || {
    log::error "virsh not found — install libvirt client tools"
    return 1
  }
  local uri="${DISCOVER_URI:-qemu:///system}"
  local -a nodes=()
  local name ip
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    ip=""
    if ip="$(virsh -c "$uri" domifaddr "$name" --source agent 2>/dev/null | awk '/ipv4/ {print $4; exit}' | cut -d/ -f1)"; then
      :
    elif ip="$(virsh -c "$uri" domifaddr "$name" --source lease 2>/dev/null | awk '/ipv4/ {print $4; exit}' | cut -d/ -f1)"; then
      :
    fi
    [[ -n "$ip" ]] || continue
    local vcpu mem
    vcpu="$(virsh -c "$uri" dominfo "$name" 2>/dev/null | awk -F: '/CPU\(s\)/ {gsub(/ /,"",$2); print $2; exit}')"
    mem="$(virsh -c "$uri" dominfo "$name" 2>/dev/null | awk -F: '/Max memory/ {gsub(/[^0-9]/,"",$2); print int($2/1024); exit}')"
    nodes+=("${name}|${ip}|libvirt|0|${vcpu:-}|${mem:-}|||")
  done < <(virsh -c "$uri" list --all --name 2>/dev/null)
  discover::_enrich_and_validate nodes
}

discover::_proxmox() {
  local host="${DISCOVER_HOST:-}"
  [[ -n "$host" ]] || die "Proxmox discovery requires --host or DISCOVER_HOST"
  local -a nodes=()
  if command -v pvesh >/dev/null 2>&1; then
    local line name ip
    while IFS= read -r line; do
      name="$(echo "$line" | awk '{print $1}')"
      ip="$(echo "$line" | awk '{print $2}')"
      [[ -n "$name" && -n "$ip" ]] || continue
      nodes+=("${name}|${ip}|proxmox|0|||||")
    done < <(pvesh get /cluster/resources --type vm --output-format text 2>/dev/null | awk 'NR>1 {print $2, $NF}')
  fi
  discover::_enrich_and_validate nodes
}

discover::_vmware() {
  command -v govc >/dev/null 2>&1 || {
    log::error "govc not found — install govc for VMware discovery"
    return 1
  }
  local -a nodes=()
  local name ip
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    ip="$(govc vm.ip "$name" 2>/dev/null || true)"
    [[ -n "$ip" ]] || continue
    nodes+=("${name}|${ip}|vmware|0|||||")
  done < <(govc ls / 2>/dev/null | grep -E '/vm/' || true)
  discover::_enrich_and_validate nodes
}

discover::_ssh_scan() {
  local cidr="${DISCOVER_CIDR:-}"
  [[ -n "$cidr" ]] || die "ssh-scan requires --cidr (e.g. 192.168.1.0/24)"
  local -a nodes=()
  if command -v nmap >/dev/null 2>&1; then
    local ip
    while IFS= read -r ip; do
      [[ -n "$ip" ]] || continue
      nodes+=("host-${ip//./-}|${ip}|ssh-scan|0|||||")
    done < <(nmap -sn "$cidr" 2>/dev/null | awk '/Nmap scan report/ {print $NF}' | tr -d '()')
  else
    local base="${cidr%%/*}"
    local prefix="${cidr##*/}"
    [[ "$prefix" == "24" ]] || die "ssh-scan without nmap supports /24 only"
    local a b c _ ip i
    IFS=. read -r a b c _ <<<"$base"
    for i in $(seq 1 254); do
      ip="${a}.${b}.${c}.${i}"
      ping -c 1 -W 1 "$ip" >/dev/null 2>&1 || continue
      nodes+=("host-${ip//./-}|${ip}|ssh-scan|0|||||")
    done
  fi
  discover::_enrich_and_validate nodes
}

discover::_csv() {
  local path="${DISCOVER_CSV:-}"
  [[ -n "$path" && -f "$path" ]] || die "csv source requires --csv <path>"
  local -a nodes=()
  local line name ip gpu vcpu mem
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "${line// /}" ]] && continue
    name="$(echo "$line" | cut -d, -f1 | tr -d '"')"
    ip="$(echo "$line" | cut -d, -f2 | tr -d '" ')"
    gpu="$(echo "$line" | cut -d, -f3 | tr -d '" ')"
    vcpu="$(echo "$line" | cut -d, -f4 | tr -d '" ')"
    mem="$(echo "$line" | cut -d, -f5 | tr -d '" ')"
    [[ -n "$name" && -n "$ip" ]] || continue
    [[ "$gpu" == "gpu" || "$gpu" == "1" || "$gpu" == "true" ]] && gpu=1 || gpu=0
    nodes+=("${name}|${ip}|csv|${gpu}|${vcpu:-}|${mem:-}|||")
  done <"$path"
  discover::_enrich_and_validate nodes
}

discover::run() {
  local json=0 source="" uri="" host="" cidr="" csv=""
  export DISCOVER_VALIDATE=0
  export DISCOVER_PROBE=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1; shift ;;
      --validate) DISCOVER_VALIDATE=1; DISCOVER_PROBE=1; shift ;;
      --probe) DISCOVER_PROBE=1; shift ;;
      --source) source="$2"; shift 2 ;;
      --uri) uri="$2"; shift 2 ;;
      --host) host="$2"; shift 2 ;;
      --cidr) cidr="$2"; shift 2 ;;
      --csv) csv="$2"; shift 2 ;;
      --ssh-user) DISCOVER_SSH_USER="$2"; shift 2 ;;
      --ssh-key) DISCOVER_SSH_KEY="$2"; shift 2 ;;
      --ssh-port) DISCOVER_SSH_PORT="$2"; shift 2 ;;
      *) die "Unknown discover arg: $1" ;;
    esac
  done
  export HC_JSON="$json"
  export DISCOVER_URI="$uri"
  export DISCOVER_HOST="$host"
  export DISCOVER_CIDR="$cidr"
  export DISCOVER_CSV="$csv"
  [[ -n "$source" ]] || die "Usage: hypercluster discover --source libvirt|proxmox|vmware|ssh-scan|csv [--json] [--validate] [--probe] ..."
  case "$source" in
    libvirt) discover::_libvirt ;;
    proxmox) discover::_proxmox ;;
    vmware) discover::_vmware ;;
    ssh-scan) discover::_ssh_scan ;;
    csv) discover::_csv ;;
    *) die "Unknown discover source: $source" ;;
  esac
}
