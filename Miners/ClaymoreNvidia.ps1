using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config
)

# Hardcoded per miner version, do not allow user to change in config
$MinerFileVersion = "2018030500" #Format: YYYYMMMDD[TwoDigitCounter], higher value will trigger config file update
$MinerBinaryInfo =  "Claymore Dual Ethereum AMD/NVIDIA GPU Miner v11.2"
$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$Type = "NVIDIA"
$API = "Claymore"
$Uri = ""
$UriInfo = "Requires manual download and installation. See 'https://bitcointalk.org/index.php?topic=1433925.0'"

if (-not $Config.Miners.$Name.MinerFileVersion) {
    # Read existing config file, do not use $Config because variables are expanded (e.g. $Wallet)
    $NewConfig = Get-Content -Path 'config.txt' -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    
    # Create default miner config
    $NewConfig.Miners | Add-Member $Name ([PSCustomObject]@{
        "MinerFileVersion" = "$MinerFileVersion"
        "MinerBinaryInfo" = "$MinerBinaryInfo"
        "Uri" = "$Uri"
        "UriInfo" = "$UriInfo"
        "Type" = "$Type"
        "Path" = "$Path"
        "Port" = 23333
        "MinerFeeInPercentSingleMode" = 1.0
        "MinerFeeInPercentDualMode" = 1.5
        "MinerFeeInfo" = "Single mode: 1%, dual mode 1.5%, 2GB cards: 0%; Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee."
        #"IgnoreHWModel" = @("GPU Model Name", "GTX10603GB") # Currently unused, example only. Strings here should match GPU model name reformatted with (Get-Culture).TextInfo.ToTitleCase(($_.Name)) -replace "[^A-Z0-9]"
        #"IgnoreAmdGpuID" = @(0, 1) # Currently unused, example only
        #"IgnoreNvidiaGpuID" =  @(0, 1) # Currently unused, example only
        "Commands" = [PSCustomObject]@{
            "ethash" = ""
            "ethash2gb" = ""
            "ethash;blake2s;-dcoin blake2s -dcri 40" = ""
            "ethash;blake2s;-dcoin blake2s -dcri 60" = ""
            "ethash;blake2s;-dcoin blake2s -dcri 80" = ""
            "ethash;decred;-dcoin dcr -dcri 100" = ""
            "ethash;decred;-dcoin dcr -dcri 130" = ""
            "ethash;decred;-dcoin dcr -dcri 160" = ""
            "ethash;keccak;-dcoin keccak -dcri 70" = ""
            "ethash;keccak;-dcoin keccak -dcri 90" = ""
            "ethash;keccak;-dcoin keccak -dcri 110" = ""
            "ethash;lbry;-dcoin lbc -dcri 60" = ""
            "ethash;lbry;-dcoin lbc -dcri 75" = ""
            "ethash;lbry;-dcoin lbc -dcri 90" = ""
            "ethash;pascal;-dcoin pasc -dcri 40" = ""
            "ethash;pascal;-dcoin pasc -dcri 60" = ""
            "ethash;pascal;-dcoin pasc -dcri 80" = ""
            "ethash;pascal;-dcoin pasc -dcri 100" = ""
            "ethash2gb;blake2s;-dcoin blake2s -dcri 75" = ""
            "ethash2gb;blake2s;-dcoin blake2s -dcri 100" = ""
            "ethash2gb;blake2s;-dcoin blake2s -dcri 125" =  ""
            "ethash2gb;decred;-dcoin dcr -dcri 100" = ""
            "ethash2gb;decred;-dcoin dcr -dcri 130" = ""
            "ethash2gb;decred;-dcoin dcr -dcri 160" = ""
            "ethash2gb;keccak;-dcoin keccak -dcri 70" = ""
            "ethash2gb;keccak;-dcoin keccak -dcri 90" = ""
            "ethash2gb;keccak;-dcoin keccak -dcri 110" = ""
            "ethash2gb;lbry;-dcoin lbc -dcri 60" = ""
            "ethash2gb;lbry;-dcoin lbc -dcri 75" = ""
            "ethash2gb;lbry;-dcoin lbc -dcri 90" = ""
            "ethash2gb;pascal;-dcoin pasc -dcri 40" = ""
            "ethash2gb;pascal;-dcoin pasc -dcri 60" = ""
            "ethash2gb;pascal;-dcoin pasc -dcri 80" = ""
        }
        "CommonCommands" = " -logsmaxsize 1"
    }) -Force

    # Save config to file
    $NewConfig | ConvertTo-Json -Depth 10 | Set-Content "config.txt" -Force -ErrorAction Stop
    # Apply config
    $Config = Get-ChildItemContent "Config.txt" -ErrorAction Stop | Select-Object -ExpandProperty Content
}
else {
    if ($MinerFileVersion -gt $Config.Miners.$Name.MinerFileVersion) {
        try {
            # Read existing config file, do not use $Config because variables are expanded (e.g. $Wallet)
            $NewConfig = Get-Content -Path 'Config.txt' | ConvertFrom-Json -InformationAction SilentlyContinue
            
            # Execute action, e.g force re-download of binary
            # Should be first action. If it fails no further update will take place, update will be retried on next loop
            if ($Uri) {
                if (Test-Path $Path) { Remove-Item $Path -Force -Confirm:$false -ErrorAction Stop } # Remove miner binary to forece re-download
                if (Test-Path ".\Stats\$($Name)_*_hashrate.txt") { Remove-Item ".\Stats\$($Name)_*_hashrate.txt" -Force -Confirm:$false -ErrorAction SilentlyContinue} # Remove benchmark files, could by fine grained to remove bm files for some algos
            }

            # Always update MinerFileVersion and download link, -Force to enforce setting
            $NewConfig.Miners.$Name | Add-member MinerFileVersion "$MinerFileVersion" -Force
            $NewConfig.Miners.$Name | Add-member Uri "$Uri" -Force

            # Remove config item if in existing config file, -ErrorAction SilentlyContinue to ignore errors if item does not exist
            $NewConfig.Miners.$Name | Foreach-Object {
                $_.Commands.PSObject.Properties.Remove("ethash;pascal;-dcoin pasc -dcri 20")
            } -ErrorAction SilentlyContinue

            # Add config item if not in existing config file, -ErrorAction SilentlyContinue to ignore errors if item exists
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash;pascal;-dcoin pasc -dcri 60" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash;pascal;-dcoin pasc -dcri 80" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash2gb;pascal;-dcoin pasc -dcri 40" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash2gb;pascal;-dcoin pasc -dcri 60" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash2gb;pascal;-dcoin pasc -dcri 80" "" -ErrorAction SilentlyContinue

            # Save config to file
            $NewConfig | ConvertTo-Json -Depth 10 | Set-Content "Config.txt" -Force -ErrorAction Stop
            # Apply config
            $Config = Get-ChildItemContent "Config.txt" | Select-Object -ExpandProperty Content
        }
        catch {}
    }
}

$Config.Miners.$Name.Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $Command = $Config.Miners.$Name.Commands.$_
    $MainAlgorithm = $_.Split(";") | Select -Index 0
    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

    if ($Pools.$($MainAlgorithm_Norm)) {
        
        $DcriCmd = $_.Split(";") | Select -Index 2
        
        if ($DcriCmd) {

            $Dcri = $DcriCmd.Split(" ") | Select -Index 3
            
            $SecondaryAlgorithm = $_.Split(";") | Select -Index 1
            $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm
        
            $MinerName = "$($Name)$($MainAlgorithm_Norm -replace '^ethash','')$($SecondaryAlgorithm_Norm)$($Dcri)"

            $HashRateMainAlgorithm = ($Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week)
            $HashRateSecondaryAlgorithm = ($Stats."$($MinerName)_$($SecondaryAlgorithm_Norm)_HashRate".Week)

            #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee.
            if($Config.Miners.SubtractMinerFees) {
                $HashRateMainAlgorithm = $HashRateMainAlgorithm * (100 - $Config.Miners.$Name.$MinerFeeInPercentDualMode)
            }

            if ($Pools.$($SecondaryAlgorithm_Norm)) {
                # Dual mining mode
                [PSCustomObject]@{
                    Name      = $MinerName
                    Type      = $Type
                    Path      = $Config.Miners.$Name.Path
                    Arguments = ("-mode 0 -mport -$($Config.Miners.$Name.Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2 $($DcriCmd) $Command $($Config.Miners.$Name.CommonCommands)" -replace "\s+", " ").trim()
                    HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                    API       = $Api
                    Port      = $Config.Miners.$Name.Port
                    URI       = $Uri
                }
                if ($SecondaryAlgorithm_Norm -eq "Sia" -or $SecondaryAlgorithm_Norm -eq "Decred") {
                    $SecondaryAlgorithm_Norm = "$($SecondaryAlgorithm_Norm)NiceHash"
                    [PSCustomObject]@{
                        Name      = $MinerName
                        Type      = $Type
                        Path      = $Config.Miners.$Name.Path
                        Arguments = ("-mode 0 -mport -$($Config.Miners.$Name.Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2 $($DcriCmd) $Command $($CommonCommands)" -replace "\s+", " ").trim()
                        HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                        API       = $Api
                        Port      = $Config.Miners.$Name.Port
                        URI       = $Uri
                    }
                }
            }
        }
        else {
            $MinerName = "$($Name)$($MainAlgorithm_Norm -replace '^ethash','')"
            $HashRateMainAlgorithm = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week)

            if($Config.Miners.SubtractMinerFees) {
                $HashRateMainAlgorithm = $HashRateMainAlgorithm * (100 - $Config.Miners.$Name.$MinerFeeInPercentSingleMode)
            }

            # Single mining mode
            [PSCustomObject]@{
                Name      = $MinerName
                Type      = $Type
                Path      = $Config.Miners.$Name.Path
                Arguments = ("-mode 1 -mport -$($Config.Miners.$Name.Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins 1 -platform 2 $Command $($Config.Miners.$Name.CommonCommands)" -replace "\s+", " ").trim()
                HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                API       = $Api
                Port      = $Config.Miners.$Name.Port
                URI       = $Uri
            }
        }
    }
}
