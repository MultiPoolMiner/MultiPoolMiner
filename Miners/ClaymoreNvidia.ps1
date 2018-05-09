using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$HashSHA256 = "11743A7B0F8627CEB088745F950557E303C7350F8E4241814C39904278204580"
$Type = "NVIDIA"
$API = "Claymore"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/Claymore.s.Dual.Ethereum.Decred_Siacoin_Lbry_Pascal_Blake2s_Keccak.AMD.NVIDIA.GPU.Miner.v11.7.-.Catalyst.15.12-18.x.-.CUDA.8.0_9.1_7.5_6.5.zip"
$Port = 23333
$MinerFeeInPercentSingleMode = 1.0
$MinerFeeInPercentDualMode = 1.5
$Commands = [PSCustomObject]@{
    "ethash" = ""
    "ethash2gb" = ""
    "ethash;blake2s:40" = ""
    "ethash;blake2s:60" = ""
    "ethash;blake2s:80" = ""
    "ethash;decred:100" = ""
    "ethash;decred:130" = ""
    "ethash;decred:160" = ""
    "ethash;keccak:70" = ""
    "ethash;keccak:90" = ""
    "ethash;keccak:110" = ""
    "ethash;lbry:60" = ""
    "ethash;lbry:75" = ""
    "ethash;lbry:90" = ""
    "ethash;pascal:40" = ""
    "ethash;pascal:60" = ""
    "ethash;pascal:80" = ""
    "ethash;pascal:100" = ""
    "ethash2gb;blake2s:75" = ""
    "ethash2gb;blake2s:100" = ""
    "ethash2gb;blake2s:125" =  ""
    "ethash2gb;decred:100" = ""
    "ethash2gb;decred:130" = ""
    "ethash2gb;decred:160" = ""
    "ethash2gb;keccak:70" = ""
    "ethash2gb;keccak:90" = ""
    "ethash2gb;keccak:110" = ""
    "ethash2gb;lbry:60" = ""
    "ethash2gb;lbry:75" = ""
    "ethash2gb;lbry:90" = ""
    "ethash2gb;pascal:40" = ""
    "ethash2gb;pascal:60" = ""
    "ethash2gb;pascal:80" = ""
}
$CommonCommands = @(" -logsmaxsize 1", "") # array, first value for main algo, second value for secondary algo

$DeviceIDs4gb = @() # array of all devices with more than 4MiB VRAM, ids will be in hex format
$DeviceIDs3gb = @() # array of all devices with more than 3MiB VRAM, ids will be in hex format
$DeviceIDsAll = @() # array of all devices, ids will be in hex format
$DeviceID = 0
# Get device list
[OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)} | Where-Object {$_.Type -eq 'GPU' -and $_.Vendor -eq 'NVIDIA Corporation'} | ForEach-Object {
    # Get DeviceIDs, filter out all disabled hw models and IDs
    if ($Config.Miners.IgnoreDeviceIDs -notcontains $DeviceID -and $Config.Miners.IgnoreHWModel -inotcontains ((Get-Culture).TextInfo.ToTitleCase($_.Name) -replace "[^A-Z0-9]")) {
        if ($IgnoreDeviceIDs -notcontains $DeviceID -and $IgnoreHWModel -inotcontains ((Get-Culture).TextInfo.ToTitleCase($_.Name) -replace "[^A-Z0-9]")) {
            $DeviceIDsAll += [Convert]::ToString($DeviceID, 16)
            if ($_.GlobalMemsize -ge 3000000000) {$DeviceIDs3gb += [Convert]::ToString($DeviceID, 16)}
            if ($_.GlobalMemsize -ge 4000000000) {$DeviceIDs4gb += [Convert]::ToString($DeviceID, 16)}
        }
    }
    $DeviceID++
}

$Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $MainAlgorithm = $_.Split(";") | Select -Index 0
    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm
    
    Switch ($MainAlgorithm_Norm) { # default is all devices, ethash has a 4GB minimum memory limit
        "Ethash"    {$DeviceIDs = $DeviceIDs4gb}
        "Ethash3gb" {$DeviceIDs = $DeviceIDs3gb}
        default     {$DeviceIDs = $DeviceIDsAll}
    }

    if ($Pools.$MainAlgorithm_Norm -and $DeviceIDs) { # must have a valid pool to mine and available devices

        $Miner_Name = $Name
        $MainAlgorithmCommands = $Commands.$_.Split(";") | Select -Index 0 # additional command line options for main algorithm
        $SecondaryAlgorithmCommands = $Commands.$_.Split(";") | Select -Index 1 # additional command line options for secondary algorithm

        if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = "3"} else {$EthereumStratumMode = "2"} #Optimize stratum compatibility

        if ($_ -notmatch ";") { # single algo mining
            $Miner_Name = "$($Miner_Name)$($MainAlgorithm_Norm -replace '^ethash', '')"
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)

            $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $MinerFeeInPercentSingleMode / 100)
            $Fees = @($MinerFeeInPercentSingleMode)

            # Single mining mode
            [PSCustomObject]@{
                Name      = $Miner_Name
                Type      = $Type
                Path      = $Path
                HashSHA256 = $HashSHA256
                Arguments = ("-mode 1 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 0) -esm $EthereumStratumMode -allpools 1 -allcoins 1 -platform 2 -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                API       = $Api
                Port      = $Port
                URI       = $Uri
                Fees      = $Fees
            }
        }
        elseif ($_ -match "^.+;.+:\d+$") { # valid dual mining parameter set

            $SecondaryAlgorithm = ($_.Split(";") | Select -Index 1).Split(":") | Select -Index 0
            $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm
            $SecondaryAlgorithmIntensity = ($_.Split(";") | Select -Index 1).Split(":") | Select -Index 1
        
            $Miner_Name = "$($Miner_Name)$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondaryAlgorithm_Norm)$($SecondaryAlgorithmIntensity)"
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)
            $HashRateSecondaryAlgorithm = ($Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week)

            #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee
            $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $MinerFeeInPercentDualMode / 100)
            $Fees = @($MinerFeeInPercentDualMode, 0)

            if ($Pools.$SecondaryAlgorithm_Norm -and $SecondaryAlgorithmIntensity -gt 0) { # must have a valid pool to mine and positive intensity
                # Dual mining mode
                [PSCustomObject]@{
                    Name      = $Miner_Name
                    Type      = $Type
                    Path      = $Path
                    HashSHA256 = $HashSHA256
                    Arguments = ("-mode 0 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 1) -esm $EthereumStratumMode -allpools 1 -allcoins 1 -dcoin $SecondaryAlgorithm -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommand$($CommonCommands | Select -Index 1) -platform 2 -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                    HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                    API       = $Api
                    Port      = $Port
                    URI       = $Uri
                    Fees      = $Fees
                }
                if ($SecondaryAlgorithm_Norm -eq "Sia" -or $SecondaryAlgorithm_Norm -eq "Decred") {
                    $SecondaryAlgorithm_Norm = "$($SecondaryAlgorithm_Norm)NiceHash"
                    [PSCustomObject]@{
                        Name      = $Miner_Name
                        Type      = $Type
                        Path      = $Path
                        HashSHA256 = $HashSHA256
                        Arguments = ("-mode 0 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 1) -esm $EthereumStratumMode -allpools 1 -allcoins 1 -dcoin $SecondaryAlgorithm -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommand$($CommonCommands | Select -Index 1) -platform 2 -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                        HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                        API       = $Api
                        Port      = $Port
                        URI       = $Uri
                        Fees      = $Fees
                    }
                }
            }
        }
    }
}
