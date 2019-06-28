using module .\vClass.psm1
$aa = 'ds' , 'vm' , 'ex'
foreach ($a in $aa)
{
    $x = [vClass]::MakeHash($a)
    $x
}

$y = [vClass]::MakeHash("k")
$y