using module ..\Include.psm1

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
	"_lyra2v2"    = " -i 24,22,21" #Lyra2RE2 beaten by Ccminer-HSR-Alexis
	"_myr-gr"    = "","" # beaten by CcminerAlexis78cuda8.0
	"_neoscrypt" = "","" #NeoScrypt beaten by CcminerKlausT
	"_nist5"     = " -i 27,26.25,25" # Nist5, generates 3% invalid shares
	"s3"         = "" 
	"sia"        = "" 
	"_sib"       = " -i 21.5,20.5,20.5" # beaten by Ccminer-Hsr
	"_skein"     = " -i 30,28,28" # Beaten by Ccminer-x11gost
	"whirlpool"  = ""
	"wildkeccak" = ""
	"x11evo"     = " -i 21,18,18"
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