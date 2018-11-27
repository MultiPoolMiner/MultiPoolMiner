using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\teamredminer.exe"
$HashSHA256 = "769AB0FC212A55687240DEB0E1EC70982315A09E405DB17C5AFB842CF83C32C9"
$Uri = "https://github.com/todxx/teamredminer/releases/download/v0.3.7/teamredminer-v0.3.7-win.zip"
$ManualUri = "https://github.com/todxx/teamredminer/blob/master/README.md"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "cnv8"  ; Fee = 2.5; Params = ""} #CryptonightV8, New in 0.3.5
    [PSCustomObject]@{Algorithm = "lyra2z"; Fee = 3;   Params = ""} #Lyra2Z, New in 0.3.5
    [PSCustomObject]@{Algorithm = "phi2"  ; Fee = 3;   Params = ""} #Phi2, New in 0.3.5
)
$CommonCommands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.Algorithm

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands = Get-CommandPerDevice $_.Params $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("--algo=$($_.Algorithm) --api_listen=127.0.0.1:$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$Commands$CommonCommands --platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
            API        = "Xgminer"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{$Algorithm_Norm = $_.Fee / 100}
        }
    }
}
