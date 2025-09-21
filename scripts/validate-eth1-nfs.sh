#!/bin/bash
# Validation script to check eth1 interface configuration for NFS
# This script can be run to verify the eth1 interface is properly configured for NFS access

set -euo pipefail

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

# Check if eth1 interface exists and is configured
check_eth1_interface() {
    log_info "Checking eth1 interface configuration..."
    
    if ip addr show eth1 >/dev/null 2>&1; then
        ETH1_IP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [[ -n "$ETH1_IP" ]]; then
            log_success "eth1 interface found with IP: $ETH1_IP"
            
            # Get network and netmask
            ETH1_NETWORK=$(ip route | grep eth1 | grep -oP '\d+(\.\d+){3}/\d+' | head -1)
            log_info "eth1 network: $ETH1_NETWORK"
            return 0
        else
            log_warning "eth1 interface exists but has no IP address configured"
            return 1
        fi
    else
        log_warning "eth1 interface not found or not configured"
        return 1
    fi
}

# Check connectivity to NFS server (if specified)
check_nfs_connectivity() {
    local nfs_server="${1:-}"
    
    if [[ -n "$nfs_server" ]]; then
        log_info "Testing connectivity to NFS server: $nfs_server"
        
        if ping -c 1 -W 3 "$nfs_server" >/dev/null 2>&1; then
            log_success "NFS server $nfs_server is reachable"
            
            # Test NFS specific connectivity
            if showmount -e "$nfs_server" >/dev/null 2>&1; then
                log_success "NFS exports are accessible from $nfs_server"
                showmount -e "$nfs_server" | head -5
            else
                log_warning "NFS exports not accessible (this is normal if server isn't configured yet)"
            fi
        else
            log_error "NFS server $nfs_server is not reachable"
            return 1
        fi
    fi
}

# Main validation
main() {
    echo "=== NFS eth1 Interface Configuration Validation ==="
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_warning "Some checks require root privileges. Run with sudo for complete validation."
    fi
    
    # Check eth1 interface
    if check_eth1_interface; then
        log_success "✓ eth1 interface configuration check passed"
    else
        log_error "✗ eth1 interface configuration check failed"
        echo
        log_info "To configure eth1 interface, you may need to:"
        echo "  1. Check your network configuration files"
        echo "  2. Ensure eth1 is properly connected and configured"
        echo "  3. Restart networking service if needed"
        return 1
    fi
    
    echo
    
    # Check NFS packages
    log_info "Checking NFS packages..."
    if command -v showmount >/dev/null 2>&1; then
        log_success "✓ NFS client tools are installed"
    else
        log_warning "NFS client tools not found. Install with: apt-get install nfs-common"
    fi
    
    echo
    
    # Test NFS connectivity if server specified
    NFS_SERVER="${NFS_SERVER:-}"
    if [[ -n "$NFS_SERVER" ]]; then
        check_nfs_connectivity "$NFS_SERVER"
    else
        log_info "Set NFS_SERVER environment variable to test NFS connectivity"
        log_info "Example: NFS_SERVER=10.87.10.101 $0"
    fi
    
    echo
    log_success "✓ eth1 interface validation completed"
}

# Run main function
main "$@"