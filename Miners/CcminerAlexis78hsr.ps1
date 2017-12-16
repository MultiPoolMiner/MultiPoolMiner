using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Path = ".\Bin\NVIDIA-Alexis78hsr\ccminer-alexis.exe"
$Uri = "https://github.com/nemosminer/ccminer-hcash/releases/download/alexishsr/ccminer-hsr-alexis-x86-cuda8.7z"

$Port = 4068

$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"_blake2s"   = " -i 31 " #Blake2s beaten by Excavator132Nvidia5
	"blakecoin"  = "" #Blakecoin, fastest!
	"_c11"        = " -i 21.5" #C11 beaten by Ccminer-HSR
	"_decred"    = "" #Decred, broken, invalid share
	"hsr"        = " -i 21.5,21,21.5" # hsr, fastest!
	"_keccak"    = " -m 2 -i 20" #Keccak beaten by CcminerXevan
	"_lbry"      = " -i 28" #Lbry beaten by ExcavatorNvidia6
	"_lyra2v2"   = "" #Lyra2RE2 beaten by Excavator132Nvidia6
	"_myr-gr"    = " -i 26" #MyriadGroestl, fastest!
	"_neoscrypt" = "" #NeoScrypt, lower intensity is better, beaten by CcminerKlausT
	"_nist5"      = "" #Nist5, fastest!
	"quark"      = " -i 25,23,23" #Quark, fastest!
	"_qubit"     = "" #Qubit beaten by CcminerPalgin-Nist5
	"_sia"       = "" #Sia
	"_sib"        = " -i 20.5" #Sib / x11gost, 
	"_skein"      = " -i 30" #Skein, reports 30%
	"skein2"     = "" # Double Skein (Woodcoin)
	"vanilla"    = "" #BlakeVanilla
	"vcash"      = "" # Blake256-8rounds (XVC)
	"veltor"     = " -i 22" #Veltor, beaten by CcminerPalgin
	"whirlpool"  = "" # whirlpool (JoinCoin)
	"_x11"       = "" #X11 beaten by CcminerPalgin-Nist5
	"_x11evo"    = "" #X11evo
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Type_Devices | ForEach-Object {
	$Type_Device = $_

	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

		$Algorithm = Get-Algorithm($_)
		$Command =  $Commands.$_
		
		if ($Type_Devices.count -gt 1) {
			$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Type_Device.Device_Norm)"
			$Command = "$(Get-CcminerCommandPerDevice -Command "$Command" -Devices $Type_Device.Devices) -d $($Type_Device.Devices -join ',')"
		}

		{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

		[PSCustomObject]@{
			Miner_Device= $Name
			Type		= $Type
			Device		= $Type_Device.Device
			Devices		= $Type_Device.Devices
			Path		= $Path
			Arguments	= "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port$Command$CommonCommands"
			HashRates	= [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
			API			= "Ccminer"
			Port		= $Port
			Wrap		= $false
			URI			= $Uri
			PowerDraw   = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
			ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
			Pool		= "$($Pools.$Algorithm.Name)"
		}
	}
	$Port ++
}