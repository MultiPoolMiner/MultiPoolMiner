using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Path = ".\Bin\NVIDIA-KlausT815_CUDA9\ccminer.exe"
$Uri = "https://github.com/KlausT/ccminer/releases/download/8.15/ccminer-815-cuda9-x64.zip"

$Port = 4068

$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"_blakecoin"	= "	-i 31,31,31" #Blakecoin, beaten by CCminer-HRS
	"_c11"		= " -i 22,22,22" #C11 beaten by Ccminer-HSR 
	"groestl"	= " -i 26.5,25,26.5" #Groestl beaten by ccminer-2.2.1-RC
	"_keccak"	= " -i 31,30,30" #Keccak beaten by Excavator138aNvidia4
	"_lyra2v2"	= "" #Lyra2RE2, result does not validate on CPU (known issue)
	"myr-gr"	= " -i 26,24,24" #MyriadGroestl beaten by CcminerAlexis78cuda8.0
	"neoscrypt"	= " -i 21,16,16" #NeoScrypt, fastest
	"_nist5"	= " -i 26,26,26" #Nist5 beaten by Ccminer-HSR
	"_quark"	= "" #Quark beaten by CcminerAlexis78hsr
	"_qubit"	= "" #Qubit beaten by CcminerPalgin-Nist5
	"sia"		= "" #Sia
	"skein"		= " -i 30,29,30" #Skein, beaten by Ccminer-HSR
	"_x11"		= "" #X11 beaten by CcminerPalgin-Nist5
	"_x13"		= "" #X13 beaten by CcminerPalgin-Nist5
	"_x14"		= "" #X14 beaten by CcminerPalgin-Nist5
	"_x15"		= "" #X15 beaten by CcminerPalgin
	"_x17"		= "" #X17 beaten by CcminerPalgin-Nist5
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