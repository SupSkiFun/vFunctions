# MakeHash is a helper which makes hash tables for VM or ESXi or DStore
Function MakeHash([string]$quoi)
{
	switch ($quoi)
	{
		'vm'
		{
			$vmq = Get-VM -Name *
			$vmhash = @{}
			$script:vmhash = foreach ($v in $vmq)
			{
				@{
					$v.id = $v.name
				}
			}
		}

		'ex'
		{
			$exq = Get-VMHost -Name *
			$exhash = @{}
			$script:exhash = foreach ($e in $exq)
			{
				@{
					$e.id = $e.name
				}
			}
		}

		'ds'
		{
			$dsq = Get-Datastore -Name *
			$dshash = @{}
			$script:dshash = foreach ($d in $dsq)
			{
				@{
					$d.id = $d.name
				}
			}
		}
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
Returns an Object of SnapShot Data for specified VMs
.DESCRIPTION
Returns an object of VM, SnapName, SnapDescription, SizeGB, File, UserName and CreatedTime of a snapshot.
Snapshot input must be piped from Get-SnapShot.  See Examples.  Auto-Generated SYNTAX (above) is not quite accurate.
Note:  Time occassionally skews a few seconds between VIevent (log) and Snapshot (actual) info.
Ergo, this advanced function creates an 11 second window to correlate log information with actual information.
Snapshots taken on the same VM within 10 seconds of each other may produce innaccurate results.  Optionally,
the 11 second window can be adjusted from 0 to 61 seconds by using the PreSeconds and PostSeconds parameters.
.PARAMETER Name
Pipe the Snapshot object.  See Examples.  Auto-Generated SYNTAX (above) is not quite accurate.
.PARAMETER PreSeconds
Number of seconds to capture VIEvents, before the SnapShot.  Default value is 5.
.PARAMETER PostSeconds
Number of seconds to capture VIEvents, after the SnapShot.  Default value is 5.
.INPUTS
VMWare SnapShot Object from Get-SnapShot
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.SnapShotData
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
		[Parameter(ValueFromPipeline = $true)]
		[Alias("SnapShot")]
		[PSObject[]]$Name,

		[Parameter(Mandatory = $false)]
		[ValidateRange(0,30)]
		[Int]$PreSeconds = 5,

		[Parameter(Mandatory = $false)]
		[ValidateRange(0,30)]
		[Int]$PostSeconds = 5
	)

	Begin
	{
		$ffm = "Create virtual machine snapshot"
	}

	Process
	{
		if(!($name))
		{
			Write-Output "Input Object Required.  For more information execute:  help gsd -full"
			break
		}

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
				CreatedTime = $entry.CreatedTime
				File = $files
			}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.SnapShotData')
			$loopobj
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
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
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
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost
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
Obtains LUN of DataStore(s).
.DESCRIPTION
Returns an object of Name, LUN, WorkingPaths, PathSelectionPolicy, Device and DeviceDisplayName of Datastore(s).
Requires Pipleline input from VmWare Get-Datastore.
.PARAMETER Name
Requires Pipleline input from VmWare PowerCLI Get-Datastore.  Only VMFS DataStores accepted.  Alias DataStore.
VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl
.INPUTS
VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.LUNinfo
.EXAMPLE
Retrieve information from one DataStore:
Get-DataStore -Name Dstore01 | Get-DataStoreLunID
.EXAMPLE
Return an object of multiple DataStores into a variable, using the Get-DataStoreLunID alias:
$MyVar = Get-Datastore -Name Dstore* | gdli
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
        [Parameter(ValueFromPipeline=$true)]
		[Alias("DataStore")]
		[VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl[]]$Name
	)

	Begin
    {
		$errmsg = "VMFS Datastore Object Required.  Try:  Help Get-DataStoreLunID -Full"
    }

    Process
    {
		If(!($name))
		{
			Write-Output $errmsg
			break
		}

		MakeHash "ex"

		foreach ($n in $name)
		{
			# Need to replace the below hardcode [0] with a random and try/catch?
			$e2 = Get-EsxCli -v2 -VMHost $exhash.$($n.ExtensionData.host[0].Key)
			$ds = $n.ExtensionData.Info.Vmfs.Extent[0].DiskName
			$li = $e2.storage.nmp.device.list.Invoke((@{'device'=$ds}))
			if($li.WorkingPaths.count -eq 1)
			{
				$ld = $li.WorkingPaths.ToString().Split(":")[3].Replace("L","")
			}
			else
			{
				$ld = $li.WorkingPaths[0].ToString().Split(":")[3].Replace("L","")
			}
			$loopobj = [pscustomobject]@{
					Name = $n.Name
					Lun = $ld
					WorkingPaths = $li.WorkingPaths
					PathSelectionPolicy = $li.PathSelectionPolicy
					Device = $li.Device
					DeviceDisplayName = $li.DeviceDisplayName
				}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.LUNinfo')
			$loopobj
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
        [PSObject[]]$Name
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
Obtain SCSI Paths on VMHost(s)
.DESCRIPTION
Return an object of multiple properties for each LUN/Path from a VMHost.
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
Formats VMHost Output in Percentage
.DESCRIPTION
Returns an object of VMHost PerCent-Free and Percent-Used of CPU/Mhz and RAM/GB.
Requires piped output from Get-VMHost from the Vmware.PowerCLI module.
.PARAMETER  VMHost
Piped output of Get-VMHost from Vmware.PowerCLI
.INPUTS
Results of Get-VMHost: VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.VMHostInfo
.EXAMPLE
Returns an object of one VMHost:
Get-VMHost -Name ESX01 | Format-VMHost
.EXAMPLE
Returns an object of all VMHosts in a cluster, using the Format-VMHost alias:
Get-VMHost -Location CL66 | fv
.EXAMPLE
Returns an object of two VMHosts, with results in table format:
Get-VMHost -Name ESX02 , ESX03 | Format-VMHost | Format-Table
.EXAMPLE
Returns an object of all VMHosts, placing results in a variable:
$MyVar = Get-VMHost -Name *	| Format-VMHost
#>
function Format-VMHostPercentage
{
    [CmdletBinding()]
    [Alias("fvp")]
    param
    (
		[Parameter(ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost
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
Obtains WWN from specified VMHost
.DESCRIPTION
Returns an object of World Wide Numbers from VMHost Fibre Channel HBAs
.PARAMETER VMHost
VMHost Name(s) or VMHost Object from Vmware.PowerCLI
.INPUTS
VMHost Name(s) or VMHost Object from Vmware.PowerCLI
VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
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
Returns Alarm Enabled Status from VMHosts and Clusters
.DESCRIPTION
Returns an object of VMHosts and / or Clusters Names with Alarm Enabled Status.
Requires VMHosts and / or Cluster objects to be piped in or specified as a parameter.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-Cluster
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
.PARAMETER Cluster
Output from VMWare PowerCLI Get-Cluster
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]
.INPUTS
VMWare PowerCLI VMHost and / or Cluster Object from Get-VMHost and / or Get-Cluster:
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]
.OUTPUTS
 PSCustomObject SupSkiFun.AlarmConfig
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
#>
function Get-VSphereAlarmConfig
{
    [CmdletBinding()]
    [Alias("gvsac")]
    param
    (
        [Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost,

		[Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl[]]$Cluster)

    Begin
	{
		$errmsg = "VMHost or Cluster Object Required.  Try:  Help Get-VSphereAlarmConfig -full"
 	}

	Process
    {
		If(!($vmhost -or $cluster))
		{
			Write-Output $errmsg
			break
		}

		If($vmhost)
		{
			foreach ($vmh in $vmhost)
			{
				$loopobj = [pscustomobject]@{
					Name = $vmh.Name
					Enabled = $vmh.ExtensionData.AlarmActionsEnabled
					Type = "VMHost"
				}
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.AlarmConfig')
				$loopobj
			}
		}

		If($cluster)
		{
			foreach ($clu in $cluster)
			{
				$loopobj = [pscustomobject]@{
					Name = $clu.Name
					Enabled = $clu.ExtensionData.AlarmActionsEnabled
					Type = "Cluster"
				}
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.AlarmConfig')
				$loopobj
			}
		}
	}
}

<#
.SYNOPSIS
Enables or Disables Alarms from VMHosts and Clusters
.DESCRIPTION
Enables or Disables Alarms from VMHosts and Clusters.
Requires VMHosts and / or Cluster objects to be piped in or specified as a parameter.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
.PARAMETER Cluster
Output from VMWare PowerCLI Get-Cluster
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]
.PARAMETER State
Set for desired state of alarm; either Enabled or Disabled
.INPUTS
VMWare PowerCLI VMHost and / or Cluster Object from Get-VMHost and / or Get-Cluster:
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]
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
Set-VSphereAlarmConfig -VMHost $host -Cluster $clus	-State Disabled
#>
function Set-VSphereAlarmConfig
{
	[CmdletBinding(SupportsShouldProcess=$true,
		ConfirmImpact='high')]
    param
    (
		[Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost,

		[Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl[]]$Cluster,

		[Parameter(Mandatory = $true)]
		[ValidateSet("Enabled" , "Disabled")]
		[string]$State
	)

    Begin
    {
		$errmsg = "VMHost or Cluster Object Required.  Try:  Help Set-VSphereAlarmConfig -full"
    }

    Process
    {
		If(!($vmhost -or $cluster))
		{
			Write-Output $errmsg
			break
		}
		Else
		{
			$alarmgr = Get-View AlarmManager
		}

		If($vmhost)
		{
			foreach ($vmh in $vmhost)
			{
				if($PSCmdlet.ShouldProcess("$vmh to $($state)"))
				{
					if($state -ieq "Enabled")
					{
						$alarmgr.EnableAlarmActions($vmh.Extensiondata.MoRef,$true)
					}
					elseif($state -ieq "Disabled")
					{
						$alarmgr.EnableAlarmActions($vmh.Extensiondata.MoRef,$false)
					}
				}
			}
		}

		If($cluster)
		{
			foreach ($clu in $cluster)
			{
				if($PSCmdlet.ShouldProcess("$clu to $($state)"))
				{
					if($state -ieq "Enabled")
					{
						$alarmgr.EnableAlarmActions($clu.Extensiondata.MoRef,$true)
					}
					elseif($state -ieq "Disabled")
					{
						$alarmgr.EnableAlarmActions($clu.Extensiondata.MoRef,$false)
					}
				}
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

<#.Synopsis
Obtains Port Groups from ESXi Hosts
.DESCRIPTION
Returns an object of PortGroups, Hostname(s), Vswitches and VLANs from ESXi Hosts by default.
Requires input from Get-VMHost.  Alias = svvpg
Optionally return MTU and Number of Ports from the Vswitch with the -Full Parameter
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
.PARAMETER Full
Optional.  If specified returns MTU and Number of Ports, in addition to the default output.
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
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
function Show-VMHostVirtualPortGroup
{
    [CmdletBinding()]
    [Alias("svvpg")]
    param
    (
		[Parameter(Mandatory = $false , ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost,
		[switch]$Full
 	)

	    Begin
    {
		$errmsg = "VMHost Object Required.  Try:  Help Show-VMHostVirtualPortGroup -full"
    }

    Process
    {
		If(!($vmhost))
		{
			Write-Output $errmsg
			break
		}

		MakeHash "ex"
		$vpg = $vmhost |
			Get-VirtualPortGroup -Name *

		foreach ($vp in $vpg)
		{
			if($full)
			{
				$loopobj = [pscustomobject]@{
					PortGroup = $vp.Name
					VLAN = $vp.VLanId
					HostName = $exhash.($vp.VMHostId)
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
					HostName = $exhash.($vp.VMHostId)
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
function Show-DrsRule
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
		MakeHash "vm"
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
Show RDMs from specified VMs or VMHosts
.DESCRIPTION
Returns an object of RDMs listing DevfsPath, Device, DisplayName, IsPerenniallyReserved, Size,
Status, VAAIStatus, Vendor, HostName and VM (when VM is specified) from VMs or VMHosts.  Alias srdm.
.PARAMETER VM
VMWare PowerCLI VM Object from Get-VM
VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
.INPUTS
VMWare PowerCLI VM or VMHost Object from Get-VM or Get-VMHost:
VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl
VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.RDMinfo
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
        [Parameter(
			ParameterSetName = "VM",
			ValueFromPipeline = $true
		)]
		[VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl[]]$VM,

        [Parameter(
			ParameterSetName = "VMHost",
			ValueFromPipeline = $true
		)]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost
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
					$loopobj = [pscustomobject]@{
						VM = $v.Name
						HostName = $v.VMHost
						DevfsPath = $rdisk.DevfsPath
						Device = $rdisk.Device
						DisplayName = $rdisk.DisplayName
						IsPerenniallyReserved =	$rdisk.IsPerenniallyReserved
						SizeGB = [Math]::Round($rdisk.Size /1kb, 2)
						Status = $rdisk.Status
						VAAIStatus = $rdisk.VAAIStatus
						Vendor = $rdisk.Vendor
					}
				$loopobj
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.RDMinfo')
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
					$loopobj = [pscustomobject]@{
						HostName = $vmh.Name
						DevfsPath = $d.DevfsPath
						Device = $d.Device
						DisplayName = $d.DisplayName
						IsPerenniallyReserved =	$d.IsPerenniallyReserved
						SizeGB = [Math]::Round($d.Size /1kb, 2)
						Status = $d.Status
						VAAIStatus = $d.VAAIStatus
						Vendor = $d.Vendor
					}
					$loopobj
					$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.RDMinfo')
				}
			}
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
Obtains basic network settings from VMHost(s)
.DESCRIPTION
Returns an object of HostName, IP, NTPServer, DNSServer, SearchDomain and IPv6Enabled from VMHosts
.PARAMETER VMHost
VMWare PowerCLI VMHost Object from Get-VMHost
VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
.INPUTS
VMHost Object from Get-VMHost:
VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
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
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost
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
				#IP = $n.VirtualNic.IP property will be deprecated.
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
Retrieves installed VIBs from VMHost(s).
.DESCRIPTION
By default returns an object of HostName, Name, ID, Vendor and Installed(Date) for all installed VIBs from VMHost(s).
Alternatively returns an object of multiple properties, for one, two, or three particular VIBs.
.PARAMETER VMHost
Output from VMWare PowerCLI Get-VMHost.  See Examples.
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
.PARAMETER Name
Optional.  Provides more detailed information for one, two, or three particular VIBs.
.INPUTS
VMWare PowerCLI VMHost from Get-VMHost:
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
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
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost,

        [Parameter(Mandatory = $false)]
        [ValidateCount(1,3)]
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
