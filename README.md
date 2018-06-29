# DSCR_FileAssoc

DSC Resource to configure file type association.

----
## Installation
You can install from [PowerShell Gallery](https://www.powershellgallery.com/packages/DSCR_FileAssoc/).
```Powershell
Install-Module -Name DSCR_FileAssoc
```

----
## Resources
## **cFileAssoc**

### Properties
+ [string] **Ensure** (Optional)
    + `Present`: Create file type association.
    + `Absent` : Remove association.
    + The default is `Present`. (`Present` or `Absent`)

+ [string] **Extension** (Require, Key):
    + The extension of file (e.g `".txt"`)

+ [string] **FileType** (Require):
    + The FileType of the desired association.  
    You can check the existing FileType by executing the `ftype` command.

+ [string] **Command** (Require):
    + The command of the desired association.
    + You can not specify both `FileType` and `Command`. (`FileType` takes precedence)

+ [string] **Icon** (Optional):
    + The path of Icon resource for file type.


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
    }
}
```

+ **Example 2**: Associate `.txt` file with WordPad and set custom icon
```Powershell
Configuration Example2
{
    Import-DscResource -ModuleName DSCR_FileAssoc
    cFileAssoc TXTtoWordPad
    {
        Ensure = "Present"
        Extension = ".txt"
        Command = '%ProgramFiles%\Windows NT\Accessories\WORDPAD.EXE %1'
        Icon = '%SystemRoot%\system32\imageres.dll,-100'
    }
}
```

+ **Example 3**: Remove file type association of `.csv`
```Powershell
Configuration Example3
{
    Import-DscResource -ModuleName DSCR_FileAssoc
    cFileAssoc CSVnoAssoc
    {
        Ensure = "Absent"
        Extension = ".csv"
    }
}
```

----
## ChangeLog
### 0.8.0
Initial pre-release for public.
