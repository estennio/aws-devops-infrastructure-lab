#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly SERVER_NAME="web.lab.test"
readonly LEGACY_ROOT="/var/www/html"
readonly DEPLOY_ROOT="/var/www/aws-devops-infrastructure-lab"
readonly RELEASES_DIR="${DEPLOY_ROOT}/releases"
readonly CURRENT_LINK="${DEPLOY_ROOT}/current"
readonly SITE_AVAILABLE="/etc/nginx/sites-available/${SERVER_NAME}.conf"
readonly SITE_ENABLED="/etc/nginx/sites-enabled/${SERVER_NAME}.conf"
readonly SITE_BACKUP="${SITE_AVAILABLE}.pre-versioned"
readonly LEGACY_CONFIG="${REPO_ROOT}/configs/nginx/web.lab.test.conf"
readonly VERSIONED_CONFIG="${REPO_ROOT}/configs/nginx/web.lab.test.versioned.conf"
readonly DEPLOY_COMMAND_SOURCE="${REPO_ROOT}/scripts/versioned-deploy.sh"
readonly DEPLOY_COMMAND="/usr/local/sbin/aws-devops-versioned-deploy"
readonly SUDOERS_FILE="/etc/sudoers.d/aws-devops-versioned-deploy"
NGINX_CONFIG_CHANGED=false

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "run as root: sudo bash scripts/prepare-versioned-deploy.sh DEPLOY_USER"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

validate_preconditions() {
    local deploy_user="$1"
    local enabled_target

    [[ "${deploy_user}" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "invalid deployment user name"
    id "${deploy_user}" >/dev/null 2>&1 || die "deployment user does not exist: ${deploy_user}"

    for source_file in "${LEGACY_CONFIG}" "${VERSIONED_CONFIG}" "${DEPLOY_COMMAND_SOURCE}"; do
        [[ -f "${source_file}" ]] || die "required repository file not found: ${source_file}"
    done

    [[ -f "${LEGACY_ROOT}/index.html" ]] || die "legacy index.html not found at ${LEGACY_ROOT}"
    [[ -f "${LEGACY_ROOT}/style.css" ]] || die "legacy style.css not found at ${LEGACY_ROOT}"
    [[ -f "${SITE_AVAILABLE}" ]] || die "expected Nginx site file not found: ${SITE_AVAILABLE}"
    [[ -L "${SITE_ENABLED}" ]] || die "expected enabled-site symlink not found: ${SITE_ENABLED}"
    enabled_target="$(readlink -f -- "${SITE_ENABLED}")"
    [[ "${enabled_target}" == "$(readlink -f -- "${SITE_AVAILABLE}")" ]] \
        || die "enabled Nginx site does not point to ${SITE_AVAILABLE}; inspect the active configuration manually"
    if ! cmp -s -- "${LEGACY_CONFIG}" "${SITE_AVAILABLE}" && \
        ! cmp -s -- "${VERSIONED_CONFIG}" "${SITE_AVAILABLE}"; then
        die "active site differs from both reviewed configurations; inspect it manually before migration"
    fi
    [[ -f "/etc/nginx/ssl/${SERVER_NAME}/${SERVER_NAME}.crt" ]] \
        || die "laboratory certificate not found"
    [[ -f "/etc/nginx/ssl/${SERVER_NAME}/${SERVER_NAME}.key" ]] \
        || die "laboratory private key not found"

    nginx -t
}

prepare_initial_release() {
    local initial_name
    local initial_release

    install -d -o root -g root -m 0755 -- "${DEPLOY_ROOT}" "${RELEASES_DIR}"

    if [[ -L "${CURRENT_LINK}" ]]; then
        [[ -d "$(readlink -f -- "${CURRENT_LINK}")" ]] \
            || die "current release link is broken"
        return
    fi
    [[ ! -e "${CURRENT_LINK}" ]] || die "current path exists but is not a symlink"

    initial_name="legacy-$(date -u +%Y%m%dT%H%M%SZ)"
    initial_release="${RELEASES_DIR}/${initial_name}"
    install -d -o root -g root -m 0755 -- "${initial_release}"
    install -o root -g root -m 0644 -- \
        "${LEGACY_ROOT}/index.html" \
        "${LEGACY_ROOT}/style.css" \
        "${initial_release}/"
    printf '%s\n' "${initial_name}" > "${initial_release}/VERSION"
    chmod 0644 "${initial_release}/VERSION"
    ln -s -- "${initial_release}" "${CURRENT_LINK}"
}

install_deployment_command() {
    local deploy_user="$1"
    local temporary_sudoers

    install -o root -g root -m 0755 -- "${DEPLOY_COMMAND_SOURCE}" "${DEPLOY_COMMAND}"
    temporary_sudoers="$(mktemp)"
    printf '%s ALL=(root) NOPASSWD: %s *\n' "${deploy_user}" "${DEPLOY_COMMAND}" > "${temporary_sudoers}"
    chmod 0440 "${temporary_sudoers}"
    visudo -cf "${temporary_sudoers}" >/dev/null
    install -o root -g root -m 0440 -- "${temporary_sudoers}" "${SUDOERS_FILE}"
    rm -f -- "${temporary_sudoers}"
    visudo -cf "${SUDOERS_FILE}" >/dev/null
}

install_nginx_config() {
    if cmp -s -- "${VERSIONED_CONFIG}" "${SITE_AVAILABLE}"; then
        return
    fi

    [[ ! -e "${SITE_BACKUP}" ]] \
        || die "backup already exists at ${SITE_BACKUP}; inspect it before retrying migration"
    install -o root -g root -m 0644 -- "${SITE_AVAILABLE}" "${SITE_BACKUP}"
    install -o root -g root -m 0644 -- "${VERSIONED_CONFIG}" "${SITE_AVAILABLE}"
    NGINX_CONFIG_CHANGED=true

    if ! nginx -t || ! systemctl reload nginx; then
        printf 'Nginx migration failed; restoring the previous configuration.\n' >&2
        install -o root -g root -m 0644 -- "${SITE_BACKUP}" "${SITE_AVAILABLE}"
        nginx -t
        systemctl reload nginx
        die "previous Nginx configuration was restored"
    fi
}

validate_migration() {
    local expected_version
    local http_version
    local https_version

    expected_version="$(<"${CURRENT_LINK}/VERSION")"
    http_version="$(curl --fail --silent --show-error \
        --noproxy '*' \
        --resolve "${SERVER_NAME}:80:127.0.0.1" \
        "http://${SERVER_NAME}/VERSION")" || return
    [[ "${http_version}" == "${expected_version}" ]] \
        || return

    printf '%s\n' \
        "HTTPS uses --insecure only for encrypted transport with the laboratory certificate; certificate trust is not validated."
    https_version="$(curl --insecure --fail --silent --show-error \
        --noproxy '*' \
        --resolve "${SERVER_NAME}:443:127.0.0.1" \
        "https://${SERVER_NAME}/VERSION")" || return
    [[ "${https_version}" == "${expected_version}" ]] \
        || return
}

restore_legacy_nginx_config() {
    [[ "${NGINX_CONFIG_CHANGED}" == true ]] || return
    [[ -f "${SITE_BACKUP}" ]] || die "cannot restore missing Nginx backup: ${SITE_BACKUP}"

    install -o root -g root -m 0644 -- "${SITE_BACKUP}" "${SITE_AVAILABLE}"
    nginx -t
    systemctl reload nginx
}

main() {
    local deploy_user="${1:-}"

    require_root
    [[ "$#" -eq 1 ]] || die "usage: sudo bash scripts/prepare-versioned-deploy.sh DEPLOY_USER"
    for required_command in cmp curl date flock id install mktemp nginx readlink systemctl visudo; do
        require_command "${required_command}"
    done

    validate_preconditions "${deploy_user}"
    prepare_initial_release
    install_deployment_command "${deploy_user}"
    install_nginx_config
    if ! validate_migration; then
        printf 'Versioned site validation failed; restoring the previous Nginx configuration.\n' >&2
        restore_legacy_nginx_config
        die "migration validation failed; the legacy Nginx configuration was restored"
    fi

    printf 'Versioned deployment preparation completed for user %s.\n' "${deploy_user}"
    printf 'The legacy site is preserved at %s and the Nginx backup is %s.\n' \
        "$(readlink -f -- "${CURRENT_LINK}")" "${SITE_BACKUP}"
}

main "$@"
