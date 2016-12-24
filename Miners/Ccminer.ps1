$Path = '.\Bin\NVIDIA\ccminer.exe'

if((Test-Path $Path) -eq $false)
{
    try
    {
        if(Test-Path "ccminer.zip")
        {
            Remove-Item "ccminer.zip"
        }
        Invoke-WebRequest "https://github.com/nicehash/ccminer-tpruvot/releases/download/1.8-decred-nicehash-2/ccminer.zip" -OutFile "ccminer.zip" -UseBasicParsing
        Expand-Archive "ccminer.zip" (Split-Path $Path)
    }
    catch
    {
        return
    }
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a sia -o $($Pools.Sia.Host):$($Pools.Sia.Port) -u $($Pools.Sia.User) -p x'
    HashRates = [PSCustomObject]@{Sia = '$($Stats.Ccminer_Sia_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a yescrypt -o $($Pools.Yescrypt.Host):$($Pools.Yescrypt.Port) -u $($Pools.Yescrypt.User) -p x'
    HashRates = [PSCustomObject]@{Yescrypt = '$($Stats.Ccminer_Yescrypt_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a vanilla -o $($Pools.Blake_Vanilla.Host):$($Pools.Blake_Vanilla.Port) -u $($Pools.Blake_Vanilla.User) -p x'
    HashRates = [PSCustomObject]@{Blake_Vanilla = '$($Stats.Ccminer_Blake_Vanilla_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a lyra2v2 -o $($Pools.Lyra2RE2.Host):$($Pools.Lyra2RE2.Port) -u $($Pools.Lyra2RE2.User) -p x'
    HashRates = [PSCustomObject]@{Lyra2RE2 = '$($Stats.Ccminer_Lyra2RE2_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a skein -o $($Pools.Skein.Host):$($Pools.Skein.Port) -u $($Pools.Skein.User) -p x'
    HashRates = [PSCustomObject]@{Skein = '$($Stats.Ccminer_Skein_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a qubit -o $($Pools.Qubit.Host):$($Pools.Qubit.Port) -u $($Pools.Qubit.User) -p x'
    HashRates = [PSCustomObject]@{Qubit = '$($Stats.Ccminer_Qubit_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a neoscrypt -o $($Pools.NeoScrypt.Host):$($Pools.NeoScrypt.Port) -u $($Pools.NeoScrypt.User) -p x'
    HashRates = [PSCustomObject]@{NeoScrypt = '$($Stats.Ccminer_NeoScrypt_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a x11 -o $($Pools.X11.Host):$($Pools.X11.Port) -u $($Pools.X11.User) -p x'
    HashRates = [PSCustomObject]@{X11 = '$($Stats.Ccminer_X11_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a myr-gr -o $($Pools.Myriad_Groestl.Host):$($Pools.Myriad_Groestl.Port) -u $($Pools.Myriad_Groestl.User) -p x'
    HashRates = [PSCustomObject]@{Myriad_Groestl = '$($Stats.Ccminer_Myriad_Groestl_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a groestl -o $($Pools.Groestl.Host):$($Pools.Groestl.Port) -u $($Pools.Groestl.User) -p x'
    HashRates = [PSCustomObject]@{Groestl = '$($Stats.Ccminer_Groestl_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a keccak -o $($Pools.Keccak.Host):$($Pools.Keccak.Port) -u $($Pools.Keccak.User) -p x'
    HashRates = [PSCustomObject]@{Keccak = '$($Stats.Ccminer_Keccak_HashRate.Day)'}
    API = 'Ccminer'
}

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = '-a scrypt -o $($Pools.Scrypt.Host):$($Pools.Scrypt.Port) -u $($Pools.Scrypt.User) -p x'
    HashRates = [PSCustomObject]@{Scrypt = '$($Stats.Ccminer_Scrypt_HashRate.Day)'}
    API = 'Ccminer'
}