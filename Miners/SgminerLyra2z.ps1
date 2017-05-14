$Path = '.\Bin\Lyra2z-AMD\sgminer.exe'
$Uri = 'https://github.com/djm34/sgminer-msvc2015/releases/download/v0.2-pre/sgminer.exe'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Lyra2z = 'lyra2z'
}

$Optimizations = [PSCustomObject]@{
    Lyra2z = ''
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'AMD'
        Path = $Path
        Arguments = -Join ('--api-listen -k ', $Algorithms.$_, ' -o $($Pools.', $_, '.Protocol)://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x', $Optimizations.$_)
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Week)')}
        API = 'Xgminer'
        Port = 4028
        Wrap = $false
        URI = $Uri
    }
}