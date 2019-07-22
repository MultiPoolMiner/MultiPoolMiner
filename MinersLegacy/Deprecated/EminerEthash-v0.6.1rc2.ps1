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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "ethash2gb"; MinMemGB = 2; Params = ""} #Ethash2GB
        [PSCustomObject]@{Algorithm = "ethash3gb"; MinMemGB = 3; Params = ""} #Ethash3GB
        [PSCustomObject]@{Algorithm = "ethash"   ; MinMemGB = 4; Params = ""} #Ethash
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " -intensity 64"}

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
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters

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
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("-http :$($Miner_Port) -S $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -U $($Pools.$Algorithm_Norm.User) -P $($Pools.$Algorithm_Norm.Pass)$(if($DevfeeCoin.($Pools.$Algorithm_Norm.CoinName)) {"$($DevfeeCoin.($Pools.$Algorithm_Norm.CoinName))"})$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" -N $($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"})$Parameters$CommonParameters -M $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Index)}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Eminer"
                Port       = $Miner_Port
                URI        = $Uri
            }
        }
    }
}
