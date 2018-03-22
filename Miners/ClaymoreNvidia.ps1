using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

# Hardcoded per miner version, do not allow user to change in config
$MinerFileVersion = "2018032200" #Format: YYYYMMDD[TwoDigitCounter], higher value will trigger config file update
$MinerBinaryInfo =  "Claymore Dual Ethereum AMD/NVIDIA GPU Miner v11.5"
$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$Type = "NVIDIA"
$API = "Claymore"
$Uri = ""
$UriManual = "https://mega.nz/#F!O4YA2JgD!n2b4iSHQDruEsYUvTQP5_w"
$WebLink = "https://bitcointalk.org/index.php?topic=1433925.0" # See here for more information about the miner

# Create default miner config, required for setup
$DefaultMinerConfig = [PSCustomObject]@{
    "MinerFileVersion" = "$MinerFileVersion"
    "MinerBinaryInfo" = "$MinerBinaryInfo"
    "Uri" = "$Uri"
    "UriManual" = "$UriManual"
    "Type" = "$Type"
    "Path" = "$Path"
    "Port" = 23333
    "MinerFeeInPercentSingleMode" = 1.0
    "MinerFeeInPercentDualMode" = 1.5
    "MinerFeeInfo" = "Single mode: 1%, dual mode 1.5%, 2GB cards: 0%; Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee."
    #"IgnoreHWModel" = @("GPU Model Name", "Another GPU Model Name", e.g "GeforceGTX1070") # Available model names are in $Devices.$Type.Name_Norm, Strings here must match GPU model name reformatted with (Get-Culture).TextInfo.ToTitleCase(($_.Name)) -replace "[^A-Z0-9]"
    "IgnoreHWModel" = @()
    #"IgnoreDeviceID" = @(0, 1) # Available deviceIDs are in $Devices.$Type.DeviceIDs
    "IgnoreDeviceID" = @()
    "Commands" = [PSCustomObject]@{
        "ethash" = ""
        "ethash2gb" = ""
        "ethash;blake2s:40" = ""
        "ethash;blake2s:60" = ""
        "ethash;blake2s:80" = ""
        "ethash;decred:" = ""
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
    "CommonCommands" = " -eres 0 -logsmaxsize 1"
}

if (-not $Config.Miners.$Name.MinerFileVersion) {
    # Read existing config file, do not use $Config because variables are expanded (e.g. $Wallet)
    $NewConfig = Get-Content -Path 'config.txt' -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    # Apply default
    $NewConfig.Miners | Add-Member $Name $DefaultMinerConfig -Force
    # Save config to file
    $NewConfig | ConvertTo-Json -Depth 10 | Set-Content "config.txt" -Force -ErrorAction Stop
    # Apply config, must re-read from file to expand variables
    $Config = Get-ChildItemContent "Config.txt" -ErrorAction Stop | Select-Object -ExpandProperty Content
}
else {
    if ($MinerFileVersion -gt $Config.Miners.$Name.MinerFileVersion) {
        try {
            # Read existing config file, do not use $Config because variables are expanded (e.g. $Wallet)
            $NewConfig = Get-Content -Path 'Config.txt' | ConvertFrom-Json -InformationAction SilentlyContinue
            
            # Execute action, e.g force re-download of binary
            # Should be the first action. If it fails no further update will take place, update will be retried on next loop
            if ($Uri) {
                if (Test-Path $Path) {Remove-Item $Path -Force -Confirm:$false -ErrorAction Stop} # Remove miner binary to forece re-download
                # Remove benchmark files, could by fine grained to remove bm files for some algos
                # if (Test-Path ".\Stats\$($Name)_*_hashrate.txt") {Remove-Item ".\Stats\$($Name)_*_hashrate.txt" -Force -Confirm:$false -ErrorAction SilentlyContinue}
            }

            # Always update MinerFileVersion and download link, -Force to enforce setting
            $NewConfig.Miners.$Name | Add-member MinerFileVersion "$MinerFileVersion" -Force
            $NewConfig.Miners.$Name | Add-member Uri "$Uri" -Force

            # Remove config item if in existing config file, -ErrorAction SilentlyContinue to ignore errors if item does not exist
            $NewConfig.Miners.$Name | Foreach-Object {
                $_.Commands.PSObject.Properties.Remove("ethash;pascal:-dcoin pasc -dcri 20")
            } -ErrorAction SilentlyContinue

            # Add config item if not in existing config file, -ErrorAction SilentlyContinue to ignore errors if item exists
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash;pascal:60" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash;pascal:80" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash2gb;pascal:40" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash2gb;pascal:60" "" -ErrorAction SilentlyContinue
            $NewConfig.Miners.$Name.Commands | Add-Member "ethash2gb;pascal:80" "" -ErrorAction SilentlyContinue

            # Save config to file
            $NewConfig | ConvertTo-Json -Depth 10 | Set-Content "Config.txt" -Force -ErrorAction Stop
            # Apply config, must re-read from file to expand variables
            $Config = Get-ChildItemContent "Config.txt" | Select-Object -ExpandProperty Content
        }
        catch {}
    }
}

if ($Info) {
    # Just return info about the miner for use in setup
    # attributes without a curresponding settings entry are read-only by the GUI, to determine variable type use .GetType().FullName
    return [PSCustomObject]@{
        MinerFileVersion = $MinerFileVersion
        MinerBinaryInfo  = $MinerBinaryInfo
        Uri              = $Uri
        UriInfo          = $UriManual
        Type             = $Type
        Path             = $Path
        Port             = $Port
        WebLink          = $WebLink
        Settings         = @(
            [PSCustomObject]@{
                Name        = "Uri"
                Controltype = "string"
                Default     = $DefaultMinerConfig.Uri
                Info        = "MPM automatically downloads the miner binaries from this link and unpacks them.`nFiles stored on Google Drive or Mega links cannot be downloaded automatically.`n"
                Tooltip     = "If Uri is blank or is not a direct download link the miner binaries must be downloaded and unpacked manually (see README). "
            }
            [PSCustomObject]@{
                Name        = "UriManual"
                Controltype = "string"
                Default     = $DefaultMinerConfig.UriManual
                Info        = "Download link for manual miner binaries download.`nUnpack downloaded files to '$Path'."
                Tooltip     = "See README for manual download and unpack instruction."
            }
            [PSCustomObject]@{
                Name        = "MinerFeeInPercentSingleMode"
                Controltype = "double"
                Min         = 0
                Max         = 100
                Fractions   = 2
                Default     = $DefaultMinerConfig.MinerFeeInPercentSingleMode
                Info        = "Single mode: 1%, dual mode 1.5%, 2GB cards: 0%; Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee. "
                Tooltip     = "Fees will not be deducted if `$Miners.IgnoreMinerFees is set to 'true'"
            }
            [PSCustomObject]@{
                Name        = "MinerFeeInPercentDualMode"
                Controltype = "double"
                Min         = 0
                Max         = 100
                Fractions   = 2
                Default     = $DefaultMinerConfig.MinerFeeInPercentDualMode
                Info        = "Dual mode 1.5%, 2GB cards: 0%; Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee. "
                Tooltip     = "Fees will not be deducted if `$Miners.IgnoreMinerFees is set to 'true'"
            }
            [PSCustomObject]@{
                Name        = "IgnoreHWModel"
                Controltype = "string[]"
                Default     = $DefaultMinerConfig.IgnoreHWModel
                Info        = "List of hardware models you do not want to mine with this miner, e.g. 'GeforceGTX1070'.`nLeave empty to mine with all available hardware. "
                Tooltip     = "Detected $Type miner HW:`n$($Devices.$Type | ForEach-Object {"$($_.Name_Norm): DeviceIDs $($_.DeviceIDs -join ' ,')`n"})"
            }
            [PSCustomObject]@{
                Name        = "IgnoreDeviceID"
                Controltype = "int[]"
                Default     = $DefaultMinerConfig.IgnoreDeviceID
                Info        = "List of device IDs you do not want to mine with this miner, e.g. '0'.`nLeave empty to mine with all available hardware. "
                Tooltip     = "Detected $Type miner HW:`n$($Devices.$Type | ForEach-Object {"$($_.Name_Norm): DeviceIDs $($_.DeviceIDs -join ' ,')`n"})"
            }
            [PSCustomObject]@{
                Name        = "Commands"
                Controltype = "PSCustomObject"
                Default     = $DefaultMinerConfig.Commands
                Info        = "Each line defines an algorithm that can be mined with this miner.`nFor dual mining the two algorithms are separated with ';', intensity parameter for the secondary algorithm is defined after the ':'.`nOptional miner parameters can be added after the '=' sign. "
                Tooltip     = "Note: Most extra parameters must be prefixed with a space"
            }
            [PSCustomObject]@{
                Name        = "CommonCommands"
                Controltype = "string"
                Default     = $DefaultMinerConfig.CommonCommands
                Info        = "Optional miner parameter that gets appended to the resulting miner command line (for all algorithms). "
                Tooltip     = "Note: Most extra parameters must be prefixed with a space"
            }
        )
    }
}

# Get device list
$Devices.$Type | Where-Object {$Config.Miners.IgnoreHWModel -inotcontains $_.Name_Norm -or $Config.Miners.$Name.IgnoreHWModel -inotcontains $_.Name_Norm} | ForEach-Object {
    
    if ($DeviceTypeModel -and -not $Config.MinerInstancePerCardModel) {return} #after first loop $DeviceTypeModel is present; generate only one miner
    $DeviceTypeModel = $_
    $DeviceIDs = @() # array of all devices with more than 3MiB VRAM, ids will be in hex format
    $DeviceIDs2gb = @() # array of all devices, ids will be in hex format

    # Get DeviceIDs, filter out all disabled hw models and IDs
    if ($Config.MinerInstancePerCardModel -and (Get-Command "Get-CommandPerDevice" -ErrorAction SilentlyContinue)) { # separate miner instance per hardware model
        if ($Config.Miners.IgnoreHWModel -inotcontains $DeviceTypeModel.Name_Norm -and $Config.Miners.$Name.IgnoreHWModel -inotcontains $DeviceTypeModel.Name_Norm) {
            $DeviceTypeModel.DeviceIDs | Where-Object {$Config.Miners.IgnoreDeviceID -notcontains $_ -and $Config.Miners.$Name.IgnoreDeviceID -notcontains $_} | ForEach-Object {
                $DeviceIDs2gb += [Convert]::ToString($_, 16) # convert id to hex
                if ($DeviceTypeModel.GlobalMemsize -ge 3000000000) {$DeviceIDs += [Convert]::ToString($_, 16)} # convert id to hex
            }
        }
    }
    else { # one miner instance per hw type
        $Devices.$Type | Where-Object {$Config.Miners.IgnoreHWModel -inotcontains $_.Name_Norm -and $Config.Miners.$Name.IgnoreHWModel -inotcontains $_.Name_Norm} | ForEach-Object {
            $_.DeviceIDs | Where-Object {$Config.Miners.IgnoreDeviceID -notcontains $_ -and $Config.Miners.$Name.IgnoreDeviceID -notcontains $_} | ForEach-Object {
                $DeviceIDs2gb += [Convert]::ToString($_, 16) # convert id to hex
                if ($_.GlobalMemsize -ge 3000000000) {$DeviceIDs += [Convert]::ToString($_, 16)} # convert id to hex
            }
        }
    }

    $Config.Miners.$Name.Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

        $MainAlgorithm = $_.Split(";") | Select -Index 0
        $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm
        
        if ($MainAlgorithm_Norm -eq "Ethash2gb") {
            $DeviceIDs = $DeviceIDs2gb
        }

        if ($Pools.$MainAlgorithm_Norm -and $DeviceIDs) { # must have a valid pool to mine and available devices

            if ($Config.MinerInstancePerCardModel -and (Get-Command "Get-CommandPerDevice" -ErrorAction SilentlyContinue)) {
                $MinerName = "$Name-$($DeviceTypeModel.Name_Norm)"
                $MainAlgorithmCommands = Get-CommandPerDevice -Command ($Config.Miners.$Name.Commands.$_.Split(";") | Select -Index 0) -Devices $DeviceIDs # additional command line options for main algorithm
                $SecondaryAlgorithmCommands = Get-CommandPerDevice -Command ($Config.Miners.$Name.Commands.$_.Split(";") | Select -Index 1) -Devices $DeviceIDs # additional command line options for secondary algorithm
            }
            else {
                $MinerName = $Name
                $MainAlgorithmCommands = $Config.Miners.$Name.Commands.$_.Split(";") | Select -Index 0 # additional command line options for main algorithm
                $SecondaryAlgorithmCommands = $Config.Miners.$Name.Commands.$_.Split(";") | Select -Index 1 # additional command line options for secondary algorithm
            }    

            if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = "3"} else {$EthereumStratumMode = "2"} #Optimize stratum compatibility
            
            $MinerPort = $Config.Miners.$Name.Port + $Devices.$Type.IndexOf($DeviceTypeModel) # make port unique
            
            if ($_ -notmatch ";") { # single algo mining
                $MinerName = "$($MinerName)$($MainAlgorithm_Norm -replace '^ethash', '')"
                $HashRateMainAlgorithm = ($Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week)

                if ($Config.IgnoreMinerFees -or $Config.Miners.$Name.$MinerFeeInPercentSingleMode -eq 0) {
                    $Fees = @($null)
                }
                else {
                    $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $Config.Miners.$Name.MinerFeeInPercentSingleMode / 100)
                    $Fees = @($Config.Miners.$Name.MinerFeeInPercentSingleMode)
                }

                # Single mining mode
                [PSCustomObject]@{
                    Name      = $MinerName
                    Type      = $Type
                    Path      = $Config.Miners.$Name.Path
                    Arguments = ("-mode 1 -mport -$MinerPort -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand -esm $EthereumStratumMode -allpools 1 -allcoins 1 -platform 2 $($Config.Miners.$Name.CommonCommands) -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                    HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                    API       = $Api
                    Port      = $MinerPort
                    URI       = $Uri
                    Fees      = $Fees
                    Index     = $DeviceIDs -join ';'
                }
            }
            elseif ($_ -match "^.+;.+:\d+$") { # valid dual mining parameter set

                $SecondaryAlgorithm = ($_.Split(";") | Select -Index 1).Split(":") | Select -Index 0
                $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm
                $SecondaryAlgorithmIntensity = ($_.Split(";") | Select -Index 1).Split(":") | Select -Index 1
            
                $MinerName = "$($MinerName)$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondaryAlgorithm_Norm)$($SecondaryAlgorithmIntensity)"
                $HashRateMainAlgorithm = ($Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week)
                $HashRateSecondaryAlgorithm = ($Stats."$($MinerName)_$($SecondaryAlgorithm_Norm)_HashRate".Week)

                #Second coin (Decred/Siacoin/Lbry/Pascal/Blake2s/Keccak) is mined without developer fee
                if ($Config.IgnoreMinerFees -or $Config.Miners.$Name.MinerFeeInPercentDualMode -eq 0) {
                    $Fees = @($null)
                }
                else {
                    $HashRateMainAlgorithm = $HashRateMainAlgorithm * (1 - $Config.Miners.$Name.MinerFeeInPercentDualMode / 100)
                    $Fees = @($Config.Miners.$Name.MinerFeeInPercentDualMode, 0)
                }

                if ($Pools.$SecondaryAlgorithm_Norm -and $SecondaryAlgorithmIntensity -gt 0) { # must have a valid pool to mine and positive intensity
                    # Dual mining mode
                    [PSCustomObject]@{
                        Name      = $MinerName
                        Type      = $Type
                        Path      = $Config.Miners.$Name.Path
                        Arguments = ("-mode 0 -mport -$MinerPort -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand -esm $EthereumStratumMode -allpools 1 -allcoins exp -dcoin $SecondaryAlgorithm -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommand -platform 2 $($Config.Miners.$Name.CommonCommands) -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                        HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                        API       = $Api
                        Port      = $MinerPort
                        URI       = $Uri
                        Fees      = $Fees
                        Index     = $DeviceIDs -join ';'
                    }
                    if ($SecondaryAlgorithm_Norm -eq "Sia" -or $SecondaryAlgorithm_Norm -eq "Decred") {
                        $SecondaryAlgorithm_Norm = "$($SecondaryAlgorithm_Norm)NiceHash"
                        [PSCustomObject]@{
                            Name      = $MinerName
                            Type      = $Type
                            Path      = $Config.Miners.$Name.Path
                            Arguments = ("-mode 0 -mport -$MinerPort -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand -esm $EthereumStratumMode -allpools 1 -allcoins exp -dcoin $SecondaryAlgorithm -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommand -platform 2 $($Config.Miners.$Name.CommonCommands) -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                            HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                            API       = $Api
                            Port      = $MinerPort
                            URI       = $Uri
                            Fees      = $Fees
                            Index     = $DeviceIDs -join ';'
                        }
                    }
                }
            }
        }
    }
}
Sleep 0