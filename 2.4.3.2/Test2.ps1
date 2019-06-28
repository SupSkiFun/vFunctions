using module .\vClass.psm1
<#.Synopsis
Obtains Port Groups from ESXi Hosts
.DESCRIPTION
Returns an object of PortGroups, Hostname(s), Vswitches and VLANs from ESXi Hosts by default.
Requires input from Get-VMHost.  Alias = svvpg
Optionally return MTU and Number of Ports from the Vswitch with the -Full Parameter
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER Full
Optional.  If specified returns MTU and Number of Ports, in addition to the default output.
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.PortGroupInfo
.EXAMPLE
Return Port Group Object from one ESXi Host:
Get-VMHost -Name ESX01 | Show-VMHostVirtualPortGroup
.EXAMPLE
Place Port Group Object from two ESXi Hosts into a variable:
$MyVar = Get-VMHost -Name ESX03, ESX04 | Show-VMHostVirtualPortGroup
.EXAMPLE
Place Port Group Object from multiple ESXi Hosts into a variable using the Show-VMHostVirtualPortGroup alias:
$MyVar = Get-VMHost -Location CLUSTER04 | svvpg
.EXAMPLE
Include MTU and Port Number with the default output using the -Full Parameter:
$MyVar = Get-VMHost -Name ESX07 | Show-VMHostVirtualPortGroup -Full
#>
function Test-VMHostVirtualPortGroup   #Show-VMHostVirtualPortGroup
{
    [CmdletBinding()]
    [Alias("svvpg")]
    param
    (
		[Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost,
		[switch]$Full
 	)

	    Begin
    {
        $exhash = [vClass]::MakeHash('ex')
    }

    Process
    {
		$vpg = $vmhost |
			Get-VirtualPortGroup -Name *

		foreach ($vp in $vpg)
		{
			if($full)
			{
				$loopobj = [pscustomobject]@{
					PortGroup = $vp.Name
					VLAN = $vp.VLanId
					HostName = $exhash.($vp.VirtualSwitch.VMHostId)
					Vswitch = $vp.VirtualSwitchName
					VswitchMTU = $vp.VirtualSwitch.MTU
					VswitchPorts = $vp.VirtualSwitch.NumPorts
				}
			}
 			else
			{
				$loopobj = [pscustomobject]@{
					PortGroup = $vp.Name
					VLAN = $vp.VLanId
					Vswitch = $vp.VirtualSwitchName
					HostName = $exhash.($vp.VirtualSwitch.VMHostId)
				}
			}
		$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.PortGroupInfo')
		$loopobj
		}
    }
}

<#
.SYNOPSIS
Outputs DRS rules for specified clusters
.DESCRIPTION
Outputs an object of DRS Rule Name, cluster, VMIds, VM Name, Type and Enabled for specified clusters.
Alias = sdr
.PARAMETER Cluster
Mandatory.  Cluster(s) to query for DRS rules.  Can manually enter or pipe output from VmWare Get-Cluster.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.PortGroupInfo
.EXAMPLE
Retrieve DRS rule for one cluster, placing the object into a variable:
$MyVar = Show-DrsRule -Cluster cluster09
.EXAMPLE
Retrieve DRS rules for all clusters, using the Show-DrsRule alias, placing the object into a variable:
$MyVar = Get-Cluster -Name * | sdr
#>
function Test-DrsRule   #Show-DrsRule
{
    [CmdletBinding()]
    [Alias("sdr")]
    param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
			ValueFromPipeline = $true,
			Position=0,
			Mandatory=$true
		)]
		[Alias("Name")]
		$Cluster
	)

    Begin
    {
		$vmhash = [vClass]::MakeHash('vm')
    }

    Process
    {
		$drule = Get-DrsRule -Cluster $Cluster
		foreach ($rule in $drule)
		{
			$vname = foreach ($vn in $rule.vmids)
			{
				$vmhash.$vn
			}
			$loopobj = [pscustomobject]@{
				Name = $rule.Name
				Cluster = $rule.cluster
				VMId = $rule.VMIds
				VM = $vname
				Type = $rule.Type
				Enabled = $rule.Enabled
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.DrsRuleInfo')
			$loopobj
			$vname = $null
		}
    }
}

<#
.SYNOPSIS
Sets Path Selection Policy for DataStores
.DESCRIPTION
Sets Path Selection Policy to either Most Recently Used, Fixed, or Round Robin.  Does not attempt if the requested policy is already set.
Produces an object of DataStore, PathSelectionPolicy, HostName, Device, SetPathStatus, WorkingPaths, and CapacityGB for all requested DataStores.
Will check / set against every VMHost that has the DataStore Mounted.  Will return pipeline error if a non-VMFS DataStore is piped in.
.PARAMETER DataStore
Output from VMWare PowerCLI Get-DataStore.  VMFS datastores only.
VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore
.PARAMETER Policy
Must be one of VMW_PSP_MRU, VMW_PSP_FIXED, or VMW_PSP_RR.  MRU = Most Recently Used, FIXED = Fixed, RR = Round Robin.
.EXAMPLE
Set Path Selection Policy for one Datastore to Round Robin, returning an object into a variable:
$MyVar = Get-Datastore -Name VOL02 | Set-PathSelectionPolicy -Policy VMW_PSP_RR
.EXAMPLE
Set Path Selection Policy for all VMFS Datastores mounted on a ESXi Host to Most Recently Used, returning an object into a variable:
$MyVar = Get-Datastore -VMHost ESX03 -Name * | Where-Object -Property Type -Match VMFS  | Set-PathSelectionPolicy -Policy VMW_PSP_MRU
.INPUTS
Output from VMWare PowerCLI Get-DataStore - VMFS datastores only
VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore
.OUTPUTS
[pscustomobject] SupSkiFun.PathSelectionInfo
#>
function Test-PathSelectionPolicySET  #  Set-PathSelectionPolicy
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'high')]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore[]]$DataStore,

        [Parameter(Mandatory = $true)]
        [ValidateSet("VMW_PSP_MRU", "VMW_PSP_FIXED", "VMW_PSP_RR")]$Policy
    )

    Begin
    {
        $exhash = [vClass]::MakeHash('ex')
    }
    
    Process
    {
        foreach ($ds in $DataStore)
        {
            if($PSCmdlet.ShouldProcess("$ds to $($policy)"))
            {
                $device = $ds.ExtensionData.Info.Vmfs.Extent.Diskname
                $devq = @{device = $device}
                $dshosts = $ds.ExtensionData.host

                foreach ($dsh in $dshosts)
                {
                    $vmh = $exhash.$($dsh.key.ToString())
                    $e2 = Get-EsxCli -v2 -VMHost $vmh
                    $r2 = $e2.storage.nmp.device.list.Invoke($devq)

                    if($r2.PathSelectionPolicy -notmatch $Policy)
                    {
                        $devset = @{device = $device ; psp = $Policy}
                        $s2 = $e2.storage.nmp.device.set.Invoke($devset)

                        if($s2 -match "true")
                        {
                            $status = "Success"
                        }
                        else
                        {
                            $status = "Unknown: Return value is $s2"
                        }

                        $r2 = $e2.storage.nmp.device.list.Invoke($devq)

                    }
                    elseif ($r2.PathSelectionPolicy -match $Policy)
                    {
                        $status = "Not Attempted; $policy is already set"
                    }

                    $lo = [pscustomobject]@{
                        DataStore = $ds.Name
                        PathSelectionPolicy = $r2.PathSelectionPolicy
                        HostName = $vmh
                        Device = $device
                        SetPathStatus = $status
                        WorkingPaths = $r2.WorkingPaths
                        CapacityGB = $ds.CapacityGB
                    }

                    $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.PathSelectionInfo')
                    Write-Output $lo
                    $devset, $e2, $r2, $s2, $status, $vmh = $null
                }
            }
        }
    }
}

<#
.SYNOPSIS
Returns Path Selection Policy from DataStores
.DESCRIPTION
Produces an object of DataStore, PathSelectionPolicy, HostName, Device, WorkingPaths, and CapacityGB for all requested DataStores.
Will check against every VMHost that has the DataStore Mounted.  Will return pipeline error if a non-VMFS DataStore is piped in.
.PARAMETER DataStore
Output from VMWare PowerCLI Get-DataStore.  VMFS datastores only.
VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore
.EXAMPLE
Return an object for one DataStore into a variable:
$MyVar = Get-Datastore -Name Storage01 | Get-PathSelectionPolicy
.EXAMPLE
Return an object for all VMFS DataStores mounted on a ESXi Host into a variable:
$MyVar = Get-Datastore -VMHost ESX03 -Name * | Where-Object -Property Type -Match VMFS  | Get-PathSelectionPolicy
.INPUTS
Output from VMWare PowerCLI Get-DataStore - VMFS datastores only
VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore
.OUTPUTS
[pscustomobject] SupSkiFun.PathSelectionInfo
#>
function Test-PathSelectionPolicyGET  #Get-PathSelectionPolicy
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore[]]$DataStore
    )

    Begin
    {
        $exhash = [vClass]::MakeHash('ex')
    }
    
    Process
    {
        foreach ($ds in $DataStore)
        {
            $device = $ds.ExtensionData.Info.Vmfs.Extent.Diskname
            $devq = @{device = $device}
            $dshosts = $ds.ExtensionData.host

            foreach ($dsh in $dshosts)
            {
                $vmh = $exhash.$($dsh.key.ToString())
                $e2 = Get-EsxCli -v2 -VMHost $vmh
                $r2 = $e2.storage.nmp.device.list.Invoke($devq)

                $lo = [pscustomobject]@{
                    DataStore = $ds.Name
                    PathSelectionPolicy = $r2.PathSelectionPolicy
                    HostName = $vmh
                    Device = $device
                    WorkingPaths = $r2.WorkingPaths
                    CapacityGB = $ds.CapacityGB
                }

                $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.PathSelectionInfo')
                Write-Output $lo
            }
        }
    }
}

<#
.SYNOPSIS
Obtains LUN of DataStore(s).
.DESCRIPTION
Returns an object of Name, LUN, WorkingPaths, PathSelectionPolicy, Device and DeviceDisplayName of VMFS Datastore(s).
Requires Pipleline input from VmWare Get-Datastore.  Will only process VMFS; NFS will not be accepted.
.PARAMETER Name
Requires Pipleline input from VmWare PowerCLI Get-Datastore.  Only VMFS DataStores accepted.
VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore
.INPUTS
VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.LUNinfo
.EXAMPLE
Retrieve information from one VMFS DataStore:
Get-DataStore -Name Dstore01 | Get-DataStoreLunID
.EXAMPLE
Return an object of multiple VMFS DataStores into a variable, using the Get-DataStoreLunID alias:
$MyVar = Get-Datastore -Name Dstore* | Where-Object -Property Type -Match "VMFS" | gdli
.EXAMPLE
Query all VMFS DataStores of an ESX host, returning the object into a variable:
$MyVar = Get-Datastore -VMHost ESX01 | Where-Object -Property Type -Match "VMFS" | Get-DataStoreLunID
#>
function Test-DataStoreLunID  #Get-DataStoreLunID
{
    [CmdletBinding()]
    [Alias("gdli")]
    param
    (
    [Parameter(ValueFromPipeline=$true, Mandatory = $true)]
	[VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore[]]$Name
	)

    Begin
    {
        $exhash = [vClass]::MakeHash('ex')
    }
    
    Process
    {
		function MakeObj
		{
        param ($lun, $luninfo=$null)

        $loopobj = [pscustomobject]@{
            Name = $n.Name
            Lun = $lun
            WorkingPaths = $luninfo.WorkingPaths
            PathSelectionPolicy = $luninfo.PathSelectionPolicy
            Device = $luninfo.Device
            DeviceDisplayName = $luninfo.DeviceDisplayName
        }
        $loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.LUNinfo')
        $loopobj
		}

		foreach ($n in $name)
		{
            $ds, $e2, $hs, $li, $ld = $null
            $hs = $n.ExtensionData.host
            foreach ($h in $hs)
            {
                $e2 = Get-EsxCli -v2 -VMHost $exhash.$($h.key.ToString()) -ErrorAction SilentlyContinue
                if ($e2)
                {
                    $ds = $n.ExtensionData.Info.Vmfs.Extent[0].DiskName
                    $li = $e2.storage.nmp.device.list.Invoke((@{'device'=$ds}))

                    if ($li.WorkingPaths.count -eq 1)
                    {
                        $ld = $li.WorkingPaths.ToString().Split(":")[3].Replace("L","")
                    }
                    else
                    {
                        $ld = $li.WorkingPaths[0].ToString().Split(":")[3].Replace("L","")
                    }

                    MakeObj -lun $ld -luninfo $li
                    break
                }

                $ld = "Error Connecting to VMHosts"
                MakeObj -lun $ld -luninfo $li
            }
		}
	}
}