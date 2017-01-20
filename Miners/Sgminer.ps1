$Path = '.\Bin\AMD\sgminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "sgminer.zip"
    try
    {
        if(Test-Path $FileName){Remove-Item $FileName}
        if(Test-Path "$(Split-Path (Split-Path $Path))\AMD"){Remove-Item "$(Split-Path (Split-Path $Path))\AMD" -Recurse}
        if(Test-Path "$(Split-Path (Split-Path $Path))\sgminer-gm"){Remove-Item "$(Split-Path (Split-Path $Path))\sgminer-gm" -Recurse}
        Invoke-WebRequest "https://github.com/genesismining/sgminer-gm/releases/download/5.5.4/sgminer-gm.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName (Split-Path (Split-Path $Path))
        Rename-Item "$(Split-Path (Split-Path $Path))\sgminer-gm" "AMD"
    }
    catch
    {
        return
    }
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Equihash = 'equihash'
    Cryptonight = 'cryptonight'
    Ethash = 'ethash'
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
        Port = 4028
    }
}