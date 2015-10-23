<#
.Synopsis
   Converts a PowerShell object to a Tabbed list which can be copied to Excel.
.EXAMPLE
   $data | ConvertTo-TabbedList | clip
.EXAMPLE
   ConvertTo-TabbedList($data)
#>
Function ConvertTo-TabbedList {
    [CmdletBinding()]
    [OutputType([string])]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        [PSObject[]]$collection
    )

    Begin {
        $first = $true
    }

    Process {
        ForEach($item in $collection) {
            if($first) {
                $items = @()
                $item.PSObject.Properties | %{
                    $items += $_.Name
                }

                Write-Output ($items -join "`t")

                $first = $false
            }
            
            $items = @()
            $item.PSObject.Properties | %{
                
                if($_.TypeNameOfValue -eq (Get-Date).GetType().FullName) {
                    $items += $_.Value.ToString('yyyy/MM/dd HH:mm:ss')
                }
                else {
                    #if($_.Value -and $_.Value.GetType().IsPrimitive) {
                    #    $items += $_.Value
                    #}
                    $items += $_.Value
                }
                
            }

            Write-Output ($items -join "`t")
        }
    }

    End {}
}

