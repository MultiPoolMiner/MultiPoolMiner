$Path = '.\Bin\Skein-AMD\sgminer.exe'
$Uri = 'https://github.com/miningpoolhub/sgminer/releases/download/5.3.1/Release.zip'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Skein = 'skeincoin'
}

$Optimizations = [PSCustomObject]@{
    Skein = ' --gpu-threads 2 --worksize 256 --intensity 23'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'AMD'
        Path = $Path
        Arguments = -Join ('--api-listen -k ', $Algorithms.$_, ' -o $($Pools.', $_, '.Protocol)://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p $($Pools.', $_, '.Pass)', $Optimizations.$_)
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Week)')}
        API = 'Xgminer'
        Port = 4028
        Wrap = $false
        URI = $Uri
    }
}