# VMDeployTools — Configuration

## Bootstrap (first run on a new machine)

Configuration auto-bootstraps from a 1Password secure note on first import. No manual config file editing required.

**1Password item required:** A secure note titled `"VMDeployTools Config"` in the Homelab vault — the vault is hardcoded for this one call — whose **note body** (the `notesPlain` field) contains the full config hashtable:

```powershell
@{
    VaultName               = 'Homelab'
    SvcTokenItemTitle       = 'VMDeployTools-ServiceAccount'   # 1P item, token in its password field
    VCenterCredItemTitle    = 'vCenter-Admin'                  # 1P item with vCenter credentials
    LocalMachineName        = 'GLaDOS'                         # Hostname that is primary admin machine
    RemoteUserProfileShare  = '\\GLaDOS\c$\Users\scott\.ssh'   # UNC to primary admin's .ssh (optional)
    VCenterServer           = 'vcenter.vollminlab.com'
    ClusterName             = 'vollminlab-cluster'
    PreferredDatastores     = @('shared-datastore-1', 'shared-datastore-2')
    Domain                  = 'vollminlab.com'
    PiHoleServer            = '192.168.100.4'                  # keepalived VIP
    PiHolePort              = '5001'
}
```

On `Import-Module VMDeployTools`, the module fetches this note via the 1Password CLI and writes the config locally. Subsequent imports load from the local file.

## Config file location

After bootstrap, the config is saved next to the module itself, in `$PSScriptRoot`:
```
<repo root>\VMDeployTools.config.psd1
```

There is no `%LOCALAPPDATA%` copy — the module only ever looks beside `VMDeployTools.psm1`.

**Never commit this file** — it contains resolved paths and vault references. The `.gitignore` excludes it by name.

## Key config values explained

| Key | Purpose |
|-----|---------|
| `VaultName` | 1Password vault to search for all homelab items |
| `SvcTokenItemTitle` | 1P item whose `password` field holds the service account token for non-interactive CLI auth |
| `VCenterCredItemTitle` | 1P item with `username` and `password` fields for vCenter |
| `LocalMachineName` | If the current hostname matches this, SSH keys are NOT mirrored to the remote share (you're already on the primary machine) |
| `RemoteUserProfileShare` | UNC path to the primary admin machine's **`.ssh` directory** — the public key is written straight into it and `config` is appended to at `<share>\config` |
| `PreferredDatastores` | Shared datastores preferred over host-local storage. Not evaluated in order: the emptiest one with enough free space wins |
| `PiHoleServer` | The VRRP VIP, not pihole1 or pihole2 directly — there is no failover logic, so pointing at a single node breaks DNS whenever that node is down |

## Required 1Password items

| Item title | Fields needed | Purpose |
|-----------|--------------|---------|
| `VMDeployTools Config` | `notesPlain` (the note body) | Bootstrap config. Vault is hardcoded to `Homelab` for this lookup |
| `<SvcTokenItemTitle>` | `password` | 1Password service account token for non-interactive auth |
| `<VCenterCredItemTitle>` | `username`, `password` | vCenter login |
| `Recordimporter` | `credential` | Pi-hole API bearer token. The item title is hardcoded; only the vault is configurable |

## Authentication flow

```
Import-Module VMDeployTools
        │
        └──► First op call triggers Initialize-OpAuth
                    │
                    ├── Checks $env:OP_SERVICE_ACCOUNT_TOKEN
                    └── If not set, reads the `password` field of 1P item <SvcTokenItemTitle>
                                │   (running `op signin` first if there is no session)
                                │
                                └──► Sets $env:OP_SERVICE_ACCOUNT_TOKEN for this process only
```

Clear the token when done (especially on shared machines):
```powershell
Clear-OpAuth
# or use: Invoke-VMDeployment ... -ClearOpAuthToken
```

## Disaster recovery

If the local config file is lost:
```powershell
# Re-bootstrap from 1Password — the file lives beside the module
Remove-Item .\VMDeployTools.config.psd1 -ErrorAction SilentlyContinue
Import-Module .\VMDeployTools.psd1 -Force
# Module will re-fetch from 1Password and regenerate the local config
```

If `op` is unavailable, the module throws and tells you to fall back to the manual path:
```powershell
Copy-Item VMDeployTools.config.example.psd1 VMDeployTools.config.psd1
# then edit it
```
