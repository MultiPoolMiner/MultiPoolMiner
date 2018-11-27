using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\CPU-Tpruvot_v1.3.1\cpuminer-gw64-avx2.exe"
$HashSHA256 = "1F7ACE389009B0CB13D048BEDBBECCCDD3DDD723892FD2E2F6F3032D999224DC"
$Uri = "https://github.com/tpruvot/cpuminer-multi/releases/download/v1.3.1-multi/cpuminer-multi-rel1.3.1-x64.zip"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    # CPU Only algos 3/27/2018
    "yescrypt"       = "" #Yescrypt
    "axiom"          = "" #axiom
    
    # CPU & GPU - still profitable 27/03/2018
    "cryptonight"    = "" #CryptoNight
    "shavite3"       = "" #shavite3

    #GPU - never profitable 27/03/2018
    #"bastion"       = "" #bastion
    #"bitcore"       = "" #Bitcore
    #"blake"         = "" #blake
    #"blake2s"       = "" #Blake2s
    #"blakecoin"     = "" #Blakecoin
    #"bmw"           = "" #bmw
    #"c11"           = "" #C11
    #"cryptolight"   = "" #cryptolight
    #"decred"        = "" #Decred
    #"dmd-gr"        = "" #dmd-gr
    #"equihash"      = "" #Equihash
    #"ethash"        = "" #Ethash
    #"groestl"       = "" #Groestl
    #"jha"           = "" #JHA
    #"keccak"        = "" #Keccak
    #"keccakc"       = "" #keccakc
    #"lbry"          = "" #Lbry
    #"lyra2re"       = "" #lyra2re
    #"lyra2v2"       = "" #Lyra2RE2
    #"myr-gr"        = "" #MyriadGroestl
    #"neoscrypt"     = "" #NeoScrypt
    #"nist5"         = "" #Nist5
    #"pascal"        = "" #Pascal
    #"pentablake"    = "" #pentablake
    #"pluck"         = "" #pluck
    #"scrypt:N"      = "" #scrypt:N
    #"scryptjane:nf" = "" #scryptjane:nf
    #"sha256d"       = "" #sha256d
    #"sib"           = "" #Sib
    #"skein"         = "" #Skein
    #"skein2"        = "" #skein2
    #"skunk"         = "" #Skunk
    #"timetravel"    = "" #Timetravel
    #"tribus"        = "" #Tribus
    #"vanilla"       = "" #BlakeVanilla
    #"veltor"        = "" #Veltor
    #"x11"           = "" #X11
    #"x11evo"        = "" #X11evo
    #"x13"           = "" #x13
    #"x14"           = "" #x14
    #"x15"           = "" #x15
    #"x16r"          = "" #x16r
    #"zr5"           = "" #zr5
}
$CommonCommands = ""

$Devices = $Devices | Where-Object Type -EQ "CPU" | Where-Object {(-not $_.CpuFeatures) -or ($_.CpuFeatures -contains "avx2")}

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
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port$($Commands.$_)$($CommonCommands)" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_port
            URI        = $Uri
        }
    }
}
