using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\EthDcrMiner64.exe"
$HashSHA256 = "2F028F580A628EF3D1D398E238E0EC7B0C0EC8AA89BB88706C4B19BF6E548FB4"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/ClaymoreDual_v15.0.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=1433925.0"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "";        Command = "" } #Ethash2gb
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; Command = "" } #Ethash2gb/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  Command = "" } #Ethash2GB/Decred
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  Command = "" } #Ethash2GB/Keccak
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    Command = "" } #Ethash2GB/Lbry
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  Command = "" } #Ethash2GB/Pascal
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "sia";     Command = "" } #Ethash2GB/Sia
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "";        Command = "" } #Ethash3GB
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; Command = "" } #Ethash3GB/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  Command = "" } #Ethash3GB/Decred
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  Command = "" } #Ethash3GB/Keccak
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    Command = "" } #Ethash3GB/Lbry
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  Command = "" } #Ethash3GB/Pascal
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "sia";     Command = "" } #Ethash3GB/Sia
    [PSCustomObject]@{ Algorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "";        Command = "" } #Ethash
    [PSCustomObject]@{ Algorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; Command = "" } #Ethash/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  Command = "" } #Ethash/Decred
    [PSCustomObject]@{ Algorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  Command = "" } #Ethash/Keccak
    [PSCustomObject]@{ Algorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    Command = "" } #Ethash/Lbry
    [PSCustomObject]@{ Algorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  Command = "" } #Ethash/Pascal
    [PSCustomObject]@{ Algorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "sia";     Command = "" } #Ethash/Sia
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

$SecondaryAlgoIntensities = [PSCustomObject]@{ 
    "blake2s" = @(40, 60, 80)
    "decred"  = @(20, 40, 70)
    "keccak"  = @(20, 30, 40)
    "lbry"    = @(60, 75, 90)
    "pascal"  = @(20, 40, 60)
    "sia"     = @(20, 40, 60, 80)
}

#Intensities from config file take precedence
$Miner_Config.SecondaryAlgoIntensities.PSObject.Properties.Name | Select-Object | ForEach-Object { 
    $SecondaryAlgoIntensities | Add-Member $_ $Miner_Config.SecondaryAlgoIntensities.$_ -Force
}

$Commands | ForEach-Object { 
    if ($_.SecondaryAlgorithm) { 
        $Command = $_
        $SecondaryAlgoIntensities.$($_.SecondaryAlgorithm) | Select-Object | ForEach-Object { 
            if ($null -ne $Command.SecondaryAlgoIntensity) { 
                $Command = ($Command | ConvertTo-Json | ConvertFrom-Json)
                $Command | Add-Member SecondaryAlgoIntensity ([String] $_) -Force
                $Commands += $Command
            }
            else { $Command | Add-Member SecondaryAlgoIntensity $_ }
        }
    }
}

#CommonCommandsAll from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommandsAll = $Miner_Config.CommonCommandsAll }
else { $CommonCommandsAll = " -dbg -1 -strap 1" }

#CommonCommandsNvidia from config file take precedence
if ($Miner_Config.CommonCommandsNvidia) { $CommonCommandsNvidia = $Miner_Config.CommonCommandsNvidia }
else { $CommonCommandsNvidia = " -platform 2" }

#CommonCommandsAmd from config file take precedence
if ($Miner_Config.CommonCommandsAmd) { $CommonCommmandAmd = $Miner_Config.CommonCommandsAmd }
else { $CommonCommandsAmd = " -platform 1 -y 1 -rxboost 1" }

$Devices = @($Devices | Where-Object Type -EQ "GPU")
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1)

    switch ($_.Vendor) { 
        "AMD" { $CommonCommands = $CommonCommandsAmd + $CommonCommandsAll }
        "NVIDIA" { $CommonCommands = $CommonCommandsNvidia + $CommonCommandsAll }
        Default { $CommonCommands = $CommonCommandsAll }
    }

    #Remove -strap parameter, not all card models support it
    if ($Device.Model -notmatch "^GTX10.*|^Baffin.*|^Ellesmere.*|^Polaris.*|^Vega.*|^gfx900.*") { 
        $CommonCommands = $CommonCommands -replace " -strap [\d,]{1,}"
    }
    
    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) { 
                $Parameters = Get-CommandPerDevice $Miner_Config.Parameters.$($Algorithm_Norm) $Miner_Device.Type_Vendor_Index
                if ($Miner_Config.Parameters.$Secondary_Algorithm_Norm -and $Secondary_Algorithm_Norm -and $_.SecondaryAlgoIntensity -gt 0) { 
                    $Parameters += Get-CommandPerDevice $Miner_Config.Parameters.$($Secondary_Algorithm_Norm) $Miner_Device.Type_Vendor_Index
                }
            }
            elseif ($Miner_Config.Parameters."*") { 
                $Parameters = Get-CommandPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else { 
                $Parameters = Get-CommandPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            if ($null -ne $_.SecondaryAlgoIntensity) { 
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) + @("$Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @($_.SecondaryAlgoIntensity) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week }

                switch ($_.Secondary_Algorithm_Norm) { 
                    "Decred"      { $Secondary_Algorithm = "dcr" }
                    "Lbry"        { $Secondary_Algorithm = "lbc" }
                    "Pascal"      { $Secondary_Algorithm = "pasc" }
                    "SiaClaymore" { $Secondary_Algorithm = "sc" }
                }
                $Arguments_Secondary = " -dcoin $Secondary_Algorithm -dpool $($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpsw $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryAlgoIntensity -ge 0){ " -dcri $($_.SecondaryAlgoIntensity)" })"
                if ($Miner_Device | Where-Object { $_.OpenCL.GlobalMemsize -gt 3GB }) { 
                    $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 1 / 100; $Secondary_Algorithm_Norm = 0 / 100 }
                }
                else { 
                    $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 0 / 100; $Secondary_Algorithm_Norm = 0 / 100 }
                }
            }
            else { 
                $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                $Arguments_Secondary = ""

                if ($Miner_Device | Where-Object { $_.OpenCL.GlobalMemsize -gt 3GB }) { 
                    $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 1 / 100 }
                }
                else { 
                    $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 0 / 100 }
                }
            }
            #Avoid DAG switching
            switch ($Algorithm_Norm) { 
                "Ethash" { $Allcoins = " -allcoins etc" }
                default  { $Allcoins = " -allcoins 1" }
            }

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) { $Miner_Config = [PSCustomObject]@{ DisableDevFeeMining = $Config.DisableDevFeeMining } }
            if ($Miner_Config.DisableDevFeeMining) { 
                $NoFee = " -nofee 1"
                $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 0 / 100 }
            }
            else { $NoFee = "" }

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            #Remove -strap parameter for Nvidia 1080(Ti) and Titan cards, OhGoAnETHlargementPill is not compatible
            if ($Device.Model -match "GTX1080.*|Nvidia TITAN.*" -and (Get-CIMInstance CIM_Process | Where-Object Processname -like "OhGodAnETHlargementPill*")) { 
                $CommonCommands = $CommonCommands -replace " -strap [\d,]{1,}"
            }

            if ($null -eq $_.SecondaryAlgoIntensity -or $Pools.$Secondary_Algorithm_Norm.Host) { 
                [PSCustomObject]@{ 
                    Name               = $Miner_Name
                    DeviceName         = $Miner_Device.Name
                    Path               = $Path
                    HashSHA256         = $HashSHA256
                    Arguments          = ("$Command$CommonCommands -mport -$Miner_Port -epool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -ewal $($Pools.$Algorithm_Norm.User) -epsw $($Pools.$Algorithm_Norm.Pass) -allpools 1$Allcoins -esm 3$Arguments_Secondary$NoFee -di $(($Miner_Device | ForEach-Object { '{0:x}' -f $_.Type_Vendor_Slot }) -join '')" -replace "\s+", " ").trim()
                    HashRates          = $Miner_HashRates
                    API                = "Claymore"
                    Port               = $Miner_Port
                    URI                = $Uri
                    Fees               = $Miner_Fees
                    IntervalMultiplier = $IntervalMultiplier
                    WarmupTime         = 45 #seconds
                }
            }
        }
    }
}
