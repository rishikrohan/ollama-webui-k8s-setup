#!/bin/bash

set -euo pipefail

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log() {
	local msg="$1"
	local color="$2"
	echo -e "$(date +'%Y-%m-%d %H:%M:%S') - ${color}${msg}${NC}"
}

log "Starting kind cluster setup..." "$GREEN"

# Check if kind is installed
if ! command -v kind &>/dev/null; then
	log "kind could not be found, please install it first." "$RED"
	exit 1
fi

# Create a kind cluster
log "Creating kind cluster..." "$YELLOW"
kind create cluster --config "$(dirname "$0")/kind-config.yaml"

log "Kind cluster setup completed successfully." "$GREEN"
