using module .\vClass.psm1

<#
.SYNOPSIS
Clears Alarms from Virtual Center
.DESCRIPTION
Clears Alarms from Virtual Center.  No output.  A status of Red, Yellow, Gray and/or Green
along with an Entity of All, VM or VMHost must be specified.  See Examples.
.NOTES
More functionality may be incorporated in a future release.
The Vsphere API isn't super flexible with clearing alarms.  See Related Links.
.PARAMETER Status
Mandatory.  Red, Yellow, Gray, or Green.  Pick one to four.
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
Clear all red and yellow alarms for all entities:
Clear-VSphereAlarm -Entity All -Status Red , Yellow
.LINK
https://communities.vmware.com/thread/623890
#>
function Clear-VSphereAlarm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Red" , "Yellow" , "Gray" , "Green")]
        [ValidateCount(1 , 4)]
        [string[]] $Status ,

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

<#
.SYNOPSIS
Finds VM associated with an IP
.DESCRIPTION
Queries all VMs for submitted IP address(es), returning an object of Name and IP.
In large envrionments it could take a minute to run.  Submit all IPs at once for better performance.
.PARAMETER IP
Valid IPv4 or IPv6 address(es).  Invalid submission will throw an exception.
.OUTPUTS
[pscustomobject] SupSkiFun.VMIPInfo
.EXAMPLE
Return VM with associated IP:
Find-VMByIP -IP 172.16.15.14
.EXAMPLE
Return VMs with associated IPs, placing the object into a variable:
$MyVar = Find-VMByIP -IP 10.9.8.7 , fe80::250:56ff:fea7:512b
#>
function Find-VMByIP
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ipaddress[]]$IP
	)

    Begin
    {
		$pasla = "NotFound"
    }

    Process
    {
		$vms = (Get-VM -Name *).Where({$_.PowerState -match "on"}) |
			Select-Object -Property  Name, @{n="IP";e={$_.Guest.IPAddress}}
		foreach ($i in $ip)
		{
			$vinfo = $vms.Where({$_.IP -match $i})
			if(!($vinfo.name))
			{
				$hname = $pasla
			}
			else
			{
				$hname = $vinfo.name
			}
			$loopobj = [pscustomobject]@{
				Name = $hname
				IP = $i
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VMIPInfo')
			$loopobj
		}
	}
}

<#
.SYNOPSIS
Formats VMHost Output in Percentage
.DESCRIPTION
Returns an object of VMHost PerCent-Free and Percent-Used of CPU/Mhz and RAM/GB.
Requires piped output from Get-VMHost from the Vmware.PowerCLI module.
.PARAMETER  VMHost
Piped output of Get-VMHost from Vmware.PowerCLI
.INPUTS
Results of Get-VMHost: VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.VMHostInfo
.EXAMPLE
Returns an object of one VMHost:
Get-VMHost -Name ESX01 | Format-VMHostPercentage
.EXAMPLE
Returns an object of all VMHosts in a cluster, using the Format-VMHostPercentage alias:
Get-VMHost -Location CL66 | fvp
.EXAMPLE
Returns an object of two VMHosts, with results in table format:
Get-VMHost -Name ESX02 , ESX03 | Format-VMHostPercentage | Format-Table
.EXAMPLE
Returns an object of all VMHosts, placing results in a variable:
$MyVar = Get-VMHost -Name *	| Format-VMHostPercentage
#>
function Format-VMHostPercentage
{
    [CmdletBinding()]
    [Alias("fvp")]
    param
    (
		[Parameter(ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost
	)

    Process
    {
		foreach ($vh in $VMHost)
		{
			$cpufree = ($vh.CpuTotalMhz - $vh.CpuUsageMhz)
			$memfree = ($vh.MemoryTotalGb - $vh.MemoryUsageGB )
			$loopobj=[pscustomobject]@{
				HostName = $vh.Name
				UsedCPUPct = [math]::Round((($vh.CpuUsageMhz / $vh.CpuTotalMhz)*100),2)
				UsedRAMPct = [math]::Round((($vh.MemoryUsageGB / $vh.MemoryTotalGb)*100),2)
				FreeCPUPct = [math]::Round((($cpufree / $vh.CpuTotalMhz)*100),2)
				FreeRAMPct = [math]::Round((($memfree / $vh.MemoryTotalGb)*100),2)
				#UsedCPU = $vh.CpuUsageMhz
				#TotalCPU = $vh.CpuTotalMhz
				#UsedRAM = [math]::Round($vh.MemoryUsageGB,2)
				#TotalRAM = [math]::Round($vh.MemoryTotalGb,2)
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VMHostInfo')
			$loopobj
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
function Get-DataStoreLunID
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

<#.SYNOPSIS
Obtains Free Space Percentage of DataStore(s).
.DESCRIPTION
Returns an object of DataStore(s) Name, URL, PerCentFree, GBFree, GbUsed, GBTotal.
Must be used in conjunction with Get-DataStore.  See Examples.
.PARAMETER Name
Pipe DataStore(s) using Get-DataStore.  See Examples.  Auto-Generated SYNTAX (above) is not quite accurate.
.INPUTS
VMware DataStore Object from Get-DataStore
.OUTPUTS
Custom PSObject SupSkiFun.DataStoreInfo
.EXAMPLE
Process information from a DataStore:
Get-DataStore -Name DataStore01 | Get-DataStorePercentageFree
.EXAMPLE
Process information from two DataStores and places object into a variable:
$MyVar = Get-DataStore -Name DataStore01 , DataStore02 | Get-DataStorePercentageFree
.EXAMPLE
Process information from multiple DataStores using the Get-DataStorePercentageFree alias, placing object into a variable:
$myVar = Get-Datastore *cl71 | gdpf
#>
function Get-DataStorePercentageFree
{
	[cmdletbinding()]
	[Alias("gdpf")]

    param
    (
        [Parameter(Mandatory = $false,
			ValueFromPipeline = $true,
			HelpMessage = "Pipe DataStore Object(s) from Get-Datastore")]
		[Alias("DataStore")]
		[VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.Datastore[]]$Name
	)

	Process
	{
		if(!$name)
		{
			Write-Output "Input Object Required. For more information execute:  help gdpf -full"
			break
		}

		foreach ($info in $name)
			{
				$loopobj=[pscustomobject]@{
					Name = $info.name
					URL = $info.ExtensionData.info.url.Split("/")[5]
					PerCentFree = [math]::Round((($info.FreeSpaceGB / $info.CapacityGB)*100),2)
					GBFree = [math]::Round($info.FreeSpaceGB, 2)
					GBUsed = [math]::Round(($info.CapacityGB - $info.FreeSpaceGB),2)
					GBTotal = [math]::Round($info.CapacityGB, 2)
				}
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.DataStoreInfo')
			$loopobj
	}
}

<#
.SYNOPSIS
Retrieves file systems of the VMHost HyperVisor.
.DESCRIPTION
By default, retrieves file systems of the VMHost HyperVisor.  If an optional pattern is specified
only file systems matching the pattern are retrieved; akin to -match.
Returns an object of HostName, MountPoint, PercentFree, Maximum, Used, and RamDiskName.
.PARAMETER VMHost
Mandatory. Output from VMWare PowerCLI Get-VMHost. See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER Pattern
Optional. If specified only returns mount points matching the pattern; akin to -match.  See Examples.
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.ESXi.HyperVisorFS.Info
.EXAMPLE
Returns an object of all HyperVisor File Systems from one VMHost:
Get-VMHost -Name ESX01 | Get-ESXiHyperVisorFS
.EXAMPLE
Returns an object of HyperVisor File Systems with a mount point matching "tmp" from two VMHosts:
Get-VMHost -Name ESX02 , ESX03 | Get-ESXiHyperVisorFS -Pattern tmp
.EXAMPLE
Returns an object of all HyperVisor File Systems from all VMHosts in a cluster, into a variable:
$myVar = Get-VMHost -Location CLUS01 | Get-ESXiHyperVisorFS
#>
Function Get-ESXiHyperVisorFS
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost,

        [string] $Pattern
    )

    Process
    {
        foreach ($vmh in $vmhost)
        {
            $x2 = Get-EsxCli -V2 -VMHost $vmh
            if (-not($pattern))
            {
                $z2 = $x2.system.visorfs.ramdisk.list.Invoke()
            }
            else
            {
                $z2 = $x2.system.visorfs.ramdisk.list.Invoke().where({$_.MountPoint -match $Pattern})
            }
            foreach ($z in $z2)
            {
                $lo = [VClass]::MakeVFSObj($vmh.Name , $z)
                $lo
            }
        }
    }
}

<#
.SYNOPSIS
Retrieves install information from a running ESXi image on a VMHost.
.DESCRIPTION
Retrieves install information from a running ESXi image on a VMHost.
Returns an object of HostName, Profile, Created, Vendor, Description, and VIBs.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.ESXi.Info
.EXAMPLE
Retrieve information from one VMHost, returning an object into a variable:
$MyVar = Get-VMHost -Name ESX01 | Get-ESXiInfo
.EXAMPLE
Retrieve information from two VMHosts, returning an object into a variable:
$MyVar = Get-VMHost -Name ESX02 , ESX03 | Get-ESXiInfo
#>
function Get-ESXiInfo
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Process
    {
        Function MakeObj
        {
            param($vhdata,$resdata)

            $lo = [PSCustomObject]@{
                HostName = $vhdata
                Profile = $resdata.Name.Replace("(Updated)","").Trim()
                Created = $resdata.CreationTime
                Vendor = $resdata.Vendor
                Description = $resdata.Description
                VIBs = $resdata.Vibs
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.ESXi.Info')
            $lo
        }

        foreach ($vmh in $VMHost)
        {
                $xcli = Get-EsxCli -V2 -VMHost $vmh
                $resp = $xcli.software.profile.get.Invoke()
                MakeObj -vhdata $vmh.Name -resdata $resp
        }
    }
}

<#
.SYNOPSIS
Retrieves HPe 650FLB Firmware and VIBs from VMHost(s).
.DESCRIPTION
Queries a VmHost for the firmware and drivers (elxnet , brcmfcoe) of a 650FLB Adapter.
Returns an object of HostName, FirmwareVersion, NicName, NicDescription, NicDriverName, NicDriverVersion,
NicDriverDescription, NicDriverID, HbaDriverName, HbaDriverVersion, HbaDriverDescription, and HbaID from VMHost(s).
Specific to HPe and 650FLB.  Will not query other Hardware Brands or NICs.  If you get an error read it.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.Info.650FLB
.EXAMPLE
Retrieve info from two VMHosts, storing the results into a variable:
$MyVar = Get-VMHost -Name ESX01 , ESX02 | Get-Info650
.EXAMPLE
Retrieve info from all VMHosts in a cluster, storing the results into a variable:
$MyVar = Get-VMHost -Location Cluster07 | Get-Info650
.EXAMPLE
Retrieve info from all connected VMHosts, storing the results into a variable:
$MyVar = Get-VMHost -Name * | Get-Info650
.LINK
Get-VMHost
#>
Function Get-Info650
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost
	)

    begin
    {
        $vend = "HP"                            # Used to only query HP/HPe systems.
        $flex = "650FLB"                        # Used to query only 650FLB NICs
        $vib1 = @{"vibname" = "elxnet"}         # Vib to Query
        $vib2 = @{"vibname" = "brcmfcoe"}       # Vib to Query
    }

    process
    {
        Function MakeObj
        {
            param ($dfirm, $dnic, $dv1, $dv2)

            $lo = [pscustomobject]@{
                    HostName = $vmh.Name
                    FirmwareVersion = $dfirm
                    NicName = $dnic.Name
                    NicDescription = $dnic.Description
                    NicDriverName = $dv1.Name
                    NicDriverVersion = $dv1.Version
                    NicDriverDescription = $dv1.Description
                    NicDriverID = $dv1.ID
                    HbaDriverName = $dv2.Name
                    HbaDriverVersion = $dv2.Version
                    HbaDriverDescription = $dv2.Description
                    HbaDriverID = $dv2.ID
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.Info.650FLB')
            $lo
        }

        foreach ($vmh in $VMHost)
        {
            $c2, $f1, $h1, $n1, $nic0, $v1, $v2 = $null
            $c2 = Get-EsxCli -V2 -VMHost $vmh
            $h1 = $c2.hardware.platform.get.Invoke().VendorName
            $n1 = $c2.network.nic.list.invoke() |
                Select-Object -First 1

            if ($h1 -inotmatch $vend)
            {
                $f1 = "Not Processed.  VendorName is $h1.  VendorName must match $vend."
                MakeObj -dfirm $f1 -dnic $n1
            }

            elseif ($n1.Description -inotmatch $flex)
            {
                $f1 = "Not Processed.  NicDescription does not match $flex."
                MakeObj -dfirm $f1 -dnic $n1
            }

            else
            {
                $nic0 = @{"nicname" = $n1.Name}
                $f1 = $c2.network.nic.get.Invoke($nic0).DriverInfo.FirmwareVersion
                $v1 = $c2.software.vib.get.Invoke($vib1)
                $v2 = $c2.software.vib.get.Invoke($vib2)
                MakeObj -dfirm $f1 -dnic $n1 -dv1 $v1 -dv2 $v2
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
function Get-PathSelectionPolicy
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
Retrieve PereniallyReserved value of RDMs from specified VMHost.
.DESCRIPTION
Retrieve PereniallyReserved value of RDMs from specified VMHost.
Returns an object of HostName, Device, and IsPerenniallyReserved.  Alias getpr.
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.INPUTS
VMWare PowerCLI VMHost Object from Get-VMHost:
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.RDM.Info
.EXAMPLE
Query one VMHost for PereniallyReserved value of RDMs:
Get-VMHost -Name ESXi17 | Get-PereniallyReserved
.EXAMPLE
Query all VMHosts in a Cluster using the Get-PereniallyReserved alias, returning object into a variable:
$myVar = Get-VMHost -Name * -Location Cluster12 | getpr
.LINK
Set-PereniallyReserved
#>

Function Get-PereniallyReserved
{
    [CmdletBinding()]
    [Alias("getpr")]
    param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
		[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Process
    {
        Function MakeObj
		{
			param($diskdata , $hostdata)

			$loopobj = [pscustomobject]@{
				HostName = $hostdata
				Device = $diskdata.Device
				IsPerenniallyReserved =	$diskdata.IsPerenniallyReserved
			}
			$loopobj
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.RDM.Info')
        }

        foreach ($vmh in $vmhost)
		{
            $x2 = Get-EsxCli -VMHost $vmh -V2
            $vd = (Get-Datastore -VMHost $vmh |
                Where-Object -Property Type -Match VMFS).ExtensionData.Info.Vmfs.Extent.Diskname
            $dl = $x2.storage.core.device.list.Invoke()
            # Remove DataStore LUNs, local MicroSd Card, Local in General, Non-Shared from the list.
            $dl = $dl |
                Where-Object {
                    $_.Device -notin $vd -and $_.Device -notmatch "^mpx" -and $_.DisplayName -notmatch "Local" -and $_.IsSharedClusterwide -eq "true"
                }
            foreach ($d in $dl)
            {
                MakeObj -diskdata $d -hostdata $vmh.Name
            }
        }
    }
}

<#
.SYNOPSIS
Returns an Object of SnapShot Data for specified VMs
.DESCRIPTION
Returns an object of VM, SnapName, Description, SizeGB, UserName, Created, and File of a snapshot.
Snapshot input must be piped from Get-SnapShot.  See Examples.
Note:  Time occassionally skews a few seconds between VIevent (log) and Snapshot (actual) info.
Ergo, this advanced function creates an 11 second window to correlate log information with actual information.
Snapshots taken on the same VM within 10 seconds of each other may produce innaccurate results.  Optionally,
the 11 second window can be adjusted from 0 to 61 seconds by using the PreSeconds and PostSeconds parameters.
.PARAMETER Name
Pipe the Snapshot object.  See Examples.
.PARAMETER PreSeconds
Number of seconds to capture VIEvents, before the SnapShot.  Default value is 5.
.PARAMETER PostSeconds
Number of seconds to capture VIEvents, after the SnapShot.  Default value is 5.
.INPUTS
VMWare SnapShot Object from Get-SnapShot
VMware.VimAutomation.ViCore.Types.V1.VM.Snapshot
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.SnapShot.Data
.EXAMPLE
Obtain Snapshot Data from one VM:
Get-SnapShot -VM Guest01 | Get-SnapShotData
.EXAMPLE
Obtain Snapshot Data from multiple VMs, using the Get-SnapShotData alias, placing the object into a variable:
$MyVar = Get-Snapshot -VM *WEB* | gsd
.EXAMPLE
Obtain Snapshot Data from one VM, increasing the VIEvent window to 31 seconds by setting both the PreSeconds and PostSeconds parameters to 15:
Get-SnapShot -VM Guest01 | Get-SnapShotData -PreSeconds 15 -PostSeconds 15
#>
function Get-SnapShotData
{
	[CmdLetBinding()]
	[Alias("gsd")]

	param
	(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[VMware.VimAutomation.ViCore.Types.V1.VM.Snapshot[]]$Name,

		[Parameter(Mandatory = $false)]
		[ValidateRange(0,30)]
		[Int]$PreSeconds = 5,

		[Parameter(Mandatory = $false)]
		[ValidateRange(0,30)]
		[Int]$PostSeconds = 5
	)

	Process
	{
		foreach ($snap in $name)
		{
			<#
			Create a 10 second window of VI events because snapshot
			creation time can skew a few seconds from the log entry
			#>
			$presec = $snap.Created.AddSeconds(( - $preseconds))
			$postsec = $snap.Created.AddSeconds(( + $postseconds))
			$files = ((Get-VM -Name $snap.VM).ExtensionData.LayoutEx.File |
				Where-Object {$_.type -match "snapshotData"}).Name
			$evnts = Get-VIEvent -Entity $snap.VM.Name -Start $presec -Finish $postsec
			$entry = $evnts |
				Where-Object {$_.FullFormattedMessage -match $ffm }
			$loopobj = [pscustomobject]@{
				VM = $snap.VM.Name
				SnapName = $snap.Name
				Description = $snap.Description
				SizeGB = [math]::Round($snap.SizeGB, 3)
				UserName = $entry.UserName
				Created = $snap.Created
				File = $files
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.SnapShot.Data')
			$loopobj
		}
	}
}

<#
.SYNOPSIS
Retrieves assigned tag information for VM or VMHost
.DESCRIPTION
Retrieves assigned tag information for VM or VMHost, returning an object of
Entity, Name, Category, and Description.
.PARAMETER VM
VMWare PowerCLI VM Object from Get-VM
VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.EXAMPLE
Retrieve tag information of one VM, returning the object into a variable:
$myVar = Get-VM -Name SYS01 | Get-TagInfo
.EXAMPLE
Retrieve tag information of two VMs, returning the object into a variable:
$myVar = Get-VM -Name SYS02 , SYS03 | Get-TagInfo
.EXAMPLE
Retrieve tag information of one VMHost, returning the object into a variable:
$myVar = Get-VMHost -Name ESX01 | Get-TagInfo
.EXAMPLE
Retrieve tag information of two VMHosts, returning the object into a variable:
$myVar = Get-VMHost -Name ESX02 , ESX03 | Get-TagInfo
.INPUTS
VMWare PowerCLI VM or VMHost Object from Get-VM or Get-VMHost:
VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.Tag.Assignment.Info
#>

function Get-TagInfo
{
    [CmdletBinding()]

    param
    (
        [Parameter(ParameterSetName = "VM" , ValueFromPipeline = $true)]
                [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $VM,

        [Parameter(ParameterSetName = "VMHost" , ValueFromPipeline = $true)]
                [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Begin
    {
        $nd = @{Tag = @{Name = "No Tag Assignment Found"}}
    }

    Process
    {
        Function MakeObj
        {
            param($vdata,$tdata)
            $lo = [PSCustomObject]@{
                Entity = $vdata
                Name = $tdata.Tag.Name
                Category = $tdata.Tag.Category.Name
                Description = $tdata.Tag.Description
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.Tag.Assignment.Info')
            $lo
        }

        Function GetTagInfo($ces)
        {
            foreach ($ce in $ces)
            {
                $il = $ce | Get-TagAssignment
                if($il)
                {
                    foreach ($i in $il)
                    {
                        MakeObj -vdata $ce.Name.ToSTring() -tdata $i
                    }
                }
                else
                {
                    MakeObj -vdata $ce.Name.ToSTring() -tdata $nd
                }
            }
        }

        if ($vm)
        {
            GetTagInfo($vm)
        }

        elseif ($vmhost)
        {
            GetTagInfo($vmhost)
        }
    }
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
        if(!$DefaultCisServers)
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

<#
.SYNOPSIS
Retrieves installed VIBs from VMHost(s).
.DESCRIPTION
By default returns an object of HostName, Name, ID, Vendor and Installed(Date) for all installed VIBs from VMHost(s).
Alternatively returns an object of multiple properties, for up to ten particular VIBs.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER Name
Optional.  Provides more detailed information for up to ten particular VIBs.
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.VIBinfo
.EXAMPLE
Retrieve all VIBs from two VMHosts, storing the results into a variable:
$MyVar = Get-VMHost -Name ESX01 , ESX02 | Get-VIB
.EXAMPLE
Retrieve two specific VIBs from one VMHost, storing the results into a variable:
$MyVar = Get-VMHost -Name ESX03 | Get-VIB -Name vsan , vmkfcoe
#>
function Get-VIB
{
    [CmdletBinding()]
    param
    (
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory = $false)]
        [ValidateCount(1,10)]
        [string[]]$Name
	)

    process
    {
        Function allvib
        {
            foreach ($vmh in $VMHost)
            {
                $c2 = Get-EsxCli -V2 -VMHost $vmh
                $v2 = $c2.software.vib.list.Invoke()
                foreach ($v in $v2)
                {
                    $lo = [pscustomobject]@{
                        HostName = $vmh.Name
                        Name = $v.Name
                        ID = $v.ID
                        Vendor = $v.Vendor
                        Installed = $v.InstallDate
                    }
                    $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VIBinfo')
                    $lo
                }
            }
        }

        Function onevib
        {
            foreach ($vmh in $VMHost)
            {
                $c2 = Get-EsxCli -V2 -VMHost $vmh
                foreach ($n in $name)
                {
                    $t1 = $c2.software.vib.get.CreateArgs()
                    $t1.vibname = $n
                    $v2 = $c2.software.vib.get.Invoke($t1)
                    $v2 |
                        Add-Member -Type NoteProperty -Name HostName -Value $vmh.name
                    $v2.PSObject.TypeNames.Insert(0,'SupSkiFun.VIBinfo')
                    $v2
                    $v2.clear()
                }
            }
        }

        if ($VMHost -and  !$Name)
        {
            allvib
        }
        elseif ($VMHost -and $Name)
        {
            onevib
        }
        else
        {
            Write-Output "Pipe in VMHost or Enter Vib Name.  Try:  help Get-VIB -full"
        }
    }
}

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
Obtain SCSI Paths on VMHost(s)
.DESCRIPTION
Returns an object of CanonicalName, RuntimeName, LunType, Vendor, CapacityGB, MultipathPolicy,
HostName, LUNPath, State, Working, Preferred and SanID from VMHosts.
.PARAMETER VMHost
Enter or Pipe one or more VMHosts.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.LUNPathInfo
.EXAMPLE
Obtain LUN/PATH information for one VMHost:
Get-VMHostScsiPath -VMHost ESX01
.EXAMPLE
Obtain LUN/PATH information for all VMHosts in a cluster, using the Get-VMHostScsiPath alias,
returning the output object into a variable:
$MyVar = Get-VMHost * -Location CLUSTER01 | gvsp
#>
function Get-VMHostScsiPath
{
    [CmdletBinding()]
    [Alias("gvsp")]
    param
    (
        [Parameter(Mandatory=$true,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage = "Enter one or more VMHost names"
		)]
		[Alias("Name")]
        [string[]]$VMHost
	)

    Process
    {
        foreach ($vmh in $VMHost)
		{
			$luns = Get-ScsiLun -VMHost $vmh -LunType disk |
				Where-Object {$_.canonicalname -notmatch "mpx"}
			foreach ($lun in $luns)
			{
				$paths = Get-ScsiLunPath -ScsiLun $lun
				foreach ($path in $paths)
				{
					$loopobj = [pscustomobject]@{
						CanonicalName = $lun.CanonicalName
						RuntimeName = $lun.RuntimeName
						LunType = $lun.LunType
						Vendor = $lun.Vendor
						CapacityGB = $lun.CapacityGB
						MultipathPolicy = $lun.MultipathPolicy
						HostName = $lun.VMHost
						LUNPath = $path.ExtensionData.Name
						State = $path.State
						Working = $path.ExtensionData.IsWorkingPath
						Preferred = $path.Preferred
						SanId = $path.SanId
					}
					$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.LUNPathInfo')
					$loopobj
				}
			}
		}
    }
}

<#
.SYNOPSIS
Retrieves Up Time for VMHost(s).
.DESCRIPTION
Returns object of VMHost, and Up Time in Days, Hours and Minutes.
Requires input from Get-VMHost.  Alias = gvut
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.Uptime
.EXAMPLE
Retrieve uptime from a host:
Get-VMHost -Name ESX01 | Get-VMHostUpTime
.EXAMPLE
Retrieve uptime from two hosts, placing object into a variable:
$MyObj = Get-VMHost -Name ESX03 , ESX04 | Get-VMHostUpTime
.EXAMPLE
Retrieve uptime from all cluster hosts, using the Get-VMHostUpTime alias, placing object into a variable:
$MyObj = Get-VMHost -Location Cluster07 | gvut
#>
function Get-VMHostUpTime
{
    [CmdletBinding()]
    [Alias("gvut")]
    param
    (
		[Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost
	)

	Begin
	{
		$errmsg = "VMHost Object Required.  Try:  Help Get-VMHostUptime -full"
	}

    Process
    {
		If(!($vmhost))
		{
			Write-Output $errmsg
			break
		}

		foreach ($vmh in $vmhost)
		{
			$gupt = [timespan]::FromSeconds($vmh.ExtensionData.Summary.QuickStats.Uptime)
			$loopobj = [pscustomobject]@{
				HostName = $vmh
				Days = $gupt.days
				Hours = $gupt.hours
				Minutes = $gupt.minutes
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.Uptime')
			$loopobj
			$gupt = $null
		}
	}
}

<#
.SYNOPSIS
Obtains WWN from specified VMHost
.DESCRIPTION
Returns an object of World Wide Numbers from VMHost Fibre Channel HBAs
.PARAMETER VMHost
VMHost Name(s) or VMHost Object from Vmware.PowerCLI
.INPUTS
VMHost Name(s) or VMHost Object from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.WWN
.EXAMPLE
Obtain World Wide Numbers from one VMHost:
Get-VMHostWWN -VMHost ESX01
.EXAMPLE
Obtain World Wide Numbers from two VMHosts using the Get-VMHostWWN alias:
gvw -VMHost ESX03, ESX04
	OR
Get-VMHost ESX03, ESX04 | gvw
.EXAMPLE
Return an obect of WWNs from all VMHosts in a Cluster into a Variable:
$MyVar = Get-VMHost -Location Cluster07 | Get-VMHostWWN
#>
function Get-VMHostWWN
{
    [CmdletBinding()]
    [Alias("gvw")]
    param
    (
		[Parameter(ValueFromPipeline = $true,
		ValueFromPipelineByPropertyName = $true
		)]
        [string[]]$VMHost
	)

    Process
    {
		foreach ($vmh in $VMHost)
		{
			$hbainfo = Get-VMHostHba -VMHost $vmh -Type FibreChannel
			foreach ($hba in $hbainfo)
			{
				$loopobj = [pscustomobject]@{
					HostName = $vmh
					Adapter = $hba.Device
					WWN = "{0:X}" -f $hba.PortWorldWideName
				}
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.WWN')
				$loopobj
			}
		}
    }
}

<#
.SYNOPSIS
Returns IP Address(es) of VMs
.DESCRIPTION
Returns an object of VM Names and IP Address(es)
.PARAMETER VM
Names of VMs or Piped input from VMWare PowerCLI Get-VM cmdlet.  Alias Name.
.OUTPUTS
[pscustomobject] SupSkiFun.VMIPInfo
.EXAMPLE
Return IP(s) from two VMs:
Get-VMIP -VM SERVER07 , SYSTEM09
.EXAMPLE
Return IP(s) from multiple VMS, placing the returned object into a variable:
$MyVar = Get-VM -Name LAB0* | Get-VMIP
#>
function Get-VMIP
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[Alias("Name")]
        [string[]]$VM
	)

	Process
    {
		try
		{
			Foreach ($v in $vm)
			{
				$vinfo = Get-VM -Name $v -ErrorAction SilentlyContinue -ErrorVariable err
				if (!($err))
				{
					$loopobj = [pscustomobject]@{
						Name = $vinfo.Name
						IP = $vinfo.Guest.IPAddress
					}
				}
				else
				{
					$loopobj = [pscustomobject]@{
						Name = $v
						IP = $err.exception.ToString().Split("`t")[3]
					}
				}
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VMIPInfo')
				$loopobj
 			}
		}
		catch
		{
			Write-Error "problem" | Out-Null
		}
    }
}

<#
.SYNOPSIS
Retrieves VM process information
.DESCRIPTION
Retrieves VM process information, returning an object of VM, PowerState,
DisplayName, WorldID, VMXCartelID, ConfigFile, UUID, and VMHost.
.PARAMETER VM
Output from VMWare PowerCLI Get-VM.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.EXAMPLE
Retrieve process information of one VM, returning the object into a variable:
$myVar = Get-VM -Name SYS01 | Get-VMpid
.EXAMPLE
Retrieve process information of two VMs, returning the object into a variable:
$myVar = Get-VM -Name SYS02 , SYS03 | Get-VMpid
.INPUTS
VMWare PowerCLI VM from Get-VM:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.OUTPUTS
[pscustomobject] SupSkiFun.VM.PID.Info
.LINK
Stop-VMpid
#>
function Get-VMpid
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM
    )

    Process
    {
        Function MakeObj
        {
            param($vdata,$resdata)

            $lo = [PSCustomObject]@{
                VM = $vdata.Name
                PowerState = $vdata.PowerState
                DisplayName = $resdata.DisplayName
                WorldID = $resdata.WorldID
                VMXCartelID = $resdata.VMXCartelID
                ConfigFile = $resdata.ConfigFile
                UUID = $resdata.UUID
                VMHost = $vdata.VMHost.Name
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VM.PID.Info')
            $lo
        }

        foreach ($v in $vm)
        {
            $x2 = Get-EsxCli -V2 -VMHost $v.vmhost.Name
            $r1 = $x2.vm.process.list.Invoke() |
                Where-Object -Property DisplayName -eq $v.Name
            MakeObj -vdata $v -resdata $r1
        }
    }
}

<#
.Synopsis
Lists VMs with outdated VM Tools.  See Examples.
.DESCRIPTION
By default returns an object of PoweredOn VM(s) with outdated tools.  Or, if specified with -List, returns
an object of VM(s) with outdated tools consisting of Name, Tools Status, Tools Version and OS.
Must be used in conjunction with Get-VM.  See Examples.
.PARAMETER VM
Pipe VM(s) using Get-VM.  See Examples.  Auto-Generated SYNTAX (above) is not quite accurate.
.PARAMETER List
If specified returns an object of Name, Tools Status, Tools Version and OS of PoweredOm VM(s) with outdated tools.
If NOT specified (default) Returns an object of PoweredOn VM(s) with outdated tools.
.INPUTS
VMware VM Object from Get-VM
.OUTPUTS
VMware VM Object OR Custom PSObject SupSkiFun.VmToolInfo
.EXAMPLE
Query for one VM with outdated VM tools with VM object as output:
Get-VM -name VM01 | Get-VMToolOutdated
.EXAMPLE
Query for VMs with outdated VM tools by cluster, returning an object in list form:
Get-VM -location Cluster01 | Get-VMToolOutdated -List
.EXAMPLE
Query for VMs with outdated VM tools by DataStore placing object into a variable:
$MyVar = Get-VM -datastore DataStore01 | Get-VMToolOutdated
.EXAMPLE
Query all VMs for outdated VM tools using the Get-VMToolOutdated alias, placing object into a variable.
$MyVar = Get-VM *  | gvto
#>
function Get-VMToolOutdated
{
	[CmdletBinding()]
	[Alias("gvto")]
	param
	(
		[Parameter(ValueFromPipeline=$true)]
		[Alias("VirtualMachine")]
		[psobject[]]$VM,
		[switch]$List
	)

	Process
	{
		foreach ($info in $vm)
		{
			if($info |
				Where-Object {$info.powerstate -notmatch 'off' -and $info.ExtensionData.guest.toolsstatus -notmatch 'ok'})
			{
				if($list)
				{
					$loopobj=[pscustomobject]@{
						Name=$info.name
						Status=$info.ExtensionData.guest.ToolsStatus
						Version=$info.ExtensionData.guest.ToolsVersion.ToDecimal($null)
						OS=$info.guest.OSFullName
					}
					$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VmToolInfo')
					$loopobj
				}
				else
				{
					$info
				}
			}
		}
	}
}

<#
.Synopsis
Returns total size of VM on a Data Store.
.DESCRIPTION
Returns an object of total Datastore Consumption of a VM on a DataStore.
Includes all files: .log, .vmx, .vswp, .vmdk, etc. in the computation.  Excludes ".rdmp" files (RDMs).
Note that a thin provisioned disk may reflect less disk space than is actually provisioned.
Default output is a hostname with total size.  Accepts PipeLine input from Get-VM or CSV file.
Use the -full parameter to include all file names and thier values as an embedded object.
Optimally used with Get-VM, returning information into an object.  See Example 4.
.PARAMETER vm
Mandatory.  Enter vm name(s), use a variable, or pipe data in.
.PARAMETER full
Optional.  Use to return all file names as an embedded object, along with the regular output.
.EXAMPLE
Displays VM name and total size:
Get-VMTotalSize -VM MyVm01
.EXAMPLE
Displays VM name and total size along with each file name and values:
Get-VMTotalSize -VM MyVm02 -full
.EXAMPLE
Displays VM names and total sizes via pipe from Get-VM:
Get-Vm MyVm* | Get-VMTotalSize
.EXAMPLE
Places VM names, files and total size into an object using Get-VM piped to the Get-VMTotalSize alias:
$MyObj = Get-VM *3* | gvts -full
#>
function Get-VMTotalSize
{
    [CmdletBinding()]
	[Alias("gvts")]
    param
    (
        [Parameter(Mandatory=$true,
					HelpMessage="Enter one or more VM names or pipe from file",
					ValueFromPipelineByPropertyName=$true)]
		[Alias("Name","ComputerName")]
        [string[]]$VM,
        [switch]$full
	)

	Process
	{
		$covm = get-vm $vm
		Write-Verbose "Value of `$covm: $covm"
		foreach ($v in $covm)
		{
			Write-Verbose "Value of `$v in loop: $v"
			#$sumsize=$v.ExtensionData.layoutex.file.size |
			$sumdisks = $v.ExtensionData.layoutex.file |
						Where-object {$_.name -notmatch "rdmp"}
			$sumsize = $sumdisks.size |Measure-Object -Sum |
						Select-Object @{n="SizeGB";e={"{0:N3}" -f	($_.sum /1gb)}}
			if($full)
			{
				$loopobj = [pscustomobject]@{
						VMName=$v.Name
						VMSizeGB=$sumsize.sizegb
						Files=$v.ExtensionData.layoutex.file
							}
			} else
			{
				$loopobj = [pscustomobject]@{
						VMName=$v.Name
						SizeGB=$sumsize.sizegb
				}
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VMsize')
			$loopobj
		}
	}
}

<#
.SYNOPSIS
Retrieves alarms from a Virtual Center
.DESCRIPTION
Returns an object of alarms from Virtual Center consisiting of:
Name, ObjectType, AlarmType, Description, Key, Status, Acknowledged, DateTime
Optimally used as shown in Example 2.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.AlarmInfo
.EXAMPLE
Output all alerts onto screen:
Get-VsphereAlarm
.EXAMPLE
Return object into a variable, using the Get-VSphereAlarm alias:
$MyVar = gvsa
#>
function Get-VSphereAlarm
{
    [CmdletBinding()]
    [Alias("gvsa")]
    param()
	Begin
	{
		$servi = Get-View ServiceInstance
		$rootf = Get-View -Id $servi.Content.RootFolder
		$alrms = $rootf.TriggeredAlarmState
	}
	Process
	{
		foreach ($alrm in $alrms)
		{
			$alrmtype = $alrm.Entity.Type
			switch ($alrmtype)
			{
				"HostSystem" {$objname = (Get-VMHost -Id $alrm.Entity).Name ; break}
				"VirtualMachine"{$objname = (Get-VM -Id $alrm.Entity).Name ; break}
				"DataStore" {$objname = (Get-DataStore -Id $alrm.Entity).Name ; break}
				"Folder" {$objname = (Get-Folder -Id $alrm.Entity).Name ; break}
				default {$objname = "Unknown"}
			}
			$alrminfo = get-view -Id $alrm.alarm
			$loopobj = [pscustomobject]@{
					Name = $objname
					ObjectType = $alrmtype
					AlarmType = $alrminfo.Info.Name
					Description = $alrminfo.Info.Description
					Key = $alrm.Key
					Status = $alrm.OverallStatus
					Acknowledged = $alrm.Acknowledged
					DateTime = $alrm.time
 			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.AlarmInfo')
			$loopobj
		}
	}
}

<#
.SYNOPSIS
Returns Alarm Enabled Status from VMs, VMHosts and / or Clusters
.DESCRIPTION
Returns Alarm Enabled Status from VMs, VMHosts and / or Clusters via an object of
Name, Enabled, and Type.  Requires VMs, VMHosts and / or Cluster objects to be piped in.
.PARAMETER VM
Output from VMWare PowerCLI Get-VM
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER Cluster
Output from VMWare PowerCLI Get-Cluster
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster]
.INPUTS
VMWare PowerCLI VM, VMHost and / or Cluster Object from Get-VM, Get-VMHost and / or Get-Cluster:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster]
.OUTPUTS
 PSCustomObject SupSkiFun.Alarm.Config
.EXAMPLE
Return information from several VMs:
Get-VM -Name QA* | Get-VSphereAlarmConfig
.EXAMPLE
Return information from one VMHost:
Get-VMHost -Name ESX01 | Get-VSphereAlarmConfig
.EXAMPLE
Return information from one Cluster using the Get-VsphereAlarmConfig alias:
Get-Cluster -Name CLUS01 | gvsac
.EXAMPLE
Return information from multiple VMHosts, returning the object into a variable:
$MyVar = Get-VMHost -Name ESX4* | Get-VsphereAlarmConfig
.EXAMPLE
Return information from all VMHosts and Clusters in the connected Virtual Center:
$host = Get-VMHost -Name *
$clus = Get-Cluster -Name *
$MyVar = Get-VSphereAlarmConfig -VMHost $host -Cluster $clus
.LINK
Set-VSphereAlarmConfig
#>
function Get-VSphereAlarmConfig
{
    [CmdletBinding()]
    [Alias("gvsac")]
    param
    (
        [Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $VM ,

        [Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost ,

        [Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster[]] $Cluster
    )

    Begin
    {
        $errmsg = "VM, VMHost, and / or Cluster Object Required. Try: Help Get-VSphereAlarmConfig -full"
    }

    Process
    {
        If( -not ($vm -or $vmhost -or $cluster))
        {
            Write-Output $errmsg
            break
        }

        If ($vm)
        {
            foreach ($obj in $vm)
            {
                $lo = [Vclass]::MakeGVSACObj($obj , "VM")
                $lo
            }
        }

        If ($vmhost)
        {
            foreach ($obj in $vmhost)
            {
                $lo = [Vclass]::MakeGVSACObj($obj , "VMHost")
                $lo
            }
        }

        If ($cluster)
        {
            foreach ($obj in $cluster)
            {
                $lo = [Vclass]::MakeGVSACObj($obj , "Cluster")
                $lo
            }
        }
    }
}

<#
.SYNOPSIS
Obtain VSphere License(s)
.DESCRIPTION
Obtain VSphere License(s)
.EXAMPLE
Prints license information to the screen:
Get-VSphereLicense
.EXAMPLE
Returns an Object of License Information into a Variable using the Get-VSphereLicense alias:
$MyVar = gvsl
#>
function Get-VSphereLicense
{
    [CmdletBinding()]
    [Alias("gvsl")]
    param()

    Process
    {
		$srvins = Get-View ServiceInstance -Server $DefaultVIServer
		$licmgr = Get-View -Id $srvins.Content.LicenseManager
		$licmgr.UpdateViewData()
		$licmgr.Licenses.Where({$_.EditionKey -notmatch "eval"}) |
			Select-Object * -ExcludeProperty Properties, Labels
	}
}

<#
.SYNOPSIS
Lists VCenter Logon Sessions
.DESCRIPTION
Lists VCenter Logon Sessions
.EXAMPLE
Output to screen:
Get-VSphereSession
.EXAMPLE
Ouput to Variable:
 $MyVar = Get-VSphereSession
#>
function Get-VSphereSession
{
	(Get-View $DefaultViserver.ExtensionData.Client.ServiceContent.SessionManager).SessionList
}

<#
.SYNOPSIS
Returns an object reflecting the status of Vsphere Clusters and VMHosts.
.DESCRIPTION
By default (i.e. with no parameters), returns an object of Name, Type, Overall Status and Config Status of
all Clusters and VMHosts.  Specific Cluster(s) and/or VMHosts(s) can be specified with parameters.
See Parameters and Examples.  Most common use is Example 4.  Non-green statuses return error(s) within Config.
.PARAMETER Cluster
Optional.  If defined, returns only the Cluster(s) specified.  Can be combined with VMHost.
.PARAMETER  VMHost
Optional.  If defined, returns only the VMHost(s) specified.  Can be combined with Cluster.
.OUTPUTS
Custom PSObject SupSkiFun.VSphereStatus
.EXAMPLE
Query for one Cluster
Get-VSphereStatus -Cluster MyCluster01
.EXAMPLE
Query for two VMHosts
Get-VSphereStatus -VMHost MyESX01 , MyESX02
.EXAMPLE
Query for multiple Clusters and VMHosts placing the object into a variable.
$myVar =  Get-VSphereStatus -Cluster *PROD -VMHost *n3*
.EXAMPLE
Query for all Clusters and VMHosts using the Get-VSphereStatus alias, placing the object into a variable.
$info = gvss
#>
function Get-VSphereStatus
{
    [CmdletBinding()]
    [Alias("gvss")]

    param
    (
        [Parameter()]
        [string[]]$Cluster = "*" ,
        [Parameter()]
        [string[]]$VMHost = "*"
	)
    Begin
	{
		if($cluster -notcontains "*" -and $vmhost -contains "*")
		{
			$cluses = Get-Cluster -Name $Cluster
			$vmhes = $null
		}
		elseif($cluster -contains "*" -and $vmhost -notcontains "*")
		{
			$cluses = $null
			$vmhes = Get-VMHost -Name $VMHost
		}
		else
		{
			$cluses = Get-Cluster -Name $Cluster
			$vmhes = Get-VMHost -Name $VMHost
		}
	}

	Process
    {
		foreach ($clus in $cluses)
		{
			$loopobj = [pscustomobject]@{
				Name=$clus.ExtensionData.Name
				Type = "cluster"
				Overall=$clus.ExtensionData.OverallStatus
				Config=$clus.ExtensionData.ConfigStatus
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VSphereStatus')
			$loopobj
		}

		foreach ($vmh in $vmhes)
		{
			$cstatus = $vmh.ExtensionData.ConfigStatus
			if ($cstatus -notmatch "green")
			{
				$config = $vmh.ExtensionData.ConfigIssue.fullformattedmessage
			}
			else
			{
				$config = $cstatus
			}
			$loopobj = [pscustomobject]@{
				Name=$vmh.ExtensionData.Name
				Type = "vmhost"
				Overall = $vmh.ExtensionData.OverallStatus
				Config = $config
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VSphereStatus')
			$loopobj
			$config = $null
		}
	}
}

<#
.SYNOPSIS
Retrieves status and settings of the WBEM Process from VMHost(s).
.DESCRIPTION
Returns an object containing WBEM Process settings, status, and HostName.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost. See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.WBEM.Info
.EXAMPLE
Retrieve WBEM Process information from two VMHosts, storing the object in a variable:
$MyVar = Get-VMHost -Name ESX01 , ESX02 | Get-WBEMState
.EXAMPLE
Retrieve WBEM Process information from all VMHosts in a cluster, storing the object in a variable:
$MyVar = Get-VMHost -Location Cluster15 | Get-WBEMState
.LINK
Set-WBEMState
#>

Function Get-WBEMState
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Process
    {
        ForEach ($vmh in $VMHost)
        {
            $x2 = Get-EsxCli -V2 -VMHost $vmh
            $v2 = $x2.system.wbem.get.Invoke()
            $v2 |
                Add-Member -Type NoteProperty -Name HostName -Value $vmh.name
            $v2.PSObject.TypeNames.Insert(0,'SupSkiFun.WBEM.Info')
            $v2
        }
    }
}

<#
.SYNOPSIS
Installs an image profile from a local depot onto a VMHost with ESXi already installed.
.DESCRIPTION
Replaces the installed image with the new image profile.  Will result in the removal of installed VIBs that don't match the profile.
System Should be in Maintenance Mode.  Use DryRun to test.  Read / Evaluate the returned object.  See Examples.
Returns an object of HostName, Message, RebootRequired, VIBSInstalled, VIBSRemoved, and VIBSSkipped.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER Depot
Full local server file path pointing to an offline bundle .zip file.  Example:
/vmfs/volumes/Datastore/Path/6.7/VMware-ESXi-6.7.0-Update1-11675023-HPE-Gen9plus-670.U1.10.4.0.19-Apr2019-depot.zip
.PARAMETER ImageProfile
Image Profile to Install.  Often found within <id>  </id> of metadata/vmware.xml in the *depot.zip file.
Example:  HPE-ESXi-6.7.0-Update1-Gen9plus-670.U1.10.4.0.19
.PARAMETER DryRun
If specified, performs a dry-run only. Reports the VIB-level operations that would be performed, but changes nothing.
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.ESXi.Info
.EXAMPLE
Perform a DryRun (Test) Install of an image onto one VMHost, returning an object into a variable:
$d = '/vmfs/volumes/Datastore/Path/6.7/VMware-ESXi-6.7.0-Update1-11675023-HPE-Gen9plus-670.U1.10.4.0.19-Apr2019-depot.zip'
$p = 'HPE-ESXi-6.7.0-Update1-Gen9plus-670.U1.10.4.0.19'
$MyVar = Get-VMHost -Name ESX01 | Install-ESXi -DryRun
.EXAMPLE
Install image onto one VMHost, returning an object into a variable:
$d = '/vmfs/volumes/Datastore/Path/6.7/VMware-ESXi-6.7.0-Update1-11675023-HPE-Gen9plus-670.U1.10.4.0.19-Apr2019-depot.zip'
$p = 'HPE-ESXi-6.7.0-Update1-Gen9plus-670.U1.10.4.0.19'
$MyVar = Get-VMHost -Name ESX02 | Install-ESXi
.EXAMPLE
Install image onto two VMHosts, returning an object into a variable:
$d = '/vmfs/volumes/Datastore/Path/6.7/VMware-ESXi-6.7.0-Update1-11675023-HPE-Gen9plus-670.U1.10.4.0.19-Apr2019-depot.zip'
$p = 'HPE-ESXi-6.7.0-Update1-Gen9plus-670.U1.10.4.0.19'
$MyVar = Get-VMHost -Name ESX03 , ESX04 | Install-ESXi
#>
function Install-ESXi
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'high')]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost,

        [Parameter(Mandatory = $true)]
        [string] $Depot,

        [Parameter(Mandatory = $true)]
        [string] $ImageProfile,

        [switch] $DryRun
    )

    Process
    {
        Function MakeObj
        {
            param($vhdata,$resdata)

            $lo = [PSCustomObject]@{
                HostName = $vhdata
                Message = $resdata.Message
                RebootRequired = $resdata.RebootRequired
                VIBsInstalled = $resdata.VIBsInstalled
                VIBsRemoved = $resdata.VIBsRemoved
                VIBsSkipped = $resdata.VIBsSkipped
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.ESXi.Info')
            $lo
        }

        foreach ($vmh in $VMHost)
        {
            if($PSCmdlet.ShouldProcess("$vmh using $imageprofile"))
            {
                $xcli = Get-EsxCli -v2 -VMHost $vmh
                $hash = $xcli.software.profile.install.CreateArgs()
                $hash.depot = $depot
                $hash.profile = $imageprofile
                $hash.oktoremove = $true
                if ($dryrun)
                {
                    $hash.dryrun = $true
                }
                $resp = $xcli.software.profile.install.Invoke($hash)
                MakeObj -vhdata $vmh.Name -resdata $resp
            }
        }
    }
}

<#
.SYNOPSIS
Installs VIB(s) on VMHost(s).
.DESCRIPTION
Installs VIB(s) on VMHost(s) and returns an object of HostName, Message, RebootRequired, VIBSInstalled, VIBSRemoved, and VIBSSkipped.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER URL
URL(s) for the VIB(s).  https://www.example.com/VMware_bootbank_vsanhealth_6.5.0-2.57.9183449.vib , https://www.example.com/NetAppNasPlugin.v23.vib
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.VIBinfo
.EXAMPLE
Install one VIB to one VMHost, returning an object into a variable:
$u = 'https://www.example.com/VMware_bootbank_vsanhealth_6.5.0-2.57.9183449.vib'
$MyVar = Get-VMHost -Name ESX02 | Install-VIB -URL $u
.EXAMPLE
Install two VIBs to two VMHosts, returning an object into a variable:
$uu = 'https://www.example.com/VMware_bootbank_vsanhealth_6.5.0-2.57.9183449.vib' , 'https://www.example.com/NetAppNasPlugin.v23.vib'
$MyVar = Get-VMHost -Name ESX03 , ESX04 | Install-VIB -URL $uu
#>
function Install-VIB
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'high')]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory = $true)]
        [string[]]$URL
    )

    Process
    {
        Function MakeObj
        {
            param($vhdata,$resdata)

            $lo = [PSCustomObject]@{
                HostName = $vhdata
                Message = $resdata.Message
                RebootRequired = $resdata.RebootRequired
                VIBsInstalled = $resdata.VIBsInstalled
                VIBsRemoved = $resdata.VIBsRemoved
                VIBsSkipped = $resdata.VIBsSkipped
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VIB.Info')
            $lo
        }

        $cible = @{viburl = $URL}
        foreach ($vmh in $VMHost)
        {
            if($PSCmdlet.ShouldProcess("$vmh installing $URL"))
            {
                $xcli = Get-EsxCli -v2 -VMHost $vmh
                $resp = $xcli.software.vib.install.invoke($cible)
                MakeObj -vhdata $vmh.Name -resdata $resp
            }
        }
    }
}

<#
.SYNOPSIS
Consolidates VM disk(s)
.DESCRIPTION
Consolidates VM disks, returning last 7 log entries.  Skips processing and reports if
a specified VM does not require consolidation.	Reports error if VM not found.
.PARAMETER VM
Mandatory.  Enter one or more comma seperated names.  Optionally pipe from Get-VM or CSV.\
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.Consolidation
.EXAMPLE
Consolidates one VM:
Invoke-VMConsolidation -VM Guest01
.EXAMPLE
Consolidates two VMs:
Invoke-VMConsolidation -VM Guest03 , Guest04
.EXAMPLE
Consolidates all VMs on Cluster 77, bypassing confirmation, using the Invoke-VMConsolidation alias:
Get-VM -Location Cluster77 | ivc -confirm:$false
#>
function Invoke-VMConsolidation
{
    [CmdletBinding(SupportsShouldProcess=$true,
					ConfirmImpact='high'
	)]
    [Alias("ivc")]
    param
    (
        [Parameter(Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			HelpMessage = "Enter one or more VM names"
		)]
		[Alias("Name")]
        [string[]]$VM
	)

    Begin
	{
		$errtxt = "Error"
	}

	Process
    {
        foreach ($va in $vm)
		{
			if($PSCmdlet.ShouldProcess("$va"))
			{
				try
				{
					$vtp = Get-VM -Name $va	-ErrorVariable err -ErrorAction SilentlyContinue
					$vtps = $vtp.ExtensionData.Runtime.ConsolidationNeeded
					If($err)
					{
						$loopobj = [pscustomobject]@{
							Name = $va
							DateTime = $errtxt
							UserName = $errtxt
							Message	= $err.exception.ToString().split("`t")[3]
						}
						$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.Consolidation')
						$loopobj
					}
					elseif(!($vtps))
					{
						$loopobj = [pscustomobject]@{
							Name = $va
							DateTime = $errtxt
							UserName = $errtxt
							Message	= "Not processing $vtp because Consolidation Needed equals $vtps"
						}
						$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.Consolidation')
						$loopobj
					}
					else
					{
						$vtp.ExtensionData.ConsolidateVMDisks()
						$log = Get-VIEvent -Entity $vtp |
							Select-Object -Property CreatedTime , UserName , FullFormattedMessage -First 7
						foreach ($notch in $log)
						{
							$loopobj = [pscustomobject]@{
								Name = $va
								DateTime = $notch.CreatedTime.DateTime.Split(",",2)[1].trim()
								UserName = $notch.UserName
								Message	= $notch.FullFormattedMessage
							}
							$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.Consolidation')
							$loopobj
						}
					}
				}
				catch
				{
					Write-Error "problem" | Out-Null
				}
			}
		}
    }
}

<#
.SYNOPSIS
Rescans and Refreshes HBA(s)
.DESCRIPTION
Rescans and Refreshes HBA(s) for specified VMHosts(s) or Cluster(s). No Output by Default.
Either VMHost(s) or Cluster(s) need to be piped into Invoke-VMHostHBARescan.  See Examples.
.PARAMETER Cluster
Piped output of Get-Cluster from Vmware.PowerCLI
.PARAMETER VMHost
Piped output of Get-VMHost from Vmware.PowerCLI
.INPUTS
Results of Get-VMHost or Get-Cluster from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
None
.EXAMPLE
Rescans and Refreshes the HBAs on one ESX Host:
Get-VMHost -Name ESX12 | Invoke-VMHostHBARescan
.EXAMPLE
Rescans and Refreshes the HBAs on two ESX Hosts, using the Invoke-VMHostHBARescan alias:
Get-VMHost -Name ESX01 , ESX03 | ivhr
.EXAMPLE
Rescans and Refreshes the HBAs on all ESX Hosts in a Cluster:
Get-Cluster -Name PROD01 | Invoke-VMHostHBARescan
.NOTES
Alias ivhr.
Parameter Sets restrict to either Cluster input or VMHost input.  Not both.
#>

function Invoke-VMHostHBARescan
{
    [CmdletBinding()]
    [Alias("ivhr")]
    param
    (
        [Parameter(ParameterSetName="Cluster",
			ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster[]]$Cluster,

		[Parameter(ParameterSetName="VMHost",
			ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost
	)

	Process
    {
		if ($Cluster)
		{
			$vhs = Get-VMHost -Location $Cluster
			foreach ($vh in $vhs)
			{
				Get-VMHostStorage -VMHost $vh -RescanAllHba -Refresh |
                    Out-Null
            }
        }

		elseif ($vmhost)
		{
			foreach ($vmh in $vmhost)
			{
				Get-VMHostStorage -VMHost $vmh -RescanAllHba -Refresh |
					Out-Null
    		}
		}
    }
}

<#
.SYNOPSIS
Opens a Console Window on a VM.
.DESCRIPTION
Opens a Console Window on a VM.  Was written as an alternative to Open-VMConsoleWindow when
Open-VMConsoleWindow was not functioning correctly after a Virtual Center upgrade.
.PARAMETER VM
Output from VMWare PowerCLI Get-VM.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.INPUTS
VMWare PowerCLI VM from Get-VM:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.EXAMPLE
Open a Console Window on a VM.
Get-VM -Name Server01 | Open-Console
.EXAMPLE
Open a Console Window on multiple VMs.
Get-VM -Name Test* | Open-Console
#>
Function Open-Console
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $VM
    )

    Begin
    {
        $modn = 'VMware.VimAutomation.Core'
        $modb = (Get-Module -Name $modn -ListAvailable)[0].ModuleBase
        $vexe = "$($modb)\net45\VMware Remote Console\vmrc.exe"
    }

    Process
    {
        foreach ($v in $vm)
        {
            $mkst = $v.ExtensionData.AcquireMksTicket()
            $parm = "vmrc://$($v.VMHost.Name):902/?mksticket=$($mkst.Ticket)&thumbprint=$($mkst.SslThumbPrint)&path=$($mkst.CfgFile)"
            & "$vexe" $parm
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

<#
.SYNOPSIS
Restarts Logging on a VMHOST
.DESCRIPTION
Restarts Logging (SysLog) on the VMHOST provided as an argument.
.PARAMETER VMHost
Mandatory.  Specify one on more ESX hosts.
.EXAMPLE
Restart-EsxLogging ESXHOST01
#>
function Restart-EsxLogging
{
	[CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'medium')]
    param
    (
        [Parameter(Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			HelpMessage = "Enter one or more ESX Host Names"
		)]
		[Alias("Name")]
        [string[]]$VMHost
	)

	Process
    {
		if($PSCmdlet.ShouldProcess($VMHost))
		{
			foreach ($vmh in $VMHost)
			{
				$reesxcli=get-esxcli -v2 -vmhost $vmh
				$reesxcli.system.syslog.reload.Invoke()
			}
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
function Set-PathSelectionPolicy
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
Sets PereniallyReserved value of RDMs from specified VMHost.
.DESCRIPTION
Sets PereniallyReserved value of RDMs from specified VMHost to either true or false.  Alias setpr.
Returns nothing.  Use Get-PereniallyReserved to query values.
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.PARAMETER State
Value of PereniallyReserved to set.  Either True or False
.INPUTS
VMWare PowerCLI VMHost Object from Get-VMHost:
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.EXAMPLE
Set all RDMs PereniallyReserved value to False for one VMHost:
Get-VMHost -Name ESXi17 | Set-PereniallyReserved -State False
.EXAMPLE
Set all RDMs PereniallyReserved value to True for all VMHosts in a Cluster using the Set-PereniallyReserved alias:
Get-VMHost -Name * -Location Cluster12 | setpr -State True
.LINK
Get-PereniallyReserved
#>

function Set-PereniallyReserved
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'high')]
    [Alias("setpr")]
    param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
		[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost,

        [Parameter(Mandatory = $true)]
        # [ValidateSet('true' , 'false' , IgnoreCase = $false)]
        [ValidateSet('True' , 'False')]
        [string] $State
    )

    Process
    {
        foreach ($vmh in $vmhost)
        {
            if ($pscmdlet.ShouldProcess("$vmh all RDMs to $state"))
            {
                $x2 = Get-EsxCli -VMHost $vmh -V2
                $vd = (Get-Datastore -VMHost $vmh |
                    Where-Object -Property Type -Match VMFS).ExtensionData.Info.Vmfs.Extent.Diskname
                $dl = $x2.storage.core.device.list.Invoke()
                # Remove DataStore LUNs, local MicroSd Card, Local Named, Non-Shared from the list.
                $dl = $dl |
                    Where-Object {
                        $_.Device -notin $vd -and $_.Device -notmatch "^mpx" -and $_.DisplayName -notmatch "Local" -and $_.IsSharedClusterwide -eq "true"
                    }
                foreach ($d in $dl)
                {
                    $z2 = $x2.storage.core.device.setconfig.CreateArgs()
                    $z2.device = $d.device
                    $z2.perenniallyreserved = $state.ToLower()
                    [void] $x2.storage.core.device.setconfig.Invoke($z2)
                }
            }
        }
    }
}

<#
.SYNOPSIS
Enables or Disables Alarms from VMs, VMHosts and / or Clusters
.DESCRIPTION
Enables or Disables Alarms from VMs, VMHosts and / or Clusters
Requires VMs, VMHosts and / or Cluster objects to be piped in.
.PARAMETER VM
Output from VMWare PowerCLI Get-VM
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER Cluster
Output from VMWare PowerCLI Get-Cluster
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster]
.PARAMETER State
Set for desired state of alarm; either Enabled or Disabled
.INPUTS
VMWare PowerCLI VM, VMHost and / or Cluster Object from Get-VM, Get-VMHost and / or Get-Cluster:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster]
.EXAMPLE
Disable alarms for two VMs:
Get-VM -Name Server01 , Server18 | Set-VSphereAlarmConfig -State Disabled
.EXAMPLE
Enable alarms for one VMHost:
Get-VMHost -Name ESX01 | Set-VSphereAlarmConfig -State Enabled
.EXAMPLE
Disable alarms for one Cluster:
Get-Cluster -Name CLUS01 | Set-VSphereAlarmConfig -State Disabled
.EXAMPLE
Enable alarms for multiple VMHosts bypassing confirmation prompt:
Get-VMHost -Name ESX4* | Set-VSphereAlarmConfig -State Enabled -Confirm:$false
.EXAMPLE
Disable alarms for all VMHosts and Clusters in the connected Virtual Center:
$host = Get-VMHost -Name *
$clus = Get-Cluster -Name *
Set-VSphereAlarmConfig -VMHost $host -Cluster $clus -State Disabled
.LINK
Get-VSphereAlarmConfig
#>
function Set-VSphereAlarmConfig
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'medium')]
    param
    (
        [Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $VM ,

        [Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost ,

        [Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster[]] $Cluster ,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Enabled" , "Disabled")]
        [string] $State
    )

    Begin
    {
        $errmsg = "VM, VMHost, and / or Cluster Object Required. Try: Help Set-VSphereAlarmConfig -full"
    }

    Process
    {
        If ( -not ($vm -or $vmhost -or $cluster))
        {
            Write-Output $errmsg
            break
        }
        Else
        {
            $alarmgr = Get-View AlarmManager
        }

        Function SetState
        {
            param($Item , $State)

            if ($state -eq "Enabled")
            {
                $state = $true
            }
            elseif ($state -eq "Disabled")
            {
                $state = $false
            }
            $alarmgr.EnableAlarmActions($item , $state)
        }

        If ($vm)
        {
            foreach ($v in $vm)
            {
                if($PSCmdlet.ShouldProcess("$v to $($state)"))
                {
                    SetState -Item $v.Extensiondata.MoRef -State $State
                }
            }
        }

        If ($vmhost)
        {
            foreach ($vmh in $vmhost)
            {
                if($PSCmdlet.ShouldProcess("$vmh to $($state)"))
                {
                    SetState -Item $vmh.Extensiondata.MoRef -State $State
                }
            }
        }

        If ($cluster)
        {
            foreach ($clu in $cluster)
            {
                if($PSCmdlet.ShouldProcess("$clu to $($state)"))
                {
                    SetState -Item $clu.Extensiondata.MoRef -State $State
                }

            }
        }
    }
}

<#
.SYNOPSIS
Enables or disables the WBEM service on VMHost(s).
.DESCRIPTION
Enables or disables the WBEM service on VMHost(s).  See Examples.
Returns no output.  Confirm settings with Get-WBEMState.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost. See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER Enabled
Switch. If specified, enables the WBEM service.
.PARAMETER Disabled
Switch. If specified, disables the WBEM service.
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.EXAMPLE
Enables the WBEM service on two VMHosts:
Get-VMHost -Name ESX01 , ESX02 | Set-WBEMState -Enabled
.EXAMPLE
Disables the WBEM service on two VMHosts:
Get-VMHost -Name ESX01 , ESX02 | Set-WBEMState -Disabled
.LINK
Get-WBEMState
#>

Function Set-WBEMState
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'high')]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost,

        [Parameter(ParameterSetName = "Enabled")]
        [switch] $Enabled,

        [Parameter(ParameterSetName = "Disabled")]
        [switch] $Disabled
    )

    Begin
    {
        <#
            $State maps switch to boolean.  $Setting clarifies Should Process message.
        #>
        If ($Enabled)
        {
            $State = $true
            $Setting = "Enabled"
        }
        elseif ($Disabled)
        {
            $State = $false
            $Setting = "Disabled"
        }
    }

    Process
    {
        ForEach ($vmh in $VMHost)
        {
            if ($pscmdlet.ShouldProcess("$vmh to $Setting"))
            {
                $x2 = Get-EsxCli -V2 -VMHost $vmh
                $y2 = $x2.system.wbem.set.CreateArgs()
                $y2.enable = $State
                [void] $x2.system.wbem.set.Invoke($y2)
            }
        }
    }
}

<#
.SYNOPSIS
Shows VMs with CD Drives Connected or configured to Start Connected
.DESCRIPTION
Returns an object of VM, Name, StartConnected, Connected, AllowGuestControl, IsoPath, HostDevice and RemoteDevice
for submitted VMs that have a CD Drive Connected or configured to Start Connected.  Non-CD-Connected VMs are skipped.
.PARAMETER VM
Output from VMWare PowerCLI Get-VM.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.INPUTS
VMWare PowerCLI VM from Get-VM:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.OUTPUTS
[pscustomobject] SupSkiFun.VM.ConnectedCD.Info
.EXAMPLE
Retrieve information for one VM:
Get-VM -Name System01 | Show-ConnectedCD
.EXAMPLE
Retrieve information for two VMs, returning object into a variable:
$myVar = Get-VM -Name System04 , System07 | Show-ConnectedCD
.EXAMPLE
Retrieve information for all VMs, returning object into a variable:
$MyVar = Get-VM -Name * | Show-ConnectedCD
#>

Function Show-ConnectedCD
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM
    )

    Process
    {
        $x = Get-CDDrive -VM $vm
        foreach ($y in $x)
        {
            if ($y.ConnectionState.StartConnected -or $y.ConnectionState.Connected)
            {
                $lo = [pscustomobject]@{
                    VM = $y.Parent.Name
                    Name = $y.Name
                    StartConnected = $y.ConnectionState.StartConnected
                    Connected = $y.ConnectionState.Connected
                    AllowGuestControl = $y.ConnectionState.AllowGuestControl
                    IsoPath = $y.isopath
                    HostDevice = $y.HostDevice
                    RemoteDevice = $y.RemoteDevice
                }
                $lo
                $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VM.ConnectedCD.Info')
            }
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
Mandatory. Cluster(s) to query for DRS rules. Can manually enter or pipe output from VmWare Get-Cluster.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.PortGroupInfo
.EXAMPLE
Retrieve DRS rule for one cluster, placing the object into a variable:
$MyVar = Show-DrsRule -Cluster cluster09
.EXAMPLE
Retrieve DRS rules for all clusters, using the Show-DrsRule alias, placing the object into a variable:
$MyVar = Get-Cluster -Name * | sdr
#>
Function Show-DrsRule
{
    [CmdletBinding()]
    [Alias("sdr")]
    param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true, Mandatory=$true)]
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
            $lo = [vClass]::MakeSDRObj($vname , $rule)
            $lo
            $vname = $null
        }
    }
}

<#
.SYNOPSIS
Provides contents of Vsphere Folders
.DESCRIPTION
Returns an object of ItemName, ItemType, ItemMoRef, FolderName, FolderId, and FolderPath of specified Vsphere Folders.
Item properties are the contents of the folder.  Folder properties elucidate folder information.
.PARAMETER Folder
Output from VMWare PowerCLI Get-Folder.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Folder]
.PARAMETER Recurse
If specified will recurse all subfolders of specified folder.
.INPUTS
VMWare PowerCLI Folder from Get-Folder:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Folder]
.OUTPUTS
[pscustomobject] SupSkiFun.VSphereFolderInfo
.EXAMPLE
Retrieve contents of one folder:
Get-Folder -Name TEMP | Show-FolderContent
.EXAMPLE
Retrieve contents of one folder and all of its subfolders:
Get-Folder -Name TEMP | Show-FolderContent -Recurse
.EXAMPLE
Retrieve content of multiple folders, returning object into a variable:
$myVar = Get-Folder -Name UAT , QA | Show-FolderContent
.EXAMPLE
Retrieve content from all folders, returning object into a variable (this may require a few minutes):
$MyVar = Get-Folder -Name * | Show-FolderContent
.LINK
Get-Folder
Show-FolderPath
#>

Function Show-FolderContent
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.Folder[]] $Folder,

        [Switch]$Recurse
    )

    Begin
    {
        $mt = "Empty Folder"
        $ei = @{
            Name = $mt
            MoRef = $mt
        }
    }

    Process
    {
        Function MakeObj
        {
            param ($item, $type)

            $lo = [pscustomobject]@{
                ItemName = $item.Name
                ItemType = $type
                ItemMoRef = $item.MoRef.ToString()
                FolderName = $fol.Name
                FolderID = $fol.ID
                FolderPath = ($fol | Show-FolderPath).Path
            }
            $lo
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VSphereFolder.Info')
        }

        Function GetInfo ($fol)
        {
            foreach ($x in $fol.ExtensionData.ChildEntity)
            {
                $t = $x.type
                $q = Get-view $x |
                    Select-Object -Property Name, Moref

                if ($Recurse -and $t -eq "Folder")
                {
                    $nfol = Get-Folder -id $q.MoRef
                    MakeObj -item $q -type $t
                    GetInfo ($nfol)
                }

                else
                {
                    MakeObj -item $q -type $t
                }
            }
        }

        foreach ($fol in $folder)
        {
            if ($fol.ExtensionData.ChildEntity)
            {
                GetInfo $fol
            }
            else
            {
                MakeObj -item $ei -type $mt
            }
        }
    }
}

<#
.SYNOPSIS
Provides information on Vsphere Folders
.DESCRIPTION
Returns an object of Name, Id, Path, and Type for specified Vsphere Folders.  If multiple folders have the same name,
they will all be returned with differing Ids and Paths listed.
.PARAMETER Folder
Output from VMWare PowerCLI Get-Folder.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Folder]
.INPUTS
VMWare PowerCLI Folder from Get-Folder:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.Folder]
.OUTPUTS
[pscustomobject] SupSkiFun.VSphereFolderInfo
.EXAMPLE
Retrieve information for one folder name:
Get-Folder -Name TEMP | Show-FolderPath
.EXAMPLE
Retrieve information for multiple folders, returning object into a variable:
$myVar = Get-Folder -Name UAT , QA | Show-FolderPath
.EXAMPLE
Retrieve information for all folders, returning object into a variable (this may require a few minutes):
$MyVar = Get-Folder -Name * | Show-FolderPath
#>

Function Show-FolderPath
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.Folder[]] $Folder
    )

    Process
    {
        foreach ($sn in $folder)
        {
            $sne = $sn.ExtensionData
            $fp = $sn.name
            while ($sne.Parent)
            {
                $sne = Get-View $sne.Parent
                $fp  = Join-Path -Path $sne.name -ChildPath $fp
            }

            $lo = [PSCustomObject]@{
                Name = $sn.Name
                Id = $sn.id
                Path = $fp
                Type = $sn.Type.ToString()
            }
            $lo
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VSphereFolder.Info')
        }
    }
}

<#
.SYNOPSIS
Show RDMs from specified VMs or VMHosts
.DESCRIPTION
Returns an object of RDMs listing DevfsPath, Device, DisplayName, IsPerenniallyReserved, Size,
Status, VAAIStatus, Vendor, HostName and VM (if applicable) from VMs or VMHosts.  Alias srdm.
.PARAMETER VM
VMWare PowerCLI VM Object from Get-VM
VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.INPUTS
VMWare PowerCLI VM or VMHost Object from Get-VM or Get-VMHost:
VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.RDM.Info
.EXAMPLE
Query one VM for RDMs:
Get-VM -Name Server01 | Show-RDM
.EXAMPLE
Query one VMHost for RDMs:
Get-VMHost -Name ESXi17 | Show-RDM
.EXAMPLE
Query multiple VMs for RDMs, returning object into a variable:
$myVar = Get-VM -Name Server50* | Show-RDM
.EXAMPLE
Query all VMHosts in a cluster using the Show-RDM alias, returning object into a variable:
$myVar = Get-VMHost -Name * -Location Cluster12 | srdm
#>
function Show-RDM
{
    [CmdletBinding()]
    [Alias("srdm")]
    param
    (
        [Parameter(ParameterSetName = "VM" , ValueFromPipeline = $true)]
		[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM,

        [Parameter(ParameterSetName = "VMHost" , ValueFromPipeline = $true)]
		[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost
	)

    Begin
	{
		# RDM properties to query.
		$rvals = @(
			"DevfsPath"
			"Device"
			"DisplayName"
			"IsPerenniallyReserved"
			"Size"
			"Status"
			"VAAIStatus"
			"Vendor"
		)
	}

	Process
    {
		Function vmrdm
		{
			foreach ($v in $vm)
			{
				$ds = Get-HardDisk -VM $v -DiskType "RawPhysical","RawVirtual"
				$x2 = Get-EsxCli -VMHost $v.VMHost -V2
				$dl = $x2.storage.core.device.list.Invoke()
				foreach ($d in $ds)
				{
					$rdisk = $dl |
						Where-Object -Property Device -Match $d.ScsiCanonicalName |
							Select-Object $rvals
					MakeObj -diskdata $rdisk -hostdata $v.VMHost.Name -vmdata $v.name
				}
			}
		}

		Function vmhrdm
		{
			foreach ($vmh in $vmhost)
			{
				$x2 = Get-EsxCli -VMHost $vmh -V2
				$vd = (Get-Datastore -VMHost $vmh |
					Where-Object -Property Type -Match VMFS).ExtensionData.Info.Vmfs.Extent.Diskname
				$dl = $x2.storage.core.device.list.Invoke()
				# Remove DataStore LUNs and local MicroSd Card from the list.
				$dl = $dl |
					Where-Object {$_.Device -notin $vd -and $_.Device -notmatch "^mpx"}
				foreach ($d in $dl)
				{
					MakeObj -diskdata $d -hostdata $vmh.Name
				}
			}
		}

		Function MakeObj
		{
			param($diskdata , $hostdata , $vmdata = "N/A")

			$loopobj = [pscustomobject]@{
				VM = $vmdata
				HostName = $hostdata
				DevfsPath = $diskdata.DevfsPath
				Device = $diskdata.Device
				DisplayName = $diskdata.DisplayName
				IsPerenniallyReserved =	$diskdata.IsPerenniallyReserved
				SizeGB = [Math]::Round($diskdata.Size /1kb, 2)
				Status = $diskdata.Status
				VAAIStatus = $diskdata.VAAIStatus
				Vendor = $diskdata.Vendor
			}
			$loopobj
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.RDM.Info')

		}

		if ($vm)
		{
			vmrdm
		}
		elseif ($vmhost)
		{
			vmhrdm
		}
		else
		{
			Write-Output "VM or VMHost must be piped in.  Terminating"
			break
		}
    }
}

<#
.SYNOPSIS
Displays IP connections on an ESX Host
.DESCRIPTION
Displays IP connections on the ESX Host specified.  Akin to NetStat or SS.
.PARAMETER VMHost
Mandatory.  Specify an ESX hosts.
.EXAMPLE
Place results from one ESX hosts into a variable:
$myVar = Show-SS -VMHost ESXHOST01
#>

function Show-SS
{
    [CmdletBinding()]
	[Alias("ss")]
    param
    (
        [Parameter(Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			HelpMessage = "Enter ESX Host Name"
		)]
		[Alias("Name")]
        [string]$VMHost
	)

	Process
	{
		foreach ($vmh in $vmhost)
		{
			$esxcli = Get-EsxCli -V2 -VMHost $vmh
			$esxcli.network.ip.connection.list.invoke()
		}
	}
}

<#
.SYNOPSIS
Retrieves detailed information from submitted tasks.
.DESCRIPTION
Retrieves detailed information from submitted tasks.  Returns an object of Name, Description,
ID, State, IsCancelable, PercentComplete, Start, Finish, UserName, EntityName, and EntityID.
.PARAMETER Task
Output from VMWare PowerCLI Get-Task.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Task]
.INPUTS
VMWare PowerCLI Task from Get-Task:
[VMware.VimAutomation.ViCore.Types.V1.Task]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.Task.Info
.EXAMPLE
Retrieve information from all running tasks, returning an object into a variable:
$MyVar = Get-Task -Status Running | Show-TaskInfo
.EXAMPLE
Retrieve information from all relocation tasks, returning an object into a variable:
$MyVar = Get-Task | Where-Object -Property Name -Match reloc | Show-TaskInfo
.EXAMPLE
Retrieve information from all recent tasks, returning an object into a variable:
$MyVar = Get-Task | Show-TaskInfo
#>
function Show-TaskInfo
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Task[]] $Task
    )

    Process
    {
        foreach ($t in $task)
        {
            $lo = [pscustomobject]@{
                Name = $t.Name
                Description = $t.Description
                ID = $t.Id
                State = $t.State
                IsCancelable = $t.IsCancelable
                PercentComplete = $t.PercentComplete
                Start = $t.StartTime
                Finish = $t.FinishTime
                UserName = $t.ExtensionData.Info.Reason.UserName
                EntityName = $t.ExtensionData.Info.EntityName
                EntityID = $t.ExtensionData.Info.Entity
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.Task.Info')
            $lo
        }
    }
}

<#
.SYNOPSIS
Queries for VMs with a USB Controller Installed
.DESCRIPTION
Returns an object of VM, Notes, VMHost and USB from VMs with a USB Controller Installed
.PARAMETER VM
Output from VMWare PowerCLI Get-VM.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.EXAMPLE
Query one VM for USB Controller:
Get-VM -Name VM01 | Show-USBController
.EXAMPLE
Query all VMs for USB Controller, returning object into a variable:
$myVar = Get-VM -Name * | Show-USBController
.INPUTS
VMWare PowerCLI VMHost from Get-VM:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.USB.Info
#>
function Show-USBController
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM
    )

    Begin
    {
        $usbd = $null
    }

    Process
    {
        foreach ($v in $VM)
        {
            $usbd = ($v.ExtensionData.Config.Hardware.Device.deviceinfo |
                Where-Object -Property label -imatch "USB").label
            if ($usbd)
            {
                $lo = [pscustomobject]@{
					VM = $v.Name
					Notes = $v.Notes
					VMHost = $v.VMHost
					USB = $usbd
                }
                $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.USB.Info')
                $lo
            }
        }
    }
}

<#
.SYNOPSIS
Outputs all Permissions with their affiliated Role and Privileges.
.DESCRIPTION
Amalgamates all Permissions with their affiliated Role and Privileges.
Returns an object of Role, RoleIsSystem, Principal, Entity, EntityID, Propogate, PrincipalIsGroup, and Privilege.
.NOTES
Optimal for archiving and for (re)creating roles and permissions.  Convertable to JSON (see example).
A privilege defines right(s) to perform actions and read properties.
A role is a set of privileges.
A permission gives a Principal (user or group) a role for a specific entity.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.Permissions.Info
.EXAMPLE
Return the object into a variable:
$MyVar = Show-VIPermission
.EXAMPLE
Return JSON into a variable:
$MyVar = Show-VIPermission | ConvertTo-Json -Depth 3
.LINK
Get-VIPermission
Get-VIPrivilege
Get-VIRole
New-VIPermission
#>
Function Show-VIPermission
{
    [CmdletBinding()]
    Param()

    Begin
    {
        $hh = @{}
        $qq = Get-VIPermission
        $rr = Get-VIRole
    }

    Process
    {
        Function MakePrivHash
        {
            foreach ($r in $rr)
            {
                ($p = Get-VIPrivilege -ErrorAction SilentlyContinue -Role $r).Name |
                    Out-Null
                # hash with array value.  [0] is RoleIsSystem true/false. [1] is array of privileges
                $hh.add($r.Name,@($r.IsSystem,$p.Name))
            }
        }

        MakePrivHash

        foreach ($q in $qq)
        {
            $lo = [vClass]::MakePPRObj($q , $hh.($q.Role))
            $lo
        }
    }
}

<#
.SYNOPSIS
Obtains basic network settings from VMHost(s)
.DESCRIPTION
Returns an object of HostName, IP, NTPServer, DNSServer, SearchDomain and IPv6Enabled from VMHosts
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.INPUTS
VMHost Object from Get-VMHost:
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.VMHostNetworkInfo
.EXAMPLE
Query one VMHost for Network Info:
Get-VMHost -Name ESXi17 | Show-VMHostNetworkInfo
.EXAMPLE
Query multiple hosts, returning the object into a variable, using the Show-VMHostNetworkInfo alias:
$MyObj = Get-VMHost -Name ESX0* | svni
#>
function Show-VMHostNetworkInfo
{
    [CmdletBinding()]
    [Alias("svni")]
    param
    (
        [Parameter(ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost
	)

    Process
    {
		foreach($vmh in $vmhost)
		{
			$n = Get-VMHostNetwork -VMHost $vmh
			$p = Get-VMHostNtpServer -VMHost $vmh
			$ip = (Get-VMHostNetworkAdapter -VMHost $vmh).ip
			$ipv = foreach ($i in $ip)
			{
				if(!([string]::IsNullOrEmpty($i)))
				{
					$i
				}
			}
			$lo = [pscustomobject]@{
				HostName = $vmh.Name
				IP = $ipv
				NTPServer = $p
				DNSServer = $n.DnsAddress
				SearchDomain = $n.SearchDomain
				IPv6Enabled = $n.IPv6Enabled
			}
			$lo
			$lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VMHostNetworkInfo')
 		}
    }
}

<#
.SYNOPSIS
Returns VMHost physical NIC properties
.DESCRIPTION
Returns an object of VMHost physical NIC properties
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.INPUTS
VMHost Object from Get-VMHost:
VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.VMHost.Physical.NIC.Info
.EXAMPLE
Query one VMHost for Physical NIC Info:
Get-VMHost -Name ESXi17 | Show-VMHostPhysicalNIC
.EXAMPLE
Query multiple hosts for Physical NIC Info returning the object into a variable:
$MyObj = Get-VMHost -Name ESX0* | Show-VMHostPhysicalNIC
#>

Function Show-VMHostPhysicalNIC
{
    [cmdletbinding()]
    Param
    (
        [Parameter(ValueFromPipeline = $true , Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
    )

    Process
    {
        $vmn = $VMHost |
            Get-VMHostNetworkAdapter -Physical
        foreach ($n in $vmn)
        {
            $lo = [vClass]::MakeVMPNObj($n)
            $lo
        }
    }
}

<#.Synopsis
Obtains Port Groups from ESXi Hosts
.DESCRIPTION
Returns an object of PortGroup, VLAN, HostName, Vswitch, VswitchMTU, and VswitchPorts.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.PortGroup.Info
.EXAMPLE
Return Port Group Object from one ESXi Host:
Get-VMHost -Name ESX01 | Show-VMHostVirtualPortGroup
.EXAMPLE
Place Port Group Object from two ESXi Hosts into a variable:
$MyVar = Get-VMHost -Name ESX03, ESX04 | Show-VMHostVirtualPortGroup
#>
function Show-VMHostVirtualPortGroup
{
    [CmdletBinding()]

    param
    (
		[Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]] $VMHost
 	)

    Process
    {
		$vpg = $vmhost |
            Get-VirtualPortGroup -Name *
        foreach ($vp in $vpg)
        {
           $lo =  [vClass]::MakeObjSVVPG($vp)
           $lo
        }
    }
}

<#
.SYNOPSIS
Return an object of information & resources for VM(s)
.DESCRIPTION
Return an object of information and resources used by VM(s): Name, CPU (number, cores, sockets), RAM, Host, OS, Notes, Disks
Optionally return embedded objects of Datastores and/or VMHosts available to the VM.  See Examples.
.PARAMETER VM
Mandatory.  Name(s) of VMs to process.
.PARAMETER Full
Optional.  Returns embedded objects of Datastores and VMHosts available to the VM, in addition
to the default output.  Equivalent of -Datastore -Cluster.	 See Examples.
.PARAMETER DataStore
Optional.  Returns an embedded object of Datastores available to the VM, in addition
to the default output. See Examples.
.PARAMETER Cluster
Optional.  Returns an embedded object of VMHosts available to the VM, in addition
to the default output. See Examples.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.VMInfo
.EXAMPLE
Return Default Output for one VM:
Show-VMResource -VM VM01
.EXAMPLE
Return Default and Datastore Output for one VM, using the Show-VMResource alias:
svr -VM VM02 -DataStore
.EXAMPLE
Return Default and Cluster-VMHost Output for two VMs, placing object into a variable:
$myVar = Show-VMResource -VM VM03,VM04 -Cluster
.EXAMPLE
Return Default, Datastore and Cluster-VMHost Output for two VMs, placing object into a variable, using the Show-VMResource alias:
$myVar = svr -VM VM05,VM06 -Full
.EXAMPLE
Return Default Output for multiple VMs, piping data from Get-VM, placing object into a variable:
$myVar = Get-VM -Name d* | Show-VMResource
#>
function Show-VMResource
{
    [CmdletBinding()]
    [Alias("svr")]
    param
    (
        [Parameter(Mandatory=$true,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="Enter a VM Name"
		)]
		[Alias("Name","ComputerName")]
        [string[]]$VM,
		[switch]$Full,
		[switch]$DataStore,
		[switch]$Cluster
	)

    Begin
    {
        $nodata = "No Data.  Likely a Regular VM"
		if($full)
		{
			$Datastore=$true
			$Cluster=$true
		}
    }

    Process
    {
        foreach($v in $vm)
		{
			$vmdata = Get-VM -Name $v
			$vmtype = $vmdata.ExtensionData.Summary.config.ManagedBy.Type
			if(!($vmtype))
			{
				$vmtype = $nodata
			}
			$hddata = Get-HardDisk -VM $v |
				Select-Object -Property Name, FileName, @{n="CapacityGB";e={[math]::Round($_.CapacityGB,2)}} , StorageFormat
			$numcpu = $vmdata.numcpu.ToDecimal($null)
			$coreps = $vmdata.CoresPerSocket.ToDecimal($null)
			$loopobj = [pscustomobject]@{
				Name = $vmdata.name
				NumCPU = $numcpu
				CoresPerSocket = $coreps
				Sockets = ($numcpu / $coreps).ToDecimal($null)
				RAM = $vmdata.memorygb.ToDecimal($null)
				Host = $vmdata.vmhost
				OS = $vmdata.ExtensionData.config.GuestFullName
				Notes = $vmdata.Notes
				Disk = $hddata
				Type = $vmtype
			}

			if($Datastore)
			{
				$dsdata = Get-Datastore -vmhost $vmdata.vmhost |
					Sort-Object -Property Name
				$loopobj |
					Add-Member -MemberType NoteProperty -name "DataStore" -value $dsdata
			}

			if($Cluster)
			{
			    $vmhdata = Get-VMHost -Location (Get-Cluster -VMHost $vmdata.vmhost) |
					Sort-Object -Property Name
				$loopobj |
					Add-Member -MemberType NoteProperty -name "Cluster" -value $vmhdata
			}

			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.VMInfo')
			$loopobj
		}
    }
}

<#
.SYNOPSIS
Retrieves Memory, CPU, and NET statistics
.DESCRIPTION
Retrieves Memory, CPU, and NET usage statistics.  Memory and CPU are in PerCentAge; NET is in KBps.
Returns an object of VM, CPUaverage, MEMaverage, NETaverage, CPUmaximum, MEMmaximum, and NETmaximum.
.PARAMETER VM
Output from VMWare PowerCLI Get-VM. See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.PARAMETER Days
Number of Past Days to check.  Defaults to 30.  1 to 45 accepted.
.EXAMPLE
Retrieve statistical information of one VM, returning the object into a variable:
$myVar = Get-VM -Name SYS01 | Show-VMStat
.EXAMPLE
Retrieve statistical information of two VMs, returning the object into a variable:
$myVar = Get-VM -Name SYS02 , SYS03 | Show-VMStat
.INPUTS
VMWare PowerCLI VM from Get-VM:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.OUTPUTS
[pscustomobject] SupSkiFun.VM.Stat.Info
.LINK
Get-Stat
Get-StatType
Get-StatInterval
#>
function Show-VMStat
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $VM,

        [Parameter()][ValidateRange(1,45)] [int32] $Days = 30
    )

    Begin
    {
        $dt = Get-Date
        $nd = "No Data"
        $ohash = @{}
        $st = @(
            'cpu.usage.average'
            'mem.usage.average'
            'net.usage.average'
        )
        $sp = @{
            Start = ($dt).AddDays(-$days)
            Finish = $dt
            MaxSamples = 10000
            Stat = $st
        }
    }

    Process
    {
        foreach ($v in $vm)
        {
            $ohash.Clear()
            $r1 , $c1 , $t1 = $null
            $r1 = Get-Stat -Entity $v @sp
            foreach ($s in $st)
            {
                $t1 = $s.Split(".")[0].ToUpper()
                $c1 = $r1 |
                    Where-Object -Property MetricID -Match $s |
                            Measure-Object -Property Value -Average -Maximum
                if ($c1)
                {
                    $ohash.Add($($t1+"avg"),[math]::Round($c1.Average,2))
                    $ohash.Add($($t1+"max"),[math]::Round($c1.Maximum,2))
                }
                else
                {
                    $ohash.Add($($t1+"avg"),$nd)
                    $ohash.Add($($t1+"max"),$nd)
                }
            }
            $lo = [VClass]::MakeSTObj($v.Name , $ohash)
            $lo
            $r1 , $c1 , $t1 = $null
        }
    }
}

<#
.SYNOPSIS
Starts SSH on an ESX Host
.DESCRIPTION
Starts SSH on an ESX Host.
.PARAMETER VMHost
Mandatory.  Specify one on more ESX hosts.
.EXAMPLE
Starts SSH on two ESX Hosts:
Start-SSH -VMHost MyESX07 , MyESX08
.EXAMPLE
Starts SSH on all ESX Hosts in a Cluster:
Get-VMHost -Location MyCluster44 | Start-SSH
#>
function Start-SSH
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'medium')]
    param
    (
        [Parameter(Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			HelpMessage = "Enter one or more ESX Host Names"
		)]
		[Alias("Name")]
        [string[]]$VMHost
	)

    Process
    {
		if($PSCmdlet.ShouldProcess($VMHost))
		{
			foreach ($vmh in $VMHost)
			{
				Get-VMHostService $vmh |
					Where-object {$_.Key -eq "TSM-SSH"} |
						Start-VMHostService -confirm:$false
			}
		}
    }
}

<#
.SYNOPSIS
Stops SSH on an ESX Host
.DESCRIPTION
Stops SSH on an ESX Host.
.PARAMETER VMHost
Mandatory.  Specify one on more ESX hosts.
.EXAMPLE
Stops SSH on two ESX Hosts:
Stop-SSH -VMHost MyESX05 , MyESX05
.EXAMPLE
Stops SSH on all ESX Hosts in a Cluster:
Get-VMHost -Location MyCluster77 | Stop-SSH
#>
function Stop-SSH
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'medium')]
    param
    (
        [Parameter(Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			HelpMessage = "Enter one or more ESX Host Names"
		)]
		[Alias("Name")]
        [string[]]$VMHost
	)

    Process
    {
		if($PSCmdlet.ShouldProcess($VMHost))
		{
		   foreach ($vmh in $VMHost)
			{
				Get-VMHostService $vmh |
					Where-object {$_.Key -eq "TSM-SSH"} |
						Stop-VMHostService -confirm:$false
			}
		}
    }
}

<#
.SYNOPSIS
Kills VM Process
.DESCRIPTION
Kills VM Process, returning an object of VM, Result, and VMHost.
.PARAMETER VM
Output from VMWare PowerCLI Get-VM.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.PARAMETER Type
Either soft, hard or force.
soft - Gives the VMX process a chance to shut down cleanly (like kill or kill -SIGTERM)
hard - Stops the VMX process immediately (like kill -9 or kill -SIGKILL)
force - Stops the VMX process when other options do not work.  Last Resort.
.EXAMPLE
Perform a soft kill of one VM, returning the object into a variable:
$myVar = Get-VM -Name SYS01 | Stop-VMpid -Type soft
.EXAMPLE
Perform a hard kill of two VMs, returning the object into a variable:
$myVar = Get-VM -Name SYS02 , SYS03 | Stop-VMpid -Type hard
.INPUTS
VMWare PowerCLI VM from Get-VM:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
.OUTPUTS
[pscustomobject] SupSkiFun.VM.PID.Info
.LINK
Get-VMpid
#>
function Stop-VMpid
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'high')]

    Param
    (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM,

        [Parameter(Mandatory = $true)]
        [ValidateSet("soft", "hard", "force")]
        [string]$Type
    )

    Begin
    {

    }

    Process
    {
        Function MakeObj
        {
            param($vdata,$resdata)

            $lo = [PSCustomObject]@{
                VM = $vdata.Name
                Result = $resdata
                VMHost = $vdata.VMHost.Name
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VM.PID.Info')
            $lo
        }

        foreach ($v in $vm)
        {
            if($PSCmdlet.ShouldProcess("$v with kill type $($type)"))
            {
                if ($v.PowerState -eq "PoweredOn")
                {
                    $x2 = Get-EsxCli -V2 -VMHost $v.vmhost.Name
                    $r1 = $x2.vm.process.list.Invoke() |
                        Where-Object -Property DisplayName -eq $v.Name
                    $z2 = $x2.vm.process.kill.CreateArgs()
                    $z2.type = $Type
                    $z2.worldid = $r1.WorldID
                    $r2 = $x2.vm.process.kill.Invoke($z2)
                    MakeObj -vdata $v -resdata $r2
                }

                else
                {
                    $np = "Not Attempted; VM Power state is $($v.PowerState)"
                    MakeObj -vdata $v -resdata $np
                }
            }
        }
    }
}

<#
.SYNOPSIS
Terminates a VSphere Session
.DESCRIPTION
Terminates a VSphere Session with provided session key.  Session keys can be obtained with Get-VSphereSession.
.EXAMPLE
Kills the VSphere Session affiliated with the provided key:
Stop-VSphereSession -Key 89887dbe9-7rrtje9ce-1ee1-d40-8b0ae5fa
#>
function Stop-VSphereSession
{
    [CmdletBinding(SupportsShouldProcess = $true,
		ConfirmImpact = 'high'
	)]
    param
    (
        [Parameter(Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			HelpMessage = "Enter Session Key"
		)]
        [string[]]$Key
	)

    Begin
	{
		$ses = (Get-View $DefaultViserver.ExtensionData.Client.ServiceContent.SessionManager)
	}

	Process
    {
		foreach ($cle in $key)
		{
			if($PSCmdlet.ShouldProcess($cle))
			{
				$ses.TerminateSession($cle)
			}
		}
    }
}

<#
.SYNOPSIS
UnInstalls VIB(s) on VMHost(s).
.DESCRIPTION
UnInstalls VIB(s) on VMHost(s) and returns an object of HostName, Message, RebootRequired, VIBSInstalled, VIBSRemoved, and VIBSSkipped.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER VIB
Name(s) of VIBS to remove.  Example: NetAppNasPlugin , esx-ui
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.VIBinfo
.EXAMPLE
Uninstall one VIB from one VMHost, returning an object into a variable:
$MyVar = Get-VMHost -Name ESX02 | UnInstall-VIB -VIB NetAppNasPlugin
.EXAMPLE
Uninstall two VIBs from two VMHosts, returning an object into a variable:
$MyVar = Get-VMHost -Name ESX03 , ESX04 | UnInstall-VIB -VIB vsan , vmkfcoe
#>
function UnInstall-VIB
{
    [CmdletBinding(SupportsShouldProcess=$true,
    ConfirmImpact='high')]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory=$true)]
        [string[]]$VIB
    )

    Process
    {
        foreach ($vmh in $VMHost)
        {
            $cible = @{vibname = $VIB}
            if($PSCmdlet.ShouldProcess("$vmh uninstalling $VIB"))
            {
                $xcli = get-esxcli -v2 -VMHost $vmh
                $res = $xcli.software.vib.remove.invoke($cible)
                $lo = [PSCustomObject]@{
                    HostName = $vmh
                    Message = $res.Message
                    RebootRequired = $res.RebootRequired
                    VIBsInstalled = $res.VIBsInstalled
                    VIBsRemoved = $res.VIBsRemoved
                    VIBsSkipped = $res.VIBsSkipped
                }
                $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VIBinfo')
                Write-Output $lo
            }
        }
    }
}

<#
.SYNOPSIS
Updates VIB(s) on VMHost(s).
.DESCRIPTION
Updates VIB(s) on VMHost(s) and returns an object of HostName, Message, RebootRequired, VIBSInstalled, VIBSRemoved, and VIBSSkipped.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.PARAMETER URL
URL(s) for the VIB(s).  https://www.example.com/VMware_bootbank_vsanhealth_6.5.0-2.57.9183449.vib , https://www.example.com/VMware_bootbank_esx-base_6.7.0-0.20.9484548
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
.OUTPUTS
[PSCUSTOMOBJECT] SupSkiFun.VIBinfo
.EXAMPLE
Update one VIB on one VMHost, returning an object into a variable:
$u = 'https://www.example.com/VMware_bootbank_vsanhealth_6.5.0-2.57.9183449.vib'
$MyVar = Get-VMHost -Name ESX02 | Update-VIB -URL $u
.EXAMPLE
Update two VIBs on two VMHosts, returning an object into a variable:
$uu = 'https://www.example.com/VMware_bootbank_vsanhealth_6.5.0-2.57.9183449.vib' , 'https://www.example.com/VMware_bootbank_esx-base_6.7.0-0.20.9484548'
$MyVar = Get-VMHost -Name ESX03 , ESX04 | Update-VIB -URL $uu
#>
function Update-VIB
{
    [CmdletBinding(SupportsShouldProcess = $true , ConfirmImpact = 'high')]

    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory = $true)]
        [string[]]$URL
    )

    Process
    {
        Function MakeObj
        {
            param($vhdata,$resdata)

            $lo = [PSCustomObject]@{
                HostName = $vhdata
                Message = $resdata.Message
                RebootRequired = $resdata.RebootRequired
                VIBsInstalled = $resdata.VIBsInstalled
                VIBsRemoved = $resdata.VIBsRemoved
                VIBsSkipped = $resdata.VIBsSkipped
            }
            $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VIB.Info')
            $lo
        }

        $cible = @{viburl = $URL}
        foreach ($vmh in $VMHost)
        {
            if($PSCmdlet.ShouldProcess("$vmh installing $URL"))
            {
                $xcli = Get-EsxCli -v2 -VMHost $vmh
                $resp = $xcli.software.vib.update.invoke($cible)
                MakeObj -vhdata $vmh.Name -resdata $resp
            }
        }
    }
}