using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-ccminer-2.2.4-x64\ccminer-x64.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.2.4-tpruvot/ccminer-x64-2.2.4-cuda9.7z"

# Custom command to be applied to all algorithms
$CommonCommands = " --submit-stale"

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    #"bitcore"     = "" # Do not use, peaks and falls back to low earnings
    "_blake2s"      = ",31,31" # beaten by Ccminer-x11gost
    "_blakecoin"   = " -i 31" 
    "c11"          = " -i 21" # Beaten by Ccminer-x11gost
    "cryptonight"  = " -i 10.75,10.75,10 --bfactor=12,8,8"
    "_decred"      = ""
    "_equihash"    = ""
    "_groestl"     = " -i 26.5" # beaten by Ccminer-Klaust814_CUDA9
    "_hmq1725"     = ""
    "_hsr"         = " -i 21,21,20.25" # beaten by CcminerAlexis78hsr
    "_keccak"      = " -i 31,30,30" #BROKEN!
     "keccakc"     = "" # Keccak-256 (CreativeCoin)
    "_lbry"        = " -i 29,29,28"
    "_lyra2v2"     = "" # beaten by Ccminer-Palgin-Nist5
    "_lyra2z"      = " -i 22,21,21" # Lyra2z for ZCash, Beaten by CcminerLyra2Z
    "_myr-gr"      = " -i 24" # Beaten by CcminerAlexis78cuda8.0
    "_neoscrypt"   = " -i 26" # beaten by Ccminer-Palgin-Nist5
    "_nist5"       = " -i 27,26.25,24.75" # Beaten, beaten by CcminerKlaust817_CUDA91
     "penta"       = "" # Pentablake hash (5x Blake 512)
    "_phi"         = " -i 25,24,24" # Ccminer 2.2.3 x86 is faster
     "_polytimos"  = " -i 26.25,26.25" # polytimos, beaten by CcminerPolytimos
    "sia"          = " -i 31,31,31" #
    "_sib"         = " -i 21"
    "_skein"       = " -i 30,29,29" # Beaten by Ccminer 2.2.3 x86
    "_skunk"       = " -i 25.7,25.2,24.9" # Beaten by Ccminer 2.2.3 x86
#    "timetravel"  = " -i 24"
    "_tribus"      = ""
    "_vanilla"     = ""
    "_veltor"      = " -i 23" # Fastest
    "_x11evo"      = " -i 21"
    "_x17"         = "" # beaten by CcminerAlexis78hsr
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