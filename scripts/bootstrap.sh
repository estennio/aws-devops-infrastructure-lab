#!/usr/bin/env bash

set -Eeuo pipefail

readonly SERVER_NAME="web.lab.test"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly DEPLOY_ROOT="/var/www/aws-devops-infrastructure-lab"
readonly RELEASES_DIR="${DEPLOY_ROOT}/releases"
readonly CURRENT_LINK="${DEPLOY_ROOT}/current"
readonly SITE_CONFIG_SOURCE="${REPO_ROOT}/configs/nginx/web.lab.test.versioned.conf"
readonly SITE_AVAILABLE="/etc/nginx/sites-available/${SERVER_NAME}.conf"
readonly SITE_ENABLED="/etc/nginx/sites-enabled/${SERVER_NAME}.conf"
readonly DEPLOY_COMMAND_SOURCE="${REPO_ROOT}/scripts/versioned-deploy.sh"
readonly DEPLOY_COMMAND="/usr/local/sbin/aws-devops-versioned-deploy"
readonly TLS_DIR="/etc/nginx/ssl/${SERVER_NAME}"
readonly TLS_KEY="${TLS_DIR}/${SERVER_NAME}.key"
readonly TLS_CERT="${TLS_DIR}/${SERVER_NAME}.crt"
readonly VALIDATION_ATTEMPTS=10
# Copy of the site file that was active before this run, kept only when this
# run replaces a different configuration, so a failed check can restore it.
PREVIOUS_SITE_BACKUP=""

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
        "${SITE_CONFIG_SOURCE}" \
        "${DEPLOY_COMMAND_SOURCE}"; do
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

# The release name is the commit SHA of the checkout, so the first release has
# the same name a deployment of that commit would use. Outside a Git checkout
# (for example a downloaded archive) a timestamped name is used instead.
initial_release_name() {
    local sha

    if sha="$(git -c safe.directory="${REPO_ROOT}" -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null)" \
        && [[ "${sha}" =~ ^[0-9a-f]{40}$ ]]; then
        printf '%s\n' "${sha}"
    else
        printf 'bootstrap-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)"
    fi
}

# Creates the first release only when no release is active. On a server that
# already has one, the deployed release is kept: re-running the bootstrap must
# never roll a deployment back to the repository checkout.
prepare_initial_release() {
    local release_name
    local release_dir
    local temporary_release

    install -d -o root -g root -m 0755 -- "${DEPLOY_ROOT}" "${RELEASES_DIR}"

    if [[ -L "${CURRENT_LINK}" ]]; then
        [[ -f "$(readlink -f -- "${CURRENT_LINK}")/VERSION" ]] \
            || die "current release link is broken or has no VERSION; inspect ${DEPLOY_ROOT} manually"
        printf 'Keeping the active release %s.\n' "$(<"${CURRENT_LINK}/VERSION")"
        return
    fi
    [[ ! -e "${CURRENT_LINK}" ]] || die "${CURRENT_LINK} exists but is not a symlink"

    release_name="$(initial_release_name)"
    release_dir="${RELEASES_DIR}/${release_name}"

    if [[ ! -d "${release_dir}" ]]; then
        temporary_release="${RELEASES_DIR}/.${release_name}.${BASHPID}"
        rm -rf -- "${temporary_release}"
        install -d -o root -g root -m 0755 -- "${temporary_release}"
        install -o root -g root -m 0644 -- \
            "${REPO_ROOT}/index.html" \
            "${REPO_ROOT}/style.css" \
            "${temporary_release}/"
        printf '%s\n' "${release_name}" > "${temporary_release}/VERSION"
        chmod 0644 "${temporary_release}/VERSION"
        mv -- "${temporary_release}" "${release_dir}"
    fi

    ln -s -- "${release_dir}" "${CURRENT_LINK}"
    printf 'Created the initial release %s.\n' "${release_name}"
}

install_deployment_command() {
    install -o root -g root -m 0755 -- "${DEPLOY_COMMAND_SOURCE}" "${DEPLOY_COMMAND}"
}

restore_previous_site() {
    [[ -n "${PREVIOUS_SITE_BACKUP}" ]] || return 0

    printf 'Restoring the previous Nginx site configuration.\n' >&2
    install -o root -g root -m 0644 -- "${PREVIOUS_SITE_BACKUP}" "${SITE_AVAILABLE}"
    nginx -t && systemctl reload nginx
}

configure_nginx() {
    if [[ -f "${SITE_AVAILABLE}" ]] && ! cmp -s -- "${SITE_CONFIG_SOURCE}" "${SITE_AVAILABLE}"; then
        PREVIOUS_SITE_BACKUP="$(mktemp)"
        install -m 0600 -- "${SITE_AVAILABLE}" "${PREVIOUS_SITE_BACKUP}"
    fi

    install -o root -g root -m 0644 -- "${SITE_CONFIG_SOURCE}" "${SITE_AVAILABLE}"
    ln -sfn -- "${SITE_AVAILABLE}" "${SITE_ENABLED}"
    rm -f -- /etc/nginx/sites-enabled/default

    if ! nginx -t; then
        restore_previous_site
        die "the versioned Nginx configuration failed nginx -t"
    fi

    systemctl enable nginx
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    else
        systemctl start nginx
    fi
}

# HTTPS uses --insecure only to prove encrypted transport with the laboratory
# certificate; certificate trust is not validated.
served_version_matches() {
    local expected_version="$1"
    local scheme
    local port
    local tls_flags
    local served_version

    for scheme in http https; do
        port=80
        tls_flags=()
        if [[ "${scheme}" == "https" ]]; then
            port=443
            tls_flags=(--insecure)
        fi

        served_version="$(curl "${tls_flags[@]}" --fail --silent \
            --noproxy '*' \
            --max-time 10 \
            --resolve "${SERVER_NAME}:${port}:127.0.0.1" \
            "${scheme}://${SERVER_NAME}/VERSION")" || return
        [[ "${served_version}" == "${expected_version}" ]] || return
    done
}

# `systemctl reload nginx` only signals the master process and returns at once,
# so old workers can briefly keep serving the previous root. Retry for a short
# window instead of trusting a single immediate check.
validate_served_release() {
    local expected_version
    local attempt

    expected_version="$(<"${CURRENT_LINK}/VERSION")"

    for ((attempt = 1; attempt <= VALIDATION_ATTEMPTS; attempt++)); do
        if served_version_matches "${expected_version}"; then
            printf 'HTTP and HTTPS serve release %s (attempt %d).\n' "${expected_version}" "${attempt}"
            return 0
        fi
        sleep 1
    done

    restore_previous_site
    die "release ${expected_version} was not served over HTTP and HTTPS after ${VALIDATION_ATTEMPTS} attempts"
}

main() {
    require_root
    require_sources
    install_packages
    install_aws_cli
    prepare_certificate
    prepare_initial_release
    install_deployment_command
    configure_nginx
    validate_served_release
    if [[ -n "${PREVIOUS_SITE_BACKUP}" ]]; then
        rm -f -- "${PREVIOUS_SITE_BACKUP}"
    fi
    printf 'Nginx bootstrap completed for http://%s and https://%s.\n' \
        "${SERVER_NAME}" "${SERVER_NAME}"
}

main "$@"
