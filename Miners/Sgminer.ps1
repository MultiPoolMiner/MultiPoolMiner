$Path = '.\Bin\AMD\sgminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "sgminer.zip"
    try
    {
        if(Test-Path $FileName)
        {
            Remove-Item $FileName
        }
        Invoke-WebRequest "https://github.com/nicehash/sgminer/releases/download/5.5.0a/sgminer-5.5.0-nicehash-46-windows-amd64.zip" -OutFile $FileName -UseBasicParsing
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
    Lyra2RE2 = 'lyra2rev2'
    Skein = 'skeincoin'
    Qubit = 'qubitcoin'
    NeoScrypt = 'neoscrypt'
    X11 = 'darkcoin-mod'
    MyriadGroestl = 'myriadcoin-groestl'
    Groestl = 'groestlcoin'
    Keccak = 'maxcoin'
    Scrypt = 'zuikkis'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'AMD'
        Path = $Path
        Arguments = -Join ('--api-listen -k ', $Algorithms.$_, ' -o $($Pools.Equihash.Protocol)://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Xgminer'
    }
}