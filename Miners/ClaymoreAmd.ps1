﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$HashSHA256 = "11743A7B0F8627CEB088745F950557E303C7350F8E4241814C39904278204580"
$API = "Claymore"
$URI = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/ClaymoreDual_v11.7.zip"
$Port = 13333
$MinerFeeInPercentSingleMode = 1.0
$MinerFeeInPercentDualMode = 1.5
$Commands = [PSCustomObject]@{
    "ethash"               = @("")
    "ethash2gb"            = @("")
    "ethash;blake2s:40"    = @("", "")
    "ethash;blake2s:60"    = @("", "")
    "ethash;blake2s:80"    = @("", "")
    "ethash;decred:40"     = @("", "")
    "ethash;decred:70"     = @("", "")
    "ethash;decred:100"    = @("", "")
    "ethash;keccak:20"     = @("", "")
    "ethash;keccak:30"     = @("", "")
    "ethash;keccak:40"     = @("", "")
    "ethash;lbry:60"       = @("", "")
    "ethash;lbry:75"       = @("", "")
    "ethash;lbry:90"       = @("", "")
    "ethash;pascal:40"     = @("", "")
    "ethash;pascal:60"     = @("", "")
    "ethash;pascal:80"     = @("", "")
    "ethash2gb;blake2s:40" = @("", "")
    "ethash2gb;blake2s:60" = @("", "")
    "ethash2gb;blake2s:80" = @("", "")
    "ethash2gb;decred:40"  = @("", "")
    "ethash2gb;decred:70"  = @("", "")
    "ethash2gb;decred:100" = @("", "")
    "ethash2gb;keccak:20"  = @("", "")
    "ethash2gb;keccak:30"  = @("", "")
    "ethash2gb;keccak:40"  = @("", "")
    "ethash2gb;lbry:60"    = @("", "")
    "ethash2gb;lbry:75"    = @("", "")
    "ethash2gb;lbry:90"    = @("", "")
    "ethash2gb;pascal:40"  = @("", "")
    "ethash2gb;pascal:60"  = @("", "")
    "ethash2gb;pascal:80"  = @("", "")
}
$CommonCommands = @(" -logsmaxsize 1", "") # To be applied to all algorithms and intensities. Array: first value for main algo, second value for secondary algo

# Get array of IDs of all devices in device set, returned DeviceIDs are of base $DeviceIdBase representation starting from $DeviceIdOffset
$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc."

$Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $MainAlgorithm = $_.Split(";") | Select-Object -Index 0
    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

    Switch ($MainAlgorithm_Norm) {
        # default is all devices, ethash has a 4GB minimum memory limit
        "Ethash" {$Device = $Devices | Where-Object GlobalMemsize -GE 4000000000}
        "Ethash3gb" {$Device = $Devices | Where-Object GlobalMemsize -GE GlobalMemsize -ge 3000000000}
        default {$Device = $Devices}
    }

    if (($Pools.$MainAlgorithm_Norm -and $Device) -or $Config.InfoOnly) {
        # must have a valid pool to mine and available devices

        $Miner_Name = $Name
        $MainAlgorithmCommands = $Commands.$_ | Select-Object -Index 0 # additional command line options for main algorithm
        $SecondaryAlgorithmCommands = $Commands.$_ | Select-Object -Index 1 # additional command line options for secondary algorithm

        if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = " -esm 3"} else {$EthereumStratumMode = " -esm 2"} #Optimize stratum compatibility

        if ($_ -notmatch ";") {
            # single algo mining
            $Miner_Name = "$($Miner_Name)$($MainAlgorithm_Norm -replace '^ethash', '')"
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)

            if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
                $Fees = @($null)
            }
            else {
                if (-not ($Devices | Where-Object GlobalMemsize -GT 2000000000)) {
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
                Device     = $Device
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("-mode 1 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommands$($CommonCommands | Select-Object -Index 0)$EthereumStratumMode -allpools 1 -allcoins 1 -platform 1 -y 1 -di $(($Device | ForEach-Object {'{0:x}' -f $_.Type_Index}) -join '')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                API        = $Api
                Port       = $Port
                URI        = $Uri
                Fees       = $Fees
            }
        }
        elseif ($_ -match "^.+;.+:\d+$") {
            # valid dual mining parameter set
            # Dual mining mode
            $SecondaryAlgorithm = ($_.Split(";") | Select-Object -Index 1).Split(":") | Select-Object -Index 0
            $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm
            $SecondaryAlgorithmIntensity = ($_.Split(";") | Select-Object -Index 1).Split(":") | Select-Object -Index 1

            $Miner_Name = "$($Miner_Name)$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondaryAlgorithm_Norm)$($SecondaryAlgorithmIntensity)"
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)
            $HashRateSecondaryAlgorithm = ($Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week)

            if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
                $Fees = @($null)
            }
            else {
                if (-not ($Devices | Where-Object GlobalMemsize -GT 2000000000)) {
                    # All GPUs are 2GB, miner is completely free in this case, developer fee will not be mined at all.
                    $Fees = @($null)
                }
                else {
                    $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $MinerFeeInPercentDualMode / 100)
                    #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee
                    $Fees = @($MinerFeeInPercentDualMode, 0)
                }
            }

            if ($Pools.$SecondaryAlgorithm_Norm -and $SecondaryAlgorithmIntensity -gt 0) {
                # must have a valid pool to mine and positive intensity
                [PSCustomObject]@{
                    Name       = $Miner_Name
                    Device     = $Device
                    Path       = $Path
                    HashSHA256 = $HashSHA256
                    Arguments  = ("-mode 0 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommands$($CommonCommands | Select-Object -Index 0)$EthereumStratumMode -allpools 1 -allcoins exp -dcoin $SecondaryAlgorithm -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommands$($CommonCommands | Select-Object -Index 1) -platform 1 -di $(($Device | ForEach-Object {'{0:x}' -f $_.Type_Index}) -join '')" -replace "\s+", " ").trim()
                    HashRates  = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                    API        = $Api
                    Port       = $Port
                    URI        = $Uri
                    Fees       = $Fees
                }
            }
        }
    }
}
