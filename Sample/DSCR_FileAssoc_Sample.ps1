$output = 'C:\MOF'
Import-Module DSCR_FileAssoc -force

Configuration DSCR_FileAssoc_Sample
{
    Import-DscResource -ModuleName DSCR_FileAssoc
    Node localhost
    {
        cFileAssoc Txt2Notepad_Sample
        {
            Ensure = "Present"
            Extension = ".txt"
            Command = 'C:\WINDOWS\system32\NOTEPAD.EXE %1'
            FileType = 'txtfile'
            Icon = '%SystemRoot%\system32\imageres.dll,-102'
        }

        cFileAssoc Csv2NoAssoc_Sample
        {
            Ensure = "Absent"
            Extension = ".csv"
        }
    }
}

DSCR_FileAssoc_Sample -OutputPath $output
#Test-DscConfiguration -Path $output -Verbose
Start-DscConfiguration -Path  $output -Verbose -Wait -Force

