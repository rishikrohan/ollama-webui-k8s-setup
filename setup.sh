#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
check_command() {
    if ! command -v $1 &>/dev/null; then
        log_error "$1 is not installed"
        exit 1
    fi
}

# Function to verify pod status
verify_pods() {
    local namespace=$1
    local attempts=0
    local max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        if kubectl get pods -n $namespace | grep -q "Running"; then
            log_success "All pods are running in namespace $namespace"
            return 0
        fi
        attempts=$((attempts + 1))
        log_info "Waiting for pods to be ready... (Attempt $attempts/$max_attempts)"
        sleep 10
    done

    log_error "Pods did not reach Running state within expected time"
    return 1
}

# Function to setup ngrok tunnel
setup_ngrok() {
    log_info "Setting up ngrok tunnel..."
    if ! command -v ngrok &>/dev/null; then
        log_error "ngrok is not installed. Please install it first."
        log_info "Visit: https://ngrok.com/download"
        exit 1
    fi

    # Start ngrok tunnel for Ollama API
    OLLAMA_PORT=$(kubectl get svc -n llm-system ollama-service -o jsonpath='{.spec.ports[0].nodePort}')
    ngrok http ${OLLAMA_PORT} >/dev/null &
    OLLAMA_PID=$!

    # Start ngrok tunnel for WebUI
    ngrok http 30080 >/dev/null &
    WEBUI_PID=$!

    # Wait for tunnels to be established
    sleep 5

    # Get tunnel URLs
    OLLAMA_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
    WEBUI_URL=$(curl -s http://localhost:4041/api/tunnels | jq -r '.tunnels[0].public_url')

    log_success "ngrok tunnels established:"
    echo -e "${GREEN}Ollama API: ${OLLAMA_URL}${NC}"
    echo -e "${GREEN}Open WebUI: ${WEBUI_URL}${NC}"
}

# Main installation script
main() {
    log_info "Starting Ollama installation script..."

    # Check required tools
    log_info "Checking required tools..."
    check_command kubectl
    check_command helm
    check_command kind

    # Create KIND cluster if it doesn't exist
    if ! kind get clusters | grep -q "llm-cluster"; then
        log_info "Creating KIND cluster..."
        kind create cluster --config cluster/kind-config.yaml --name llm-cluster
    fi

    # Add Helm repository
    log_info "Adding Open WebUI Helm repository..."
    helm repo add open-webui https://open-webui.github.io/helm-charts
    helm repo update

    # Apply namespace
    log_info "Creating namespace..."
    kubectl apply -f cluster/llm-namespace.yaml

    # Install/Upgrade Helm chart
    log_info "Installing/Upgrading Ollama Helm chart..."
    helm upgrade --install llm-system helm/llm-system \
        --namespace llm-system \
        --create-namespace \
        --wait \
        --timeout 10m \
        --values helm/llm-system/values.yaml

    # Install Open WebUI Helm chart
    log_info "Installing Open WebUI..."
    helm repo add open-webui https://open-webui.github.io/helm-charts
    helm repo update

    helm upgrade --install open-webui open-webui/open-webui \
        --namespace llm-system \
        --set environment.OPENAI_API_BASE="${OPENAI_API_BASE}" \
        --set environment.OPENAI_API_KEY="${OPENAI_API_KEY}" \
        --set environment.MODEL="${MODEL}" \
        --set service.type=NodePort \
        --set service.nodePort=30080

    if [ $? -eq 0 ]; then
        log_success "Helm upgrade completed successfully"
    else
        log_error "Helm upgrade failed"
        exit 1
    fi

    if [ $? -eq 0 ]; then
        log_success "Helm upgrade completed successfully"
    else
        log_error "Helm upgrade failed"
        exit 1
    fi

    # Verify installation
    log_info "Verifying installation..."

    # Check pods
    verify_pods llm-system

    # Check services
    log_info "Checking services..."
    kubectl get svc -n llm-system
    if [ $? -eq 0 ]; then
        log_success "Services are created successfully"
    else
        log_error "Service verification failed"
        exit 1
    fi

    # Setup ngrok tunnels
    setup_ngrok

    log_success "Installation and verification completed successfully!"
    log_info "To stop ngrok tunnels, run: pkill ngrok"
}

# Run main function
main "$@"
