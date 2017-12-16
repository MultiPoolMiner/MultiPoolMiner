using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Path = ".\Bin\ccminer_decred_nicehash\ccminer.exe"
$Uri = ""

$Port = 4068

$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"_blake2s"   = "" #Blake2s beaten by Excavator132Nvidia5
	"_blakecoin" = "" #Blakecoin, has stratum connection timeouts - beaten by CcminerSp-mod
	"_c11"       = " -i 21" #C11 beaten by CcminerPalgin
	"decred"     = " -i 31,31,31" #Decred
	"_groestl"   = " -i 26" #Groestl beaten by ccminer-2.2.1-RC
	"_keccak"    = " -i 31 -m 2" #Keccak, beaten by CcminerXevan
	"_lyra2v2"   = "" #Lyra2RE2, has stratum connection timeouts - beaten by Excavator132Nvidia6
	"_myr-gr"    = " -i 25" #MyriadGroestl beaten by CcminerAlexis78cuda8.0
	"_neoscrypt" = " -i 12" #NeoScrypt, lower intensity is better, beaten by CcminerKlausT
	"_nist5"     = " -i 22" #Nist5 beaten by CcminerPalgin-Nist5
	"_quark"     = "" #Quark beaten by CcminerAlexis78cuda8.0
	"_qubit"     = "" #Qubit beaten by CcminerPalgin-Nist5
	#"scrypt"    = "" #Scrypt
	"_skein"     = "" #Skein, beaten by CcminerPalgin-Nist5
	"vanilla"    = "" #BlakeVanilla
	"_x11"       = "" #X11 beaten by CcminerPalgin-Nist5
	"_x13"       = "" #X13 beaten by CcminerPalgin-Nist5
	"_x14"       = "" #X14 beaten by CcminerPalgin-Nist5
	"_x15"       = "" #X15 beaten by CcminerPalgin
	"_x17"       = "" #X17 beaten by CcminerPalgin-Nist5
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Type_Devices | ForEach-Object {
	$Type_Device = $_

	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

		$Algorithm = Get-Algorithm($_)
		$Command =  $Commands.$_

		if ($Type_Devices.count -gt 1) {
			$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Type_Device.Device_Norm)"
			$Command = "$(Get-CcminerCommandPerDevice -Command "$Command" -Devices $Type_Device.Devices) -d $($Type_Device.Devices -join ',')"
		}

		{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

		if ($Algorithm -ne "Decred" -and $Algorithm -ne "Sia") {
			if ($Pools.$Algorithm.Name) {
				[PSCustomObject]@{
					Miner_Device= $Name
					Type		= $Type
					Device		= $Type_Device.Device
					Devices		= $Type_Device.Devices
					Path        = $Path
					Arguments   = "-a $Algorithm -o stratum+tcp://$($Pools.($Algorithm).Host):$($Pools.($Algorithm).Port) -u $($Pools.($Algorithm).User) -p $($Pools.($Algorithm).Pass) -b $Port$Command$CommonCommands"
					HashRates   = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
					API         = "Ccminer"
					Port        = $Port
					Wrap        = $false
					URI         = $Uri
					PowerDraw   = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
					ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
					Pool        = "$($Pools.$Algorithm.Name)"
				}    
			}
		}
		else {
			if ($Pools."$($Algorithm)Nicehash".Name) {
				[PSCustomObject]@{
					Miner_Device= $Name
					Type		= $Type
					Device		= $Type_Device.Device
					Devices		= $Type_Device.Devices
					Path        = $Path
					Arguments   = "-a $Algorithm -o stratum+tcp://$($Pools."$($Algorithm)NiceHash".Host):$($Pools."$($Algorithm)NiceHash".Port) -u $($Pools."$($Algorithm)NiceHash".User) -p $($Pools."$($Algorithm)NiceHash".Pass) -b $Port$Command$CommonCommands"
					HashRates   = [PSCustomObject]@{"$($Algorithm)NiceHash" = ($Stats."$($Name)_$($Algorithm)NiceHash_HashRate".Week)}
					API         = "Ccminer"
					Port        = $Port
					Wrap        = $false
					URI         = $Uri
					PowerDraw   = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
					ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
					Pool        = $Pools."$($Algorithm)Nicehash".Name
				}
			}
		}
	}
	$Port ++
}