#
# Modulmanifest fuer das Modul "BieberWorks.RepoSetup"
#
# Generiert von: Pierre Bieber
#

@{

    RootModule        = 'BieberWorks.RepoSetup.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '4074db7a-2b9a-453d-8304-b86e04e81066'
    Author            = 'BieberWorks'
    CompanyName       = 'BieberWorks'
    Copyright         = '(c) 2026 BieberWorks. Alle Rechte vorbehalten.'
    Description       = 'BieberWorks SDK Repo-Setup Tools — New-BwAppRepo, New-BwModuleRepo, New-BwApiRepo, New-BwWasmApiRepo, New-BwWasmRepo, New-BwBlankRepo und Hilfsfunktionen.'
    PowerShellVersion = '7.2'

    FunctionsToExport = @(
        'New-BwModuleRepo',
        'New-BwAppRepo',
        'New-BwApiRepo',
        'New-BwWasmApiRepo',
        'New-BwWasmRepo',
        'New-BwBlankRepo',
        'Get-BwGithubUser',
        'Get-BwRepoIdentity',
        'Add-BwPackageDeployment',
        'Add-BwDockerPublish',
        'Add-BwSlnxItem'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags        = @('BieberWorks', 'SDK', 'Repo', 'Setup')
            ProjectUri  = 'https://github.com/BieberWorks/tooling'
            LicenseUri  = 'https://github.com/BieberWorks/tooling/blob/main/LICENSE'
            ReleaseNotes = ''
        }
    }

}
