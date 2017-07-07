. .\Include.ps1

$ThreadIndex = 0
$Threads = 2

$Path = ".\Bin\Excavator\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/"

$Commands = [PSCustomObject]@{
    "decred" = @() #Decred
    "daggerhashimoto" = @() #Ethash
    "equihash" = @() #Equihash
    "pascal" = @() #Pascal
    "sia" = @() #Sia
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$Port = 3456 + ($ThreadIndex * 10000)

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$($Pools.$_.Host):$($Pools.$_.Port)", "$($Pools.$_.User):$($Pools.$_.Pass)")})},
    [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$ThreadIndex") + $Commands.$_}) * $Threads},
    [PSCustomObject]@{time = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$_$ThreadIndex.json" -Force -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Type = "AMD", "NVIDIA"
        Path = $Path
        Arguments = "-p $Port -c $_$ThreadIndex.json"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "NiceHash"
        Port = $Port
        Wrap = $false
        URI = $Uri
        Device = "GPU#{0:d2}" -f $ThreadIndex
    }

    if ($_ -eq "daggerhashimoto") {
        [PSCustomObject]@{
            Type = "AMD", "NVIDIA"
            Path = $Path
            Arguments = "-p $Port -c $_$ThreadIndex.json"
            HashRates = [PSCustomObject]@{"$(Get-Algorithm($_))2gb" = $Stats."$($Name)_$(Get-Algorithm($_))2gb_HashRate".Week}
            API = "NiceHash"
            Port = $Port
            Wrap = $false
            URI = $Uri
            Device = "GPU#{0:d2}" -f $ThreadIndex
        }
    }
}