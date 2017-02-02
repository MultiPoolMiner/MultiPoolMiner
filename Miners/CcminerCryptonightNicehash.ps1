$Path = '.\Bin\Cryptonight-NiceHash\ccminer.exe'
$Uri = "https://github.com/nicehash/ccminer-cryptonight/releases/download/v1.0.0/ccminer.zip"

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Cryptonight = 'cryptonight'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'NVIDIA'
        Path = $Path
        Arguments = -Join ('-a ', $Algorithms.$_, ' -o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Ccminer'
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}