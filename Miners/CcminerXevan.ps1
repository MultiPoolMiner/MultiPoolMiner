using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-xevan\ccminer_x86.exe"
$Uri = "https://github.com/nemosminer/ccminer-xevan/releases/download/ccminer-xevan/ccminer_x86.7z"

$Port = 4068

$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "_blake2s"   = "" # Beaten by CcminerNanashi
    "_blakecoin" = "" # my best values Values for 1080ti/1070/10603G "-i 31" # beaten by CcminerSp-mod
    "_c11"       = "" # my best values Values for 1080ti/1070/10603G "-i 21" # Stratum problem on mine.zpool.ca
    "_decred"    = "" #broken, gives invalid share
    "_keccak"    = "" # my best values Values for 1080ti/1070/10603G "-i 31,28,28 -m 2" # beaten by Ccminer-2.2.3
    "_lbry"      = "" # Beaten by ExcavatorNvidia5
    "_lyra2v2"   = "" # my best values Values for 1080ti/1070/10603G "-i 24" # Beaten by Excavator132Nvidia6
    "_myr-gr"    = "" # my best values Values for 1080ti/1070/10603G "-i 24" # No results on mine.zpool.ca
    "_neoscrypt" = "" # my best values Values for 1080ti/1070/10603G "-i 22" # slow. beaten by Ccminer Nanashi
    "_nist5"     = "" # Beaten by CcminerPalgin-Nist5
    "_quark"     = "" #Quark beaten by CcminerAlexis78cuda8.0
    "_qubit"     = "" #Qubit beaten by CcminerPalgin-Nist5 
    "sia"        = ""  
    "_sib"       = "" # my best values Values for 1080ti/1070/10603G "-i 21" # sib is broken 
    "_skein"     = "" # my best values Values for 1080ti/1070/10603G "-i 30" # Beaten by CcminerPalgin-Nist5 
    "_veltor"    = "" # my best values Values for 1080ti/1070/10603G "-i 22" # Broken
    "_x11"       = "" # my best values Values for 1080ti/1070/10603G "-i 21" 
    "_x11evo"    = "" # my best values Values for 1080ti/1070/10603G "-i 21" 
    "_x13"       = "" 
    "_x14"       = "" # my best values Values for 1080ti/1070/10603G "-i 21" 
    "_x15"       = "" # my best values Values for 1080ti/1070/10603G "-i 20" 
    "xevan"      = "" # my best values Values for 1080ti/1070/10603G "-i 21.5,20,18"
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
            Name         = $Name
            Type         = $Type
            Device       = $Device.Device
            Path         = $Path
            Arguments    = "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port $Command $CommonCommands"
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