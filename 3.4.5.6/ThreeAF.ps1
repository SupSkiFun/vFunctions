<#
.SYNOPSIS
Returns VMHost High Availability (HA) Status
.DESCRIPTION
Returns VMHost High Availability (HA) Status
.PARAMETER VMHost
Output from Get-VMHost from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.INPUTS
Results of Get-VMHost from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
[pscustomobject] SupSkiFun.VMHost.HA.Status
.EXAMPLE
Returns VMHost High Availability (HA) Status from one ESX Host:
Get-VMHost -Name ESX12 | Get-VMHostHA
.EXAMPLE
Returns VMHost High Availability (HA) Status from two ESX Hosts:
Get-VMHost -Name ESX01 , ESX03 | Get-VMHostHA
#>
function Get-VMHostHA
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Process
    {
        foreach ($vmh in $vmhost)
        {
            $lo = [pscustomobject]@{
                Name = $vmh.Name
                Status = $vmh.ExtensionData.Summary.runtime.DasHostState.State
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VMHost.HA.Status')
            $lo
        }
    }
}

<#
.SYNOPSIS
Reconfigures High Availability (HA)
.DESCRIPTION
Reconfigures High Availability (HA) for specified VMHosts(s) via task.  No Output by Default.
.PARAMETER VMHost
Output from Get-VMHost from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.INPUTS
Results of Get-VMHost from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
None
.EXAMPLE
Reconfigures High Availability (HA) on one ESX Host:
Get-VMHost -Name ESX12 | Reset-VMHostHA
.EXAMPLE
Reconfigures High Availability (HA) on two ESX Hosts:
Get-VMHost -Name ESX01 , ESX03 | Reset-VMHostHA
#>
function Reset-VMHostHA
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Process
    {
        foreach ($vmh in $vmhost)
        {
            $vmh.ExtensionData.ReconfigureHostForDAS_Task()
        }
    }
}


function Clear-VSphereAlarm
{
    <#
    $almg = Get-View AlarmManager
    $filt = [VMware.Vim.AlarmFilterSpec]::new()
    $filt.Status += [VMware.Vim.ManagedEntityStatus]::red
    $filt.TypeEntity = [VMware.Vim.AlarmFilterSpecAlarmTypeByEntity]::entityTypeVm
    $filt.TypeTrigger = [vmware.vim.AlarmFilterSpecAlarmTypeByTrigger]::triggerTypeEvent
    $almg.ClearTriggeredAlarms($filt)

    https://communities.vmware.com/thread/623890

    #>

}

function Get-VMHostHA
{
    <#
        $vh1 = Get-VMhost 
        $vh1.ExtensionData.Summary.runtime.DasHostState.State
    #>

}