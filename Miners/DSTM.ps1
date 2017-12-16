	using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Path = ".\Bin\NVIDIA-DSTM\zm.exe"
# Uri = "https://bitcointalk.org/index.php?topic=2021765.0"

$Port = 2222

$CommonCommands = ""

$Commands = [PSCustomObject]@{
	#"bitcore" = "" #Bitcore
	#"blake2s" = "" #Blake2s
	#"blakecoin" = "" #Blakecoin
	#"vanilla" = "" #BlakeVanilla
	#"cryptonight" = "" #Cryptonight
	#"decred" = "" #Decred
	"equihash" = "" #Equihash
	#"ethash" = "" #Ethash
	#"groestl" = "" #Groestl
	#"hmq1725" = "" #hmq1725
	#"keccak" = "" #Keccak
	#"lbry" = "" #Lbry
	#"lyra2v2" = "" #Lyra2RE2
	#"lyra2z" = "" #Lyra2z
	#"myr-gr" = "" #MyriadGroestl
	#"neoscrypt" = "" #NeoScrypt
	#"nist5" = "" #Nist5
	#"pascal" = "" #Pascal
	#"qubit" = "" #Qubit
	#"scrypt" = "" #Scrypt
	#"sia" = "" #Sia
	#"sib" = "" #Sib
	#"skein" = "" #Skein
	#"timetravel" = "" #Timetravel
	#"x11" = "" #X11
	#"x11evo" = "" #X11evo
	#"x17" = "" #X17
	#"yescrypt" = "" #Yescrypt
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

	$Type_Devices | ForEach-Object {
		$Type_Device = $_

		$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

			$Algorithm = Get-Algorithm($_)
			$Command = $Commands.$_

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
				Path        = $Path
				Arguments   = "--telemetry=127.0.0.1:$Port --server $($Pools.$Algorithm.Host) --port $($Pools.$Algorithm.Port) --user $($Pools.$Algorithm.User) --pass $($Pools.$Algorithm.Pass)$Command$CommonCommands"
				HashRates   = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
				API         = "DSTM"
				Port        = $Port
				Wrap        = $false
				URI         = $Uri
				PowerDraw   = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
				ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
				Pool        = "$($Pools.$Algorithm.Name)"
			}
		}
	$Port ++
}
