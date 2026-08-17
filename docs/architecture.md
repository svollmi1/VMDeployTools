# VMDeployTools — Architecture

## What it does

A PowerShell module that automates the full lifecycle of VMware vSphere VM deployment in the vollminlab homelab. A single command (`Invoke-VMDeployment`) provisions a VM end-to-end: SSH key generation, DNS registration, VM cloning, cloud-init configuration, and password storage — all integrated with 1Password and Pi-hole.

`Remove-VMDeployment` tears down everything: DNS, SSH config, 1Password items, and the VM itself.

## Design principles

- **1Password is the source of truth** for all credentials — nothing stored on disk or in environment variables between sessions
- **Early validation** — vCenter prerequisites (template, folder, cluster existence) checked before any side effects (SSH keys, DNS, VM creation)
- **Idempotent** where possible — SSH key creation reuses existing 1Password items, DNS add returns success if record already exists
- **Graceful degradation** — remote SSH mirroring, repo syncing and DNS registration warn on failure but never abort a deployment or a teardown

## Full deployment workflow

```
Invoke-VMDeployment
│
├── 1. DNS conflict check (abort if FQDN already resolves)
│
├── 2. vCenter prerequisites validation (abort if template/folder/cluster missing)
│
├── 3. SSH key generation
│   └── Creates ed25519 keypair in 1Password as "{VMName}_id_ed25519"
│       Reuses existing key if found
│
├── 4. SSH config update
│   ├── Writes Host block to ~/.ssh/config (local)
│   ├── Writes to homelab-infrastructure repo SSH config (auto-discovered)
│   ├── Commits to branch "chore/ssh-config-add-{vmname}", pushes it,
│   │   and opens a PR with `gh pr create` — never pushes to main
│   └── Mirrors to remote GLaDOS share if on secondary admin host
│
├── 5. DNS registration
│   └── POST /add-a-record to Pi-hole VRRP VIP:{VMName}.{Domain} → {IPAddress}
│
└── 6. VM creation (Install-VirtualMachine)
    ├── Abort if a VM of that name already exists
    ├── Generate the random sudo password and store it in 1Password
    │   as login item "{VMName}" — this happens before the clone,
    │   because the cloud-init payload embeds its SHA-512 hash
    ├── Build the cloud-init user-data and metadata
    ├── Select datastore + host (prefers shared, falls back to local ESXi)
    ├── Clone from template (New-VM)
    ├── Inject cloud-init via guestinfo advanced settings (base64 encoded):
    │   ├── user-data: hostname, user, SSH key, static IP, sudo password hash
    │   └── metadata: instance-id, local-hostname
    ├── Auto-detect network port group from IP subnet and set the adapter
    ├── Resize CPU/memory/disk if specified
    └── Power on (optional -PowerOn flag)
```

The sudo password is created and stored **first** inside `Install-VirtualMachine`, not as a
final step — its hash has to exist before the user-data can be built, and the user-data has to
exist before the VM is cloned.

## Cloud-init configuration injected

```yaml
# user-data (simplified)
hostname: <VMName>
fqdn: <VMName>.<Domain>
manage_etc_hosts: true

users:
  - name: vollmin
    sudo: ALL=(ALL) ALL          # NOT NOPASSWD — sudo prompts for the password
    shell: /bin/bash
    lock_passwd: false
    passwd: <SHA-512 hashed random password>
    ssh_authorized_keys:
      - <ed25519 public key from 1Password>

ssh_pwauth: false

# written to /etc/netplan/50-cloud-init.yaml; cloud-init's own network config
# is disabled first via /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network:
  version: 2
  ethernets:
    id0:
      match:
        name: "en*"              # matches whatever the NIC is named
      addresses:
        - <IPAddress>/24
      nameservers:
        addresses: [192.168.100.4, 192.168.100.3]
      routes:
        - to: default            # `routes:`, not the deprecated `gateway4:`
          via: <first-three-octets>.1
```

A `/24` prefix and a gateway at `.1` are hardcoded assumptions, derived from the supplied
`-IPAddress`. `runcmd` then runs `netplan apply` and rewrites the `search` line in
`/etc/resolv.conf`.

## Network port group detection

Port groups are selected based on the third octet of the VM's IP address. Auto-detection is tried
**first**, for every subnet; the hardcoded map is only a fallback:

1. Query vCenter for distributed port groups matching `^\d{3}-DPG-`, then take the first one
   named `{third-octet}-DPG-*`
2. If none matched, fall back to the hardcoded map below
3. If the subnet is not in that map either, throw

| Subnet | Hardcoded fallback | Notes |
|--------|-------------------|-------|
| 192.168.152.x | `152-DPG-GuestNet` | Main VM network |
| 192.168.160.x | `160-DPG-DMZ` | DMZ network |
| Other | *(none — throws)* | Only auto-detection can resolve it |

## Datastore selection

Required free space is `DiskGB × 1.1`, or 30 GB when `-DiskGB` is not supplied.

1. Of the datastores named in `PreferredDatastores` that have enough free space, the **emptiest**
   one wins — the list is not evaluated in order. The VM is then placed on the connected host with
   the lowest `CpuUsageMhz`.
2. If no preferred datastore qualifies, walk the connected hosts and take the first one whose own
   local datastore has enough space — host and datastore are chosen together in that case.

## Repository auto-discovery

The module finds `homelab-infrastructure` automatically by:
1. Getting the GitHub remote URL of `VMDeployTools`
2. Extracting the org owner (`vollminlab`)
3. Searching sibling directories for a repo with the same GitHub owner

No hardcoded paths — works as long as both repos are cloned under the same parent directory.

## 1Password items created per VM

| Item title | Type | Contents |
|-----------|------|----------|
| `{VMName}_id_ed25519` | SSH Key | ed25519 keypair, tags `Homelab,AutoProvisioned` |
| `{VMName}` | Login | sudo password, `username=vollmin`, tag `Homelab` |

Both items are archived (not deleted) on `Remove-VMDeployment`.

## Integration points

| System | How it's used |
|--------|--------------|
| 1Password CLI (`op`) | Key generation, secret storage, config bootstrap |
| 1Password SSH agent | SSH key auth (must be running at deploy time) |
| Pi-hole REST API | DNS A record registration/removal |
| VMware vCenter | VM clone, power, hardware config via PowerCLI |
| homelab-infrastructure repo | SSH config change committed to a branch and proposed as a PR |
| Git | Branch, commit and push of SSH config changes |
| `gh` CLI | Opens the SSH config PR. If absent, the branch is left pushed for a manual PR |
