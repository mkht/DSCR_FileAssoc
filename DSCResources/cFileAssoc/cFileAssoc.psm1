using namespace Microsoft.Win32

# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [string]
        $Extension,

        [Parameter()]
        [string]
        $FileType,

        [Parameter()]
        [string]
        $Command,

        [Parameter()]
        [string]
        $Icon
    )

    Assert-PsDscRunAsUser

    $GetRes = @{
        Ensure    = $Ensure
        Extension = $Extension
    }

    $GetAssoc = Get-FileAssoc -Extension $Extension
    $GetRes.FileType = $GetAssoc.ProgId
    $GetRes.Command = $GetAssoc.Command
    $GetRes.Icon = $GetAssoc.Icon

    if ($GetRes.FileType) {
        $GetRes.Ensure = 'Present'
    }
    else {
        $GetRes.Ensure = 'Absent'
    }

    $GetRes
} # end of Get-TargetResource


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [string]
        $Extension,

        [Parameter()]
        [string]
        $FileType,

        [Parameter()]
        [string]
        $Command,

        [Parameter()]
        [string]
        $Icon
    )

    Assert-PsDscRunAsUser

    $Ret = $true

    $CurrentState = Get-TargetResource -Ensure $Ensure -Extension $Extension

    if ($Ensure -ne $CurrentState.Ensure) {
        # Not match Ensure state
        Write-Verbose ('Not match Ensure state. your desired "{0}" but current "{1}"' -f $Ensure, $CurrentState.Ensure)
        $Ret = $Ret -and $false
    }

    if ($Ensure -eq 'Present') {
        if ($PSBoundParameters.FileType -and ($FileType -ne $CurrentState.FileType)) {
            # Not match associated FileType
            Write-Verbose ('Associated FileType is not match (Current:"{0}" / Desired:"{1}")' -f $CurrentState.FileType, $FileType)
            $Ret = $Ret -and $false
        }

        if ($PSBoundParameters.Command -and ($Command -ne $CurrentState.Command)) {
            # Not match associated command (optional)
            Write-Verbose ('Command attr is not match (Current:"{0}" / Desired:"{1}")' -f $CurrentState.Command, $Command)
            $Ret = $Ret -and $false
        }

        if ($PSBoundParameters.Icon -and ($Icon -ne $CurrentState.Icon)) {
            # Not match Icon (optional)
            Write-Verbose ('Icon attr is not match (Current:"{0}" / Desired:"{1}")' -f $CurrentState.Icon, $Icon)
            $Ret = $Ret -and $false
        }
    }

    return $Ret
} # end of Test-TargetResource


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Set-TargetResource {
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [string]
        $Extension,

        [Parameter()]
        [string]
        $FileType,

        [Parameter()]
        [string]
        $Command,

        [Parameter()]
        [string]
        $Icon
    )

    Assert-PsDscRunAsUser

    if ($Ensure -eq 'Absent') {
        #Remove association
        Write-Verbose ('Your desired state is "Absent". Start trying to remove file association of "{0}"' -f $Extension)
        Remove-FileAssoc -Extension $Extension
    }
    elseif ($Ensure -eq 'Present') {
        #Associate file type
        Write-Verbose ('Your desired state is "Present". Start trying to associate file type of "{0}"' -f $Extension)

        if (-not $PSBoundParameters.FileType) {
            Write-Error ('FileType is not specified.')
            return
        }

        $GetAssoc = Get-FileAssoc -Extension $Extension

        if ($FileType -ne $GetAssoc.FileType) {
            Write-Verbose ('Associate {0} to {1}' -f $Extension, $FileType)
            Set-FileAssoc -Extension $Extension -ProgId $FileType
        }

        if ($PSBoundParameters.Command -and ($Command -ne $GetAssoc.Command)) {
            $paramHash = @{
                FileType = $FileType
                Command  = $Command
            }

            if ($PSBoundParameters.Icon) {
                $paramHash.Icon = $Icon
            }
        }

        if ($PSBoundParameters.Icon -and ($Icon -ne $GetAssoc.Icon)) {
            if ($null -eq $paramHash) {
                $paramHash = @{
                    FileType = $FileType
                    Command  = $Command
                    Icon     = $Icon
                }
            }
            else {
                $paramHash.Icon = $Icon
            }
        }

        if ($paramHash.Command) {
            Write-Verbose ('Create FileType {0}' -f $FileType)
            New-FileType @paramHash
        }
    }
} # end of Set-TargetResource


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Get-FileAssoc {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [string]
        $Extension
    )

    try {
        $SetUserFTA = Get-SetUserFTAPath -ErrorAction Stop
    }
    catch {
        throw
    }

    $Ret = @{
        Extension = $Extension
        ProgId    = $null
        Command   = $null
        Icon      = $null
    }

    $allUserFTAList = ConvertFrom-Csv (& $SetUserFTA get) -Header ('Extension', 'ProgId')

    if (-not $allUserFTAList) {
        throw 'Failed to get user file type associations.'
    }

    $fType = $allUserFTAList | Where-Object {$Extension -eq $_.Extension} | Select-Object -First 1

    if ($fType.ProgId) {
        $Ret.ProgId = $fType.ProgId

        $GetCommand = & cmd.exe /c ("ftype {0} 2>null" -f $Ret.ProgId)
        foreach ($Line in $GetCommand) {
            if ($Line -match '=') {
                $Ret.Command = $Line.Split("=")[1].Trim()
            }
        }
    
        $RegKey = [Registry]::LocalMachine.OpenSubKey(("SOFTWARE\Classes\{0}\DefaultIcon" -f $Ret.ProgId))
        if ($RegKey) {
            $Ret.Icon = $RegKey.GetValue($null, $null, [RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $RegKey.Close()
        }
    }

    $Ret
}

# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Set-FileAssoc {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $Extension,

        [Parameter(Mandatory = $true)]
        [string]
        $ProgId
    )

    try {
        $SetUserFTA = Get-SetUserFTAPath -ErrorAction Stop
    }
    catch {
        throw
    }

    & $SetUserFTA $Extension $ProgId
}


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Remove-FileAssoc {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $Extension
    )

    try {
        $SetUserFTA = Get-SetUserFTAPath -ErrorAction Stop
    }
    catch {
        throw
    }

    & $SetUserFTA del $Extension
}


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function New-FileType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $FileType,

        [Parameter(Mandatory = $true)]
        [string]
        $Command,

        [Parameter()]
        [string]
        $Icon
    )

    $SetCommand = & cmd.exe /c ("ftype {0}={1} 2>null" -f $FileType, $Command)

    if ($PSBoundParameters.ContainsKey('Icon')) {
        $Key = ("HKLM:\SOFTWARE\Classes\{0}\DefaultIcon" -f $FileType)
        if (-not (Test-Path -LiteralPath $Key)) {
            New-Item -Path $Key -Force | Out-Null
        }
        $RegKey = [Registry]::LocalMachine.OpenSubKey(("SOFTWARE\Classes\{0}\DefaultIcon" -f $FileType), $true)
        if ($RegKey) {
            $RegKey.SetValue("", $Icon, [RegistryValueKind]::ExpandString)
            $RegKey.Close()
        }
    }
}


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Get-SetUserFTAPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $private:exeHash = '791DC39F7BD059226364BB05CF5F8E1DD7CCFDAA33A1574F9DC821B2620991C2'
    $exe = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) '\Libs\SetUserFTA\SetUserFTA.exe'

    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Error 'SetUserFTA.exe is not found in the libs directory.'
    }
    elseif ($private:exeHash -ne (Get-FileHash -LiteralPath $exe).Hash) {
        Write-Error 'The Hash of SetUserFTA.exe is not valid.'
    }
    else {
        $exe
    }
}


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Assert-PsDscRunAsUser {
    [CmdletBinding()]
    param()

    if ('SYSTEM' -eq [Environment]::UserName) {
        throw [System.ArgumentException]::new('The PsDscRunAsCredential parameter is mandatory for this Resource.')
    }
}


# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
Export-ModuleMember -Function *-TargetResource
