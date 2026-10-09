#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SERVER_NAME="web.lab.test"
readonly TLS_CERT="/etc/nginx/ssl/${SERVER_NAME}/${SERVER_NAME}.crt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
readonly RUN_ID
readonly DEFAULT_OUTPUT="${REPO_ROOT}/evidence/artifacts/server-${RUN_ID}.txt"
readonly OUTPUT_FILE="${1:-${DEFAULT_OUTPUT}}"
CHECK_FAILURES=0

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_root() {
    [[ "${EUID}" -eq 0 ]] \
        || die "run this collector as root (for example: sudo bash scripts/collect-evidence.sh)"
}

require_commands() {
    local command_name

    for command_name in date systemctl nginx ss curl openssl awk grep tee timeout; do
        command -v "${command_name}" >/dev/null 2>&1 \
            || die "required command not found: ${command_name}"
    done
}

run_check() {
    local title="$1"
    local status
    shift

    printf '\n=== %s ===\n' "${title}"
    set +e
    "$@"
    status=$?
    set -e
    printf 'exit_status=%d\n' "${status}"
    if ((status != 0)); then
        ((CHECK_FAILURES += 1))
    fi
    return 0
}

collect_os_version() {
    local status=0

    if command -v lsb_release >/dev/null 2>&1; then
        lsb_release -a 2>/dev/null || status=$?
    else
        grep -E '^(NAME|VERSION|VERSION_ID|VERSION_CODENAME|PRETTY_NAME)=' /etc/os-release \
            || status=$?
    fi
    printf 'kernel=%s\n' "$(uname -r)" || status=$?
    return "${status}"
}

collect_nginx_state() {
    local status=0

    systemctl is-active nginx || status=$?
    systemctl is-enabled nginx || status=$?
    systemctl show nginx \
        --property=ActiveState,SubState,UnitFileState \
        --no-pager || status=$?
    return "${status}"
}

collect_nginx_test() {
    nginx -t
}

collect_listeners() {
    local listeners

    listeners="$(ss -lntH | awk '$4 ~ /:(80|443)$/')"
    if [[ -z "${listeners}" ]]; then
        printf 'No TCP listeners found on ports 80 or 443.\n'
        return 1
    fi
    printf '%s\n' "${listeners}"
}

collect_http() {
    curl --fail --silent --show-error --head --max-time 10 http://127.0.0.1/
}

collect_https_insecure() {
    printf 'Note: --insecure verifies HTTPS connectivity, not certificate trust.\n'
    curl --insecure --fail --silent --show-error --head --max-time 10 \
        --resolve "${SERVER_NAME}:443:127.0.0.1" \
        "https://${SERVER_NAME}/"
}

collect_certificate_properties() {
    [[ -f "${TLS_CERT}" ]] || {
        printf 'Certificate not found: %s\n' "${TLS_CERT}"
        return 1
    }

    openssl x509 -in "${TLS_CERT}" -noout \
        -subject \
        -issuer \
        -serial \
        -dates \
        -fingerprint \
        -sha256 \
        -ext subjectAltName
}

collect_tls_1_3() {
    timeout 15 openssl s_client \
        -brief \
        -connect 127.0.0.1:443 \
        -servername "${SERVER_NAME}" \
        -tls1_3 </dev/null
}

collect_all() {
    printf 'AWS DevOps Infrastructure Lab - server evidence\n'
    printf 'Collector output excludes credentials, tokens, and private-key contents.\n'

    run_check "UTC date and time" date -u --iso-8601=seconds
    run_check "Operating system version" collect_os_version
    run_check "Nginx service state" collect_nginx_state
    run_check "Nginx configuration test" collect_nginx_test
    run_check "TCP listeners on 80 and 443" collect_listeners
    run_check "Local HTTP response" collect_http
    run_check "Local HTTPS response without trust validation (-k)" collect_https_insecure
    run_check "Public certificate properties" collect_certificate_properties
    run_check "Forced TLS 1.3 negotiation" collect_tls_1_3

    printf '\nchecks_failed=%d\n' "${CHECK_FAILURES}"
    ((CHECK_FAILURES == 0))
}

main() {
    local -a pipeline_status

    require_root
    require_commands
    [[ ! -e "${OUTPUT_FILE}" ]] || die "output file already exists: ${OUTPUT_FILE}"
    mkdir -p "$(dirname -- "${OUTPUT_FILE}")"

    set +e
    collect_all 2>&1 | tee "${OUTPUT_FILE}"
    pipeline_status=("${PIPESTATUS[@]}")
    set -e

    ((pipeline_status[1] == 0)) || die "could not write evidence file: ${OUTPUT_FILE}"
    chmod 0600 "${OUTPUT_FILE}"
    printf 'Evidence written to %s\n' "${OUTPUT_FILE}"
    if ((pipeline_status[0] != 0)); then
        printf 'One or more evidence checks failed; inspect the recorded exit statuses.\n' >&2
        return "${pipeline_status[0]}"
    fi
}

main "$@"
