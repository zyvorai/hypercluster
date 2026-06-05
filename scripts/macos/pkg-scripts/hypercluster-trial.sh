#!/usr/bin/env bash
# 30-day trial persistence for Hypercluster Desktop (macOS).
# Trial survives app uninstall/reinstall via Keychain + ~/.hypercluster/trial.json.

hc_trial_days() {
    echo "30"
}

hc_trial_sales_email() {
    echo "sales@zyvor.dev"
}

hc_trial_record_path() {
    echo "${HOME}/.hypercluster/trial.json"
}

hc_trial_machine_id() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null \
            | awk -F'"' '/IOPlatformUUID/ { print $4; exit }'
        return
    fi
    hostname 2>/dev/null || echo "unknown"
}

hc_trial_keychain_service() {
    echo "dev.zyvor.hypercluster.desktop.trial"
}

hc_trial_read_keychain() {
    security find-generic-password -a "trial" -s "$(hc_trial_keychain_service)" -w 2>/dev/null || true
}

hc_trial_write_keychain() {
    local json="$1"
    security add-generic-password -a "trial" -s "$(hc_trial_keychain_service)" -w "$json" -U >/dev/null 2>&1
}

hc_trial_read_file() {
    local record
    record="$(hc_trial_record_path)"
    [[ -f "$record" ]] || return 1
    cat "$record"
}

hc_trial_write_file() {
    local json="$1"
    local record dir
    record="$(hc_trial_record_path)"
    dir="$(dirname "$record")"
    mkdir -p "$dir"
    printf '%s\n' "$json" >"$record"
}

hc_trial_commercial_license_path() {
    echo "${HOME}/.hypercluster/commercial-license.json"
}

hc_trial_has_commercial_license() {
    local lic
    lic="$(hc_trial_commercial_license_path)"
    [[ -f "$lic" ]] || return 1
    python3 - "$lic" <<'PY'
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
sys.exit(0 if data.get("licenseId") and data.get("issuedTo") else 1)
PY
}

# Start trial if missing. Never resets an existing trial.
hc_trial_ensure_started() {
    if hc_trial_has_commercial_license; then
        return 0
    fi

    local existing_kc existing_file machine_id started_at days json
    days="$(hc_trial_days)"
    machine_id="$(hc_trial_machine_id)"
    started_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    existing_kc="$(hc_trial_read_keychain)"
    existing_file=""
    if hc_trial_read_file >/dev/null 2>&1; then
        existing_file="$(hc_trial_read_file)"
    fi

    if [[ -n "$existing_kc" || -n "$existing_file" ]]; then
        if [[ -n "$existing_kc" ]]; then
            hc_trial_write_file "$existing_kc" || true
            hc_trial_write_keychain "$existing_kc" || true
        elif [[ -n "$existing_file" ]]; then
            hc_trial_write_keychain "$existing_file" || true
        fi
        return 0
    fi

    json="$(python3 - "$started_at" "$days" "$machine_id" <<'PY'
import json, sys
started, days, machine = sys.argv[1], int(sys.argv[2]), sys.argv[3]
print(json.dumps({
    "trialStartedAt": started,
    "trialDays": days,
    "machineId": machine,
    "product": "Hypercluster Desktop",
}, indent=2))
PY
)"
    hc_trial_write_file "$json"
    hc_trial_write_keychain "$json" || true
}

hc_trial_is_expired() {
    if hc_trial_has_commercial_license; then
        return 1
    fi
    local record
    record="$(hc_trial_read_keychain)"
    if [[ -z "$record" ]] && hc_trial_read_file >/dev/null 2>&1; then
        record="$(hc_trial_read_file)"
    fi
    [[ -n "$record" ]] || return 1
    python3 - "$record" "$(hc_trial_days)" <<'PY'
import json, sys
from datetime import datetime, timedelta, timezone

record = json.loads(sys.argv[1])
days = int(sys.argv[2])
started = datetime.fromisoformat(record["trialStartedAt"].replace("Z", "+00:00"))
ends = started + timedelta(days=days)
sys.exit(0 if datetime.now(timezone.utc) >= ends else 1)
PY
}
