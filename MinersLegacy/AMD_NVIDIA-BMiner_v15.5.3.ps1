using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\BMiner.exe"
$HashSHA256 = "13A9CB591C7A9FAF4D51273B8B448B6F27F7D1D86237039AD356452F3A7B737C"
$Uri = "https://www.bminercontent.com/releases/bminer-lite-v15.5.3-747d98e-amd64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=2519271.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = $Devices | Where-Object Type -EQ "GPU"

# Miner requires CUDA 9.2.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.00"
if ($Devices.Vendor -contains "NVIDIA Corporation" -and $CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    $Devices = $Devices | Where-Object Vendor -NE "NVIDIA Corporation"
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        #Single algo mining
        [PSCustomObject]@{MainAlgorithm = "beam";         SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Params = ""} #Equihash1505, new in 11.3.0
        [PSCustomObject]@{MainAlgorithm = "cuckaroo29";   SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 8; Vendor = @("NVIDIA"); Params = " --fast"} #Cuckaroo29, new in 14.3.1
        [PSCustomObject]@{MainAlgorithm = "cuckatoo31";   SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 8; Vendor = @("NVIDIA"); Params = ""} #Cuckatoo31, new in 14.2.0, requires GTX 1080Ti or RTX 2080Ti
        [PSCustomObject]@{MainAlgorithm = "aeternity";    SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = " --fast"} #Aeternity, new in 11.1.0
        [PSCustomObject]@{MainAlgorithm = "equihash";     SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Equihash
        [PSCustomObject]@{MainAlgorithm = "equihash1445"; SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Equihash1445
        [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash
        [PSCustomObject]@{MainAlgorithm = "ethash2gb";    SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2Gb
        [PSCustomObject]@{MainAlgorithm = "ethash3gb";    SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3Gb
        [PSCustomObject]@{MainAlgorithm = "ethash2gb";    SecondaryAlgorithm = "blake14r";  ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2Gb & Blake14r dual mining, auto dual solver and auto intensity
        [PSCustomObject]@{MainAlgorithm = "ethash3gb";    SecondaryAlgorithm = "blake14r";  ; SecondaryIntensity = 0;  MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3Gb & Blake14r dual mining, auto dual solver and autointensity
        [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "blake14r";  ; SecondaryIntensity = 0;  MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Blake14r dual mining, auto dual solver and auto intensity
        [PSCustomObject]@{MainAlgorithm = "ethash2gb";    SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 20; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2Gb & Blake14r dual mining, auto dual solver and intensity20
        [PSCustomObject]@{MainAlgorithm = "ethash3gb";    SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 20; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3Gb & Blake14r dual mining, auto dual solver and intensity20
        [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 20; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Blake14r dual mining, auto dual solver and intensity20
        [PSCustomObject]@{MainAlgorithm = "ethash2gb";    SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 40; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2Gb & Blake14r dual mining, auto dual solver and intensity40
        [PSCustomObject]@{MainAlgorithm = "ethash3gb";    SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 40; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3Gb & Blake14r dual mining, auto dual solver and intensity40
        [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 40; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Blake14r dual mining, auto dual solver and intensity40
        [PSCustomObject]@{MainAlgorithm = "ethash2gb";    SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 60; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2Gb & Blake14r dual mining, auto dual solver and intensity60
        [PSCustomObject]@{MainAlgorithm = "ethash3gb";    SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 60; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3Gb & Blake14r dual mining, auto dual solver and intensity60
        [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "blake2s";   ; SecondaryIntensity = 60; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Blake14r dual mining, auto dual solver and intensity60
        [PSCustomObject]@{MainAlgorithm = "ethash2gb";    SecondaryAlgorithm = "tensority"; ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2Gb & Bytom dual mining, auto dual solver and intensity
        [PSCustomObject]@{MainAlgorithm = "ethash3gb";    SecondaryAlgorithm = "tensority"; ; SecondaryIntensity = 0;  MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3Gb & Bytom dual mining, auto dual solver and intensity
        [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "tensority"; ; SecondaryIntensity = 0;  MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Bytom dual mining, auto dual solver and intensity
        [PSCustomObject]@{MainAlgorithm = "ethash2gb";    SecondaryAlgorithm = "vbk";       ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2Gb & Bytom dual mining, auto dual solver and intensity
        [PSCustomObject]@{MainAlgorithm = "ethash3gb";    SecondaryAlgorithm = "vbk";       ; SecondaryIntensity = 0;  MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3Gb & Bytom dual mining, auto dual solver and intensity
        [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "vbk";       ; SecondaryIntensity = 0;  MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Bytom dual mining, auto dual solver and intensity
        [PSCustomObject]@{MainAlgorithm = "tensority";    SecondaryAlgorithm = "";          ; SecondaryIntensity = 0;  MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Bytom
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " -watchdog=false"}

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Main_Algorithm_Norm = Get-Algorithm $_.MainAlgorithm; $_} | Where-Object {$Pools.$Main_Algorithm_Norm.Host} | ForEach-Object {
        $Arguments_Secondary = ""
        $IntervalMultiplier = 1
        $Main_Algorithm = $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters
        $Vendor = $_.Vendor
        $WarmupTime = $null
        
        #Cuckatoo31 on windows 10 requires 3.5 GB extra
        if ($Main_Algorithm -eq "Cuckatoo31" -and ([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) {$MinMemGB += 3.5}

        if ($Miner_Device = @($Device | Where-Object {$Vendor -contains $_.Vendor_ShortName -and ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Secondary_Algorithm = $_.SecondaryAlgorithm
            $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$($Main_Algorithm_Norm, $Secondary_Algorithm_Norm -join '') $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            if ($Main_Algorithm_Norm -like "Equihash1445") {
                #define -pers for equihash1445
                $Pers = " -pers $(Get-EquihashPers -CoinName $Pools.$Algorithm_Norm.CoinName -Default 'auto')"
            }
            else {$Pers = ""}

            #define protocol
            switch ($Main_Algorithm -replace "ethash(\dgb)", "ethash") {
                "equihash"     {$Protocol = "stratum"}
                "equihash1445" {$Protocol = "zhash"}
                default        {$Protocol = $_}
            }
            if ($Protocol -eq "ethash") {$Protocol = "ethstratum"} #Special protocol for Ethash
            if ($Pools.$Main_Algorithm_Norm.SSL) {$Protocol = "$($Protocol)+ssl"}

            if ($Secondary_Algorithm -and $Miner_Device.Vendor_ShortName -eq "NVIDIA") { #Dual mining only works with NVIDIA
                $IntervalMultiplier = 2
                $WarmupTime = 120
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @("$Main_Algorithm_Norm$Secondary_Algorithm_Norm") + @(if ($_.SecondaryIntensity) {"$($_.SecondaryIntensity)"}) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; "$Secondary_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 1.3 / 100; $Secondary_Algorithm_Norm = 0 / 100} # Fixed at 1.3%, secondary algo no fee
                $Arguments_Secondary = " -uri2 $($Secondary_Algorithm)$(if ($Pools.$Secondary_Algorithm_Norm.SSL) {'+ssl'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.Pass))@$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port)$(if($_.SecondaryIntensity -ge 0){" -dual-intensity $($_.SecondaryIntensity)"})"
            }
            else {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}

                if ($Main_Algorithm_Norm -like "Ethash*") {$MinerFeeInPercent = 0.65} # Ethash fee fixed at 0.65%
                else {$MinerFeeInPercent = 2} # Other algos fee fixed at 2%

                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = $MinerFeeInPercent / 100}
            }

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) {$Miner_Config = [PSCustomObject]@{DisableDevFeeMining = $Config.DisableDevFeeMining}}
            if ($Miner_Config.DisableDevFeeMining) {
                $NoFee = " -nofee"
                $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0 / 100}
                if ($Secondary_Algorithm_Norm) {$Miner_Fees | Add-Member $Secondary_Algorithm_Norm (0 / 100)}
            }
            else {$NoFee = ""}

            [PSCustomObject]@{
                Name               = $Miner_Name
                BaseName           = $Miner_BaseName
                Version            = $Miner_Version
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("-api 127.0.0.1:$($Miner_Port) $Pers -uri $($Protocol)://$([System.Web.HttpUtility]::UrlEncode($Pools.$Main_Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Main_Algorithm_Norm.Pass))@$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port)$Arguments_Secondary$Parameters$CommonParameters$NoFee -devices $(if ($Miner_Device.Vendor -EQ "Advanced Micro Devices, Inc.") {"amd:"})$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates          = $Miner_HashRates
                API                = "Bminer"
                Port               = $Miner_Port
                URI                = $URI
                Fees               = $Miner_Fees
                IntervalMultiplier = $IntervalMultiplier
                WarmupTime         = $WarmupTime
            }
        }
    }
}
