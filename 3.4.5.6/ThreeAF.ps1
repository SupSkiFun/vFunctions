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
.LINK
Reset-VMHostHA
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
Reconfigures High Availability (HA) for specified VMHosts(s) via task.  Returns
task information as an object of VMHost, Name, Description, Start and ID.
.NOTES
Obtain further task information by querying the ID of the returned object with Get-Task -Id
.PARAMETER VMHost
Output from Get-VMHost from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.INPUTS
Results of Get-VMHost from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
 [pscustomobject] SupSkiFun.VMHost.HA.Status
.EXAMPLE
Reconfigures High Availability (HA) on one ESX Host:
Get-VMHost -Name ESX12 | Reset-VMHostHA
.EXAMPLE
Reconfigures High Availability (HA) on two ESX Hosts, returning the object into a variable:
$myVar = Get-VMHost -Name ESX01 , ESX03 | Reset-VMHostHA
.EXAMPLE
Reconfigures High Availability (HA) on one ESX Host, then queries the running task:
$myVar = Get-VMHost -Name ESX12 | Reset-VMHostHA -Confirm:$false
Get-Task -Id $myVar.ID
.LINK
Get-Task
Get-VMHostHA
#>
function Reset-VMHostHA
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'high')]
    param
    (
        [Parameter(ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Process
    {
        foreach ($vmh in $vmhost)
        {
            if($PSCmdlet.ShouldProcess($vmh , "Reconfigure HA"))
            {
                $t1 = $vmh.ExtensionData.ReconfigureHostForDAS_Task()
                Start-Sleep -Milliseconds 500
                $t2 = Get-Task -Id $t1
                $lo = [PSCustomObject]@{
                    VMHost = $vmh.Name
                    Name = $t2.Name
                    Description = $t2.Description
                    Start = $t2.StartTime
                    ID = $t2.ID
                }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VMHost.HA.Task')
            $lo
            }
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
