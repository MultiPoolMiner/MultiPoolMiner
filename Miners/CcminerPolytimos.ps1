using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Ccminer-Polytimos\ccminer.exe"
$Uri = "https://github.com/punxsutawneyphil/ccminer/releases/download/polytimosv2/ccminer-polytimos_v2.zip"

$Port = 4068

$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
#    #"bitcore"      = "" # Do not use, peaks and falls back to low earnings
#    "_blake2s"      = " -i 31" # beaten by Excavator136aNvidia4
#    "_blakecoin"   = " -i 31" 
#    "_c11"         = " -i 21" # Beaten by Ccminer-HSR
#    "_cryptonight" = " -i 10.25,10.25,10.25 --bfactor=12"
#    "_decred"      = ""
#    "_equihash"    = ""
#    "_groestl"      = " -i 26.5" # beaten by Ccminer-Klaust814_CUDA9
#    "_hmq1725"     = ""
#    "_hsr"         = " -i 21" # beaten by CcminerAlexis78hsr
#    "_keccak"      = " -i 31,30,30" #BROKEN!
#	"keccakc"      = "" # Keccak-256 (CreativeCoin)
#    "_lbry"        = ""
#    "_lyra2v2"     = "" # beaten by Ccminer-Palgin-Nist5
#    "_lyra2z"      = " -i 22,21,21" # Lyra2z for ZCash, Beaten by CcminerLyra2Z
#    "_myr-gr"       = " -i 24" # Beaten by CcminerAlexis78cuda8.0
#    "_neoscrypt"   = " -i 26" # beaten by Ccminer-Palgin-Nist5
#    "_nist5"       = " -i 22" # Beaten, beaten by Ccminer-Palgin-Nist5
#	"penta"        = "" # Pentablake hash (5x Blake 512)
#    "phi"          = " -i 25,24,24"
	"poly"    = " -i 25.5,24.5,24.5" # polytimos
#    "_quark"       = "" 
#    "_qubit"       = ""
#    "_scrypt"      = "" 
#    "sia"          = " -i 31,31" #
#    "_sib"         = " -i 21"
#    "_skein"       = " -i 30,29,29" # Beaten by CcminerKlaust-815-CUDA9
#    "skunk"       = " -i 25.7,25.2,25,2" # Fastest
##    "timetravel"   = " -i 24"
#    "_tribus"      = ""
#    "_vanilla"     = ""
#    "_veltor"      = " -i 23" # Fastest
#    "_x11"         = " -i 21" # beaten by CcminerPalgin
#    "_x11evo"      = " -i 21" 
#    "_x13"         = ""
#    "_x14"         = " -i 21"
#    "_x15"         = " -i 20"
#    "_x17"         = " -i 21" # same as CcminerPalgin-nist5, but no stratum connection issues, fastest
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