<#
.Synopsis
    Checks whether file is valid UTF8.
.EXAMPLE
    Is-UTF8 C:\test.txt
.EXAMPLE
    Get-ChildItem | select-object Name, @{n='UTF8';e={ Is-UTF8 $_.FullName }}
.EXAMPLE
    Get-ChildItem | select -ExpandProperty FullName | Is-UTF8
#>
Function Is-UTF8 {
    [CmdletBinding()]
    [OutputType([bool])]
    Param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path
    )

    Begin {}

    Process {
        $bytes1 = Get-Content -Path $Path -Encoding Byte -Raw
        $bytes2 = [System.Text.Encoding]::UTF8.GetBytes((Get-Content -Path $Path -Encoding UTF8 -Raw))
    
        if(Compare-Object $bytes1 $bytes2) {
            #Write-Host $Path -ForegroundColor Red
            $false
        } else {
            #Write-Host $Path -ForegroundColor Green
            $true
        }
    }

    End {}
}

