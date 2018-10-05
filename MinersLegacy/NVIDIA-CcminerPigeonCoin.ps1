using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-PigeonCoin\ccminer.exe"
$HashSHA256 = "0A181FF0EA3A0F2CDC0A2C151397496F1AA159F092BDD4D0022BD1D24A63E8FE"
$Uri = "https://github.com/Pigeoncoin-Miner/Pigeoncoin/releases/download/v2.6-64bit-cu92/Pigeoncoin-Miner.cu92.64bit.2.6.zip"

$Commands = [PSCustomObject]@{
    "X16s" = "" #PigeonCoin
}

$CommonCommands = " --donate 0"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Miner requires CUDA 9.2
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    Switch ($Algorithm_Norm) {
        "X16S"  {$ExtendInterval = 10}
        default {$ExtendInterval = 0}
    }

    [PSCustomObject]@{
        Type           = "NVIDIA"
        Path           = $Path
        HashSHA256     = $HashSHA256
        Arguments      = "-a $_ -b 4068 -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API            = "Ccminer"
        Port           = 4068
        URI            = $Uri
        ExtendInterval = $ExtendInterval
    }
}
