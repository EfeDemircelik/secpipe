#!/usr/bin/env bash

# This file is a CLI parsing library. Source it from an executable pipeline
# script. It records requested operations and their inputs, but does not run
# Hadolint, Trivy, Docker, Syft, Grype, Cosign, or Kyverno itself.

# Prevent loading the CLI library more than once.
if [[ "${PIPELINE_CLI_LOADED:-false}" == true ]]; then
    return 0
fi

PIPELINE_CLI_LOADED=true

# Selected operations are stored as a set.
declare -Ag PIPELINE_CLI_OPERATIONS=()

PIPELINE_CLI_IMAGE=""
PIPELINE_CLI_DOCKERFILE="Dockerfile"
PIPELINE_CLI_PRIVATE_KEY=""
PIPELINE_CLI_PUBLIC_KEY=""
PIPELINE_CLI_HELP=false

pipeline_cli_reset() {
    PIPELINE_CLI_OPERATIONS=()
    PIPELINE_CLI_POLICY_FILES=()

    PIPELINE_CLI_IMAGE=""
    PIPELINE_CLI_DOCKERFILE="Dockerfile"
    PIPELINE_CLI_PRIVATE_KEY=""
    PIPELINE_CLI_PUBLIC_KEY=""
    PIPELINE_CLI_HELP=false
}

pipeline_cli_parse() {
    local image_was_set=false
    local dockerfile_was_set=false
    local private_key_was_set=false
    local public_key_was_set=false

    pipeline_cli_reset

    while (( $# > 0 )); do
        case "$1" in
            # Pipeline operations
            -H|--hadolint)
                PIPELINE_CLI_OPERATIONS[hadolint]=true
                shift
                ;;

            -C|--trivy-config)
                PIPELINE_CLI_OPERATIONS[trivy-config]=true
                shift
                ;;

            -B|--build)
                PIPELINE_CLI_OPERATIONS[build]=true
                shift
                ;;

            -S|--syft)
                PIPELINE_CLI_OPERATIONS[syft]=true
                shift
                ;;

            -G|--grype)
                PIPELINE_CLI_OPERATIONS[grype]=true
                shift
                ;;

            -T|--trivy-image)
                PIPELINE_CLI_OPERATIONS[trivy-image]=true
                shift
                ;;

            --sign|--cosign-sign)
                PIPELINE_CLI_OPERATIONS[cosign-sign]=true
                shift
                ;;

            --verify|--cosign-verify)
                PIPELINE_CLI_OPERATIONS[cosign-verify]=true
                shift
                ;;

            --tree|--cosign-tree)
                PIPELINE_CLI_OPERATIONS[cosign-tree]=true
                shift
                ;;

            --apply-policy|--kyverno-policy)
                PIPELINE_CLI_OPERATIONS[kyverno-policy]=true
                shift
                ;;

            --check-kyverno)
                PIPELINE_CLI_OPERATIONS[check-kyverno]=true
                shift
                ;;

            --kyverno-test)
                PIPELINE_CLI_OPERATIONS[kyverno-test]=true
                shift
                ;;

            # One image for build, scans, Cosign, and Kyverno testing.
            -i|--image)
                if [[ "$image_was_set" == true ]]; then
                    printf 'Error: --image may only be supplied once\n' >&2
                    return 2
                fi

                if (( $# < 2 )); then
                    printf 'Error: %s requires an image reference\n' "$1" >&2
                    return 2
                fi

                PIPELINE_CLI_IMAGE="$2"
                image_was_set=true
                shift 2
                ;;

            --image=*)
                if [[ "$image_was_set" == true ]]; then
                    printf 'Error: --image may only be supplied once\n' >&2
                    return 2
                fi

                if [[ -z "${1#*=}" ]]; then
                    printf 'Error: --image requires an image reference\n' >&2
                    return 2
                fi

                PIPELINE_CLI_IMAGE="${1#*=}"
                image_was_set=true
                shift
                ;;

            # One Dockerfile. It defaults to Dockerfile when omitted.
            -f|--dockerfile)
                if [[ "$dockerfile_was_set" == true ]]; then
                    printf 'Error: --dockerfile may only be supplied once\n' >&2
                    return 2
                fi

                if (( $# < 2 )); then
                    printf 'Error: %s requires a file path\n' "$1" >&2
                    return 2
                fi

                PIPELINE_CLI_DOCKERFILE="$2"
                dockerfile_was_set=true
                shift 2
                ;;

            --dockerfile=*)
                if [[ "$dockerfile_was_set" == true ]]; then
                    printf 'Error: --dockerfile may only be supplied once\n' >&2
                    return 2
                fi

                if [[ -z "${1#*=}" ]]; then
                    printf 'Error: --dockerfile requires a file path\n' >&2
                    return 2
                fi

                PIPELINE_CLI_DOCKERFILE="${1#*=}"
                dockerfile_was_set=true
                shift
                ;;

            --private-key)
                if [[ "$private_key_was_set" == true ]]; then
                    printf 'Error: --private-key may only be supplied once\n' >&2
                    return 2
                fi

                if (( $# < 2 )); then
                    printf 'Error: --private-key requires a file path\n' >&2
                    return 2
                fi

                PIPELINE_CLI_PRIVATE_KEY="$2"
                private_key_was_set=true
                shift 2
                ;;

            --private-key=*)
                if [[ "$private_key_was_set" == true ]]; then
                    printf 'Error: --private-key may only be supplied once\n' >&2
                    return 2
                fi

                if [[ -z "${1#*=}" ]]; then
                    printf 'Error: --private-key requires a file path\n' >&2
                    return 2
                fi

                PIPELINE_CLI_PRIVATE_KEY="${1#*=}"
                private_key_was_set=true
                shift
                ;;

            --public-key)
                if [[ "$public_key_was_set" == true ]]; then
                    printf 'Error: --public-key may only be supplied once\n' >&2
                    return 2
                fi

                if (( $# < 2 )); then
                    printf 'Error: --public-key requires a file path\n' >&2
                    return 2
                fi

                PIPELINE_CLI_PUBLIC_KEY="$2"
                public_key_was_set=true
                shift 2
                ;;

            --public-key=*)
                if [[ "$public_key_was_set" == true ]]; then
                    printf 'Error: --public-key may only be supplied once\n' >&2
                    return 2
                fi

                if [[ -z "${1#*=}" ]]; then
                    printf 'Error: --public-key requires a file path\n' >&2
                    return 2
                fi

                PIPELINE_CLI_PUBLIC_KEY="${1#*=}"
                public_key_was_set=true
                shift
                ;;

            # Repeatable because the project may contain several Kyverno policy
            # files, even though there is only one image and one Dockerfile.
            -p|--policy|--policy-file)
                if (( $# < 2 )); then
                    printf 'Error: %s requires a policy filename\n' "$1" >&2
                    return 2
                fi

                PIPELINE_CLI_POLICY_FILES+=("$2")
                shift 2
                ;;
	    --push|--docker-push)
	 	PIPELINE_CLI_OPERATIONS[docker-push]=true
		shift
		;;

            --policy=*|--policy-file=*)
                if [[ -z "${1#*=}" ]]; then
                    printf 'Error: --policy-file requires a policy filename\n' >&2
                    return 2
                fi

                PIPELINE_CLI_POLICY_FILES+=("${1#*=}")
                shift
                ;;

            -h|--help)
                PIPELINE_CLI_HELP=true
                shift
                ;;

            *)
                printf 'Error: unknown option: %s\n' "$1" >&2
                return 2
                ;; 
        esac
    done
}

pipeline_cli_operation_selected() {
    local operation="${1:-}"

    [[ "${PIPELINE_CLI_OPERATIONS[$operation]:-false}" == true ]]
}

pipeline_cli_any_operation_selected() {
    (( ${#PIPELINE_CLI_OPERATIONS[@]} > 0 ))
}

pipeline_cli_print_help() {
    printf '%s\n' \
        'Pipeline options:' \
        '' \
        'Operations:' \
        '  -H, --hadolint              Run Hadolint' \
        '  -C, --trivy-config          Run Trivy Dockerfile/config scan' \
        '  -B, --build                 Build the Docker image' \
        '  -S, --syft                  Generate an SBOM with Syft' \
        '  -G, --grype                 Scan the generated SBOM with Grype' \
        '  -T, --trivy-image           Run the Trivy image scan' \
        '      --sign                  Sign the image with Cosign' \
        '      --verify                Verify the image with Cosign' \
        '      --tree                  Display the Cosign artifact tree' \
        '      --apply-policy          Apply Kyverno policy files' \
        '      --check-kyverno         Check Kyverno pods and policies' \
        '      --kyverno-test          Test the image against Kyverno' \
        '' \
        'Inputs:' \
        '  -i, --image IMAGE           Image used by image operations' \
        '  -f, --dockerfile FILE       Dockerfile (default: Dockerfile)' \
        '      --private-key FILE      Cosign private key' \
        '      --public-key FILE       Cosign public key' \
        '  -p, --policy-file FILE      Kyverno policy filename; repeatable' \
        '      --push                  Push the image to the docker hub' \
        '' \
        'Other:' \
        '  -h, --help                  Show this help'
}
