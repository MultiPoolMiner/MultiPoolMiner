using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\eminer.exe"
$HashSHA256 = "B4D0723F5BE34731108B558B8BA9E9F1DFCE92AFD6C2D93D9A7FD0E0C55430D3"
$Uri = "https://github.com/ethash/eminer-release/releases/download/v0.6.1-rc2/eminer.v0.6.1-rc2.win64.zip"
$ManualUri = "https://github.com/ethash/eminer-release"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "ethash2gb"; MinMemGB = 2; Command = ""} #Ethash2GB
    [PSCustomObject]@{Algorithm = "ethash3gb"; MinMemGB = 3; Command = ""} #Ethash3GB
    [PSCustomObject]@{Algorithm = "ethash"   ; MinMemGB = 4; Command = ""} #Ethash
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " -intensity 64"}

# Set devfee default coin, it may reduce DAG changes
$DevFeeCoin  = [PSCustomObject]@{
    "Ethereum"        = " -devfee-coin ETH"
    "Eth"             = " -devfee-coin ETH"
    "EthereumClassic" = " -devfee-coin ETC"
    "Etc"             = " -devfee-coin ETC"
    "Expanse"         = " -devfee-coin EXP"
    "Exp"             = " -devfee-coin EXP"
    "Music"           = " -devfee-coin MUSIC"
    "MusiCoin"        = " -devfee-coin MUSIC"
    "Ubiq"            = " -devfee-coin UBQ"
    "Ubq"             = " -devfee-coin UBQ"
}

$Devices = @($Devices | Where-Object Type -EQ "GPU")
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands -http :$($Miner_Port) -S $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -U $($Pools.$Algorithm_Norm.User) -P $($Pools.$Algorithm_Norm.Pass)$(if($DevfeeCoin.($Pools.$Algorithm_Norm.CoinName)) {"$($DevfeeCoin.($Pools.$Algorithm_Norm.CoinName))"})$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" -N $($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"}) -M $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Index)}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Eminer"
                Port       = $Miner_Port
                URI        = $Uri
                WarmupTime = 45 #seconds
            }
        }
    }
}
