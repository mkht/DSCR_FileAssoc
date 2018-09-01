# DSCR_FileAssoc

DSC Resource to configure file type association.

----
## Installation
You can install from [PowerShell Gallery](https://www.powershellgallery.com/packages/DSCR_FileAssoc/).
```Powershell
Install-Module -Name DSCR_FileAssoc
```

----
## Requirements
DSCR_FileAssoc only supports these environments

+ Windows 8 or later
+ Windows Server 2012 or later

----
## **cFileAssoc**

### Properties
+ [string] **Ensure** (Optional)
    + `Present`: Create file type association.
    + `Absent` : Remove association.
    + The default is `Present`. (`Present` or `Absent`)

+ [string] **Extension** (Require, Key):
    + The extension of file (e.g `".txt"`)

+ [string] **FileType** (Write):
    + The FileType of the desired association.  
    You can check the existing FileType by executing the `ftype` command.

+ [PSCredential] **PsDscRunAsCredential** (Require):
    + The user credential to configure.


### Examples
+ **Example 1**: Associate `.pdf` file with Acrobat Reader
```Powershell
Configuration Example1
{
    Import-DscResource -ModuleName DSCR_FileAssoc
    cFileAssoc PDFtoAcrobat
    {
        Ensure = "Present"
        Extension = ".pdf"
        FileType = "AcroExch.Document.DC"
        PsDscRunAsCredential = (Get-Credential)
    }
}
```

+ **Example 2**: Remove file type association of `.csv`
```Powershell
Configuration Example2
{
    Import-DscResource -ModuleName DSCR_FileAssoc
    cFileAssoc CSVnoAssoc
    {
        Ensure = "Absent"
        Extension = ".csv"
        PsDscRunAsCredential = (Get-Credential)
    }
}
```

----
## ChangeLog
### Not Released
+ The parameter `Command` and `Icon` is deprecated. (We plan to re-implement in the future)
+ The parameter `PsDscRunAsCredential` is now mandatory.
+ Windows 7 is no longer supported.

### 0.8.0
Initial pre-release for public.
