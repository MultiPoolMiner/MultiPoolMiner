using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Nanashi\ccminer.exe"
$URI = "https://github.com/Nanashi-Meiyo-Meijin/ccminer/releases/download/v2.2-mod-r2/2.2-mod-r2-CUDA9.binary.zip"

# Custom command to be applied to all algorithms
$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "bitcore"      = "" #Bitcore beaten by ccminer-2.2.1-RC
    "blake2s"      = "" # my best values for 1080ti/1070/10603G " -i 31" #Blake2s beaten by Excavator132Nvidia5
    "blakecoin"    = "" #Blakecoin beaten by CcminerSp-mod
    #"vanilla"     = "" #BlakeVanilla
    #"c11"         = "" #C11
    #"cryptonight" = "" #CryptoNight
    #"decred"      = "" #Decred
    #"equihash"    = "" #Equihash
    #"ethash"      = "" #Ethash
    #"groestl"     = "" #Groestl
    "hmq1725"      = "" # my best values for 1080ti/1070/10603G " -i 21,20,20 -m 2" #HMQ1725
    "jha"          = "" # my best values for 1080ti/1070/10603G " -i 24,22,22" #JHA
    #"keccak"      = "" #Keccak
    #"lbry"        = "" #Lbry
    "lyra2v2"      = "" # my best values for 1080ti/1070/10603G " -i 24.25,24.25,22" #Lyra2RE2 beaten by Excavator132Nvidia6
    "lyra2z"       = "" # my best values for 1080ti/1070/10603G " -i 21.5,21,20.5" #Lyra2z, equal to by CcminerLyra2z, 40% of hashes go missing at the pool?
    "myr-gr"       = "" # my best values for 1080ti/1070/10603G " -i 25" #MyriadGroestl beaten by CcminerAlexis78cuda8.0
    "neoscrypt"    = "" # my best values for 1080ti/1070/10603G " -i 24" #NeoScrypt beaten by CcminerKlaust
    #"nist5"       = "" #Nist5
    #"pascal"      = "" #Pascal
    #"scrypt"      = "" #Scrypt
    #"sia"         = "" #Sia
    #"sib"         = "" #Sib
    #"skein"       = "" #Skein
    "skunk"        = "" # my best values for 1080ti/1070/10603G " -i 25,23,23" #Skunk, beaten by Ccminer 2.2.2
    #"timetravel"  = "" #Timetravel
    #"tribus"      = "" #Tribus
    #"veltor"      = "" #Veltor
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

        while ([Bool](Get-NetTCPConnection -State "Listen" -LocalPort $Port -ErrorAction SilentlyContinue)) {$Port++}

        [PSCustomObject]@{
            Name         = $Name
            Type         = $Device.Type
            Device       = $Device.Device
            Path         = $Path
            Arguments    = ("-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port $Command $CommonCommands").trim()
            HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
            API          = "Ccminer"
            Port         = $Port
            Wrap         = $false
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