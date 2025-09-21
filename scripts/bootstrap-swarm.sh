#!/bin/bash
# Bootstrap script for Docker Swarm cluster with NFS storage and SOPS secrets
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap a Docker Swarm cluster with NFS storage and SOPS secrets management.

OPTIONS:
    -i, --inventory PATH    Path to Ansible inventory file (default: ansible/inventories/homelab/hosts.yml)
    -k, --generate-key      Generate new age key for SOPS encryption
    -e, --encrypt-secrets   Encrypt secrets after generation
    -d, --deploy-stacks     Deploy stacks after cluster setup
    -a, --all               Run complete bootstrap (generate key, encrypt secrets, deploy)
    -h, --help              Show this help message

EXAMPLES:
    $0 --all                           # Complete bootstrap
    $0 -k -e                          # Generate key and encrypt secrets only
    $0 -i custom/inventory.yml --all  # Complete bootstrap with custom inventory

EOF
}

# Default values
INVENTORY_PATH="ansible/inventories/homelab/hosts.yml"
GENERATE_KEY=false
ENCRYPT_SECRETS=false
DEPLOY_STACKS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--inventory)
            INVENTORY_PATH="$2"
            shift 2
            ;;
        -k|--generate-key)
            GENERATE_KEY=true
            shift
            ;;
        -e|--encrypt-secrets)
            ENCRYPT_SECRETS=true
            shift
            ;;
        -d|--deploy-stacks)
            DEPLOY_STACKS=true
            shift
            ;;
        -a|--all)
            GENERATE_KEY=true
            ENCRYPT_SECRETS=true
            DEPLOY_STACKS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT"

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v ansible-playbook >/dev/null 2>&1; then
    log_error "ansible-playbook is required but not installed"
    exit 1
fi

if ! command -v age >/dev/null 2>&1 || ! command -v sops >/dev/null 2>&1; then
    log_warning "age or sops not found. Installing required tools..."
    make install-tools
fi

if [[ ! -f "$INVENTORY_PATH" ]]; then
    log_error "Inventory file not found: $INVENTORY_PATH"
    exit 1
fi

# Generate age key if requested
if [[ "$GENERATE_KEY" == true ]]; then
    log_info "Generating age key for SOPS encryption..."
    make age-key
    log_success "Age key generated"
fi

# Validate that we have an age key
if [[ ! -f "age.key" ]]; then
    log_error "age.key not found. Run with --generate-key or create one manually."
    exit 1
fi

# Bootstrap the swarm cluster
log_info "Bootstrapping Docker Swarm cluster..."
ansible-playbook -i "$INVENTORY_PATH" ansible/site.yml

# Validate swarm status
log_info "Validating swarm cluster..."
ansible -i "$INVENTORY_PATH" managers -b -m shell -a 'docker node ls' | head -10

# Validate NFS mounts
log_info "Validating NFS mounts..."
ansible -i "$INVENTORY_PATH" managers -b -m shell -a 'mount | grep -E " nfs |:/srv/nfs/" || echo "No NFS mounts found"'

# Encrypt secrets if requested
if [[ "$ENCRYPT_SECRETS" == true ]]; then
    log_info "Encrypting secrets..."
    
    # Check if we have plaintext secrets to encrypt
    if [[ -f "shared/komodo.secret.yaml" ]] || [[ -f "shared/komodo.env" ]]; then
        # Update the plaintext secrets with actual age key before encrypting
        AGE_KEY=$(cat age.key)
        AGE_KEY_BASE64=$(echo -n "$AGE_KEY" | base64 -w 0)
        
        # Update the secret files with actual values
        sed -i "s/PLACEHOLDER_AGE_KEY_BASE64/$AGE_KEY_BASE64/g" shared/komodo.secret.yaml
        sed -i "s/PLACEHOLDER_AGE_KEY/$AGE_KEY/g" shared/komodo.env
        
        make encrypt-secrets TARGET=shared
        log_success "Secrets encrypted"
    else
        log_warning "No plaintext secrets found to encrypt"
    fi
fi

# Deploy stacks if requested
if [[ "$DEPLOY_STACKS" == true ]]; then
    log_info "Creating Docker secrets for SOPS age key..."
    
    # Create Docker secret for age key on the swarm
    AGE_KEY=$(cat age.key)
    echo "$AGE_KEY" | ansible -i "$INVENTORY_PATH" managers[0] -b -m shell -a 'docker secret create komodo-age-key -' || true
    
    log_info "Deploying Traefik stack..."
    ansible -i "$INVENTORY_PATH" managers[0] -b -m shell -a 'cd /tmp && docker stack deploy -c <(cat) traefik' -e ansible_shell_executable=/bin/bash || true
    
    log_info "Deploying Komodo stack..."
    ansible -i "$INVENTORY_PATH" managers[0] -b -m shell -a 'cd /tmp && docker stack deploy -c <(cat) komodo' -e ansible_shell_executable=/bin/bash || true
    
    log_success "Stacks deployed"
fi

# Final validation
log_info "Running final validation..."
make validate
make lint

log_success "Bootstrap complete!"

cat << EOF

🎉 Docker Swarm cluster bootstrap completed successfully!

Next steps:
1. Verify services: ansible -i $INVENTORY_PATH managers[0] -b -m shell -a 'docker service ls'
2. Check logs: ansible -i $INVENTORY_PATH managers[0] -b -m shell -a 'docker service logs <service-name>'
3. Access Traefik dashboard: https://traefik.your-domain.com
4. Access Komodo dashboard: https://komodo.your-domain.com

Configuration files:
- Inventory: $INVENTORY_PATH
- Age key: age.key (keep secure!)
- SOPS config: .sops.yaml

Documentation:
- README.md - Overview and getting started
- docs/ - Detailed documentation

EOF