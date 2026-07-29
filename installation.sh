#!/usr/bin/env bash
set -Eeuo pipefail

LOG_DIR="$HOME/pipesec/reports"
INSTALL_LOG="$LOG_DIR/install-$(date '+%Y%m%d-%H%M%S').log"

mkdir -p "$LOG_DIR"
touch "$INSTALL_LOG"

# Save the original terminal output
exec 3>&1
exec 4>&2

# Send normal command output to the log file
exec >>"$INSTALL_LOG" 2>&1

# Installation selections
INSTALL_HADOLINT=true
INSTALL_TRIVY=true
INSTALL_COSIGN=true
INSTALL_SYFT=true
INSTALL_GRYPE=true
INSTALL_K3S=true
INSTALL_HELM=true
INSTALL_KYVERNO=true
INSTALL_DOCKER=true

#Colors
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

#========== Log functions ==========

log_info() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Colored output to terminal
    printf "[%s] ${BLUE}[INFO]${RESET} %s\n" \
        "$timestamp" "$*" >&3

    # Plain output to installation log
    printf "[%s] [INFO] %s\n" \
        "$timestamp" "$*"
}

log_success() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    printf "[%s] ${GREEN}[SUCCESS]${RESET} %s\n" \
        "$timestamp" "$*" >&3

    printf "[%s] [SUCCESS] %s\n" \
        "$timestamp" "$*"
}

log_warning() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    printf "[%s] ${YELLOW}[WARNING]${RESET} %s\n" \
        "$timestamp" "$*" >&4

    printf "[%s] [WARNING] %s\n" \
        "$timestamp" "$*" >&2
}

log_error() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    printf "[%s] ${RED}[ERROR]${RESET} %s\n" \
        "$timestamp" "$*" >&4

    printf "[%s] [ERROR] %s\n" \
        "$timestamp" "$*" >&2
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

install_prereq() {
	log_info "Installing prerequisites"

	sudo apt-get update
	sudo apt-get install -y wget curl gnupg jq ca-certificates
	
	log_success "Prerequisites installed"
}

install_docker() {
    if command_exists docker; then
        log_info "Docker is already installed"

        if sudo systemctl is-active --quiet docker; then
            log_success "Docker service is active"
            return 0
        else
            log_error "Docker is installed but the service is not active"
            return 1
        fi
    fi

    log_info "Installing Docker"

    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt-get update

    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    if sudo systemctl is-active --quiet docker; then
        log_success "Docker service is active"
    else
        log_error "Docker service is not active"
        sudo systemctl status docker --no-pager
        return 1
    fi

    sudo usermod -aG docker "$USER"

    sudo docker version

    log_success "Docker installed"
    log_warning "Log out and log back in before using Docker without sudo"
}

install_helm() {
	if command_exists helm; then
		log_info "Helm is already installed"
		return 0
	fi
	
	if ! command_exists snap; then
    	log_info "Installing snapd"
    	sudo apt-get install -y snapd
    	sudo systemctl enable --now snapd
	fi
	
	log_info "Installing Helm"

	sudo snap install helm --classic

	log_success "Helm installed"
}

install_k3s() {
	if command_exists k3s; then
		log_info "K3s is already installed"
		return 0
	fi

	log_info "Installing k3s"

	curl -sfL https://get.k3s.io | sudo sh -

	if sudo systemctl is-active --quiet k3s; then
		log_success "K3s is active"
	else
		log_error "K3s is not active"
		return 1
	fi

	log_success "K3s installed"
}

install_hadolint() {
	if command_exists hadolint; then
		log_info "Hadolint is already installed"
		return 0
	fi

	log_info "Installing Hadolint"
	
	wget https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
	chmod +x hadolint-Linux-x86_64
	sudo mv hadolint-Linux-x86_64 /usr/local/bin/hadolint

	hadolint --version
	log_success "Hadolint installed"
}

install_trivy() {
	if command_exists trivy; then
		log_info "Trivy is already installed"
		return 0
	fi

	log_info "Installing trivy"

	wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
	echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list
	sudo apt-get update
	sudo apt-get install -y trivy

	trivy --version
	log_success "Trivy installed"
}

install_syft() {
	if command_exists syft; then
		log_info "Syft is already installed"
		return 0
	fi

	log_info "Installing Syft"

	curl -sSfL https://get.anchore.io/syft | sudo sh -s -- -b /usr/local/bin

	syft version

	log_success "Syft installed"
}

install_grype() {
	if command_exists grype; then
		log_info "Grype is already installed"
		return 0
	fi
	
	log_info "Installing Grype"

	curl -sSfL https://get.anchore.io/grype | sudo sh -s -- -b /usr/local/bin

	grype version

	log_success "Grype installed"
}

install_cosign() {
	if command_exists cosign; then
		log_info "Cosign is already installed"
		return 0;
	fi

	wget https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64
	sudo mv cosign-linux-amd64 /usr/local/bin/cosign
	sudo chmod +x /usr/local/bin/cosign

	cosign version
	log_success "Cosign installed"
}

configure_kubeconfig() {
    local source_config="/etc/rancher/k3s/k3s.yaml"
    local target_config="$HOME/.kube/config"

    log_info "Configuring Kubernetes access"

    if [ ! -f "$source_config" ]; then
        log_error "k3s kubeconfig not found: $source_config"
        return 1
    fi

    mkdir -p "$HOME/.kube"
    chmod 700 "$HOME/.kube"

    sudo cp "$source_config" "$target_config"
    sudo chown "$USER":"$(id -gn)" "$target_config"
    chmod 600 "$target_config"

    export KUBECONFIG="$target_config"

    if ! grep -qxF \
	'export KUBECONFIG="$HOME/.kube/config"' \
	"$HOME/.bashrc"
	then
		echo 'export KUBECONFIG="$HOME/.kube/config"' \
			>> "$HOME/.bashrc"
    fi

    if ! helm \
        --kubeconfig "$target_config" \
        list --all-namespaces
    then
        log_error "Helm cannot connect to the k3s cluster"
        return 1
    fi

    log_success "Kubernetes access configured"
}

install_kyverno() {
    local kubeconfig="$HOME/.kube/config"

    log_info "Installing Kyverno"

    if [ ! -f "$kubeconfig" ]; then
        log_error "Kubeconfig not found: $kubeconfig"
        return 1
    fi

    helm repo add \
        kyverno \
        https://kyverno.github.io/kyverno/ \
        --force-update

    helm repo update

    helm \
        --kubeconfig "$kubeconfig" \
        upgrade --install \
        kyverno \
        kyverno/kyverno \
        --namespace kyverno \
        --create-namespace

    kubectl \
        --kubeconfig "$kubeconfig" \
        get pods \
        --namespace kyverno

    log_success "Kyverno installed"
}

parse_arguments() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
	    	--skip-docker)
    			INSTALL_DOCKER=false
    			;;

            --skip-hadolint)
                INSTALL_HADOLINT=false
                ;;

            --skip-trivy)
                INSTALL_TRIVY=false
                ;;

            --skip-cosign)
                INSTALL_COSIGN=false
                ;;

            --skip-syft)
                INSTALL_SYFT=false
                ;;

            --skip-grype)
                INSTALL_GRYPE=false
                ;;

            --skip-kyverno)
				INSTALL_K3S=false
                INSTALL_HELM=false
                INSTALL_KYVERNO=false
                ;;
				
	    	*)
                log_error "Unknown option: $1"
                return 2
                ;;
        esac

        shift
    done
}

main() {
    parse_arguments "$@" || return

    log_info "starting installation"
    install_prereq || return

    if [ "$INSTALL_DOCKER" = true ]; then
		install_docker || return
    fi
   
    if [ "$INSTALL_HADOLINT" = true ]; then
        install_hadolint
    fi

    if [ "$INSTALL_TRIVY" = true ]; then
        install_trivy
    fi

    if [ "$INSTALL_SYFT" = true ]; then
        install_syft
    fi

    if [ "$INSTALL_GRYPE" = true ]; then
        install_grype
    fi

    if [ "$INSTALL_COSIGN" = true ]; then
        install_cosign
    fi

    if [ "$INSTALL_HELM" = true ]; then
		install_helm
    fi

    if [ "$INSTALL_K3S" = true ]; then
		install_k3s
    fi
	
    if [ "$INSTALL_K3S" = true ] ||
       [ "$INSTALL_HELM" = true ] ||
       [ "$INSTALL_KYVERNO" = true ]; then
		configure_kubeconfig || return
    fi 

    if [ "$INSTALL_KYVERNO" = true ]; then
        install_kyverno
    fi 

    log_success "Requested installations completed"
	if [ "$INSTALL_DOCKER" = true ]; then
    	log_warning "Log out and log back in to use Docker without sudo"
	fi
}

main "$@"
