class vClass
{
    static [pscustomobject] MakeGVSACObj ( [psobject] $obj , [string] $type )
    {
        $lo = [pscustomobject]@{
            Name = $obj.Name
            Enabled = $obj.ExtensionData.AlarmActionsEnabled
            Type = $type
        }
        $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.Alarm.Config')
        return $lo
    }

    static [hashtable] MakeHash( [string] $quoi )
    {
        $src = $null
        $shash = @{}

        switch ($quoi)
        {
            ds { $src = Get-Datastore -Name * }
            ex { $src = Get-VMHost -Name * }
            vm { $src = Get-VM -Name * }
        }

        foreach ($s in $src)
        {
            $shash.add($s.Id , $s.Name)
        }
        return $shash
    }

    static [pscustomobject] MakeObjSVVPG( [psobject[]] $vp )
    {
        $obj = $null
		$obj = [pscustomobject]@{
            PortGroup = $vp.Name
            VLAN = $vp.VLanId
            HostName = $vp.VirtualSwitch.VMHost.Name
            Vswitch = $vp.VirtualSwitchName
            VswitchMTU = $vp.VirtualSwitch.MTU
            VswitchPorts = $vp.VirtualSwitch.NumPorts
		}
		$obj.PSObject.TypeNames.Insert(0,'SupSkiFun.PortGroup.Info')
		return $obj
    }

    static [pscustomobject] MakePPRObj ( [psobject] $perm , [Array] $priv )
    {
        $obj = [PSCustomObject]@{
            Role = $perm.Role
            RoleIsSystem = $priv[0]
            Principal = $perm.Principal
            Entity = $perm.Entity.ToString()
            EntityID = $perm.EntityId
            Propagate = $perm.Propagate
            PrincipalIsGroup = $perm.IsGroup
            Privilege = $priv[1]
        }
        $obj.PSObject.TypeNames.Insert(0,'SupSkiFun.Permissions.Info')
        return $obj
    }

    static [pscustomobject] MakeSDRObj ( [Array] $VName , [PSObject] $Rule )
    {
        $obj = [pscustomobject]@{
            Name = $rule.Name
            Cluster = $rule.cluster.ToSTring()
            VMId = $rule.VMIds
            VM = $vname
            Type = $rule.Type.ToString()
            Enabled = $rule.Enabled.ToString()
        }
        $obj.PSObject.TypeNames.Insert(0,'SupSkiFun.DrsRuleInfo')
        return $obj
    }

    static [pscustomobject] MakeSTObj( [string] $vdata , [hashtable] $ohash )
    {
        $obj = [PSCustomObject]@{
            VM = $vdata
            CPUavg = $ohash.CPUavg
            MEMavg = $ohash.MEMavg
            NETavg = $ohash.NETavg
            CPUmax = $ohash.CPUmax
            MEMmax = $ohash.MEMmax
            NETmax = $ohash.NETmax
        }
        $obj.PSObject.TypeNames.Insert(0,'SupSkiFun.VM.Stat.Info')
        return $obj
    }

    static [pscustomobject] MakeVFSObj ( [string] $Name , [PSObject] $Info )
    {
        $obj = [pscustomobject]@{
            HostName = $name
            MountPoint = $info.MountPoint
            PercentFree = $info.Free
            Maximum = $info.Maximum
            Used = $info.Used
            RamDiskName = $info.RamdiskName
        }
        $obj.PSObject.TypeNames.Insert(0,'SupSkiFun.ESXi.HyperVisorFS.Info')
        return $obj
    }

    static [pscustomobject] MakeVMPNObj ( [psobject] $n)
    {
        $lo = [pscustomobject]@{
            VMHost = $n.VmHost.Name
            NIC = $n.Name
            Speed = $n.extensiondata.linkspeed.SpeedMB
            Duplex = $n.extensiondata.linkspeed.Duplex
        }
        $lo.PSObject.TypeNames.Insert(0,'SupSkiFun.VMHost.Physical.NIC.Info')
        return $lo
    }
}