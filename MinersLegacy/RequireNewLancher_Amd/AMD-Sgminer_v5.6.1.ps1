using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\sgminer.exe"
$HashSHA256 = "7A29E1280898D049BEE35B1CE4A6F05A7B3A3219AC805EA51BEFD8B9AFDE7D85"
$Uri = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-amd64.zip"
$ManualUri = "https://github.com/nicehash/sgminer"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "groestlcoin"  = " --gpu-threads 2 --worksize 128 --intensity d" #Groestl
    "lbry"         = "" #Lbry
    "lyra2rev2"    = " --gpu-threads 2 --worksize 128 --intensity d" #Lyra2RE2
    "neoscrypt"    = " --gpu-threads 1 --worksize 64 --intensity 15" #NeoScrypt
    "sibcoin-mod"  = "" #Sib
    "skeincoin"    = " --gpu-threads 2 --worksize 256 --intensity d" #Skein
    "yescrypt"     = " --worksize 4 --rawintensity 256" #Yescrypt

    # ASIC - never profitable 23/05/2018    
    #"blake2s"     = "" #Blake2s
    #"blake"       = "" #Blakecoin
    #"cryptonight" = " --gpu-threads 1 --worksize 8 --rawintensity 896" #CryptoNight
    #"decred"      = "" #Decred
    #"lbry"        = "" #Lbry
    #"maxcoin"     = "" #Keccak
    #"myriadcoin-groestl" = " --gpu-threads 2 --worksize 64 --intensity d" #MyriadGroestl
    #"nist5"       = "" #Nist5
    #"pascal"      = "" #Pascal
    #"vanilla"     = " --intensity d" #BlakeVanilla
}
$CommonCommands = " --text-only"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = <#temp fix#> Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name        = $Miner_Name
            DeviceName  = $Miner_Device.Name
            Path        = $Path
            HashSHA256  = $HashSHA256
            Arguments   = ("--api-listen --api-port $Miner_Port --kernel $_ --url $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands --gpu-platform $($Miner_Device.PlatformId | Sort-Object -Unique) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API         = "Xgminer"
            Port        = $Miner_Port
            URI         = $Uri
            Environment = @{"GPU_FORCE_64BIT_PTR" = 0}
        }
    }
}
