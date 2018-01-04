using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Ccminer-Polytimos\ccminer.exe"
$Uri = "https://github.com/punxsutawneyphil/ccminer/releases/download/polytimosv2/ccminer-polytimos_v2.zip"

# Custom command to be applied to all algorithms
$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
#    #"bitcore"     = "" # Do not use, peaks and falls back to low earnings
#    "blake2s"      = "" # my best values for 1080ti/1070/10603G " -i 31" # beaten by Excavator136aNvidia4
#    "blakecoin"    = "" # my best values for 1080ti/1070/10603G " -i 31" 
#    "c11"          = "" # my best values for 1080ti/1070/10603G " -i 21" # Beaten by Ccminer-HSR
#    "cryptonight"  = "" # my best values for 1080ti/1070/10603G " -i 10.25,10.25,10.25 --bfactor=12"
#    "decred"       = ""
#    "equihash"     = ""
#    "groestl"      = "" # my best values for 1080ti/1070/10603G " -i 26.5" # beaten by Ccminer-Klaust814_CUDA9
#    "hmq1725"      = ""
#    "hsr"          = "" # my best values for 1080ti/1070/10603G " -i 21" # beaten by CcminerAlexis78hsr
#    "keccak"       = "" # my best values for 1080ti/1070/10603G " -i 31,30,30" #BROKEN!
#	"keccakc"       = "" # Keccak-256 (CreativeCoin)
#    "lbry"         = ""
#    "lyra2v2"      = "" # beaten by Ccminer-Palgin-Nist5
#    "lyra2z"       = "" # my best values for 1080ti/1070/10603G " -i 22,21,21" # Lyra2z for ZCash, Beaten by CcminerLyra2Z
#    "myr-gr"       = "" # my best values for 1080ti/1070/10603G " -i 24" # Beaten by CcminerAlexis78cuda8.0
#    "neoscrypt"    = "" # my best values for 1080ti/1070/10603G " -i 26" # beaten by Ccminer-Palgin-Nist5
#    "nist5"        = "" # my best values for 1080ti/1070/10603G " -i 22" # Beaten, beaten by Ccminer-Palgin-Nist5
#	"penta"         = "" # Pentablake hash (5x Blake 512)
#    "phi"          = "" # my best values for 1080ti/1070/10603G " -i 25,24,24"
	"poly"          = "" # my best values for 1080ti/1070/10603G " -i 25.5,24.5,24.5" # polytimos
#    "quark"        = "" 
#    "qubit"        = ""
#    "scrypt"       = "" 
#    "sia"          = "" # my best values for 1080ti/1070/10603G " -i 31,31" #
#    "sib"          = "" # my best values for 1080ti/1070/10603G " -i 21"
#    "skein"        = "" # my best values for 1080ti/1070/10603G " -i 30,29,29" # Beaten by CcminerKlaust-815-CUDA9
#    "skunk"        = "" # my best values for 1080ti/1070/10603G " -i 25.7,25.2,25,2" # Fastest
##    "timetravel"  = "" # my best values for 1080ti/1070/10603G " -i 24"
#    "tribus"       = ""
#    "vanilla"      = ""
#    "veltor"       = "" # my best values for 1080ti/1070/10603G " -i 23" # Fastest
#    "x11"          = "" # my best values for 1080ti/1070/10603G " -i 21" # beaten by CcminerPalgin
#    "x11evo"       = "" # my best values for 1080ti/1070/10603G " -i 21" 
#    "x13"          = ""
#    "x14"          = "" # my best values for 1080ti/1070/10603G " -i 21"
#    "x15"          = "" # my best values for 1080ti/1070/10603G " -i 20"
#    "x17"          = "" # my best values for 1080ti/1070/10603G " -i 21" # same as CcminerPalgin-nist5, but no stratum connection issues, fastest
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
			Arguments    = "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port $Command $CommonCommands"
			HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
			API	         = "Ccminer"
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