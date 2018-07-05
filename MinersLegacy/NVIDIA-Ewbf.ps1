using module ..\Include.psm1

$Type = "NVIDIA"
$Path = ".\Bin\NVIDIA-EWBF-Equihash\miner.exe"
$ManualUri = "https://mega.nz/#F!fsAlmZQS!CwVgFfBDduQI-CbwVkUEpQ"
$Port = 42000

$Commands = [PSCustomObject]@{
    "equihash-BTG"   = @("144_5","--pers BgoldPoW","") #EquihashBTG
    "zerocurrencies" = @("192_7","--pers ZERO_PoW","") #zerocurrencies
    "Minexcoin"      = @("96_5","","") #Minexcoin
}

$CommonCommands = "" #eg. " --cuda_devices 0 1 8 9"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type           = $Type
        Path           = $Path
        Arguments      = "--algo $($Commands.$_ | Select-Object -Index 0) --eexit 1 --api 0.0.0.0:$($Port) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($Commands.$_ | Select-Object -Index 2)$($CommonCommands) $($Commands.$_ | Select-Object -Index 1) --fee 0 --log 1 --color"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API            = "DSTM"
        Port           = $Port
        URI            = $Uri
    }
}