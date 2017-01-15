$Path = '.\Bin\gatelessgate-0.1.0-win64\gatelessgate.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "gatelessgate-0.1.0-win64.zip"
    try
    {
        if(Test-Path $FileName)
        {
            Remove-Item $FileName
        }
        Invoke-WebRequest "https://github.com/zawawawa/gatelessgate/releases/download/v0.1.0/gatelessgate-0.1.0-win64.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName -DestinationPath '.\Bin\' 
    }
    catch
    {
        return
    }
}


$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
	Equihash = 'equihash'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'AMD'
        Path = $Path
        Arguments = -Join ('--api-listen -k ', $Algorithms.$_, ' -o $($Pools.Equihash.Protocol)://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x --gpu-threads 2')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Xgminer'
        Port = '4028'
    }
}