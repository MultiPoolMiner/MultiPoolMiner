$Path = '.\Bin\NeoScrypt-AMD\nsgminer.exe'
$Uri = 'https://github.com/ghostlander/nsgminer/releases/download/nsgminer-v0.9.2/nsgminer-win64-0.9.2.zip'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    NeoScrypt = 'neoscrypt'
}

$Optimizations = [PSCustomObject]@{
    NeoScrypt = ' --gpu-threads 1 --worksize 64 --intensity 13 --thread-concurrency 64'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'AMD'
        Path = $Path
        Arguments = -Join ('--api-listen --', $Algorithms.$_, ' -o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x', $Optimizations.$_)
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Week)')}
        API = 'Xgminer'
        Port = 4028
        Wrap = $false
        URI = $Uri
    }
}