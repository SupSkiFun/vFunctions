




function Clear-VSphereAlarm
{
    [CmdletBinding()]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Red" , "Yellow")]
        [string] $Status ,

        [Parameter(Mandatory = $true)]
        [ValidateSet("All" , "VM", "VMHost")]
        [string] $Entity
    )

    Begin
    {
        $hv = @{
            All = "entityTypeAll"
            VM = "entityTypeVm"
            VMHost = "entityTypeHost"
        }
    }

    Process
    {
        $almg = Get-View AlarmManager
        $filt = [VMware.Vim.AlarmFilterSpec]::new()
        $filt.Status = $Status.ToLower()
        $filt.TypeEntity = $hv.$Entity
        $almg.ClearTriggeredAlarms($filt)
    }




    <#
    $almg = Get-View AlarmManager
    $filt = [VMware.Vim.AlarmFilterSpec]::new()
    $filt.Status += [VMware.Vim.ManagedEntityStatus]::red
    $filt.TypeEntity = [VMware.Vim.AlarmFilterSpecAlarmTypeByEntity]::entityTypeVm
    $filt.TypeTrigger = [vmware.vim.AlarmFilterSpecAlarmTypeByTrigger]::triggerTypeEvent
    $almg.ClearTriggeredAlarms($filt)

    https://communities.vmware.com/thread/623890

    $hv.'All'

    #>

}



