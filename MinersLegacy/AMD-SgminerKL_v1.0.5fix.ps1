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
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.5fix/sgminer-kl-1.0.5_fix-windows_x64.zip"
$ManualUri = "https://github.com/KL0nLutiy"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
  "aergo"     = " -X 256 -g 2" #Aergo
  "blake"     = "" #Blake
  "bmw"       = "" #Bmw
  "echo"      = "" #Echo
  "hamsi"     = "" #Hamsi
  "keccak"    = "" #Keccak
  "phi"       = " -X 256 -g 2 -w 256" # Phi
  "skein"     = "" #Skein
  "tribus"    = " -X 256 -g 2" #Tribus
  "whirlpool" = "" #Whirlpool
  "xevan"     = " -X 256 -g 2" #Xevan
  "x16s"      = " -X 256 -g 2" #X16S Pigeoncoin
  "x16r"      = " -X 256 -g 2" #X16R Ravencoin
  "x17"       = " -X 256 -g 2"
}
$CommonCommands = " --text-only"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_;"$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("--api-listen --api-port $Miner_Port --kernel $_ --url $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands --gpu-platform $($Miner_Device.PlatformId | Sort-Object -Unique) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Xgminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
