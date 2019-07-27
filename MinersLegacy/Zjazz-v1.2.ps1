using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\zjazz_cuda.exe"
$HashSHA256 = "A65ED6394F667B5BB4126445A832BAA51C6D9E9AFDC9E868EE6CB3D99E9CB8ED"
$Uri = "https://github.com/zjazz/zjazz_cuda_miner/releases/download/1.2/zjazz_cuda_win64_1.2.zip"
$ManualUri = "https://github.com/zjazz/zjazz_cuda_miner"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation" | Where-Object {$_.OpenCL.GlobalMemsize -ge 2GB})

# Miner requires CUDA 9.2
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "bitcash"; MinMemGb = 1; Params = ""; WarmupTime = 60} #Bitcash
        [PSCustomObject]@{Algorithm = "cuckoo";  MinMemGb = 1; Params = ""; WarmupTime = 60} #Merit
        [PSCustomObject]@{Algorithm = "x22i";    MinMemGb = 1; Params = ""; WarmupTime = 0} #SUQA
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm ("cryptonight$($_.Algorithm)"); $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Parameters = $_.Parameters
        $MinMemGB = $_.MinMemGB
        $WarmupTime = $_.WarmupTime
        
        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $_.Parameters $Miner_Device.Type_Vendor_Index
            }

            [PSCustomObject]@{
                Name           = $Miner_Name
                BaseName       = $Miner_BaseName
                Version        = $Miner_Version
                DeviceName     = $Miner_Device.Name
                Path           = $Path
                HashSHA256     = $HashSHA256
                Arguments      = ("-a $_ --api-bind $Miner_Port -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ' -d ')" -replace "\s+", " ").trim()
                HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API            = "Ccminer"
                Port           = $Miner_Port
                URI            = $Uri
                Fees           = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
                WarmupTime     = $WarmupTime #seconds
            }
        }
    }
}
