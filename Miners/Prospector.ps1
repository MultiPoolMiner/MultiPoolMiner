﻿using module ..\Include.psm1

$Path = ".\Bin\Prospector\prospector.exe"
$HashSHA256 = "7DA74533F67707BFE7FA12F8885A97A79F079DD58A30F039E63D7680CFE47CF1"
$Uri = "https://github.com/semtexzv/Prospector/releases/download/0.0.13-ALPHA/prospector-0.0.13-ALPHA-win64.zip"

$Commands = [PSCustomObject]@{
    "eth"  = @() #Ethash
    "sigt" = @() #Skunk
    # "xmr"  = @() #CryptoNight is ASIC territory
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 42000

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    try {
        if (Test-Path (Split-Path $Path)) {
            "[general]
gpu-coin = ""$_""
[pools.$_]
url = ""stratum+tcp://$($Pools.$(Get-Algorithm $_).Host):$($Pools.$(Get-Algorithm $_).Port)/""
username = ""$($Pools.$(Get-Algorithm $_).User)""
password = ""$($Pools.$(Get-Algorithm $_).Pass)""
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))-0]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))-1]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))-2]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))-3]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))-4]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))-5]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'NVIDIA Corporation'))-0]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'NVIDIA Corporation'))-1]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'NVIDIA Corporation'))-2]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'NVIDIA Corporation'))-3]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'NVIDIA Corporation'))-4]
enabled = true
[gpus.$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'NVIDIA Corporation'))-5]
enabled = true
[cpu]
enabled = false" | Set-Content "$(Split-Path $Path)\$($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_)_$($Pools.$(Get-Algorithm $_).User).toml" -Force -ErrorAction Stop
        }
        
        [PSCustomObject]@{
            Type = "AMD", "NVIDIA"
            Path = $Path
            HashSHA256 = $HashSHA256
            Arguments = "-c $($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_)_$($Pools.$(Get-Algorithm $_).User).toml"
            HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
            API = "Prospector"
            Port = $Port
            URI = $Uri
        }

        if ($_ -eq "eth") {
            [PSCustomObject]@{
                Type = "AMD", "NVIDIA"
                Path = $Path
                HashSHA256 = $HashSHA256
                Arguments = "-c $($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_)2gb_$($Pools.$(Get-Algorithm $_).User).toml"
                HashRates = [PSCustomObject]@{"$(Get-Algorithm $_)2gb" = $Stats."$($Name)_$(Get-Algorithm $_)2gb_HashRate".Week}
                API = "Prospector"
                Port = $Port
                URI = $Uri
            }
        }
    }
    catch {
    }
}