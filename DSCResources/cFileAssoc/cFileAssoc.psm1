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
        $FileType
    )

    Assert-PsDscRunAsUser

    $GetRes = @{
        Ensure    = $Ensure
        Extension = $Extension
    }

    $GetAssoc = Get-FileAssoc | Where-Object {$Extension -eq $_.Extension} | Select-Object -First 1
    $GetRes.FileType = $GetAssoc.ProgId

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
        $FileType
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
        $FileType
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

        Set-FileAssoc -Extension $Extension -ProgId $FileType
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

    $allUserFTAList = ConvertFrom-Csv (& $SetUserFTA get) -Header ('Extension', 'ProgId')

    if (-not $allUserFTAList) {
        throw 'Failed to get user file type associations.'
    }
    else {
        $allUserFTAList
    }
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
function Get-SetUserFTAPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $private:exeHash = '2EE75BEB17B6755DB6138E84E91CD72D06A95DDAE8A14EFF4216010FD1D0973D'
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
