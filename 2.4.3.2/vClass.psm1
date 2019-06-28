class vClass
{
    <# MakeHash is a helper which makes hash tables for VM or ESXi or DStore #>
    static [hashtable] MakeHash( [string] $quoi )
    {
        [string] [ValidateSet('ds' , 'ex' , 'vm')] $quoi
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
}