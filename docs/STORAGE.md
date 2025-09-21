# Shared storage for Swarm: NFS

This repo now uses NFS for shared storage. You can enable an NFS server on the first manager and mount it on all managers using the provided Ansible roles.

## Enable NFS

1. In `ansible/inventories/homelab/group_vars/managers.yml`, set/update:

```yaml
nfs_enabled: true
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
