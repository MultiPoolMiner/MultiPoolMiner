using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-EWBF\zminer.exe"
$Uri = "https://github.com/poolgold/ewbf-miner-btg-edition/releases/download/v0.3.4b-BTG/BTG-nVidia.miner.0.3.4b.zip"

# Custom command to be applied to all algorithms
$CommonCommands = ""

$Commands = [PSCustomObject]@{
    #"bitcore"      = "" #Bitcore
    #"blake2s"      = "" #Blake2s
    #"blakecoin"    = "" #Blakecoin
    #"vanilla"      = "" #BlakeVanilla
    #"cryptonight"  = "" #Cryptonight
    #"decred"       = "" #Decred
    "equihash"      = "" #Equihash
    #"ethash"       = "" #Ethash
    #"groestl"      = "" #Groestl
    #"hmq1725"      = "" #hmq1725
    #"keccak"       = "" #Keccak
    #"lbry"         = "" #Lbry
    #"lyra2v2"      = "" #Lyra2RE2
    #"lyra2z"       = "" #Lyra2z
    #"myr-gr"       = "" #MyriadGroestl
    #"neoscrypt"    = "" #NeoScrypt
    #"nist5"        = "" #Nist5
    #"pascal"       = "" #Pascal
    #"qubit"        = "" #Qubit
    #"scrypt"       = "" #Scrypt
    #"sia"          = "" #Sia
    #"sib"          = "" #Sib
    #"skein"        = "" #Skein
    #"timetravel"   = "" #Timetravel
    #"x11"          = "" #X11
    #"x11evo"       = "" #X11evo
    #"x17"          = "" #X17
    #"yescrypt"     = "" #Yescrypt
}

#Cannot do SSL
if ($Pools.Equihash.SSL) {exit}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {
    $Device = $_

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

        $Algorithm = Get-Algorithm($_)
        $Command = $Commands.$_

        if ($Devices.count -gt 1) {
            $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Device.Device_Norm)"
            $Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $Device.Devices) --cuda_devices $($Device.Devices -join ',')"
            $Index = $Device.Devices -join ","
        }

        while ([Bool](Get-NetTCPConnection -State "Listen" -LocalPort $Port -ErrorAction SilentlyContinue)) {$Port++}

        [PSCustomObject]@{
            Name         = $Name
            Type         = $Device.Type
            Device       = $Device.Device
            Path         = $Path
            Arguments    = ("--eexit 1 --api 0.0.0.0:$port --server $($Pools.Equihash.Host) --port $($Pools.Equihash.Port) --user $($Pools.Equihash.User) --pass $($Pools.Equihash.Pass) --fee 0 --intensity 64 $Command $CommonCommands").trim()
            HashRates    = [PSCustomObject]@{$Algorithm = $Stats."$($Name)_Equihash_HashRate".Week}
            API          = "DSTM"
            Port         = $Port
            URI          = $Uri
            PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
            ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
            Pool         = "$($Pools.$Algorithm.Name)"
            Index        = $Index
        }
    }
    if ($Port) {$Port ++}
}
Sleep 0