using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-SP\ccminer.exe"
$Uri = "https://github.com/sp-hash/ccminer/releases/download/1.5.81/release81.7z"

# Custom command to be applied to all algorithms
$CommonCommands = ""

$Commands = [PSCustomObject]@{
    #"bitcore"      = "" #Bitcore
    #"blake2s"      = "" #Blake2s
    #"blakecoin"    = "" #Blakecoin
    #"vanilla"      = "" #BlakeVanilla
    "c11"           = "" #C11, beaten by Ccminer-x11gost
    #"cryptonight"  = "" #CryptoNight
    #"decred"       = "" #Decred
    #"equihash"     = "" #Equihash
    #"ethash"       = "" #Ethash
    #"groestl"      = "" #Groestl
    #"hmq1725"      = "" #HMQ1725
    #"jha"          = "" #JHA
    #"keccak"       = "" #Keccak
    #"lbry"         = "" #Lbry
    #"lyra2v2"      = "" #Lyra2RE2
    #"lyra2z"       = "" #Lyra2z
    #"myr-gr"       = "" #MyriadGroestl
    #"neoscrypt"    = "" #NeoScrypt
    #"nist5"        = "" #Nist5
    #"pascal"       = "" #Pascal
    #"phi"          = "" #PHI
    #"sia"          = "" #Sia
    #"sib"          = "" #Sib
    "skein"         = "" #Skein, reports incorrect hashrate
    #"skunk"        = "" #Skunk
    #"timetravel"   = "" #Timetravel
    #"tribus"       = "" #Tribus
    #"veltor"       = "" #Veltor
    #"x11evo"       = "" #X11evo
    "x17"           = "" # my best values Values for 1080ti/1070/10603G " -i 23,22.5,21.1" #X17, Beaten by CcminerAlexis78hsr
    #"yescrypt"     = "" #Yescrypt
    #"xevan"        = "" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
    $Devices | ForEach-Object {

        $Device = $_

        $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

        $Algorithm = Get-Algorithm($_)
        $Command =  $Commands.$_

        if ($Devices.count -gt 1) {
            $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Device.Device_Norm)"
            $Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $Device.Devices) -d $($Device.Devices -join ',')"
            $Index = $Device.Devices -join ","
        }

        while ([Bool](Get-NetTCPConnection -State "Listen" -LocalPort $Port -ErrorAction SilentlyContinue)){$Port++} | Out-Null

        [PSCustomObject]@{
            Name         = $Name
            Type         = $Type
            Device       = $Device.Device
            Path         = $Path
            Arguments    = "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port $Command $CommonCommands"
            HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
            API          = "Wrapper"
            Port         = $Port
            Wrap         = $true
            URI	         = $Uri
            PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
            ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
            Pool         = "$($Pools.$Algorithm.Name)"
            Index        = $Index
        }
    }
    if ($Port) {$Port ++}
}
Sleep 0