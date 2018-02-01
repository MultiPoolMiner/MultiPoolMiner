using module ..\Include.psm1

$Threads = 2

$Path = ".\Bin\NVIDIA-Excavator_142a\excavator.exe"
#$Uri = "https://github.com/nicehash/excavator/releases/tag/v1.4.2a"

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "blake2s"         = @() #Blake2s
    "cryptonight"     = @() #Cryptonight
    "decred"          = @() #Decred
    "daggerhashimoto" = @() #Ethash
    "equihash"        = @() #Equihash
    "neoscrypt"       = @() #NeoScrypt
    "nist5"           = @() #Nist5
    "keccak"          = @() #Keccak
    "lbry"            = @() #Lbry
    "lyra2rev2"       = @() #Lyra2RE2
    "pascal"          = @() #Pascal
    "sia"             = @() #Sia
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$API = "Nicehash"
$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where-Object {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {
    $Device = $_

    if ($Devices.count -gt 1 ){
        $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Device.Device_Norm)"
        $Index = $Device.Devices -join ","
    }

    $APIPort = $Port++
    
    $CommonCommands = " -f 6 -wp $($APIPort)"

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name} | ForEach-Object {

        $Algorithm = Get-Algorithm($_)
        $Command = $Commands.$_

        try {

            if ($Algorithm -ne "Decred" -and $Algorithm -ne "Sia") {

                $PoolIpAddress = ([System.Net.Dns]::GetHostAddresses($Pools.$($Algorithm).Host)[0]).IPAddressToString

                [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$($PoolIpAddress):$($Pools.$($Algorithm).Port)", "$($Pools.$($Algorithm).User):$($Pools.$($Algorithm).Pass)")})},
                [PSCustomObject]@{time = 1; commands = @($Device.Devices | Foreach {[PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$_") + $Commands.$Algorithm}}) * $Threads},
                [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools.$($Algorithm).Name)_$($Algorithm)_$($Threads)_Nvidia_$($Device.Device_Norm).json" -Force -ErrorAction SilentlyContinue

                [PSCustomObject]@{
                    Name         = $Name
                    Type         = $Device.Type
                    Device       = $Device.Device
                    Path         = $Path
                    Arguments    = ("-p $Port -c $($Pools.$Algorithm.Name)_$($Algorithm)_$($Threads)_Nvidia_$($Device.Device_Norm).json -na $CommonCommands").trim()
                    HashRates    = [PSCustomObject]@{$Algorithm = $Stats."$($Name)_$($Algorithm)_HashRate".Week}
                    API          = $API
                    Port         = $Port
                    URI          = $Uri
                    PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
                    ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
                    Pool         = $($Pools.$Algorithm.Name)
                    Index        = $Index
                }
            }
            else {
                $PoolIpAddress = ([System.Net.Dns]::GetHostAddresses($Pools."$($Algorithm)Nicehash".Host)[0]).IPAddressToString

                [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$($PoolIpAddress):$($Pools."$($Algorithm)NiceHash".Port)", "$($Pools."$($Algorithm)NiceHash".User):$($Pools."$($Algorithm)NiceHash".Pass)")})},
                [PSCustomObject]@{time = 3; commands = @($Device.$Devices | Foreach {[PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$_") + $Commands.$Algorithm}}) * $Threads},
                [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools."$($Algorithm)NiceHash".Name)_$($Algorithm)Nicehash_$($Threads)_Nvidia_$($Device.Device_Norm).json" -Force -ErrorAction SilentlyContinue

                [PSCustomObject]@{
                    Name         = $Name
                    Type         = $Device.Type
                    Device       = $Device.Device
                    Path         = $Path
                    Arguments    = ("-p $Port -c $($Pools."$($Algorithm)NiceHash".Name)_$($Algorithm)Nicehash_$($Threads)_Nvidia_$($Device.Device_Norm).json -na $CommonCommands").trim()
                    HashRates    = [PSCustomObject]@{"$($Algorithm)NiceHash" = $Stats."$($Name)_$($Algorithm)NiceHash_HashRate".Week}
                    API          = $API
                    Port         = $Port
                    URI          = $Uri
                    PowerDraw    = $Stats."$($Name)_$($Algorithm)Nicehash_PowerDraw".Week
                    ComputeUsage = $Stats."$($Name)_$($Algorithm)Nicehash_ComputeUsage".Week
                    Pool         = $Pools."$($Algorithm)Nicehash".Name
                    Index        = $Index
                }
            }
        }
        catch {}
    }
    if ($APIPort) {$Port = $APIPort +1}
}