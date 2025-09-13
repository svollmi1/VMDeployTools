@{
    RootModule        = 'VMDeployTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'e5b1c6a4-4f5a-4c2f-b4d9-9f66187a9084'
    Author            = 'Scott Vollmin'
    CompanyName       = 'VollminLab'
    Copyright         = '(c) 2025 VollminLab'
    Description       = 'Automates VM deployments, sets DNS records in Pi-hole, generates SSH keys, manages cloud-init and logging.'
    PowerShellVersion = '5.1'

    # -------------------------------------------------------------------------
    # *** REMOVED RequiredModules to avoid cyclic dependency with VMware modules ***
    # RequiredModules   = @('VMware.PowerCLI')
    # -------------------------------------------------------------------------

    RequiredAssemblies = @()

    FunctionsToExport = @(
        'Set-OpSession',
        'Connect-ToVCenter',
        'Test-VMHostReadiness',
        'Invoke-VMDeployment',
        'Add-DnsRecordToPiHole',
        'Remove-DnsRecordFromPiHole',
        'New-SshKeyPair',
        'Add-SshConfigEntry',
        'Install-VirtualMachine',
        'Remove-VMDeployment'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('VMware','VMDeployment','CloudInit','PiHole','SSH','Logging')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/VollminLab/VMDeployTools'
            ReleaseNotes = 'Initial 1.0.0 release with full logging and cloud-init support'
        }
    }
}
