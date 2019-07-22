using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\miner.exe"
$HashSHA256 = "C3CB1770B93611F45CC194DF11188E56ACE58DD718F5E4260C3ED65EABB1F6B7"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/EWBF2/EWBF.Equihash.miner.v0.6.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "Equihash-96_5";  MinMemGB = 1.8; Params = ""}
        [PSCustomObject]@{Algorithm = "Equihash-144_5"; MinMemGB = 1.7; Params = ""}
        [PSCustomObject]@{Algorithm = "Equihash-192_7"; MinMemGB = 2.7; Params = ""}
        [PSCustomObject]@{Algorithm = "Equihash-210_9"; MinMemGB = 1.3; Params = ""}
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --pec --intensity 64"}

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = ($_.Algorithm) -replace "Equihash-"
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {$([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
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

            if ($Algorithm_Norm -eq "Equihash1445") {
                #define --pers for equihash1445
                $AlgoPers = " --pers $(Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default 'auto')"
            }
            else {$AlgoPers = ""}

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) {$Miner_Config = [PSCustomObject]@{DisableDevFeeMining = $Config.DisableDevFeeMining}}
            if ($Miner_Config.DisableDevFeeMining) {
                $NoFee = " --fee 0"
                $Miner_Fees = [PSCustomObject]@{$Algorithm_Norm = 0 / 100}
            }
            else {
                $NoFee = ""
                $Miner_Fees = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
            }

            if ($Algorithm_Norm -ne "Equihash1445" -or $Pers) {
                [PSCustomObject]@{
                    Name             = $Miner_Name
                    BaseName         = $Miner_BaseName
                    Version          = $Miner_Version
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = ("--algo $Algorithm$AlgoPers --eexit 1 --api 127.0.0.1:$($Miner_Port) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters$NoFee --cuda_devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                    HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API              = "DSTM"
                    Port             = $Miner_Port
                    URI              = $Uri
                    Fees             = $Miner_Fees
                    PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                }
            }
        }
    }
}
