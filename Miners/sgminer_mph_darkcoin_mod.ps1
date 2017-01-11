$Path = '.\Bin\Sgminer_miningpoolhub\sgminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "sgminer-gm.zip"
    try
    {
        if(Test-Path $FileName)
        {
            Remove-Item $FileName
        }
        Invoke-WebRequest "https://github.com/genesismining/sgminer-gm/releases/download/5.5.4/sgminer-gm.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName (Split-Path (Split-Path $Path))
    }
    catch
    {
        return
    }
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
	X11 = 'darkcoin-mod'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'AMD'
        Path = $Path
        Arguments = -Join ('--api-listen -k ', $Algorithms.$_, ' -o $($Pools.Equihash.Protocol)://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x -I d --gpu-threads 2 -w 128')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Xgminer'
        Port = '4028'
    }
}