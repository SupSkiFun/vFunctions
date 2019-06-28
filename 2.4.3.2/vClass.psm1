class vClass
{
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
        $lo = $null
		$lo = [pscustomobject]@{
            PortGroup = $vp.Name
            VLAN = $vp.VLanId
            HostName = $vp.VirtualSwitch.VMHost.Name
            Vswitch = $vp.VirtualSwitchName
            VswitchMTU = $vp.VirtualSwitch.MTU
            VswitchPorts = $vp.VirtualSwitch.NumPorts
		}
		$lo.PSObject.TypeNames.Insert(0,'SupSkiFun.PortGroupInfo')
		return $lo
    }
}