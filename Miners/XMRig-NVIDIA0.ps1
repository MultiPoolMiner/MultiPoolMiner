using module ..\Include.psm1

$ThreadIndex = 0

$Path = ".\Bin\NVIDIA-XMRig$ThreadIndex\xmrig-nvidia.exe"
$Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.4.2/xmrig-nvidia-2.4.2-cuda9-win64.zip"

# Custom command to be applied to all algorithms
$CommonCommands = " --keepalive --donate-level=1"

# Uncomment outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "cryptonight"       = " --cuda-bfactor=10,8,6 --cuda-launch=64x72,53x64,16x77"
    "cryptonight-light" = ""
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
    $Devices | ForEach-Object {
        $Device = $_

        $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name} | ForEach-Object {

            $Algorithm = Get-Algorithm($_)
            $Command = $Commands.$_

            if ($Devices.count -gt 1 ){
                $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Device.Device_Norm)"
                $Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $Device.Devices) --cuda-devices=$($Device.Devices -join ',')"
                $Index = $Device.Devices -join ","
            }

            {while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

            if ($($Pools.$Algorithm.Host) -match ".+\.NiceHash\..+") {$Nicehash = " --nicehash"} else {$Nicehash = ""}

            [PSCustomObject]@{
                Name         = $Name
                Type         = "NVIDIA"
                Device       = $Device.Device
                Path         = $Path
                Arguments    = "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) --api-port=$port$NiceHash $Command $CommonCommands"
                HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
                API          = "XmRig"
                Port         = $Port
                Wrap         = $false
                URI	         = $Uri
                PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
                ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
                Pool         = "$($Pools.$Algorithm.Name)"
                Index        = $Index
            }
        }
        if ($Port) {$Port ++}
    }
sleep 0
