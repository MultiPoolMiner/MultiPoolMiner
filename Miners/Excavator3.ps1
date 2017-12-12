using module ..\Include.psm1

$Threads = 3

$Path = ".\Bin\Excavator\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/"

$Commands = [PSCustomObject]@{
    #"blake2s" = @() #Blake2s
    "decred" = @() #Decred
    "daggerhashimoto" = @() #Ethash
    "equihash" = @() #Equihash
    #"lbry" = @() #Lbry
    #"lyra2rev2" = @() #Lyra2RE2
    "pascal" = @() #Pascal
    "sia" = @() #Sia
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3456 + (0 * 10000)

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    try {
        if ((Get-Algorithm $_) -ne "Decred" -and (Get-Algorithm $_) -ne "Sia") {
            if ((Test-Path (Split-Path $Path)) -and $Pools.$(Get-Algorithm $_).Host) {
                [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$([Net.DNS]::Resolve($Pools.$(Get-Algorithm $_).Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$(Get-Algorithm $_).Port)", "$($Pools.$(Get-Algorithm $_).User):$($Pools.$(Get-Algorithm $_).Pass)")})},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "0") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "1") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "2") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "3") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "4") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "5") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_)_$($Pools.$(Get-Algorithm $_).User)_$($Threads).json" -Force -ErrorAction Stop
            }

            [PSCustomObject]@{
                Type = "AMD", "NVIDIA"
                Path = $Path
                Arguments = "-p $Port -c $($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_)_$($Pools.$(Get-Algorithm $_).User)_$($Threads).json"
                HashRates = [PSCustomObject]@{$(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
                API = "NiceHash"
                Port = $Port
                Wrap = $false
                URI = $Uri
                PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
            }
        }
        else {
            if ((Test-Path (Split-Path $Path)) -and $Pools."$(Get-Algorithm $_)NiceHash".Host) {
                [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$([Net.DNS]::Resolve($Pools."$(Get-Algorithm $_)NiceHash".Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools."$(Get-Algorithm $_)NiceHash".Port)", "$($Pools."$(Get-Algorithm $_)NiceHash".User):$($Pools."$(Get-Algorithm $_)NiceHash".Pass)")})},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "0") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "1") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "2") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "3") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "4") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "5") + $Commands.$_}) * $Threads},
                [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools."$(Get-Algorithm $_)NiceHash".Name)_$(Get-Algorithm $_)_$($Pools."$(Get-Algorithm $_)NiceHash".User)_$($Threads).json" -Force -ErrorAction Stop
            }

            [PSCustomObject]@{
                Type = "AMD", "NVIDIA"
                Path = $Path
                Arguments = "-p $Port -c $($Pools."$(Get-Algorithm $_)NiceHash".Name)_$(Get-Algorithm $_)_$($Pools."$(Get-Algorithm $_)NiceHash".User)_$($Threads).json"
                HashRates = [PSCustomObject]@{"$(Get-Algorithm $_)NiceHash" = $Stats."$($Name)_$(Get-Algorithm $_)NiceHash_HashRate".Week}
                API = "NiceHash"
                Port = $Port
                Wrap = $false
                URI = $Uri
                PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
            }
        }
    }
    catch {
    }
}