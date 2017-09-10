. .\Include.ps1

$Path = ".\Bin\Prospector\prospector.exe"
$Uri = "https://github.com/semtexzv/Prospector/releases/download/0.0.10-ALPHA/prospector-0.0.10-ALPHA-win64.zip"

$Commands = [PSCustomObject]@{
    #"xmr" = @() #CryptoNight
    "eth" = @() #Ethash
    "sia" = @() #Sia
    "sigt" = @() #Skunk
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$Port = 42000

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    try {
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
enabled = false" | Set-Content "$(Split-Path $Path)\$($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_).toml" -Force -ErrorAction Stop
    
        [PSCustomObject]@{
            Type = "AMD", "NVIDIA"
            Path = $Path
            Arguments = "-c $($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_).toml"
            HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
            API = "Prospector"
            Port = $Port
            Wrap = $false
            URI = $Uri
        }

        if ($_ -eq "eth") {
            [PSCustomObject]@{
                Type = "AMD", "NVIDIA"
                Path = $Path
                Arguments = "-c $($Pools.$(Get-Algorithm $_).Name)_$(Get-Algorithm $_)2gb.toml"
                HashRates = [PSCustomObject]@{"$(Get-Algorithm $_)2gb" = $Stats."$($Name)_$(Get-Algorithm $_)2gb_HashRate".Week}
                API = "Prospector"
                Port = $Port
                Wrap = $false
                URI = $Uri
            }
        }
    }
    catch {
    }
}