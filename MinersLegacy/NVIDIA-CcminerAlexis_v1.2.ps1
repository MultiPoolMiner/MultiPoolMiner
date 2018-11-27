using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "B0222106230616A31A93811640E8488BDCDA0FBF9EE2C5AD7EB1B3F4E4421884"
$Uri = "https://github.com/nemosminer/ccminerAlexis78/releases/download/Alexis78-v1.2/ccminerAlexis78v1.2x32.7z"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    #GPU - profitable 16/05/2018
    #Intensities and parameters tested by nemosminer on 10603gb to 1080ti
    "c11"          = " -i 21" #X11evo; fix for default intensity
    "hsr"          = "" #HSR, HShare
    "keccak"       = " -m 2 -i 29" #Keccak; fix for default intensity, difficulty x M
    "keccakc"      = " -i 29" #Keccakc; fix for default intensity
    "lyra2v2"      = "" #lyra2v2
    #"neoscrypt"   = " -i 15.5" #NeoScrypt; fix for default intensity, about 50% slower then Excavator of JustAMinerNeoScrypt 
    "poly"         = "" #Poly
    "skein"        = "" #Skein
    "skein2"       = "" #skein2
    "veltor"       = " -i 23" #Veltor; fix for default intensity
    "whirlcoin"    = "" #WhirlCoin
    "whirlpool"    = "" #Whirlpool
    "x11evo"       = " -i 21" #X11evo; fix for default intensity
    "x17"          = " -i 20" #x17; fix for default intensity

    # ASIC - never profitable 11/08/2018
    #"blake2s"     = "" #Blake2s
    #"blake"       = "" #blake
    #"blakecoin"   = "" #Blakecoin
    #"cryptolight" = "" #cryptolight
    #"cryptonight" = "" #CryptoNight
    #"decred"      = "" #Decred
    #"lbry"        = "" #Lbry
    #"lyra2"       = "" #Lyra2
    #"myr-gr"      = "" #MyriadGroestl
    #"nist5"       = "" #Nist5
    #"quark"       = "" #Quark
    #"qubit"       = "" #Qubit
    #"scrypt"      = "" #Scrypt
    #"scrypt:N"    = "" #scrypt:N
    #"sha256d"     = "" #sha256d
    #"sia"         = "" #SiaCoin
    #"sib"         = "" #Sib
    #"x11"         = "" #X11
    #"x13"         = "" #x13
    #"x14"         = "" #x14
    #"x15"         = "" #x15
}
$CommonCommands = " -N 1"

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
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

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
