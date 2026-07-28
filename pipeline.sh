#!/usr/bin/env bash

set -Eeuo pipefail

# Expected project layout:
#
# devsecops-pipeline/
# ├── pipeline.sh
# └── scripts/
#     ├── lib.sh
#     └── pipeline-cli.sh

PIPELINE_ENTRY_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"

# shellcheck source=/dev/null
source "$PIPELINE_ENTRY_DIR/scripts/lib.sh"

# shellcheck source=/dev/null
source "$PIPELINE_ENTRY_DIR/scripts/pipeline-cli.sh"

pipeline_error() {
    printf 'Error: %s\n' "$*" >&2
}

pipeline_print_help() {
    printf 'Usage: %s [OPTIONS]\n\n' "$(basename -- "$0")"
    pipeline_cli_print_help
}

pipeline_image_operation_selected() {
    local operation

    for operation in \
        build \
        syft \
        trivy-image \
        docker-push \
        cosign-sign \
        cosign-verify \
        cosign-tree \
        kyverno-test
    do
        if pipeline_cli_operation_selected "$operation"; then
            return 0
        fi
    done

    return 1
}

pipeline_remote_operation_selected() {
    local operation

    for operation in \
        cosign-sign \
        cosign-verify \
        cosign-tree \
        kyverno-test
    do
        if pipeline_cli_operation_selected "$operation"; then
            return 0
        fi
    done

    return 1
}

pipeline_validate_arguments() {
    if ! pipeline_cli_any_operation_selected; then
        pipeline_error "no operation was selected"
        printf 'Use --help to see the available operations.\n' >&2
        return 2
    fi

    if pipeline_image_operation_selected &&
        [[ -z "$PIPELINE_CLI_IMAGE" ]]
    then
        pipeline_error "the selected operation requires --image IMAGE"
        return 2
    fi

    # grype_sbom_scan reads the SBOM generated in the current run's report
    # directory, so Syft must be selected in the same invocation.
    if pipeline_cli_operation_selected grype &&
        ! pipeline_cli_operation_selected syft
    then
        pipeline_error "--grype requires --syft in the same run"
        return 2
    fi

    if pipeline_cli_operation_selected kyverno-policy &&
        (( ${#PIPELINE_CLI_POLICY_FILES[@]} == 0 ))
    then
        pipeline_error "--apply-policy requires at least one --policy-file FILE"
        return 2
    fi

    if ! pipeline_cli_operation_selected kyverno-policy &&
        (( ${#PIPELINE_CLI_POLICY_FILES[@]} > 0 ))
    then
        pipeline_error "--policy-file requires --apply-policy"
        return 2
    fi

    if [[ -n "$PIPELINE_CLI_PRIVATE_KEY" ]] &&
        ! pipeline_cli_operation_selected cosign-sign
    then
        pipeline_error "--private-key requires --sign"
        return 2
    fi

    if [[ -n "$PIPELINE_CLI_PUBLIC_KEY" ]] &&
        ! pipeline_cli_operation_selected cosign-verify
    then
        pipeline_error "--public-key requires --verify"
        return 2
    fi

    # Cosign and Kyverno operate on registry images. If this invocation builds
    # the image, push it first so they do not inspect or sign an older Docker
    # Hub image that happens to have the same tag.
    if pipeline_cli_operation_selected build &&
        pipeline_remote_operation_selected &&
        ! pipeline_cli_operation_selected docker-push
    then
        pipeline_error \
            "--build with Cosign or Kyverno image testing requires --push"
        return 2
    fi
}

pipeline_run_selected_operations() {
    if pipeline_cli_operation_selected hadolint; then
        hadolint_scan "$PIPELINE_CLI_DOCKERFILE"
    fi

    if pipeline_cli_operation_selected trivy-config; then
        trivy_dockerfile_scan "$PIPELINE_CLI_DOCKERFILE"
    fi

    if pipeline_cli_operation_selected build; then
        docker_build_image \
            "$PIPELINE_CLI_IMAGE" \
            "$PIPELINE_CLI_DOCKERFILE"
    fi

    if pipeline_cli_operation_selected syft; then
        syft_generate_sbom "$PIPELINE_CLI_IMAGE"
    fi

    if pipeline_cli_operation_selected grype; then
        grype_sbom_scan
    fi

    if pipeline_cli_operation_selected trivy-image; then
        trivy_image_scan "$PIPELINE_CLI_IMAGE"
    fi

    # A newly built image is scanned before it is published.
    if pipeline_cli_operation_selected docker-push; then
        docker_push_image "$PIPELINE_CLI_IMAGE"
    fi

    if pipeline_cli_operation_selected cosign-sign; then
        if [[ -n "$PIPELINE_CLI_PRIVATE_KEY" ]]; then
            cosign_sign_image \
                "$PIPELINE_CLI_IMAGE" \
                "$PIPELINE_CLI_PRIVATE_KEY"
        else
            cosign_sign_image "$PIPELINE_CLI_IMAGE"
        fi
    fi

    if pipeline_cli_operation_selected cosign-verify; then
        if [[ -n "$PIPELINE_CLI_PUBLIC_KEY" ]]; then
            cosign_verify_image \
                "$PIPELINE_CLI_IMAGE" \
                "$PIPELINE_CLI_PUBLIC_KEY"
        else
            cosign_verify_image "$PIPELINE_CLI_IMAGE"
        fi
    fi

    if pipeline_cli_operation_selected cosign-tree; then
        cosign_show_tree "$PIPELINE_CLI_IMAGE"
    fi

    if pipeline_cli_operation_selected kyverno-policy; then
        local policy_file

        for policy_file in "${PIPELINE_CLI_POLICY_FILES[@]}"; do
            kubectl_apply_policy "$policy_file"
        done
    fi

    if pipeline_cli_operation_selected check-kyverno; then
        check_kyverno
    fi

    if pipeline_cli_operation_selected kyverno-test; then
        kyverno_image_testing "$PIPELINE_CLI_IMAGE"
    fi
}

main() {
    if ! pipeline_cli_parse "$@"; then
        printf 'Use --help to see the available options.\n' >&2
        return 2
    fi

    if [[ "$PIPELINE_CLI_HELP" == true ]]; then
        pipeline_print_help
        return 0
    fi

    pipeline_validate_arguments

    initialize_run "$@"
    trap on_exit EXIT

    pipeline_run_selected_operations
}

main "$@"
