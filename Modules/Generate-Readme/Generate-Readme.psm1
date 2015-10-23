<#
.Synopsis
   Generate markdown readme with module descriptions and usage examples
.EXAMPLE
   Generate-Readme
#>
function Generate-Readme
{
    [OutputType([string])]
    Param (
    )
    Begin
	{
        $Modules = Get-Module -ListAvailable | Where-Object Path -Like "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\*"
    }
    Process
    {
        $Modules | %{
            $Module = $_
            Write-Host ("`n" * 4)
            Write-Host $Module.Name -ForegroundColor Green
            Write-Host ('=' * $Module.Name.Length) -ForegroundColor Green
    
            $Module | Select-Object -ExpandProperty ExportedFunctions | Select-Object -ExpandProperty Values | %{
                $Function = $_
                Write-Host ("`n" * 2)
                Write-Host $Function.Name -ForegroundColor Yellow
                Write-Host ('-' * $Function.Name.Length) -ForegroundColor Yellow
                Write-Host ''

                $Examples = Get-Help $Function.Name -Examples
                Write-Host $Examples.Synopsis
                Write-Host ''

                $Examples | Select-Object -ExpandProperty examples | %{
                    $_ | Select-Object -ExpandProperty example | %{

                        $Lines = @()
                        $Lines += $_.code.Trim()
                
                        $_.remarks | Where-Object Text -NE '' | %{
                            $_.Text.Trim().Split("`n") | %{
                                $Line = $_.Trim()
                                if($Line -ne '') {
                                    $Lines += $Line
                                }
                            }
                        }

                        $Lines | %{
                            $Line = $_
                            if($Line.StartsWith('#')) {
                                Write-Host "`t$Line" -ForegroundColor DarkGray
                            } else {
                                Write-Host "`t$Line" -ForegroundColor Gray
                            }
                    
                        }
                    }
                }
            }
        }
    }
    End {}
}