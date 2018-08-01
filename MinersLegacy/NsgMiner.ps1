using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\AMD_NVIDIA-Nsgminer-NeoScrypt\nsgminer.exe"
$HashSHA256 = "5FD5F65E360E93C7A520DA5E1945E58F8AD6B1CF9ECBDF2E4D5FB06DEDD2C6A8"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/NsgMiner/nsgminer-win64-0.9.4.zip"
$ManualUri = "https://github.com/ghostlander/nsgminer"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "neoscrypt" = "" #NeoScrypt
}

$CommonCommands = " --text-only --worksize 64 --intensity 15"

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = @($Devices | Where-Object Type -EQ "GPU")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    
    
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        [PSCustomObject]@{
            Name             = $Miner_Name
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = ("--$_ --api-listen --api-port $Miner_Port -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands --gpu-platform $($Miner_Device.PlatformId) --device $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_PlatformId_Index)}) -join '--device ')" -replace "\s+", " ").trim()
            HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API              = "Xgminer"
            Port             = $Miner_Port
            URI              = $Uri
        }
    }
}
