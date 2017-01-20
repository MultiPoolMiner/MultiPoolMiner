$Path = '.\Bin\all-in-one-miner-20160728\AMD\sgminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "20160728.zip"
    try
    {
        if(Test-Path $FileName)
        {
            Remove-Item $FileName
        }
        Invoke-WebRequest "https://github.com/miningpoolhub/all-in-one-miner/archive/20160728.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName -DestinationPath '.\Bin\' 
    }
    catch
    {
        return
    }
}

Get-ChildItem -Path ".\Bin\all-in-one-miner-20160728\AMD\kernel\*.cl" -Recurse | Move-Item -Destination ".\Bin\all-in-one-miner-20160728\AMD" -Force

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
	Qubit = 'qubitcoin'
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