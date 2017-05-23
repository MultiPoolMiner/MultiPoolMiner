$ThreadIndex = 3
$Threads = 2

$Path = ".\Bin\Excavator\excavator.exe"
$Uri = 'https://github.com/nicehash/excavator/releases/'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    #Decred = 'decred'
    #Pascal = 'pascal'
    Equihash = 'equihash'
    Sia = 'sia'
}

$Port = 3456+($ThreadIndex*10000)

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    try
    {
        $Config = Get-Content "$(Split-Path $Path)\default_command_file.json" -ErrorAction Stop | ConvertFrom-Json
        $Config[0].commands[0].params[0] = $Algorithms.$_
        $Config[0].commands[0].params[1] = "$($Pools.$_.Host):$($Pools.$_.Port)"
        $Config[0].commands[0].params[2] = "$($Pools.$_.User):$($Pools.$_.Pass)"
        $Config[1].commands = @(@{id = 1; method = "worker.add"; params = @("0","$ThreadIndex")})*$Threads
        ($Config | ConvertTo-Json -Depth 10) | Set-Content "$(Split-Path $Path)\$_$ThreadIndex.json"
    }
    catch
    {
    }

    [PSCustomObject]@{
        Type = 'AMD','NVIDIA'
        Path = $Path
        Arguments = -Join ('-p ', $Port, ' -c ', $_, $ThreadIndex, '.json')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Week)')}
        API = 'NiceHash'
        Port = $Port
        Wrap = $false
        URI = $Uri
        Device = 'GPU#{0:d2}' -f $ThreadIndex
    }
}