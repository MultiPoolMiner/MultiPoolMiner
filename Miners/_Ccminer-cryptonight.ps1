using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Path = ".\Bin\NVIDIA-ccminer-cryptonight\ccminer-cryptonight.exe"
$Uri = "https://github.com/KlausT/ccminer-cryptonight/releases/download/2.06beta/ccminer-cryptonight-206beta-x64-cuda8.zip"

$Port = 4068

$CommonCommands = " --bfactor=10"

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"cryptonight" = "" #
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
	        Path        = $Path
	        Arguments   = "-o $($Pools.Cryptonight.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass)$Command$CommonCommands"
	        HashRates   = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
	        API         = "Wrapper"
	        Port        = 4068
	        Wrap        = $true
	        URI         = $Uri
			PowerDraw   = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
			ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
	        Pool        = $($Pools.$Algorithm.Name)
		}
	}
	$Port ++
}