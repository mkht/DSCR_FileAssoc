$output = 'C:\MOF'
Import-Module DSCR_FileAssoc -force

$configuraionData = @{
    AllNodes =
    @(
        @{
            NodeName = "*"
            PSDscAllowPlainTextPassword = $true
        },
        @{
            NodeName = "localhost"
            Role = "test"
        }
    )
}

Configuration DSCR_FileAssoc_Sample
{
    param (
        [PSCredential]$Credential = (Get-Credential)
    )
    Import-DscResource -ModuleName DSCR_FileAssoc
    Node localhost
    {
        cFileAssoc example
        {
            Ensure = "Present"
            Extension = ".pdf"
            FileType = 'AcroExch.Document.DC'
            PsDscRunAsCredential = $Credential
        }
    }
}

DSCR_FileAssoc_Sample -OutputPath $output -ConfigurationData $configuraionData -ErrorAction Stop
Start-DscConfiguration -Path $output -Verbose -wait -force
Remove-DscConfigurationDocument -Stage Current,Previous,Pending -Force
