using module ..\Include.psm1

$Threads = 4

$Path = ".\Bin\NVIDIA-Excavator_138a\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.3.8a/excavator_v1.3.8a_NVIDIA_Win64.zip"

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "_blake2s"   = @() #Blake2s, Beaten by Ccminer-x11gost
    "_cryptonight"  = @() #Cryptonight, Beaten by XMRig Nvidia
    #"decred"   = @() #Decred
    "_daggerhashimoto" = @() #Ethash, 4 threads out of memory, Beaten by EthMiner
    "_equihash"   = @() #Equihash, Beaten by DSTM
    "_neoscrypt"  = @() #NeoScrypt, 4 threads out of memory
    "_keccak"   = @() #Keccak, Beaten by Excavator138aNvidia4
    "lbry"    = @() #Lbry, Beaten by Excavator138aNvidia4
    "_lyra2rev2"  = @() #Lyra2RE2, Beaten by Ccminer-Palgin_Nist5
    "pascal"   = @() #Pascal, Beaten by Excavator138aNvidia4
    "sia"    = @() #Sia
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$API = "Nicehash"
$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {
    $Device = $_

    if ($Devices.count -gt 1 ){
        $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Device.Device_Norm)"
        $Index = $Device.Devices -join ","
    }
    
    while ([Bool](Get-NetTCPConnection -State "Listen" -LocalPort $Port -ErrorAction SilentlyContinue)){$Port++} | Out-Null
    $APIPort = $Port++
    while ([Bool](Get-NetTCPConnection -State "Listen" -LocalPort $APIPort -ErrorAction SilentlyContinue)){$APIPort++} | Out-Null
    
    $CommonCommands = " -f 6 -wp $($APIPort)"

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name} | ForEach-Object {

        $Algorithm = Get-Algorithm($_)
        $Command = $Commands.$_

        try {

        if ($Algorithm -ne "Decred" -and $Algorithm -ne "Sia") {

            $PoolIpAddress = ([System.Net.Dns]::GetHostAddresses($Pools.$($Algorithm).Host)[0]).IPAddressToString

            [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$($PoolIpAddress):$($Pools.$($Algorithm).Port)", "$($Pools.$($Algorithm).User):$($Pools.$($Algorithm).Pass)")})},
            [PSCustomObject]@{time = 1; commands = @($Device.Devices | Foreach {[PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$_") + $Command}}) * $Threads},
            [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools.$($Algorithm).Name)_$($Algorithm)_$($Threads)_Nvidia_$($Device.Device_Norm).json" -Force -ErrorAction SilentlyContinue

            [PSCustomObject]@{
                Name         = $Name
                Type         = $Type
                Device       = $Device.Device
                Path         = $Path
                Arguments    = "-p $Port -c $($Pools.$Algorithm.Name)_$($Algorithm)_$($Threads)_Nvidia_$($Device.Device_Norm).json -na$CommonCommands"
                HashRates    = [PSCustomObject]@{$Algorithm = $Stats."$($Name)_$($Algorithm)_HashRate".Week}
                API          = $API
                Port         = $Port
                Wrap         = $false
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
            [PSCustomObject]@{time = 3; commands = @($Device.$Devices | Foreach {[PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$_") + $Command}}) * $Threads},
            [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools."$($Algorithm)NiceHash".Name)_$($Algorithm)Nicehash_$($Threads)_Nvidia_$($Device.Device_Norm).json" -Force -ErrorAction SilentlyContinue

            [PSCustomObject]@{
                Name         = $Name
                Type         = $Type
                Device       = $Device.Device
                Path         = $Path
                Arguments    = "-p $Port -c $($Pools."$($Algorithm)NiceHash".Name)_$($Algorithm)Nicehash_$($Threads)_Nvidia_$($Device.Device_Norm).json -na$CommonCommands"
                HashRates    = [PSCustomObject]@{"$($Algorithm)NiceHash" = $Stats."$($Name)_$($Algorithm)NiceHash_HashRate".Week}
                API          = $API
                Port         = $Port
                Wrap         = $false
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
Sleep 0
