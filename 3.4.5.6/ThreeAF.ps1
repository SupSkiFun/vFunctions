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


<#
.SYNOPSIS
Produces an object of VAMI Health
.DESCRIPTION
Produces an object of VAMI Health, including Name, Status, Returns and Full Name of
load, storage, swap, softwarepackages, databasestorage, applmgmt, system, and mem monitors.
Requires connection to CIS Server; see Connect-CisServer.
.NOTES
Status for softwarepackages (only) are:
Red indicates that security updates are available.
Orange indicates that non-security updates are available.
Green indicates that there are no updates available.
Gray indicates that there was an error retreiving information on software updates.
.OUTPUTS
pscustomobject SupSkiFun.VAMI.Health.Status
.EXAMPLE
Returns an object of VAMI Health into a variable:
$MyObj = Get-VAMIHealth
.EXAMPLE
Returns an object of VAMI Health into a variable, using the Get-VAMIHealth alias:
$MyObj = gvh
.LINK
Connect-CisServer
#>
function Get-VAMIHealth
{
    [CmdletBinding()]
    [Alias("gvh")]
    param()
    
    Begin
	{
        if(!$global:DefaultCisServers)
        {
            Write-Output "Terminating. Session is not connected to a CIS server.  See Connect-CisServer."
            break
        }
        
        $svcs = Get-CisService -Name com.vmware.appliance.health.*
        $ti = (Get-Culture).TextInfo
	}

    Process
    {
		foreach ($svc in $svcs)
		{
 			$r = ($svc.Help.get.Returns).Trim(".",1)
			$loopobj = [pscustomobject]@{
				Name = $svc.name.Split(".")[($svc.name.Split(".").count) -1]
				Status = $svc.get()
				Returns = $ti.ToTitleCase($r)
				FullName = $svc.Name
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VAMI.Health.Status')
			$loopobj
		}
	}
}


function Invoke-HAReconfigure
{
    <#
        Get-VMhost | Sort Name | %{$_.ExtensionData.ReconfigureHostForDAS()} DAS_Task alsoâ€¦.
    #>

}