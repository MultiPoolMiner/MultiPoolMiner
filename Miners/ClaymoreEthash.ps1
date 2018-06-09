using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$HashSHA256 = "11743A7B0F8627CEB088745F950557E303C7350F8E4241814C39904278204580"
$URI = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/ClaymoreDual_v11.7.zip"
$Port = "50{0:d2}"

$MinerFeeInPercentSingleMode = 1.0
$MinerFeeInPercentDualMode = 1.5

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = ""; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "blake2s"; Params = " -dcri 40"} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "blake2s"; Params = " -dcri 60"} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "blake2s"; Params = " -dcri 80"} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "decred"; Params = " -dcri 40"} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "decred"; Params = " -dcri 70"} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "decred"; Params = " -dcri 100"} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "keccak"; Params = " -dcri 20"} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "keccak"; Params = " -dcri 30"} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "keccak"; Params = " -dcri 40"} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "lbry"; Params = " -dcri 60"} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "lbry"; Params = " -dcri 75"} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "lbry"; Params = " -dcri 90"} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "pascal"; Params = " -dcri 40"} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "pascal"; Params = " -dcri 60"} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "pascal"; Params = " -dcri 80"} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = ""; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "blake2s"; Params = " -dcri 40"} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "blake2s"; Params = " -dcri 60"} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "blake2s"; Params = " -dcri 80"} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "decred"; Params = " -dcri 40"} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "decred"; Params = " -dcri 70"} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "decred"; Params = " -dcri 100"} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "keccak"; Params = " -dcri 20"} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "keccak"; Params = " -dcri 30"} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "keccak"; Params = " -dcri 40"} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "lbry"; Params = " -dcri 60"} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "lbry"; Params = " -dcri 75"} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "lbry"; Params = " -dcri 90"} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "pascal"; Params = " -dcri 40"} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "pascal"; Params = " -dcri 60"} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "pascal"; Params = " -dcri 80"} #Ethash/Pascal
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = $Devices | Where-Object Type -EQ "GPU"

$Miner_Port = $Port -f ($Devices | Where-Object Vendor -EQ "Advanced Micro Devices, Inc." | Select-Object -First 1 -ExpandProperty Index)

$CommonCommands = @(" -platform 1 -y 1", "")

$Commands | ForEach-Object {
    $MainAlgorithm = $_.MainAlgorithm
    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

    Switch ($MainAlgorithm_Norm) {
        # default is all devices, ethash has a 4GB minimum memory limit
        "Ethash" {$Device = $Devices | Where-Object Vendor -EQ "Advanced Micro Devices, Inc." | Where-Object {$_.OpenCL.GlobalMemsize -ge 4000000000}}
        "Ethash3gb" {$Device = $Devices | Where-Object Vendor -EQ "Advanced Micro Devices, Inc." | Where-Object {$_.OpenCL.GlobalMemsize -ge 3000000000}}
        default {$Device = $Devices | Where-Object Vendor -EQ "Advanced Micro Devices, Inc."}
    }

    if (($Pools.$MainAlgorithm_Norm -and $Device) -or $Config.InfoOnly) {
        if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = " -esm 3"} else {$EthereumStratumMode = " -esm 2"} #Optimize stratum compatibility

        if (-not $_.SecondaryAlgorithm) {
            # single algo mining
            $Miner_Name = (@($Name) + @($Device.Name | Sort-Object) | Select-Object) -join '-'
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)

            if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
                $Fees = @($null)
            }
            else {
                if (-not ($Devices | Where-Object {$_.OpenCL.GlobalMemsize -gt 2000000000})) {
                    # All GPUs are 2GB, miner is completely free in this case, developer fee will not be mined at all.
                    $Fees = @($null) 
                }
                else {
                    $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $MinerFeeInPercentSingleMode / 100)
                    #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee
                    $Fees = @($MinerFeeInPercentSingleMode)
                }
            }

            # Single mining mode
            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("-mode 1 -mport -$Miner_Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$EthereumStratumMode$($_.Params)$($CommonCommands | Select-Object -Index 0) -allpools 1 -allcoins 1 -di $(($Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                API        = "Claymore"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = $Fees
            }
        }
        elseif ($_.SecondaryAlgorithm) {
            # Dual mining mode
            $SecondaryAlgorithm = $_.SecondaryAlgorithm
            $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm

            $Miner_Name = (@("$Name$SecondaryAlgorithm_Norm") + @($Device.Name | Sort-Object) | Select-Object) -join '-'
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)
            $HashRateSecondaryAlgorithm = ($Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week)

            if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
                $Fees = @($null)
            }
            else {
                if (-not ($Devices | Where-Object {$_.OpenCL.GlobalMemsize -gt 2000000000})) {
                    # All GPUs are 2GB, miner is completely free in this case, developer fee will not be mined at all.
                    $Fees = @($null)
                }
                else {
                    $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $MinerFeeInPercentDualMode / 100)
                    #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee
                    $Fees = @($MinerFeeInPercentDualMode, 0)
                }
            }

            if ($Pools.$SecondaryAlgorithm_Norm) {
                # must have a valid pool to mine and positive intensity
                [PSCustomObject]@{
                    Name       = $Miner_Name
                    DeviceName = $Device.Name
                    Path       = $Path
                    HashSHA256 = $HashSHA256
                    Arguments  = ("-mode 0 -mport -$Miner_Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$EthereumStratumMode$($_.Params)$($CommonCommands | Select-Object -Index 0) -allpools 1 -allcoins exp -dcoin $SecondaryAlgorithm -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$($CommonCommands | Select-Object -Index 1) -di $(($Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
                    HashRates  = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                    API        = "Claymore"
                    Port       = $Miner_Port
                    URI        = $Uri
                    Fees       = $Fees
                }
            }
        }
    }
}

$Miner_Port = $Port -f ($Devices | Where-Object Vendor -EQ "NVIDIA Corporation" | Select-Object -First 1 -ExpandProperty Index)

$CommonCommands = @(" -platform 2", "")

$Commands | ForEach-Object {
    $MainAlgorithm = $_.MainAlgorithm
    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

    Switch ($MainAlgorithm_Norm) {
        # default is all devices, ethash has a 4GB minimum memory limit
        "Ethash" {$Device = $Devices | Where-Object Vendor -EQ "NVIDIA Corporation" | Where-Object {$_.OpenCL.GlobalMemsize -ge 4000000000}}
        "Ethash3gb" {$Device = $Devices | Where-Object Vendor -EQ "NVIDIA Corporation" | Where-Object {$_.OpenCL.GlobalMemsize -ge 3000000000}}
        default {$Device = $Devices | Where-Object Vendor -EQ "NVIDIA Corporation"}
    }

    if (($Pools.$MainAlgorithm_Norm -and $Device) -or $Config.InfoOnly) {
        if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = " -esm 3"} else {$EthereumStratumMode = " -esm 2"} #Optimize stratum compatibility

        if (-not $_.SecondaryAlgorithm) {
            # single algo mining
            $Miner_Name = (@($Name) + @($Device.Name | Sort-Object) | Select-Object) -join '-'
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)

            if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
                $Fees = @($null)
            }
            else {
                if (-not ($Devices | Where-Object {$_.OpenCL.GlobalMemsize -gt 2000000000})) {
                    # All GPUs are 2GB, miner is completely free in this case, developer fee will not be mined at all.
                    $Fees = @($null)
                }
                else {
                    $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $MinerFeeInPercentSingleMode / 100)
                    #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee
                    $Fees = @($MinerFeeInPercentSingleMode)
                }
            }

            # Single mining mode
            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("-mode 1 -mport -$Miner_Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$EthereumStratumMode$($_.Params)$($CommonCommands | Select-Object -Index 0) -allpools 1 -allcoins 1 -di $(($Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                API        = "Claymore"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = $Fees
            }
        }
        elseif ($_.SecondaryAlgorithm) {
            # Dual mining mode
            $SecondaryAlgorithm = $_.SecondaryAlgorithm
            $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm

            $Miner_Name = (@("$Name$SecondaryAlgorithm_Norm") + @($Device.Name | Sort-Object) | Select-Object) -join '-'
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)
            $HashRateSecondaryAlgorithm = ($Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week)

            if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
                $Fees = @($null)
            }
            else {
                if (-not ($Devices | Where-Object {$_.OpenCL.GlobalMemsize -gt 2000000000})) {
                    # All GPUs are 2GB, miner is completely free in this case, developer fee will not be mined at all.
                    $Fees = @($null)
                }
                else {
                    $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $MinerFeeInPercentDualMode / 100)
                    #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee
                    $Fees = @($MinerFeeInPercentDualMode, 0)
                }
            }

            if ($Pools.$SecondaryAlgorithm_Norm) {
                # must have a valid pool to mine and positive intensity
                [PSCustomObject]@{
                    Name       = $Miner_Name
                    DeviceName = $Device.Name
                    Path       = $Path
                    HashSHA256 = $HashSHA256
                    Arguments  = ("-mode 0 -mport -$Miner_Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$EthereumStratumMode$($_.Params)$($CommonCommands | Select-Object -Index 0) -allpools 1 -allcoins exp -dcoin $SecondaryAlgorithm -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$($CommonCommands | Select-Object -Index 1) -di $(($Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
                    HashRates  = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                    API        = "Claymore"
                    Port       = $Miner_Port
                    URI        = $Uri
                    Fees       = $Fees
                }
            }
        }
    }
}
