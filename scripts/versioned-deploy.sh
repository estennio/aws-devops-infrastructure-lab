#!/usr/bin/env bash

set -Eeuo pipefail

readonly SERVER_NAME="web.lab.test"
readonly DEPLOY_ROOT="/var/www/aws-devops-infrastructure-lab"
readonly RELEASES_DIR="${DEPLOY_ROOT}/releases"
readonly CURRENT_LINK="${DEPLOY_ROOT}/current"
readonly PREVIOUS_LINK="${DEPLOY_ROOT}/previous"
readonly LOCK_FILE="${DEPLOY_ROOT}/deploy.lock"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "this command must run as root"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

validate_sha() {
    [[ "$1" =~ ^[0-9a-f]{40}$ ]] || die "commit SHA must contain exactly 40 lowercase hexadecimal characters"
}

validate_release_files() {
    local release_dir="$1"
    local expected_version="$2"
    local file

    [[ -d "${release_dir}" && ! -L "${release_dir}" ]] \
        || die "release directory is missing or unsafe: ${release_dir}"

    for file in index.html style.css VERSION; do
        [[ -f "${release_dir}/${file}" && ! -L "${release_dir}/${file}" ]] \
            || die "release file is missing or unsafe: ${release_dir}/${file}"
    done

    [[ "$(<"${release_dir}/VERSION")" == "${expected_version}" ]] \
        || die "VERSION does not match expected commit ${expected_version}"
}

atomic_link() {
    local target="$1"
    local link_path="$2"
    local temporary_link="${DEPLOY_ROOT}/.$(basename "${link_path}").${BASHPID}"

    rm -f -- "${temporary_link}"
    ln -s -- "${target}" "${temporary_link}"
    mv -Tf -- "${temporary_link}" "${link_path}"
}

served_version() {
    local scheme="$1"

    if [[ "${scheme}" == "https" ]]; then
        curl --insecure --fail --silent --show-error \
            --noproxy '*' \
            --resolve "${SERVER_NAME}:443:127.0.0.1" \
            "https://${SERVER_NAME}/VERSION"
    else
        curl --fail --silent --show-error \
            --noproxy '*' \
            --resolve "${SERVER_NAME}:80:127.0.0.1" \
            "http://${SERVER_NAME}/VERSION"
    fi
}

validate_served_release() {
    local expected_version="$1"
    local http_version
    local https_version

    curl --fail --silent --show-error \
        --noproxy '*' \
        --resolve "${SERVER_NAME}:80:127.0.0.1" \
        "http://${SERVER_NAME}/index.html" > /dev/null || return
    curl --fail --silent --show-error \
        --noproxy '*' \
        --resolve "${SERVER_NAME}:80:127.0.0.1" \
        "http://${SERVER_NAME}/style.css" > /dev/null || return
    http_version="$(served_version http)" || return
    [[ "${http_version}" == "${expected_version}" ]] \
        || return

    printf '%s\n' \
        "HTTPS uses --insecure only for encrypted transport with the laboratory certificate; certificate trust is not validated."
    curl --insecure --fail --silent --show-error \
        --noproxy '*' \
        --resolve "${SERVER_NAME}:443:127.0.0.1" \
        "https://${SERVER_NAME}/index.html" > /dev/null || return
    curl --insecure --fail --silent --show-error \
        --noproxy '*' \
        --resolve "${SERVER_NAME}:443:127.0.0.1" \
        "https://${SERVER_NAME}/style.css" > /dev/null || return
    https_version="$(served_version https)" || return
    [[ "${https_version}" == "${expected_version}" ]] \
        || return
}

reload_and_validate() {
    local expected_version="$1"

    nginx -t || return
    systemctl reload nginx || return
    validate_served_release "${expected_version}" || return
}

activate_release() {
    local sha="$1"
    local staging_dir="$2"
    local release_dir="${RELEASES_DIR}/${sha}"
    local temporary_release="${RELEASES_DIR}/.${sha}.${BASHPID}"
    local prior_target
    local prior_version

    validate_sha "${sha}"
    [[ "${staging_dir}" == "/tmp/aws-devops-site/${sha}" ]] \
        || die "staging directory must be /tmp/aws-devops-site/${sha}"
    validate_release_files "${staging_dir}" "${sha}"

    [[ -L "${CURRENT_LINK}" ]] || die "current release link is missing; run server preparation first"
    prior_target="$(readlink -f -- "${CURRENT_LINK}")"
    [[ -d "${prior_target}" ]] || die "current release target is missing: ${prior_target}"
    [[ -f "${prior_target}/VERSION" ]] || die "current release has no VERSION file"
    prior_version="$(<"${prior_target}/VERSION")"

    if [[ -e "${release_dir}" ]]; then
        validate_release_files "${release_dir}" "${sha}"
        cmp -s -- "${staging_dir}/index.html" "${release_dir}/index.html" \
            || die "existing release ${sha} has different index.html content"
        cmp -s -- "${staging_dir}/style.css" "${release_dir}/style.css" \
            || die "existing release ${sha} has different style.css content"
    else
        rm -rf -- "${temporary_release}"
        install -d -o root -g root -m 0755 -- "${temporary_release}"
        install -o root -g root -m 0644 -- \
            "${staging_dir}/index.html" \
            "${staging_dir}/style.css" \
            "${staging_dir}/VERSION" \
            "${temporary_release}/"
        mv -- "${temporary_release}" "${release_dir}"
    fi

    atomic_link "${release_dir}" "${CURRENT_LINK}"

    if ! reload_and_validate "${sha}"; then
        printf 'Activation validation failed; restoring version %s.\n' "${prior_version}" >&2
        atomic_link "${prior_target}" "${CURRENT_LINK}"
        nginx -t
        systemctl reload nginx
        validate_served_release "${prior_version}"
        die "release ${sha} failed validation and was rolled back"
    fi

    if [[ "${prior_target}" != "${release_dir}" ]]; then
        atomic_link "${prior_target}" "${PREVIOUS_LINK}"
    fi

    rm -rf -- "${staging_dir}"
    printf 'Activated release %s; previous release is %s.\n' "${sha}" "${prior_version}"
}

rollback_release() {
    local expected_current="$1"
    local current_target
    local previous_target
    local current_version
    local previous_version

    validate_sha "${expected_current}"
    [[ -L "${CURRENT_LINK}" ]] || die "current release link is missing"
    [[ -L "${PREVIOUS_LINK}" ]] || die "previous release link is missing"

    current_target="$(readlink -f -- "${CURRENT_LINK}")"
    previous_target="$(readlink -f -- "${PREVIOUS_LINK}")"
    [[ -f "${current_target}/VERSION" ]] || die "current release has no VERSION file"
    [[ -f "${previous_target}/VERSION" ]] || die "previous release has no VERSION file"
    current_version="$(<"${current_target}/VERSION")"
    previous_version="$(<"${previous_target}/VERSION")"
    [[ "${current_version}" == "${expected_current}" ]] \
        || die "refusing rollback: current version is ${current_version}, not ${expected_current}"

    atomic_link "${previous_target}" "${CURRENT_LINK}"

    if ! reload_and_validate "${previous_version}"; then
        printf 'Rollback validation failed; restoring version %s.\n' "${current_version}" >&2
        atomic_link "${current_target}" "${CURRENT_LINK}"
        nginx -t
        systemctl reload nginx
        validate_served_release "${current_version}"
        die "rollback to ${previous_version} failed validation"
    fi

    atomic_link "${current_target}" "${PREVIOUS_LINK}"
    printf 'Rolled back from %s to %s.\n' "${current_version}" "${previous_version}"
}

main() {
    local action="${1:-}"

    require_root
    for required_command in cmp curl flock install ln mv nginx readlink systemctl; do
        require_command "${required_command}"
    done

    install -d -o root -g root -m 0755 -- "${DEPLOY_ROOT}" "${RELEASES_DIR}"
    exec 9>"${LOCK_FILE}"
    flock -n 9 || die "another server-side deployment operation is already running"

    case "${action}" in
        activate)
            [[ "$#" -eq 3 ]] || die "usage: $0 activate COMMIT_SHA STAGING_DIRECTORY"
            activate_release "$2" "$3"
            ;;
        rollback)
            [[ "$#" -eq 2 ]] || die "usage: $0 rollback EXPECTED_CURRENT_SHA"
            rollback_release "$2"
            ;;
        *)
            die "usage: $0 {activate COMMIT_SHA STAGING_DIRECTORY|rollback EXPECTED_CURRENT_SHA}"
            ;;
    esac
}

main "$@"
