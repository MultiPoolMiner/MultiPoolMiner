$Path = '.\Bin\Equihash\nheqminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "nheqminer.zip"
    try
    {
        if(Test-Path $FileName){Remove-Item $FileName}
        Invoke-WebRequest "https://github.com/nicehash/nheqminer/releases/download/0.4b/nheqminer_v0.4b.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName (Split-Path $Path)
    }
    catch
    {
        return
    }
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Port = 3334

[PSCustomObject]@{
    Type = 'CPU'
    Path = $Path
    Arguments = '-a ' + $Port + ' -l $($Pools.Equihash.Host):$($Pools.Equihash.Port) -u $($Pools.Equihash.User)'
    HashRates = [PSCustomObject]@{Equihash = '$($Stats.' + $Name + '_Equihash_HashRate.Day)'}
    API = 'Nheqminer'
    Port = $Port
}