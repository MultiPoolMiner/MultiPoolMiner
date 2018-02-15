using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config
)

# Hardcoded per miner version, do not allow user to chage in config
$MinerFileVersion = "2018021501" #Format: YYYYMMMDD[TwoDigitCounter], higher value will trigger config file update
$MinerBinaryInfo =  "Claymore Claymore Dual Ethereum AMD/NVIDIA GPU Miner v11.0"
$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$Type = "NVIDIA"
$API = "Claymore"
$Uri = "https://github.com/nemosminer/Claymores-Dual-Ethereum/releases/download/v11.0/Claymore.s.Dual.Ethereum.Decred_Siacoin_Lbry_Pascal.AMD.NVIDIA.GPU.Miner.v11.0.zip"
$UriInfo = ""

try {
	if (-not $Config.Miners.$Name.MinerFileVersion) {
        # Create default miner config
	    $Config.Miners | Add-Member $Name ([PSCustomObject]@{
	        "MinerFileVersion" = "$MinerFileVersion"
	        "MinerBinaryInfo" = "$MinerBinaryInfo"
            "Uri" = "$Uri"
	        "UriInfo" = "$UriInfo"
	        "Type" = "$Type"
	        "Path" = "$Path"
	        "Port" = 23333
	        "MinerFeeInPercent" = 1.5
	        "MinerFeeSSLInPercent" = 1.5
            "MinerFeeInfo" = ""
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
	    })
        # Save config to file
	    $Config | ConvertTo-Json -Depth 10 | Set-Content "Config.txt" -Force -ErrorAction Stop
    }
	else {
	    if ($MinerFileVersion -gt $Config.Miners.$Name.MinerFileVersion) {
	        try {
	            # Execute action, e.g force re-download of binary
	            # Should be first action. If it fails no further update will take place, update will be retried on next loop
	            if (Test-Path $Path) { Remove-Item $Path -Force -Confirm:$false -ErrorAction Stop }

	            # Always update MinerFileVersion and download link
	            $Config.Miners.$Name | Add-member MinerFileVersion "$MinerFileVersion" -Force
	            $Config.Miners.$Name | Add-member Uri "$Uri" -Force
	            
	            # Add config item if not in existing config file
	            $Config.Miners.$Name.Commands | Add-Member "ethash;pascal;-dcoin pasc -dcri 40" "" -ErrorAction SilentlyContinue
	            $Config.Miners.$Name.Commands | Add-Member "ethash;pascal;-dcoin pasc -dcri 60" "" -ErrorAction SilentlyContinue
	            $Config.Miners.$Name.Commands | Add-Member "ethash;pascal;-dcoin pasc -dcri 80" "" -ErrorAction SilentlyContinue
	            $Config.Miners.$Name.Commands | Add-Member "ethash2gb;pascal;-dcoin pasc -dcri 40" "" -ErrorAction SilentlyContinue
	            $Config.Miners.$Name.Commands | Add-Member "ethash2gb;pascal;-dcoin pasc -dcri 60" "" -ErrorAction SilentlyContinue
	            $Config.Miners.$Name.Commands | Add-Member "ethash2gb;pascal;-dcoin pasc -dcri 80" "" -ErrorAction SilentlyContinue
	            
	            # Remove config item if in existing config file
	            #$Config.Miners.$Name | Foreach-Object { $Config.Miners.$Name.PSObject.Properties.Remove("Dummy") } -ErrorAction SilentlyContinue

	            # Update config file
	            $Config | ConvertTo-Json -Depth 10 | Set-Content "Config.txt" -Force -ErrorAction Stop
	        }
			catch {}
		}
	}

	if (-not $Config.Miners.SubtractMinerFees) { $MinerFeeInPercent = 0} else {$MinerFeeInPercent = $Config.Miners.$Name.MinerFeeInPercent}

	$Config.Miners.$Name.Commands | ForEach-Object {

	    $Command = $Config.Miners.$Name.Commands.$_
	    $MainAlgorithm = $_.Split(";") | Select -Index 0
	    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm
	    $DcriCmd = $_.Split(";") | Select -Index 2
	    if ($DcriCmd) {
	        $SecondaryAlgorithm = $_.Split(";") | Select -Index 1
	        $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm
	        $Dcri = $DcriCmd.Split(" ") | Select -Index 3
	    }
	    else {
	        $SecondaryAlgorithm = ""
	        $SecondaryAlgorithm_Norm = ""
	        $Dcri = ""
	    }

	    if ($Pools.$($MainAlgorithm_Norm).Name -and -not $SecondaryAlgorithm) {
	        
	        [PSCustomObject]@{
	            Name      = "$($Name)_$($MainAlgorithm_Norm)"
	            Type      = $Type
	            Path      = $Config.Miners.$Name.Path
	            Arguments = ("-mode 1 -mport -$($Config.Miners.$Name.Port) -epool $($Pools.$MainAlgorithm_Norm.Host) $($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins 1 -platform 2 $Command $($Config.Miners.$Name.CommonCommands)").trim()
	            HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * (100 - $MinerFeeInPercent))} 
	            API       = $Api
	            Port      = $Config.Miners.$Name.Port
	            URI       = $Uri
	        }
	    }
	    if ($Pools.$($MainAlgorithm_Norm).Name -and $Pools.$($SecondaryAlgorithm_Norm).Name) {
	        [PSCustomObject]@{
	            Name      = "$($Name)_$($SecondaryAlgorithm_Norm)$($Dcri)"
	            Type      = $Type
	            Path      = $Config.Miners.$Name.Path
	            Arguments = ("-mode 0 -mport -$($Config.Miners.$Name.Port) -epool $($Pools.$MainAlgorithm_Norm.Host) $($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools."$SecondaryAlgorithm_Norm".Host) $($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2 $($DcriCmd) $Command $($Config.Miners.$Name.CommonCommands)").trim()
	            HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * (100 - $MinerFeeInPercent)); "$SecondaryAlgorithm_Norm" = ($Stats."$($Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week * (100 - $MinerFeeInPercent))}
	            API       = $Api
	            Port      = $Config.Miners.$Name.Port
	            URI       = $Uri
	        }
	        if ($SecondaryAlgorithm_Norm -eq "Sia" -or $SecondaryAlgorithm_Norm -eq "Decred") {
	            $SecondaryAlgorithm_Norm = "$($SecondaryAlgorithm_Norm)NiceHash"
	            [PSCustomObject]@{
	                Name      = "$($Name)_$($SecondaryAlgorithm_Norm)$($Dcri)"
	                Type      = $Type
	                Path      = $Config.Miners.$Name.Path
	                Arguments = ("-mode 0 -mport -$($Config.Miners.$Name.Port) -epool $($Pools.$MainAlgorithm_Norm.Host) $($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools.$SecondaryAlgorithm_Norm.Host) $($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2 $($DcriCmd) $Command $($CommonCommands)").trim()
	                HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * (100 - $MinerFeeInPercent)); "$SecondaryAlgorithm_Norm" = ($Stats."$($Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week * (100 - $MinerFeeInPercent))}
	                API       = $Api
	                Port      = $Config.Miners.$Name.Port
	                URI       = $Uri
	            }
	        }
	    }
	}
}
catch {}
