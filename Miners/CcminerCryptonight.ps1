$Path = '.\Bin\Cryptonight\ccminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "ccminer_cryptonight.zip"
    try
    {
        if(Test-Path $FileName){Remove-Item $FileName}
        Invoke-WebRequest "https://github.com/nicehash/ccminer-cryptonight/releases/download/v1.0.0/ccminer.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName (Split-Path $Path)
    }
    catch
    {
        return
    }
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Cryptonight = 'cryptonight'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'NVIDIA'
        Path = $Path
        Arguments = -Join ('-o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Ccminer'
        Port = 4068
    }
}