using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-ccminer-2.2.3\ccminer.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.2.3-tpruvot/ccminer-x64-2.2.3-cuda9.7z"

$Port = 4068

# Custom command to be applied to all algorithms
$CommonCommands = "--submit-stale"

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    #"bitcore"      = "" # Do not use, peaks and falls back to low earnings
    "_blake2s"      = "" # my best values Values for 1080ti/1070/10603G "-i 31" # beaten by Excavator136aNvidia4
    "_blakecoin"   = "" # my best values Values for 1080ti/1070/10603G "-i 31" 
    "_c11"         = "" # my best values Values for 1080ti/1070/10603G "-i 21" # Beaten by Ccminer-x11gost
    "_cryptonight" = "" # my best values Values for 1080ti/1070/10603G "-i 10.25,10.25,10.25 --bfactor=12"
    "_decred"      = ""
    "_equihash"    = ""
    "_groestl"      = "" # my best values Values for 1080ti/1070/10603G "-i 26.5" # beaten by Ccminer-Klaust814_CUDA9
    "_hmq1725"     = ""
    "_hsr"           = "" # my best values Values for 1080ti/1070/10603G "-i 21,21,20.25"  #HSR, beaten by CcminerAlexis78hsr
    "_keccak"      = "" # my best values Values for 1080ti/1070/10603G "-i 31,30,30" #BROKEN!
    "keccakc"      = "" # Keccak-256 (CreativeCoin)
    "_lbry"        = ""
    "_lyra2v2"     = "" # beaten by Ccminer-Palgin-Nist5
    "_lyra2z"      = "" # my best values Values for 1080ti/1070/10603G "-i 22,21,21" # Lyra2z for ZCash, Beaten by CcminerLyra2Z
    "_myr-gr"       = "" # my best values Values for 1080ti/1070/10603G "-i 24" # Beaten by CcminerAlexis78cuda8.0
    "_neoscrypt"   = "" # my best values Values for 1080ti/1070/10603G "-i 26" # beaten by Ccminer-Palgin-Nist5
    "_nist5"       = "" # my best values Values for 1080ti/1070/10603G "-i 22" # Beaten, beaten by CcminerKlaust817_CUDA91
    "penta"        = "" # Pentablake hash (5x Blake 512)
    "phi"          = "" # my best values Values for 1080ti/1070/10603G "-i 25,24,24"
    "_polytimos"    = "" # my best values Values for 1080ti/1070/10603G "-i 25.5,25.5,25" # polytimos, beaten by CcminerPolytimos
    "sia"          = "" # my best values Values for 1080ti/1070/10603G "-i 31,31,31" #
    "_sib"         = "" # my best values Values for 1080ti/1070/10603G "-i 21"
    "_skein"       = "" # my best values Values for 1080ti/1070/10603G "-i 30,29,28.9" # beaten by others
    "skunk"       = "" # my best values Values for 1080ti/1070/10603G "-i 25.7,25.2,24.9" # Fastest
    #    "timetravel"   = "" # my best values Values for 1080ti/1070/10603G "-i 24"
    "_tribus"      = ""
    "_vanilla"     = ""
    "_veltor"      = "" # my best values Values for 1080ti/1070/10603G "-i 23" # Fastest
    "_x11evo"      = "" # my best values Values for 1080ti/1070/10603G "-i 21"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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

        {while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

        [PSCustomObject]@{
            Name        = $Name
            Type		= $Type
            Device		= $Device.Device
            Path		= $Path
            Arguments	= "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port$Command$CommonCommands"
            HashRates	= [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
            API			= "Ccminer"
            Port		= $Port
            Wrap		= $false
            URI			= $Uri
            PowerDraw	= $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
            ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
            Pool		= "$($Pools.$Algorithm.Name)"
            Index		= $Index
        }
    }
    if ($Port) {$Port ++}
}
Sleep 0