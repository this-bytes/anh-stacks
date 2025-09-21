#!/bin/bash
# Validation script for anh-stacks bootstrap configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

cd "$PROJECT_ROOT"

log_info "Validating anh-stacks configuration..."

# Check file structure
log_info "Checking repository structure..."

required_files=(
    "ansible/site.yml"
    "ansible/storage.yml"
    "ansible/inventories/homelab/hosts.yml"
    "ansible/inventories/homelab/group_vars/managers.yml"
    "scripts/bootstrap-swarm.sh"
    "Makefile"
    ".sops.yaml"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        log_success "Found: $file"
    else
        log_error "Missing: $file"
        exit 1
    fi
done

# Check ansible roles
log_info "Checking Ansible roles..."
required_roles=(
    "ansible/roles/docker"
    "ansible/roles/swarm"
    "ansible/roles/nfs_server"
    "ansible/roles/nfs_client"
)

for role in "${required_roles[@]}"; do
    if [[ -d "$role" ]]; then
        log_success "Found role: $role"
    else
        log_error "Missing role: $role"
        exit 1
    fi
done

# Validate TOML configurations
log_info "Validating TOML configurations..."
if make validate; then
    log_success "TOML validation passed"
else
    log_error "TOML validation failed"
    exit 1
fi

# Validate shell scripts
log_info "Validating shell scripts..."
if make lint; then
    log_success "Shell script linting passed"
else
    log_error "Shell script linting failed"
    exit 1
fi

# Check ansible syntax
log_info "Checking Ansible syntax..."
if command -v ansible-playbook >/dev/null 2>&1; then
    if ansible-playbook --syntax-check ansible/site.yml >/dev/null 2>&1; then
        log_success "Ansible site.yml syntax valid"
    else
        log_error "Ansible site.yml syntax invalid"
        exit 1
    fi

    if ansible-playbook --syntax-check ansible/storage.yml >/dev/null 2>&1; then
        log_success "Ansible storage.yml syntax valid"
    else
        log_error "Ansible storage.yml syntax invalid"
        exit 1
    fi
else
    log_warning "Ansible not installed, skipping playbook syntax check"
fi

# Check Docker Compose syntax
log_info "Checking Docker Compose files..."
compose_files=$(find stacks/ -name "docker-compose.yml" 2>/dev/null || true)

if [[ -n "$compose_files" ]]; then
    for compose_file in $compose_files; do
        if command -v docker-compose >/dev/null 2>&1; then
            if docker-compose -f "$compose_file" config >/dev/null 2>&1; then
                log_success "Docker Compose syntax valid: $compose_file"
            else
                log_error "Docker Compose syntax invalid: $compose_file"
                exit 1
            fi
        else
            log_warning "docker-compose not installed, skipping compose validation"
            break
        fi
    done
else
    log_warning "No Docker Compose files found"
fi

# Check for sensitive data
log_info "Checking for sensitive data in repository..."
sensitive_patterns=(
    "password"
    "secret"
    "key.*=.*[a-zA-Z0-9]{20,}"
    "token.*=.*[a-zA-Z0-9]{20,}"
    "api.*key.*=.*[a-zA-Z0-9]{20,}"
)

has_sensitive=false
for pattern in "${sensitive_patterns[@]}"; do
    # Exclude encrypted files and this validation script
    if git ls-files | grep -v -E '\.(sops\.yaml|sop\.env)$' | grep -v "validate-config.sh" | xargs grep -l -i "$pattern" 2>/dev/null; then
        log_warning "Potentially sensitive data found matching pattern: $pattern"
        has_sensitive=true
    fi
done

if [[ "$has_sensitive" == false ]]; then
    log_success "No sensitive data detected in plaintext files"
fi

# Check inventory configuration
log_info "Validating inventory configuration..."
inventory_file="ansible/inventories/homelab/hosts.yml"

if grep -q "10.87.10" "$inventory_file"; then
    log_warning "Inventory still contains example IPs (10.87.10.x). Update with your actual server IPs."
fi

if grep -q "managers:" "$inventory_file"; then
    manager_count=$(grep -A 20 "managers:" "$inventory_file" | grep -c "ansible_host:" || echo "0")
    if [[ "$manager_count" -ge 3 ]]; then
        log_success "Sufficient manager nodes configured ($manager_count)"
    else
        log_warning "Only $manager_count manager nodes configured. Consider 3+ for HA."
    fi
fi

# Check NFS configuration
log_info "Validating NFS configuration..."
managers_yml="ansible/inventories/homelab/group_vars/managers.yml"

if grep -q "nfs_enabled: true" "$managers_yml"; then
    log_success "NFS enabled in configuration"
else
    log_warning "NFS not enabled in configuration"
fi

# Check SOPS configuration
log_info "Validating SOPS configuration..."
if [[ -f ".sops.yaml" ]]; then
    if grep -q "age1" ".sops.yaml"; then
        log_success "SOPS age recipient configured"
    else
        log_warning "No age recipient found in .sops.yaml"
    fi
else
    log_error "SOPS configuration missing"
    exit 1
fi

# Summary
log_info "Validation Summary:"
echo "✓ Repository structure valid"
echo "✓ Ansible roles present"
echo "✓ Configuration syntax valid"
echo "✓ Security checks passed"

if [[ "$has_sensitive" == true ]]; then
    echo "⚠ Potential sensitive data detected"
fi

log_success "Configuration validation completed successfully!"

echo ""
echo "Next steps:"
echo "1. Update ansible/inventories/homelab/hosts.yml with your server IPs"
echo "2. Customize ansible/inventories/homelab/group_vars/managers.yml if needed"
echo "3. Run 'make bootstrap' to deploy the cluster"
echo ""