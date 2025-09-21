# Bootstrap Guide for Docker Swarm with NFS and SOPS

This guide covers the complete bootstrap process for setting up a Docker Swarm cluster with NFS shared storage and SOPS secrets management.

## Overview

The bootstrap process creates:
- **Docker Swarm cluster** with multiple manager nodes
- **NFS shared storage** mounted across all nodes for persistence
- **SOPS encryption** with age keys for secure secrets management
- **Komodo GitOps engine** for continuous deployment
- **Traefik ingress** for external routing and SSL termination

## Prerequisites

- **Control machine**: Linux/macOS with Ansible installed
- **Target servers**: 3+ Ubuntu/Debian servers for swarm managers
- **Network access**: SSH key-based authentication to target servers
- **DNS/Domain**: Optional domain for Traefik SSL certificates

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/this-bytes/anh-stacks.git
cd anh-stacks

# Update server IPs in inventory
vim ansible/inventories/homelab/hosts.yml

# Optional: Customize configuration
vim ansible/inventories/homelab/group_vars/managers.yml
```

### 2. Bootstrap Everything

```bash
# Complete automated setup
make bootstrap
```

This single command will:
1. Install required tools (age, sops)
2. Generate encryption keys
3. Deploy Docker Swarm cluster
4. Setup NFS shared storage
5. Encrypt secrets
6. Deploy infrastructure stacks

### 3. Verify Deployment

```bash
# Check swarm status
make ping
ansible -i ansible/inventories/homelab/hosts.yml managers[0] -b -m shell -a 'docker node ls'

# Check NFS mounts
make storage-check

# Check services
ansible -i ansible/inventories/homelab/hosts.yml managers[0] -b -m shell -a 'docker service ls'
```

## Advanced Configuration

### Custom Inventory

Create your own inventory file:

```yaml
# custom-inventory.yml
all:
  children:
    managers:
      hosts:
        swarm-01:
          ansible_host: 10.0.1.10
        swarm-02:
          ansible_host: 10.0.1.11
        swarm-03:
          ansible_host: 10.0.1.12
```

Run bootstrap with custom inventory:

```bash
./scripts/bootstrap-swarm.sh --inventory custom-inventory.yml --all
```

### NFS Configuration

The default NFS setup creates these shared mount points:

- `/mnt/traefik` - Traefik configuration and certificates
- `/mnt/komodo` - Komodo GitOps data and repositories  
- `/mnt/shared` - Shared application data
- `/mnt/stacks` - Stack-specific persistent volumes

**Important**: NFS is configured to use the **eth1** interface for external NFS server access. Ensure your servers have the eth1 interface properly configured for the NFS network.

Customize in `ansible/inventories/homelab/group_vars/managers.yml`:

```yaml
nfs_interface: eth1  # Network interface for NFS access
nfs_exports:
  - path: /srv/nfs/custom-app
    clients: "{{ hostvars[inventory_hostname]['ansible_' + nfs_interface].ipv4.network | default(ansible_default_ipv4.network) }}/{{ hostvars[inventory_hostname]['ansible_' + nfs_interface].ipv4.netmask | default(ansible_default_ipv4.netmask) }}(rw,sync,no_subtree_check,no_root_squash)"

nfs_mounts:
  - src: "{{ nfs_server }}:/srv/nfs/custom-app"
    path: /mnt/custom-app
    opts: defaults,_netdev
```

### Secrets Management

Create new encrypted secrets:

```bash
# Create plaintext secret file
echo "api_key: super-secret-value" > shared/myapp.secret.yaml

# Encrypt it
make encrypt-secrets TARGET=shared

# File becomes: shared/myapp.secret.sops.yaml
# Original plaintext file is automatically removed
```

### Domain Configuration

Update domain settings before encryption:

```bash
# Edit shared/komodo.env before first encryption
DOMAIN=your-domain.com
KOMODO_REPO_URL=https://github.com/your-org/your-repo.git
```

## Manual Steps (Alternative)

If you prefer manual control:

### 1. Install Tools
```bash
make install-tools
```

### 2. Generate Keys
```bash
make age-key
```

### 3. Deploy Cluster
```bash
make site        # Deploy swarm cluster
make storage     # Setup NFS storage
```

### 4. Setup Secrets
```bash
# Create your secret files in shared/ directory
make encrypt-secrets TARGET=shared
```

### 5. Deploy Stacks
```bash
# Manual stack deployment via ansible or docker commands
```

## Troubleshooting

### Common Issues

**SSH Connection Failed**
```bash
# Ensure SSH key authentication is working
ansible -i ansible/inventories/homelab/hosts.yml managers -m ping
```

**NFS Mount Failed**
```bash
# Check NFS server status
ansible -i ansible/inventories/homelab/hosts.yml managers[0] -b -m shell -a 'systemctl status nfs-kernel-server'

# Check network connectivity
ansible -i ansible/inventories/homelab/hosts.yml managers -b -m shell -a 'showmount -e {{ nfs_server }}'
```

**SOPS Encryption Failed**
```bash
# Verify age key exists
ls -la age.key

# Check SOPS configuration
cat .sops.yaml
```

### Log Collection

```bash
# Docker service logs
ansible -i ansible/inventories/homelab/hosts.yml managers[0] -b -m shell -a 'docker service logs komodo_komodo'

# System logs
ansible -i ansible/inventories/homelab/hosts.yml managers -b -m shell -a 'journalctl -u docker -n 50'
```

## Maintenance

### Updating Stacks

The Komodo GitOps engine automatically deploys changes when you:
1. Update files in `stacks/` or `komodo/`
2. Push changes to the main branch
3. Komodo detects changes and applies them

### Rotating Keys

```bash
# Generate new age key
make age-key

# Re-encrypt all secrets with new key
find . -name "*.sops.yaml" -exec sops updatekeys {} \;
find . -name "*.sop.env" -exec sops updatekeys {} \;
```

### Scaling Cluster

Add new nodes to inventory and run:

```bash
make site
make storage
```

## Security Considerations

- **Age keys**: Store `age.key` securely, it's required for secret decryption
- **SSH access**: Use key-based authentication, disable password auth
- **Network**: Consider firewall rules for NFS and Docker Swarm ports
- **Secrets**: Never commit plaintext secrets, always use SOPS encryption
- **Certificates**: Use real SSL certificates for production (Let's Encrypt via Traefik)

## Next Steps

After successful bootstrap:

1. Configure your applications in `stacks/` directory
2. Set up monitoring and logging stacks
3. Configure backup strategies for persistent data
4. Set up CI/CD pipelines for application deployment
5. Review and customize Traefik routing rules

See [ROADMAP.md](ROADMAP.md) for planned features and improvements.