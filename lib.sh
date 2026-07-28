#!/usr/bin/env bash 

# Prevent loading the library more than once.
if [ "${PIPELINE_LIB_LOADED:-false}" = "true" ]; then
    return 0
fi

PIPELINE_LIB_LOADED=true

#========== Directory/path ==========

PIPELINE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PIPELINE_ROOT="$(cd -- "$PIPELINE_LIB_DIR/.." && pwd)"

PIPELINE_CONFIG_DIR="$PIPELINE_ROOT/config"
PIPELINE_KEY_DIR="$PIPELINE_ROOT/keys"
PIPELINE_POLICY_DIR="$PIPELINE_ROOT/policies"


# Colors
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

#========== Log functions ==========

log_info() {
    printf "[%s] ${BLUE}[INFO]${RESET} %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*"
}

log_success() {
    printf "[%s] ${GREEN}[SUCCESS]${RESET} %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*"
}

log_warning() {
    printf "[%s] ${YELLOW}[WARNING]${RESET} %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*" >&2
}

log_error() {
    printf "[%s] ${RED}[ERROR]${RESET} %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*" >&2
}

#========== Default configs ==========

set_default_configuration() {
    HADOLINT_FAILURE_THRESHOLD="error"

    TRIVY_SEVERITY="HIGH,CRITICAL"
    TRIVY_EXIT_CODE="1"

    SYFT_FORMAT="cyclonedx-json"

    GRYPE_FAIL_ON="high"

    COSIGN_PRIVATE_KEY="$PIPELINE_KEY_DIR/cosign.key"
    COSIGN_PUBLIC_KEY="$PIPELINE_KEY_DIR/cosign.pub"

    REPORT_BASE_DIR="$PIPELINE_ROOT/reports"

    WORKSPACE_DIR="$PWD"
}

#========== Config operations ==========

load_configuration() {
    local config_file="$PIPELINE_CONFIG_DIR/pipeline.conf"

    # First, load built-in default values.
    set_default_configuration

    # Then, override defaults with values from pipeline.conf.
    if [ -f "$config_file" ]; then
        if [ ! -r "$config_file" ]; then
            log_error "Configuration file is not readable: $config_file"
            return 1
        fi

        # shellcheck source=/dev/null
        source "$config_file"

        log_info "Configuration loaded from: $config_file"
    else
        log_info "No configuration file found; using defaults"
    fi
}

#========== initialization ==========

initialize_run() {
    load_configuration

    if [ ! -d "$WORKSPACE_DIR" ]; then
        log_error "Workspace directory does not exist: $WORKSPACE_DIR"
        return 1
    fi

    WORKSPACE_DIR="$(
        cd -- "$WORKSPACE_DIR" &&
        pwd
    )"

    RUN_ID="$(date '+%Y%m%d_%H%M%S')"
    REPORT_DIR="$REPORT_BASE_DIR/$RUN_ID"
    LOG_FILE="$REPORT_DIR/pipeline.log"

    mkdir -p "$REPORT_DIR"

    # Send stdout and stderr to both:
    #   1. the terminal
    #   2. pipeline.log
    exec > >(tee -a "$LOG_FILE") 2>&1

    log_info "Pipeline initialized"
    log_info "Library directory: $PIPELINE_LIB_DIR"
    log_info "Project root: $PIPELINE_ROOT"
    log_info "Workspace: $WORKSPACE_DIR"
    log_info "Run ID: $RUN_ID"
    log_info "Report directory: $REPORT_DIR"
    log_info "Command: $0 $*"
}

#========== exit handling ==========

on_exit() {
    local exit_code=$?

    if [ "$exit_code" -eq 0 ]; then
        log_success "Pipeline completed successfully"
    else
        log_error "Pipeline failed with exit code $exit_code"
    fi

    return "$exit_code"
}

#========== helpers ==========

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local command_name="$1"

    if ! command_exists "$command_name"; then
        log_error "Required command is not installed: $command_name"
        return 127
    fi
}

require_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "Required file does not exist: $file"
        return 1
    fi
}

require_directory() {
    local directory="$1"

    if [ ! -d "$directory" ]; then
        log_error "Required directory does not exist: $directory"
        return 1
    fi
}

resolve_workspace_path() {
    local path="$1"

    if [[ "$path" = /* ]]; then
        printf '%s\n' "$path"
    else
        printf '%s/%s\n' "$WORKSPACE_DIR" "$path"
    fi
}

#========== hadolint ==========

hadolint_scan(){
	log_info "Starting hadolint_scan"
	local dockerfile="$(resolve_workspace_path "$1")"

	local report="$REPORT_DIR/hadolint.txt"

	#checking whether command exists
	require_command hadolint || return

	#checking if the dockerfile exists
	require_file "$dockerfile" || return

	#running hadolint
	log_info "Running Hadolint on: $dockerfile"
	
	if hadolint --failure-threshold "$HADOLINT_FAILURE_THRESHOLD" "$dockerfile" > "$report" 2>&1
	then
		log_success "Hadolint scan passed"
	else
		local exit_code=$?
		cat "$report"
		log_error "Hadolint scan failed"
		return "$exit_code"
	fi
}

#========== trivy ==========

trivy_dockerfile_scan() {
	local dockerfile="$(resolve_workspace_path "$1")"

	local report="$REPORT_DIR/trivy-dockerfile.json"

	#checking if trivy command exists
	require_command trivy || return

	#running trivy
	log_info "Running trivy on: $dockerfile"
	
	if trivy config --severity "$TRIVY_SEVERITY" --format json --exit-code "$TRIVY_EXIT_CODE" --output "$report" "$dockerfile" 2>&1
	then
		log_success "trivy dockerfile scan passed"
	else
		local exit_code=$?
		cat "$report"
		log_error "Trivy dockerfile scan failed"
		return "$exit_code"
	fi
}


trivy_image_scan() {
	local image="$1"
	local report="$REPORT_DIR/trivy-image.json"

	#checking whether command exists
	require_command trivy || return

	#running trivy
	log_info "Running trivy on: $image"

	if trivy image --severity "$TRIVY_SEVERITY" --format json --exit-code "$TRIVY_EXIT_CODE" --no-progress --output "$report" "$image" 2>&1
	then
		log_success "Trivy image scan passed"
	else
		local exit_code=$?
		cat "$report"
		log_error "Trivy image scan failed"
		return "$exit_code"
	fi
}


#========== docker ==========

#docker build -t name .
#	          $1  $2

docker_build_image() {
	local image_ref="$1"
	local dockerfile_path="${2:-Dockerfile}"
	local build_context_path="${3:-.}"

	local dockerfile="$(resolve_workspace_path "$dockerfile_path")"
	local build_context="$(resolve_workspace_path "$build_context_path")"

	local report="$REPORT_DIR/docker-build.txt"

	#checking docker command
	require_command docker || return

	#checking if dockerfile exists
	require_file "$dockerfile" || return

	#checking if the directory exists
	require_directory "$build_context" || return
	
	#running docker build
	log_info "Building Docker image: $image_ref"
	log_info "Dockerfile: $dockerfile"
	log_info "Build context: $build_context"

	if docker build --file "$dockerfile" --tag "$image_ref" "$build_context">"$report" 2>&1
	then
		log_success "Docker image build success: $image_ref"
	else
		local exit_code=$?
		cat "$report"
		log_error "Docker build failed"
		return "$exit_code"
	fi
}

#====================
# NOTE: Currently unused. Kept for future Docker registry authentication and image push support.
#====================

#docker_check_login() {
#	local image="$1"
#	local report="$REPORT_DIR/docker-push.txt"
#
#	#checking docker command
#	require_command docker
#	local command_status=$?
#	if [ $command_status != "0" ]; then
#		printf "error: docker command does not exist."
#		return "$command_status"
#	fi
#
#	#checking connection to docker hub
#	docker info | grep "Username"
#	local connection_status=$?
#	if [ $connection_status != "0" ]; then
#		printf "error: login to docker"
#		return "$connection_status"
#	fi
#
#	#running docker push
#	log_info "Running docker push: $image"
#	
#	if docker push "$image" 2>&1 | tee "$report"; then
#		log_success "Docker image pushed successfully: $image"
#	else
#		local exit_code=$?
#		log_error "Docker push failed"
#		return "$exit_code"
#	fi
#}
#
#
#
#docker_registry_login() {
#    local registry="$1"
#
#    require_command docker || return
#
#    log_info "Logging in to registry: $registry"
#
#    if docker login "$registry"; then
#        log_success "Registry login succeeded: $registry"
#    else
#        local exit_code=$?
#        log_error "Registry login failed: $registry"
#        return "$exit_code"
#    fi
#}

docker_push_image() {
	local image="$1"
	local report="$REPORT_DIR/docker-push.txt"

	#checking if the command exists
	require_command docker || return

	log_info "Pushing Docker image to Docker hub: $image"

	#running docker push
	if docker push "$image" 2>&1 | tee "$report"; then
		log_success "Docker image pushed successfully: $image"
	else
		local exit_code=$?
		log_error "Docker push failed"
		return "$exit_code"
	fi
}

#========== syft ==========

syft_generate_sbom() {
	local image="$1"
	local report="$REPORT_DIR/syft-sbom.json"

	require_command syft || return

	log_info "generating SBOM for: $image"

	if syft scan "$image" -o "${SYFT_FORMAT}=${report}"
	then
		log_success "syft sucessfully generated SBOM."
	else
		local exit_code=$?
		cat "$report"
		log_error "syft SBOM generation failed"
		return "$exit_code"
	fi
}

#========== grype ==========

grype_sbom_scan() {
	local sbom_file="$REPORT_DIR/syft-sbom.json"
	local report="$REPORT_DIR/grype-result.json"

	require_command grype || return
	require_file "$sbom_file" || return

	log_info "scanning SBOM with grype: $sbom_file"

	if grype "sbom:$sbom_file" --fail-on "$GRYPE_FAIL_ON" --output json --file "$report"
	then
		log_success "Grype scan passed"
	else
		local exit_code=$?
		cat "$report"
		log_error "grype scan failed"
		return "$exit_code"
	fi
}

#========== cosign ==========

cosign_sign_image() {
	local image="$1"
	local private_key="${2:-$COSIGN_PRIVATE_KEY}"
	local report="$REPORT_DIR/cosign-sign.txt"

	require_command cosign || return
	require_file "$private_key" || return

	log_info "Running cosign sign on: $image"
	log_info "Private key: $private_key"
	
	if cosign sign --yes --key "$private_key" "$image" 2>&1 | tee "$report"
	then
		log_success "cosign sign sucessfull: $image"
	else
		local exit_code=$?
		cat "$report"
		log_error "cosign sign failed"
		return "$exit_code"
	fi
}

cosign_verify_image() {
	local image="$1"
	local public_key="${2:-$COSIGN_PUBLIC_KEY}"
	local report="$REPORT_DIR/cosign-verify.txt"

	require_command cosign || return

	require_file "$public_key" || return

	log_info "Running cosign verify on: $image"
	log_info "Public key: $public_key"

	if cosign verify --key "$public_key" "$image">"$report" 2>&1
	then
		log_success "cosign verify sucessfully: $image"
	else
		local exit_code=$?
		cat "$report"
		log_error "cosign verify failed"
		return "$exit_code"
	fi
}

cosign_show_tree() {
	local image="$1"
	local report="$REPORT_DIR/cosign-tree.txt"
	
	require_command cosign || return
	
	#running cosign tree
	log_info "Displaying Cosign artifact tree for: $image"
	if cosign tree "$image" 2>&1 | tee "$report"; then
		log_success "Cosign tree displayed"
	else
		local exit_code=$?
		cat "$report"
		log_error "Cosign tree failed"
		return "$exit_code"
	fi
}

#========== kyverno ==========

kubectl_apply_file() {
	local file="$(resolve_workspace_path "$1")"
	local report="$REPORT_DIR/kubectl-apply.txt"

	require_command kubectl || return
	require_file "$file" || return

	#running kubectl apply
	log_info "Applying kubernetes file: $file"

	if kubectl apply -f "$file" 2>&1 | tee -a "$report"
	then
		log_success "Kubernetes succeeded"
	else
		local exit_code=$?
		log_error "kubectl apply failed"
		return "$exit_code"
	fi
}

kubectl_apply_policy() {
	local policy_name="$1"
	local policy_file="$PIPELINE_POLICY_DIR/$policy_name"

	local report="$REPORT_DIR/kubectl-policy.txt"

	require_command kubectl || return
	require_file "$policy_file" || return

	log_info "Applying policy: $policy_file"

	if kubectl apply -f "$policy_file" 2>&1 | tee -a "$report"
	then
		log_success "Policy applied successfully"
	else
		local exit_code=$?
		log_error "Policy apply failed"
		return "$exit_code"
	fi
}

check_kubernetes_node() {
	local report="$REPORT_DIR/kubernetes-nodes.txt"
	require_command kubectl || return

	log_info "Checking Kubernetes nodes"
	kubectl get nodes 2>&1 | tee "$report"
}

check_kyverno() {
	local report="$REPORT_DIR/kyverno-status.txt"

	require_command kubectl || return

	log_info "Checking Kyverno status"

	kubectl get pods -n kyverno 2>&1 | tee -a "$report"
	kubectl get clusterpolicy 2>&1 | tee -a "$report"
}

kyverno_image_testing() {
	local image="$1"
	local pod_name="policy-test-${RUN_ID//_/-}"
	local report="$REPORT_DIR/kyverno-test.txt"

	require_command kubectl || return

	if [ -z "$image" ]; then
		log_error "image is required"
		return 2
	fi

	log_info "Testing image against Kyverno policies: $image"
	
	if kubectl run "$pod_name" --image="$image" --dry-run=server --output yaml 2>&1 | tee "$report"
	then
		log_success "kyverno policies passed: $image is allowed"
	else
		local exit_code=$?
		log_error "kyverno policies failed: $image is rejected"
		return "$exit_code"	
	fi
}
