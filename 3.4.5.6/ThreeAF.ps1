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



function Invoke-HAReconfigure
{
    <#
        Get-VMhost | Sort Name | %{$_.ExtensionData.ReconfigureHostForDAS()} DAS_Task alsoâ€¦.
    #>

}