using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "82477387C860517C5FACE8758BCB7AAC890505280BF713ACA9F86D7B306AC711"
$Uri = "https://github.com/sp-hash/ccminer/releases/download/1.5.81/release81.7z"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "bastion"       = "" #bastion
    "c11"           = "" #C11
    "credit"        = "" #Credit
    "deep"          = "" #deep
    "dmd-gr"        = "" #dmd-gr
    "fresh"         = "" #fresh
    "fugue256"      = "" #Fugue256
    "heavy"         = "" #heavy
    "jackpot"       = "" #JackPot
    "keccak"        = "" #Keccak
    "luffa"         = "" #Luffa
    "mjollnir"      = "" #Mjollnir
    "pentablake"    = "" #pentablake
    "scryptjane:nf" = "" #scryptjane:nf
    "s3"            = "" #S3
    "spread"        = "" #Spread
    "x17"           = "" #x17

    # ASIC - never profitable 24/06/2018
    #"blake"         = "" #blake
    #"blakecoin"     = "" #Blakecoin
    #"blake2s"       = "" #Blake2s
    #"decred"        = "" #Decred
    #"groestl"       = "" #Groestl
    #"lbry"          = "" #Lbry
    #"lyra2"         = "" #lyra2RE
    #"myr-gr"        = "" #MyriadGroestl
    #"nist5"         = "" #Nist5
    #"quark"         = "" #Quark
    #"qubit"         = "" #Qubit
    #"scrypt"        = "" #Scrypt
    #"scrypt:N"      = "" #scrypt:N
    #"sha256d"       = "" #sha256d Bitcoin
    #"sia"           = "" #SiaCoin
    #"vanilla"       = "" #BlakeVanilla
    #"x11"           = "" #X11
    #"x13"           = "" #x13
    #"x14"           = "" #x14
    #"x15"           = "" #x15
}

$CommonCommmands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

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
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
