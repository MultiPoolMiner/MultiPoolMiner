. .\Include.ps1

$Threads = 4

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
$Port = 3456 + (2 * 1000)

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$($Pools.$(Get-Algorithm($_)).Host):$($Pools.$(Get-Algorithm($_)).Port)", "$($Pools.$(Get-Algorithm($_)).User):$($Pools.$(Get-Algorithm($_)).Pass)")})},
    [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "0") + $Commands.$_}) * $Threads},
    [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "1") + $Commands.$_}) * $Threads},
    [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "2") + $Commands.$_}) * $Threads},
    [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "3") + $Commands.$_}) * $Threads},
    [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "4") + $Commands.$_}) * $Threads},
    [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "5") + $Commands.$_}) * $Threads},
    [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools.$(Get-Algorithm($_)).Name)_$(Get-Algorithm($_))_$($Threads)_Nvidia.json" -Force -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-p $Port -c $($Pools.$(Get-Algorithm($_)).Name)_$(Get-Algorithm($_))_$($Threads)_Nvidia.json -na"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "NiceHash"
        Port = $Port
        Wrap = $false
        URI = $Uri
    }
}