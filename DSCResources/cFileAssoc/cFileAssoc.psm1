
# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [ValidateSet("Present","Absent")]
        [string]
        $Ensure = 'Present',

        [parameter(Mandatory = $true)]
        [string]
        $Extension,

        [parameter()]
        [string]
        $Command,

        [parameter()]
        [string]
        $FileType,

        [parameter()]
        [string]
        $Icon
    )

    $GetRes = @{
        Ensure = $Ensure
        Extension = $Extension
        Command = ''
        FileType = ''
        Icon = ''
    }

    $GetAssoc = Get-FileAssoc -Extension $Extension
    $GetRes.FileType = $GetAssoc.FileType
    $GetRes.Command = $GetAssoc.Command
    $GetRes.Icon = $GetAssoc.Icon
    if($GetRes.Command -and $GetRes.FileType){
        $GetRes.Ensure = 'Present'
    }
    else{
        $GetRes.Ensure = 'Absent'
    }
    $GetRes
} # end of Get-TargetResource

# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [string]
        $Ensure = 'Present',

        [parameter(Mandatory = $true)]
        [string]
        $Extension,

        [parameter()]
        [string]
        $Command,

        [parameter()]
        [string]
        $FileType,

        [parameter()]
        [string]
        $Icon
    )

    $Ret = $true

    $CurrentState = Get-TargetResource -Ensure $Ensure -Extension $Extension
    if($Ensure -ne $CurrentState.Ensure){   # Not match Ensure state
        Write-Verbose ('Not match Ensure state. your desired "{0}" but current "{1}"' -f $Ensure, $CurrentState.Ensure)
        $Ret = $Ret -and $false
    }
    if($Ensure -eq 'Present'){
        if($Command -ne $CurrentState.Command){ # Not match associated command
            Write-Verbose ('Command attr is not match')
            $Ret = $Ret -and $false
        }
        if($PSBoundParameters.FileType -and ($FileType -ne $CurrentState.FileType)){ # Not match FileType (optional)
            Write-Verbose ('FileType attr is not match')
            $Ret = $Ret -and $false
        }
        if($PSBoundParameters.Icon -and ($Icon -ne $CurrentState.Icon)){ # Not match Icon (optional)
            Write-Verbose ('Icon attr is not match')
            $Ret = $Ret -and $false
        }
    }

    return $Ret
} # end of Test-TargetResource

# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [string]
        $Ensure = 'Present',

        [parameter(Mandatory = $true)]
        [string]
        $Extension,

        [parameter()]
        [string]
        $Command,

        [parameter()]
        [string]
        $FileType,

        [parameter()]
        [string]
        $Icon
    )

    if($Ensure -eq 'Absent'){   #関連付け削除
        $Res = @{
            Extension = $Extension
            FileType = ''
            Command = ''
            Icon = ''
        }
    }
    elseif($Ensure -eq 'Present'){   #関連付け登録
        $Res = Get-FileAssoc -Extension $Extension
        $Res.Command = $Command
        if($PSBoundParameters.FileType){    #FileType指定あり -> 指定されたFileTypeを使う
            $Res.FileType = $FileType
        }
        elseif(-not $Res.FileType){ #FileType未設定 & FileType指定なし -> 拡張子(ドット無)+file を使う eg).txt -> txtfile
            $Res.FileType = ('{0}fiie' -f $Extension.TrimStart('.'))
        }
        # アイコン指定あり
        if($PSBoundParameters.Icon){
            $Res.Icon = $Icon
        }
    }

    Set-FileAssoc @Res    
} # end of Set-TargetResource



# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Get-FileAssoc {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]
        $Extension
    )

    $Ret = @{
        Extension = $Extension
        FileType = ''
        Command = ''
        Icon = ''
    }

    $GetFileType = & cmd.exe /c ("assoc {0} 2>null" -f $Extension)
    foreach($Line in $GetFileType)
    {
        if($Line -match '='){
            $Ret.FileType = $Line.Split("=")[1].Trim()
        }
    }

    if($Ret.FileType){
        $GetCommand = & cmd.exe /c ("ftype {0} 2>null" -f $Ret.FileType)
        foreach($Line in $GetCommand)
        {
            if($Line -match '='){
                $Ret.Command = $Line.Split("=")[1].Trim()
            }
        }

        $RegKey = ("HKLM:\SOFTWARE\Classes\{0}\DefaultIcon" -f $Ret.FileType)
        if(Test-Path $RegKey){
            $Ret.Icon = Get-ItemProperty -Path $RegKey -Name '(default)'
        }
    }
    $Ret
}

# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
function Set-FileAssoc {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]
        $Extension,

        [Parameter()]
        [string]
        $FileType = [String]::Empty,

        [Parameter()]
        [string]
        $Command = [String]::Empty,

        [Parameter()]
        [string]
        $Icon = [String]::Empty
    )

    # 拡張子とファイルタイプの紐付け
    $SetFileType = & cmd.exe /c ("assoc {0}={1}" -f $Extension, $FileType)
    if($FileType){
        # ファイルタイプと実行コマンドの紐付け
        $SetCommand = & cmd.exe /c ("ftype {0}={1} 2>null" -f $FileType, $Command.Replace('%','^%'))    # Powershellではなくコマンドラインの動作仕様に引きずられるので%を^%にエスケープする必要あり
        # ファイルアイコンの設定
        $Key = ("HKLM:\SOFTWARE\Classes\{0}\DefaultIcon" -f $FileType)
        if(-not (Test-Path $Key)){
            New-Item -Path $Key -Force | Out-Null
        }
        Set-ItemProperty -Path $Key -Name "(default)" -Value $Icon | Out-Null
    }
    #システムへの変更通知
    Update-FileAssoc
}

# ////////////////////////////////////////////////////////////////////////////////////////
# 拡張子登録変更を反映させるためのWin32APIコール
# https://msdn.microsoft.com/ja-jp/library/windows/desktop/bb762118(v=vs.85).aspx
# ////////////////////////////////////////////////////////////////////////////////////////
Function Update-FileAssoc {
    $CSharp = @'
private const int SHCNE_ASSOCCHANGED = 0x08000000;

[System.Runtime.InteropServices.DllImport("Shell32.dll")]
private static extern int SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);

public static void AssocReflesh()  {
    SHChangeNotify(SHCNE_ASSOCCHANGED, 0, IntPtr.Zero, IntPtr.Zero);
}
'@

    Add-Type -MemberDefinition $CSharp -Namespace WinAPI -Name Shell
    [WinAPI.Shell]::AssocReflesh()
}

# ////////////////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////////////////////////////////////
Export-ModuleMember -Function *-TargetResource
