#!/usr/bin/env bash
# Check that a host serves a complete release over HTTP and HTTPS and that the
# served VERSION matches the expected commit. Used by the deploy workflows from
# the GitHub runner; the server-side command has its own copy of this check
# because it is installed as a standalone file.
#
# Usage: validate-release.sh HOST EXPECTED_VERSION
#
# HTTPS uses --insecure because the laboratory certificate is self-signed: this
# proves encrypted transport only and does not validate certificate trust.

set -Eeuo pipefail

readonly SERVER_NAME="web.lab.test"
readonly RELEASE_FILES=(index.html style.css)

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

fetch() {
    local scheme="$1"
    local port="$2"
    local host="$3"
    local path="$4"
    local tls_flags=()

    [[ "${scheme}" == "https" ]] && tls_flags=(--insecure)

    curl "${tls_flags[@]}" --fail --silent --show-error \
        --noproxy '*' \
        --connect-timeout 10 --max-time 30 \
        --connect-to "${SERVER_NAME}:${port}:${host}:${port}" \
        "${scheme}://${SERVER_NAME}/${path}"
}

validate_scheme() {
    local scheme="$1"
    local port="$2"
    local host="$3"
    local expected_version="$4"
    local file
    local served_version

    for file in "${RELEASE_FILES[@]}"; do
        fetch "${scheme}" "${port}" "${host}" "${file}" > /dev/null \
            || die "${scheme^^} request for ${file} failed"
    done

    served_version="$(fetch "${scheme}" "${port}" "${host}" VERSION)" \
        || die "${scheme^^} request for VERSION failed"
    [[ "${served_version}" == "${expected_version}" ]] \
        || die "${scheme^^} serves VERSION ${served_version}, expected ${expected_version}"
}

main() {
    [[ "$#" -eq 2 ]] || die "usage: $0 HOST EXPECTED_VERSION"

    local host="$1"
    local expected_version="$2"

    [[ -n "${host}" ]] || die "HOST must not be empty"
    [[ -n "${expected_version}" ]] || die "EXPECTED_VERSION must not be empty"

    validate_scheme http 80 "${host}" "${expected_version}"
    echo "HTTPS check uses --insecure for the laboratory certificate; certificate trust is not validated."
    validate_scheme https 443 "${host}" "${expected_version}"

    printf 'HTTP and HTTPS serve version %s from %s.\n' "${expected_version}" "${host}"
}

main "$@"
