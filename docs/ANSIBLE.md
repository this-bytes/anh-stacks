# Ansible: Swarm bootstrap

This folder (`ansible/`) contains playbooks to provision a 3-node Docker Swarm with all nodes as managers. Optional NFS shared storage is provided for simple workloads.

## Layout

- `ansible.cfg` — default inventory and settings
- `inventories/homelab/hosts.yml` — inventory for the 3 VMs (managers)
- `inventories/homelab/group_vars/managers.yml` — variables (network iface, networks, NFS)
- `collections/requirements.yml` — required collections
- `roles/docker` — installs Docker engine
- `roles/swarm` — initializes Swarm and joins managers; creates overlay networks
- `roles/nfs_server`, `roles/nfs_client` — optional NFS storage
- `site.yml` — main bootstrap (docker + swarm)
- `storage.yml` — optional storage setup

## Prereqs

- Python and Ansible installed on your control machine
- SSH access to the hosts with privilege escalation (become)
- Update `inventories/homelab/hosts.yml` IPs and `group_vars/managers.yml` as needed

Install collections:

```zsh
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

## Run

Bootstrap Docker + Swarm:

```zsh
ansible-playbook -i ansible/inventories/homelab/hosts.yml ansible/site.yml
```

Optional NFS storage (disabled by default, set `nfs_enabled: true` in `group_vars`):

```zsh
ansible-playbook -i ansible/inventories/homelab/hosts.yml ansible/storage.yml
```

## Storage discussion

  - Longhorn (K3s/K8s-centric; heavier than needed for Swarm)
  - Ceph (powerful but complex for homelab)
  - SMB (Windows-friendly; similar to NFS in complexity)

If you prefer a newer lightweight option over Gluster: NFS remains the simplest. For strict POSIX semantics, start with NFS and evolve if requirements grow.

## Troubleshooting & tips

- Do not pass `-Kk` unless you explicitly need to. The SSH bootstrap in `site.yml` installs your controller public key into `~localadmin/.ssh/authorized_keys` and enables `PubkeyAuthentication`, so runs should not prompt for passwords.
- Ensure the SSH user is consistent. We set `ansible_user: localadmin` in `inventories/homelab/group_vars/managers.yml` so plays use the correct account.
- If a single host becomes unreachable at Gathering Facts, test it directly:
  - `ssh localadmin@<ip> true`
  - `ansible -i ansible/inventories/homelab/hosts.yml <host> -m ping`
  
