# Shared storage for Swarm: NFS

This repo now uses NFS for shared storage. You can enable an NFS server on the first manager and mount it on all managers using the provided Ansible roles.

**Important**: NFS storage is configured to use the **eth1** interface for external NFS server access. Ensure your servers have an eth1 interface configured for the NFS network.

## Enable NFS

1. In `ansible/inventories/homelab/group_vars/managers.yml`, set/update:

```yaml
nfs_enabled: true
nfs_interface: eth1  # Network interface for NFS access (external server)
nfs_server: <ip-of-nfs-server>  # by default, first manager
nfs_exports:
  - path: /srv/nfs/traefik
    clients: 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
nfs_mounts:
  - src: "{{ nfs_server }}:/srv/nfs/traefik"
    path: /mnt/traefik
    opts: defaults,_netdev
```

2. Apply storage playbook:

```zsh
ansible-playbook -i ansible/inventories/homelab/hosts.yml ansible/storage.yml
```

3. Validate mounts:

```zsh
ansible -i ansible/inventories/homelab/hosts.yml managers -b -m shell -a 'mount | grep -E " nfs |:/srv/nfs/" || true'
```

4. Validate eth1 interface configuration:

```bash
# Check eth1 interface setup locally
make validate-eth1-nfs

# Or run directly
./scripts/validate-eth1-nfs.sh

# Test with specific NFS server
NFS_SERVER=10.87.10.101 ./scripts/validate-eth1-nfs.sh
```

## Use in Swarm stacks

Bind-mount the NFS-backed host path into services:

```yaml
volumes:
  traefik-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/traefik

services:
  traefik:
    volumes:
      - traefik-data:/etc/traefik
```

## Notes

- NFS is simple and widely supported. Ensure network reliability and proper export options for your subnet.
- If you later require distributed semantics across nodes without a single NFS server, consider solutions like GlusterFS or Ceph; those are out of scope here.
