<#
.SYNOPSIS
Clears Alarms from Virtual Center
.DESCRIPTION
Clears Alarms from Virtual Center.  No output.  A status of Red, Yellow, Gray or Green
along with an Entity of All, VM or VMHost must be specified.  See Notes.
.NOTES
Future Functionality may include the option to submit more than one status color per run.
The Vsphere API isn't super flexible with clearing alarms.  See Related Links.
.PARAMETER Status
Mandatory.  Red, Yellow, Gray, or Green.  Pick one.
.PARAMETER Entity
Mandatory.  All, VM, or VMHost.  Pick one.
.INPUTS
None
.OUTPUTS
None
.EXAMPLE
Clear all alarms for all VMs with a red status:
Clear-VSphereAlarm -Entity VM -Status Red
.EXAMPLE
Clear all alarms for all VMHosts with a yellow status:
Clear-VSphereAlarm -Entity VMHost -Status Yellow
.EXAMPLE
Clear all red alarms for all entities:
Clear-VSphereAlarm -Entity All -Status Red
.LINK
https://communities.vmware.com/thread/623890
#>
function Clear-VSphereAlarm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Red" , "Yellow", "Gray", "Green")]
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
}