using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Type = "NVIDIA"
if (-not $Devices.$Type) {return} # No NVIDIA mining device present in system

$DriverVersion = (Get-Devices).NVIDIA.Platform.Version -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -lt $RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers to 397.93 or newer. "
    return
}

$Path = ".\Bin\zFast-NVIDIA\zFastminer-v233.exe"
$HashSHA256 = "B213F9989FCE204A723E0762C2FB4A713C18D3C858EC6B0468CE3295C8F151D8"
$ManaulURI = "https://file.fm/f/b7dwr5vw"
$MinerFeeInPercent = 1.8

$Commands = [PSCustomObject]@{
    "lyra2z" = "" #Lyra2z
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
    $Fees = @($null)
}
else {
    $Fees = @($MinerFeeInPercent)
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    if ($Pools.$Algorithm_Norm.host -match ".*miningpoolhub\.com") { *only available for miningpoolhub
	
        $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week
        
        if ($Fees) {$HashRate = $HashRate * (1 - $MinerFeeInPercent / 100)}
        
        [PSCustomObject]@{
            Type       = $Type
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
            API        = "Ccminer"
            Port       = 4068
            URI        = $Uri
            Fees       = @($Fees)
        }
    }
}
