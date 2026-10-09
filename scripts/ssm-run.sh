#!/usr/bin/env bash
# Run a shell script on an EC2 instance through SSM Run Command, wait for it to
# finish, print its output, and exit non-zero if the command did not succeed.
#
# Usage: ssm-run.sh INSTANCE_ID REGION COMMENT SCRIPT
# Requires the AWS CLI and jq; credentials come from the environment.

set -Eeuo pipefail

readonly POLL_INTERVAL_SECONDS=5
readonly MAX_WAIT_SECONDS=600

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

main() {
    [[ "$#" -eq 4 ]] || die "usage: $0 INSTANCE_ID REGION COMMENT SCRIPT"

    local instance_id="$1"
    local region="$2"
    local comment="$3"
    local script="$4"
    local parameters
    local command_id
    local status
    local waited=0

    parameters="$(jq -cn --arg script "${script}" \
        '{commands: [$script], executionTimeout: ["300"]}')"

    command_id="$(aws ssm send-command \
        --region "${region}" \
        --instance-ids "${instance_id}" \
        --document-name AWS-RunShellScript \
        --comment "${comment:0:100}" \
        --parameters "${parameters}" \
        --query Command.CommandId \
        --output text)"
    printf 'SSM command %s sent to %s.\n' "${command_id}" "${instance_id}"

    while true; do
        # The invocation can be briefly unknown right after send-command.
        status="$(aws ssm get-command-invocation \
            --region "${region}" \
            --command-id "${command_id}" \
            --instance-id "${instance_id}" \
            --query Status \
            --output text 2>/dev/null || echo Pending)"

        case "${status}" in
            Pending | InProgress | Delayed) ;;
            *) break ;;
        esac

        if ((waited >= MAX_WAIT_SECONDS)); then
            die "timed out after ${MAX_WAIT_SECONDS}s waiting for SSM command ${command_id}"
        fi
        sleep "${POLL_INTERVAL_SECONDS}"
        waited=$((waited + POLL_INTERVAL_SECONDS))
    done

    printf '::group::SSM stdout\n'
    aws ssm get-command-invocation --region "${region}" --command-id "${command_id}" \
        --instance-id "${instance_id}" --query StandardOutputContent --output text
    printf '::endgroup::\n::group::SSM stderr\n'
    aws ssm get-command-invocation --region "${region}" --command-id "${command_id}" \
        --instance-id "${instance_id}" --query StandardErrorContent --output text
    printf '::endgroup::\n'

    [[ "${status}" == "Success" ]] || die "SSM command ${command_id} finished with status ${status}"
    printf 'SSM command %s succeeded.\n' "${command_id}"
}

main "$@"
