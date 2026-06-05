#!/usr/bin/env bash
# Require acceptance of the Zyvor proprietary LICENSE before Hypercluster Desktop install.
# shellcheck shell=bash

hc_license_project_dir() {
    local script_dir="${1:?}"
    cd "$(dirname "$script_dir")/.." && pwd
}

hc_license_file() {
    local root="${1:?}"
    if [[ -f "${root}/desktop/distribution/HYPERCLUSTER-EULA.txt" ]]; then
        echo "${root}/desktop/distribution/HYPERCLUSTER-EULA.txt"
    else
        echo "${root}/LICENSE"
    fi
}

hc_license_hash() {
    local file="${1:?}"
    if command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    else
        wc -c <"$file" | tr -d ' '
    fi
}

hc_license_record_path() {
    echo "${HOME}/.hypercluster/license-acceptance.json"
}

hc_license_already_recorded() {
    local root="${1:?}"
    local license_file
    license_file="$(hc_license_file "$root")"
    local current_hash
    current_hash="$(hc_license_hash "$license_file")"
    local record
    record="$(hc_license_record_path)"
    [[ -f "$record" ]] || return 1
    command -v python3 &>/dev/null || return 1
    python3 - "$record" "$current_hash" <<'PY' >/dev/null 2>&1
import json, sys
path, want = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
sys.exit(0 if data.get("licenseHash") == want and data.get("accepted") is True else 1)
PY
}

hc_license_write_record() {
    local root="${1:?}"
    local actor="${2:-${USER:-unknown}}"
    local license_file
    license_file="$(hc_license_file "$root")"
    local hash
    hash="$(hc_license_hash "$license_file")"
    mkdir -p "${HOME}/.hypercluster"
    local record
    record="$(hc_license_record_path)"
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 - "$record" "$hash" "$actor" "$ts" <<'PY'
import json, sys
path, h, actor, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path, "w") as f:
    json.dump({
        "accepted": True,
        "licenseVersion": "1.0",
        "licenseHash": h,
        "acceptedAt": ts,
        "acceptedBy": actor,
        "product": "Hypercluster Desktop",
        "licensor": "ZyvorAI Labs Private Limited",
        "brand": "zyvor.dev",
    }, f, indent=2)
    f.write("\n")
PY
}

hc_license_show_summary() {
    local root="${1:?}"
    local license_file
    license_file="$(hc_license_file "$root")"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Hypercluster Desktop — ZyvorAI Labs License (zyvor.dev)"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  File: ${license_file}"
    echo ""
    sed -n '1,28p' "$license_file" | sed 's/^/  /'
    echo "  ..."
    echo "  Full text: ${license_file}"
    echo ""
    echo "  You may NOT redistribute, sublicense, or offer as a service without"
    echo "  written permission from ZyvorAI Labs Private Limited."
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Exit 0 if accepted; otherwise prompt or fail.
# Env bypass: HYPERCLUSTER_LICENSE_ACCEPT=1 (records acceptance on first use).
require_hypercluster_license_accept() {
    local root="${1:?}"
    local license_file
    license_file="$(hc_license_file "$root")"
    if [[ ! -f "$license_file" ]]; then
        echo "ERROR: Missing license at ${license_file}" >&2
        exit 1
    fi

    if hc_license_already_recorded "$root"; then
        return 0
    fi

    if [[ "${HYPERCLUSTER_LICENSE_ACCEPT:-}" = "1" ]]; then
        hc_license_write_record "$root" "${HYPERCLUSTER_LICENSE_ACTOR:-${USER:-unknown}}"
        echo "✅ License accepted (HYPERCLUSTER_LICENSE_ACCEPT=1). Record: $(hc_license_record_path)"
        return 0
    fi

    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        echo "ERROR: Zyvor license not accepted." >&2
        echo "  Read: ${license_file}" >&2
        echo "  Run interactively and type ACCEPT, or:" >&2
        echo "    export HYPERCLUSTER_LICENSE_ACCEPT=1" >&2
        exit 1
    fi

    hc_license_show_summary "$root"
    echo -n "Type ACCEPT to agree to the Zyvor Proprietary License: "
    local reply
    read -r reply
    if [[ "$reply" != "ACCEPT" ]]; then
        echo "License not accepted. Installation aborted." >&2
        exit 1
    fi
    hc_license_write_record "$root" "${USER:-unknown}"
    echo "✅ License accepted. Record saved to $(hc_license_record_path)"
}
