#!/usr/bin/env bash

set -Eeuo pipefail

readonly SERVER_NAME="web.lab.test"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly WEB_ROOT="/var/www/html"
readonly SITE_AVAILABLE="/etc/nginx/sites-available/${SERVER_NAME}.conf"
readonly SITE_ENABLED="/etc/nginx/sites-enabled/${SERVER_NAME}.conf"
readonly TLS_DIR="/etc/nginx/ssl/${SERVER_NAME}"
readonly TLS_KEY="${TLS_DIR}/${SERVER_NAME}.key"
readonly TLS_CERT="${TLS_DIR}/${SERVER_NAME}.crt"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "run this script as root (for example: sudo bash scripts/bootstrap.sh)"
}

require_sources() {
    local source_file

    for source_file in \
        "${REPO_ROOT}/index.html" \
        "${REPO_ROOT}/style.css" \
        "${REPO_ROOT}/configs/nginx/web.lab.test.conf"; do
        [[ -f "${source_file}" ]] || die "required repository file not found: ${source_file}"
    done
}

install_packages() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install --yes --no-install-recommends nginx openssl curl ca-certificates
}

# The SSM deploy downloads releases from S3 with the AWS CLI, so the instance
# gets it at bootstrap instead of during a deployment. Ubuntu 24.04 ships snapd.
install_aws_cli() {
    if command -v aws >/dev/null 2>&1 || [[ -x /snap/bin/aws ]]; then
        printf 'AWS CLI already installed.\n'
        return
    fi

    command -v snap >/dev/null 2>&1 || die "snap is required to install the AWS CLI"
    # On first boot, cloud-init can run before snapd has finished seeding.
    snap wait system seed.loaded
    snap install aws-cli --classic
}

validate_existing_certificate() {
    local cert_public_key
    local key_public_key
    local subject

    openssl x509 -in "${TLS_CERT}" -noout >/dev/null 2>&1 \
        || die "existing certificate is not a readable X.509 certificate: ${TLS_CERT}"
    openssl pkey -in "${TLS_KEY}" -noout >/dev/null 2>&1 \
        || die "existing private key is not readable by OpenSSL: ${TLS_KEY}"
    openssl x509 -in "${TLS_CERT}" -noout -checkend 0 >/dev/null \
        || die "existing certificate is expired; it was preserved and must be replaced deliberately"

    subject="$(openssl x509 -in "${TLS_CERT}" -noout -subject -nameopt RFC2253)"
    [[ ",${subject#subject=}," == *",CN=${SERVER_NAME},"* ]] \
        || die "existing certificate CN is not ${SERVER_NAME}; it was preserved"

    openssl x509 -in "${TLS_CERT}" -noout -ext subjectAltName \
        | tr ',' '\n' \
        | sed 's/^[[:space:]]*//' \
        | grep -Fxq "DNS:${SERVER_NAME}" \
        || die "existing certificate SAN does not contain DNS:${SERVER_NAME}; it was preserved"

    cert_public_key="$(
        openssl x509 -in "${TLS_CERT}" -pubkey -noout \
            | openssl pkey -pubin -outform DER 2>/dev/null \
            | openssl dgst -sha256
    )"
    key_public_key="$(
        openssl pkey -in "${TLS_KEY}" -pubout -outform DER 2>/dev/null \
            | openssl dgst -sha256
    )"
    [[ "${cert_public_key}" == "${key_public_key}" ]] \
        || die "existing certificate and private key do not match; both files were preserved"
}

prepare_certificate() {
    install -d -o root -g root -m 0750 "${TLS_DIR}"

    if [[ -e "${TLS_KEY}" || -e "${TLS_CERT}" ]]; then
        [[ -f "${TLS_KEY}" && -f "${TLS_CERT}" ]] \
            || die "incomplete TLS material in ${TLS_DIR}; existing files were preserved"
        validate_existing_certificate
        printf 'Keeping the existing valid certificate for %s.\n' "${SERVER_NAME}"
    else
        openssl req \
            -x509 \
            -nodes \
            -newkey rsa:2048 \
            -sha256 \
            -days 365 \
            -keyout "${TLS_KEY}" \
            -out "${TLS_CERT}" \
            -subj "/CN=${SERVER_NAME}" \
            -addext "subjectAltName=DNS:${SERVER_NAME}"
        printf 'Created a self-signed laboratory certificate for %s.\n' "${SERVER_NAME}"
    fi

    chown root:root "${TLS_KEY}" "${TLS_CERT}"
    chmod 0600 "${TLS_KEY}"
    chmod 0644 "${TLS_CERT}"
}

publish_site() {
    install -d -o root -g root -m 0755 "${WEB_ROOT}"
    install -o root -g root -m 0644 "${REPO_ROOT}/index.html" "${WEB_ROOT}/index.html"
    install -o root -g root -m 0644 "${REPO_ROOT}/style.css" "${WEB_ROOT}/style.css"
}

configure_nginx() {
    install -o root -g root -m 0644 \
        "${REPO_ROOT}/configs/nginx/web.lab.test.conf" \
        "${SITE_AVAILABLE}"
    ln -sfn "${SITE_AVAILABLE}" "${SITE_ENABLED}"
    rm -f /etc/nginx/sites-enabled/default

    nginx -t
    systemctl enable nginx

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    else
        systemctl start nginx
    fi
}

main() {
    require_root
    require_sources
    install_packages
    install_aws_cli
    prepare_certificate
    publish_site
    configure_nginx
    printf 'Nginx bootstrap completed for http://%s and https://%s.\n' \
        "${SERVER_NAME}" "${SERVER_NAME}"
}

main "$@"
