using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

if (-not $Devices.NVIDIA) {return} # No NVIDIA mining device present in system


$DriverVersion = (Get-Devices).NVIDIA.Platform.Version -replace ".*CUDA ",""
$RequiredVersion = "9.1.00"
if ($DriverVersion -lt $RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers to 390.77 or newer. "
    return
}

$Type = "NVIDIA"
$Path = ".\Bin\NVIDIA-EWBF-Equihash-030\miner.exe"
$Uri = "http://semitest.000webhostapp.com/binary/EWBF%20Equihash%20miner%20v0.3.zip"
$Port = 42000
$Fee = 0

$Commands = [PSCustomObject]@{
    "equihash-BTG"   = @("144_5","--pers BgoldPoW","") #EquihashBTG
    "zerocurrencies" = @("192_7","--pers ZERO_PoW","") #zerocurrencies
    "Minexcoin"      = @("96_5","","") #Minexcoin
}

$CommonCommands = "" #eg. " --cuda_devices 0 1 8 9"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week * (1 - $Fee / 100)

    [PSCustomObject]@{
        Type           = $Type
        Path           = $Path
        Arguments      = "--algo $($Commands.$_ | Select-Object -Index 0) --eexit 1 --api 0.0.0.0:$($Port) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($Commands.$_ | Select-Object -Index 2)$($CommonCommands) $($Commands.$_ | Select-Object -Index 1) --fee 0 --log 1 --color"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API            = "DSTM"
        Port           = $Port
        URI            = $Uri
        MinerFee       = @($Fee)
        ExtendInterval = $ExtendInterval
    }
}