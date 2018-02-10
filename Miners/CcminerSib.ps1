using module ..\Include.psm1

$Path = ".\Bin\Sib-NVIDIA\ccminer_x11gost.exe"
$Uri = "https://github.com/nicehash/ccminer-x11gost/releases/download/ccminer-x11gost_windows/ccminer_x11gost.7z"

# Custom commands to be applied to all algorithms
$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "blake2s"       = "" # my best values for 1080ti/1070/10603G " -i 31,31,31" # fastest, do not use Excavator, high rejects
    "_blakecoin"    = "" # my best values for 1080ti/1070/10603G " -i 31,31,31" # beaten by CcminerAlexis78hsr 
    "c11"           = "" # my best values for 1080ti/1070/10603G " -i 21" # Beaten by Ccminer-HSR
    #"decred"       = "" # boo
    "_keccak"       = "" # my best values for 1080ti/1070/10603G " -i 31,30,29" # Beaten by Excavator138aNvidia4
    "keccakc"       = "" # Keccak-256 (CreativeCoin)
    "_lbry"         = "" # my best values for 1080ti/1070/10603G " -i 29,28,28" # Beaten by Excavator138aNvidia4
    "_lyra2v2"      = "" # beaten by CcminerAlexis78Hsr
    "_myr-gr"       = "" # my best values for 1080ti/1070/10603G " -i 24,24,24" # Beaten by CcminerKlaust817_CUDA91
    "_neoscrypt"    = "" # my best values for 1080ti/1070/10603G " -i 17.1,16.6,15.2" # beaten by CcminerKlaust-817-CUDA91 & PalginHSR_Neoscrypt
    "nist5"         = "" # fastest
    "_nist5"        = "" # my best values for 1080ti/1070/10603G " -i 26.75,26.25,24.75" # fastest
    "penta"         = "" # Pentablake hash (5x Blake 512)
    "_phi"          = "" # my best values for 1080ti/1070/10603G " -i 25,24,24" # Ccminer 2.2.3 x86 is faster
    "_polytimos"    = "" # my best values for 1080ti/1070/10603G " -i 26.25,26.25" # polytimos, beaten by CcminerPolytimos
    "sia"           = "" # my best values for 1080ti/1070/10603G " -i 31,31,31" #
    "sib"           = "" # my best values for 1080ti/1070/10603G " -i 23,21.4,21" # Fastest
    "_skein"        = "" # my best values for 1080ti/1070/10603G " -i 30,29,28.9" # beaten by CcminerSp, dodgy hasrate
    "_tribus"       = ""
    "_vanilla"      = ""
    "_veltor"       = "" # Veltor, beaten by CcminerAlexis78Hsr
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where-Object {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {

    $Device = $_

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

        $Algorithm = Get-Algorithm($_)
        $Command =  $Commands.$_

        if ($Devices.count -gt 1) {
            $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)-$($Device.Device_Norm)"
            $Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $Device.Devices) -d $($Device.Devices -join ',')"
            $Index = $Device.Devices -join ","
        }

        if ($Algorithm -ne "Decred" -and $Algorithm -ne "Sia") {
            if ($Pools.$Algorithm.Name) {
                [PSCustomObject]@{
                    Name         = $Name
                    Type         = $Device.Type
                    Device       = $Device.Device
                    Path         = $Path
                    Arguments    = ("-a $Algorithm -o $($Pools.($Algorithm).Protocol)://$($Pools.($Algorithm).Host):$($Pools.($Algorithm).Port) -u $($Pools.($Algorithm).User) -p $($Pools.($Algorithm).Pass) -b $Port $Command $CommonCommands").trim()
                    HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
                    API          = "Ccminer"
                    Port         = $Port
                    URI          = $Uri
                    PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
                    ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
                    Pool         = "$($Pools.$Algorithm.Name)"
                    Index        = $Index
                }    
            }
        }
        else {
            if ($Pools."$($Algorithm)Nicehash".Name) {
                [PSCustomObject]@{
                    Name         = $Name
                    Type         = $Device.Type
                    Device       = $Device.Device
                    Path         = $Path
                    Arguments    = ("-a $Algorithm -o stratum+tcp://$($Pools."$($Algorithm)NiceHash".Host):$($Pools."$($Algorithm)NiceHash".Port) -u $($Pools."$($Algorithm)NiceHash".User) -p $($Pools."$($Algorithm)NiceHash".Pass) -b $Port $Command $CommonCommands").trim()
                    HashRates    = [PSCustomObject]@{"$($Algorithm)NiceHash" = ($Stats."$($Name)_$($Algorithm)NiceHash_HashRate".Week)}
                    API          = "Ccminer"
                    Port         = $Port
                    URI          = $Uri
                    PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
                    ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
                    Pool         = $Pools."$($Algorithm)Nicehash".Name
                    Index        = $Index
                }
            }
        }
    }
    if ($Port) {$Port ++}
}