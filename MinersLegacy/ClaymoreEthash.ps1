using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\AMD_NVIDIA-Claymore-Ethash\EthDcrMiner64.exe"
$HashSHA256 = "41FDBE471F168CB82A2931DCB009CA236DC8280C808F29F415DDE3A86939D4B4"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/ClaymoreDual_v11.8.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=1433925.0"
$Port = "50{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash2GB
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash2GB/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash2GB/Blake2s60
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash2GB/Blake2s80
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash2GB/Decred40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 70; Params = ""} #Ethash2GB/Decred70
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 100; Params = ""} #Ethash2GB/Decred100
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 20; Params = ""} #Ethash2GB/Keccak20
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash2GB/Keccak30
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 40; Params = ""} #Ethash2GB/Keccak40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 60; Params = ""} #Ethash2GB/Lbry60
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 75; Params = ""} #Ethash2GB/Lbry75
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 90; Params = ""} #Ethash2GB/Lbry90
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 40; Params = ""} #Ethash2GB/Pascal40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 60; Params = ""} #Ethash2GB/Pascal60
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 80; Params = ""} #Ethash2GB/Pascal80
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash3GB
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash3GB/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash3GB/Blake2s60
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash3GB/Blake2s80
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash3GB/Decred40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 70; Params = ""} #Ethash3GB/Decred70
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 100; Params = ""} #Ethash3GB/Decred100
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 20; Params = ""} #Ethash3GB/Keccak20
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash3GB/Keccak30
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 40; Params = ""} #Ethash3GB/Keccak40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 60; Params = ""} #Ethash3GB/Lbry60
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 75; Params = ""} #Ethash3GB/Lbry75
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 90; Params = ""} #Ethash3GB/Lbry90
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 40; Params = ""} #Ethash3GB/Pascal40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 60; Params = ""} #Ethash3GB/Pascal60
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 80; Params = ""} #Ethash3GB/Pascal80
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s60
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash/Blake2s80
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred40
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 70; Params = ""} #Ethash/Decred70
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 100; Params = ""} #Ethash/Decred100
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 20; Params = ""} #Ethash/Keccak20
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash/Keccak30
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 40; Params = ""} #Ethash/Keccak40
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 60; Params = ""} #Ethash/Lbry60
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 75; Params = ""} #Ethash/Lbry75
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 90; Params = ""} #Ethash/Lbry90
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 40; Params = ""} #Ethash/Pascal40
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 60; Params = ""} #Ethash/Pascal60
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 80; Params = ""} #Ethash/Pascal80
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = @($Devices | Where-Object Type -EQ "GPU")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {$Arguments_Platform = " -platform 1 -y 1"}
        "NVIDIA Corporation" {$Arguments_Platform = " -platform 2"}
        Default {$Arguments_Platform = ""}
    }

    $Commands | ForEach-Object {
        $Main_Algorithm = $_.MainAlgorithm
        $Main_Algorithm_Norm = Get-Algorithm $Main_Algorithm
        $MinMemGB = $_.MinMemGB

        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMemGB * 1000000000})

        if ($Arguments_Platform -and $Miner_Device) {
            if ($_.SecondaryAlgorithm) {
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                $Miner_Name = (@($Name) + @("$($Main_Algorithm_Norm -replace '^ethash', '')$Secondary_Algorithm_Norm") + @(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity}) + @("$($Miner_Device.count)x$($Miner_Device.Model_Norm | Sort-Object -unique)") | Select-Object) -join '-'

                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; "$Secondary_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary = " -dcoin $Secondary_Algorithm -dpool $($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpsw $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -dcri $($_.SecondaryIntensity)"})"
                $ExtendInterval = 2

                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 2000000000}) {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 1.5 / 100; "$Secondary_Algorithm_Norm" = 0 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0 / 100; "$Secondary_Algorithm_Norm" = 0 / 100}
                }
            }
            else {
                $Miner_Name = ((@($Name) + @("$($Main_Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"

                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary = ""
                $ExtendInterval = 1

                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 2000000000}) {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 1 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0 / 100}
                }
            }

            [PSCustomObject]@{
                Name           = $Miner_Name
                DeviceName     = $Miner_Device.Name
                Path           = $Path
                HashSHA256     = $HashSHA256
                Arguments      = ("-mport -$Miner_Port -epool $($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -ewal $($Pools.$Main_Algorithm_Norm.User) -epsw $($Pools.$Main_Algorithm_Norm.Pass) -allpools 1 -allcoins exp -esm 3$Arguments_Secondary$($_.Params)$Arguments_Platform$CommonCommands -di $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
                HashRates      = $Miner_HashRates
                API            = "Claymore"
                Port           = $Miner_Port
                URI            = $Uri
                Fees           = $Miner_Fees
                ExtendInterval = $ExtendInterval
            }
        }
    }
}
