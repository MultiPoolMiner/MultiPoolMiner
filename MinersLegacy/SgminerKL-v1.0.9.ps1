using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\sgminer.exe"
$HashSHA256 = "A24024BEA8789B62D61CB3F41432EA1A62EE5AD97CD3DEAB1E2308F40B127A4D"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.9/sgminer-kl-1.0.9-windows.zip"
$ManualUri = "https://github.com/KL0nLutiy/sgminer-kl"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
      "aergo"     = " -X 256 -g 2" #Aergo
      "geek"      = " -X 256 -g 2" # Geek
      "phi"       = " -X 256 -g 2 -w 256" # Phi
      "polytimos" = " -X 256 -g 2 -w 256" # Polytimos
      "skunk"     = " -X 256 -g 2 -w 256" # Skunk
      "tribus"    = " -X 256 -g 2" #Tribus
      # "xevan"     = " -X 256 -g 2" #Xevan, AMD-SgminerAvermore_v1.4.1 is 20% faster
      "x16s"      = " -X 256 -g 2" #X16S Pigeoncoin
      "x16r"      = " -X 256 -g 2" #X16R Ravencoin
      "x17"       = " -X 256 -g 2"
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " $(if (-not $Config.ShowMinerWindow) {' --text-only'})"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc." | Where-Object {$_.OpenCL.GlobalMemSize -gt 2GB})
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '-') | Select-Object) -join '-'

        #Get parameters for active miner devices
        if ($Miner_Config.Parameters.$Algorithm_Norm) {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
        }
        elseif ($Miner_Config.Parameters."*") {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
        }
        else {
            $Parameters = Get-ParameterPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index
        }

        Switch ($Algorithm_Norm) {
            "X16R"  {$IntervalMultiplier = 5}
            default {$IntervalMultiplier = 1}
        }

        #Allow time to build binaries
        if (-not (Get-Stat "$($Miner_Name)_$($Algorithm_Norm)_HashRate")) {$WarmupTime = 90} else {$WarmupTime = 30}

        [PSCustomObject]@{
            Name               = $Miner_Name
            BaseName           = $Miner_BaseName
            Version            = $Miner_Version
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("--kernel $_ --api-listen --api-port $Miner_Port --url $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters --gpu-platform $($Miner_Device.PlatformId | Sort-Object -Unique) --device $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Xgminer"
            Port               = $Miner_Port
            URI                = $Uri
            Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            Environment        = @("GPU_FORCE_64BIT_PTR=0")
            IntervalMultiplier = $IntervalMultiplier
            WarmupTime         = $WarmupTime #seconds
        }
    }
}
