$Path = '.\Bin\NVIDIA\ccminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "ccminer.zip"
    try
    {
        if(Test-Path $FileName)
        {
            Remove-Item $FileName
        }
        Invoke-WebRequest "https://github.com/nicehash/ccminer-tpruvot/releases/download/1.8-decred-nicehash-2/ccminer.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName (Split-Path $Path)
    }
    catch
    {
        return
    }
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Sia = 'sia'
    Yescrypt = 'yescrypt'
    BlakeVanilla = 'vanilla'
    Lyra2RE2 = 'lyra2v2'
    Skein = 'skein'
    Qubit = 'qubit'
    NeoScrypt = 'neoscrypt'
    X11 = 'x11'
    MyriadGroestl = 'myr-gr'
    Groestl = 'groestl'
    Keccak = 'keccak'
    Scrypt = 'scrypt'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'NVIDIA'
        Path = $Path
        Arguments = -Join ('-a ', $Algorithms.$_, ' -o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Ccminer'
    }
}