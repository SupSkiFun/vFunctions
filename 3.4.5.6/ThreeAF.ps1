<#
.SYNOPSIS
Reconfigures High Availability (HA)
.DESCRIPTION
Reconfigures High Availability (HA) for specified VMHosts(s) via task.  No Output by Default.
.PARAMETER VMHost
Piped output of Get-VMHost from Vmware.PowerCLI
.INPUTS
Results of Get-VMHost from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
None
.EXAMPLE
Reconfigures High Availability (HA) on one ESX Host:
Get-VMHost -Name ESX12 | Invoke-HAReconfigure
.EXAMPLE
Reconfigures High Availability (HA) on two ESX Hosts:
Get-VMHost -Name ESX01 , ESX03 | Invoke-HAReconfigure
#>
function Invoke-HAReconfigure
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

function Invoke-HAReconfigureSource
{
    <#
        Get-VMhost | Sort Name | %{$_.ExtensionData.ReconfigureHostForDAS()} DAS_Task alsoâ€¦.
    #>

}