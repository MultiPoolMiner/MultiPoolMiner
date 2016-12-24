$Path = '.\Claymore\Equihash\ZecMiner64.exe'

[PSCustomObject]@{
    Path = $Path 
    Arguments = '-zpool $($Pools.Equihash.Host):$($Pools.Equihash.Port) -zwal $($Pools.Equihash.User) -zpsw x'
    HashRates = @{Equihash = '$($Stats.Claymore_Equihash_HashRate.Day)'}
}

$Path = '.\Claymore\Ethash\EthDcrMiner64.exe'

[PSCustomObject]@{
    Path = $Path
    Arguments = '-epool $($Pools.Ethash.Host):$($Pools.Ethash.Port) -ewal $($Pools.Ethash.User) -epsw x -esm 3 -allpools 1'
    HashRates = @{Ethash = '$($Stats.Claymore_Ethash_HashRate.Day)'}
}