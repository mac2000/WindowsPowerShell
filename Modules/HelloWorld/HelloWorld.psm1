<#
.Synopsis
   PowerShell Module StarterKit
.EXAMPLE
   Say-Hello
.EXAMPLE
   Say-Hello -To Alexandr
#>
function Say-Hello
{
    [OutputType([string])]
    Param
    (
        # Say hello to
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string]$To
    )
    Begin
	{
        if(-not $To)
		{  
            Write-Verbose 'Retrieving current username'         
            $To = $env:Username
        }
    }
    Process
    {
        Write-Host "Hello $To" -ForegroundColor Green
    }
    End {}
}