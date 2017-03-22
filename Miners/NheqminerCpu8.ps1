$Path = '.\Bin\Equihash-NiceHash\nheqminer.exe'
$Uri = 'https://github.com/nicehash/nheqminer/releases/download/0.5c/Windows_x64_nheqminer-5c.zip'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Port = 3334

$Threads = 8

[PSCustomObject]@{
    Type = 'CPU'
    Path = $Path
    Arguments = -Join ('-a ', $Port, ' -l $($Pools.Equihash.Host):$($Pools.Equihash.Port) -u $($Pools.Equihash.User) -t ', $Threads)
    HashRates = [PSCustomObject]@{Equihash = '$($Stats.' + $Name + '_Equihash_HashRate.Week)'}
    API = 'Nheqminer'
    Port = $Port
    Wrap = $false
    URI = $Uri
}