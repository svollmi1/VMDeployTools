@{
    RootModule        = 'VMDeployTools.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'e5b1c6a4-4f5a-4c2f-b4d9-9f66187a9084'
    Author            = 'Scott Vollmin'
    CompanyName       = 'VollminLab'
    Copyright         = '(c) 2026 VollminLab'
    Description       = 'Automates VM deployments, sets DNS records in Pi-hole, generates SSH keys, manages cloud-init and logging.'
    PowerShellVersion = '5.1'

    RequiredAssemblies = @()

    FunctionsToExport = @(
        # Core operations
        'Invoke-VMDeployment',
        'Remove-VMDeployment',
        # vCenter
        'Connect-ToVCenter',
        'Test-VMDeploymentPrerequisites',
        'Test-VMHostReadiness',
        'Install-VirtualMachine',
        # DNS
        'Add-DnsRecordToPiHole',
        'Remove-DnsRecordFromPiHole',
        # SSH
        'New-1PSSHKeyForHost',
        'Add-SshConfigEntryLocal',
        'Update-RemoteGladosSsh',
        'Invoke-SshConfigRepoCommit',
        # 1Password
        'Initialize-OpAuth',
        'Clear-OpAuth',
        'Save-SudoPasswordTo1Password',
        # Utilities
        'Find-SiblingRepo',
        'Test-1PasswordSSHAgent'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('VMware','VMDeployment','CloudInit','PiHole','SSH','Logging')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/svollmi1/VMDeployTools'
            ReleaseNotes = '1.1.0: auto-bootstrap config from 1Password, auto-discover homelab-infrastructure repo via Find-SiblingRepo, validate vCenter prereqs before side effects, idempotent SSH key handling, SSH config synced to infra repo with auto-commit/push, Pi-hole VRRP VIP support, deprecated VMHost.State and Get-VirtualPortGroup replaced'
        }
    }
}
