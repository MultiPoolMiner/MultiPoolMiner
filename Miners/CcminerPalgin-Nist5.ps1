using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Path = ".\Bin\NVIDIA-Palgin_1_1-Nist5\ccminer.exe"
$Uri = "https://github.com/palginpav/ccminer/releases/download/1.1-nist5/palginmod_1.1_nist5_x86.zip"

$Port = 4068

$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"_blake2s"   = " -i 26" # beaten by Ccminer Nanashi
	"_blakecoin" = "","" #Blakecoin, has stratum connection timeouts - beaten by CcminerSp-mod
	"_c11"       = " -i 21"
	"_decred"    = "","" #boo!
	"deep"       = "",""
	"_keccak"    = " -i 31" #Beaten by Ccminer Klaust 8.15 CUDA9
	"_lbry"      = "","" 
	"luffa"      = "",""
	"lyra2"      = "",""
	"lyra2v2"    = " -i 24,21,22" #Lyra2RE2 beaten by Excavator136aNvidia4
	"_myr-gr"    = "","" # beaten by CcminerAlexis78cuda8.0
	"_neoscrypt" = "","" #NeoScrypt beaten by CcminerKlausT
	"nist5"     = " -i 24,21,22"
	"_quark"     = "" #Quark beaten by CcminerAlexis78cuda8.0
	"qubit"      = " -i 21,18,18" 
	"s3"         = "" 
	"sia"        = "" 
	"sib"       = " -i 21.5,20.5,20.5" # Fastest, beaten by Ccminer-Hsr
	"_skein"     = " -i 30,28,28" # Beaten by Ccminer-HSR 
	"whirlpool"  = ""
	"wildkeccak" = ""
	"_x11"        = " -i 21,18,18" 
	"x11evo"     = " -i 21,18,18"
	"_x13"        = " -i 16,16,16"
	"_x14"        = " -i 21,18,18"
	"_x15"       = " -i 20,18,18"
	"_x17"       = " -i 21,18,18"
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
			PowerDraw	= $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
			ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
			Pool		= "$($Pools.$Algorithm.Name)"
		}
	}
	$Port ++
}