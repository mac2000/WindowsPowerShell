<#
.Synopsis
   Remove VM and its VHD
.EXAMPLE
   Destroy-VM -Name Server1
#>
function Destroy-VM
{
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('VMName')]
        [string]$Name
    )
    Begin {
        if((Get-VM $Name).State -ne 'Off') {
            Write-Verbose "Stop $Name VM before deleting its VHD"
            Stop-VM $Name
        }
    }
    Process
    {
        Get-VMHardDiskDrive -VMName $Name | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-VMHardDiskDrive -VMName $Name | Remove-VMHardDiskDrive -ErrorAction SilentlyContinue
        Remove-VM -Name $Name -Force -ErrorAction SilentlyContinue
    }
    End {}
}

<#
.Synopsis
   Create new virtual machine from base image. Eleveted privileges required
.EXAMPLE
   Clone-VM -Name Server1 -Parent UbuntuBase
#>
function Clone-VM
{
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
		[ValidateNotNullOrEmpty()]
        [Alias('VMName')]
        [string]$Name,
        
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
		[ValidateNotNullOrEmpty()]
        [string]$Parent
    )
    Begin {
        $ParentVM = Get-VM $Parent
        $ParentVHD = Get-VMHardDiskDrive -VMName $Parent | Select-Object -ExpandProperty Path
        $ParentSwitch = Get-VMNetworkAdapter -VMName $Parent | Select-Object -First 1 -ExpandProperty SwitchName
        $VirtualHardDiskPath = Get-VMHost | Select-Object -ExpandProperty VirtualHardDiskPath
        $Ext = [System.IO.Path]::GetExtension($ParentVHD).Trim('.')
        $DiffVHD = "$VirtualHardDiskPath\$Name.$Ext"
            
        if($ParentVM.State -ne 'Off') {
            Write-Verbose "Stop $Parent VM so its VHD can be used as base image for cloned machine"
            Stop-VM $Parent
        }
    }
    Process
    {
        Write-Verbose "Creating differencial VHD from $ParentVHD to $DiffVHD"
        New-VHD -Path $DiffVHD -ParentPath $ParentVHD
        
        Write-Verbose "Create $Name VM"
        New-VM -Name $Name -Generation $ParentVM.Generation -VHDPath $DiffVHD -SwitchName $ParentSwitch -MemoryStartupBytes $ParentVM.MemoryStartup
        
        if ($ParentVM.DynamicMemoryEnabled)
        {
            Set-VMMemory -VMName $Name -DynamicMemoryEnabled $True -MinimumBytes $ParentVM.MemoryMinimum -MaximumBytes $ParentVM.MemoryMaximum
        }
        
        Set-VMProcessor -VMName $Name -Count $ParentVM.ProcessorCount
        
        if($ParentVM.Generation -eq 2) {
            Set-VMFirmware -VMName $Name -EnableSecureBoot (Get-VMFirmware -VMName $Parent | Select-Object -ExpandProperty SecureBoot)
        }
        
        Get-VMIntegrationService -VMName $Parent | %{
            if($_.Enabled) {
                Enable-VMIntegrationService -Name $_.Name -VMName $Name
            } else {
                Disable-VMIntegrationService -Name $_.Name -VMName $Name
            }
        }
    }
    End {}
}

<#
.Synopsis
   Retrieve VM IP Address
.EXAMPLE
   Get-VMIP -Name Server1
#>
function Get-VMIP
{
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('VMName')]
        [string]$Name
    )
    Begin {
    }
    Process
    {
        Get-VMNetworkAdapter -VMName $Name | Select-Object -ExpandProperty IPAddresses | ?{ $_ -Like '*.*.*.*'} | Select-Object -First 1
    }
    End {}
}