using module ..\Include.psm1

$Type = "NVIDIA","AMD"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Path = ".\Bin\Ethash-Eminer\eminer.exe"
$Uri = "https://github.com/ethash/eminer-release/releases/download/v0.6.1-rc2/eminer.v0.6.1-rc2.win64.zip"

$Port = 8550

$CommonCommands = " -no-devfee"

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
     "Ethash"		= " -intensity 64"
	 "Ethash2gb"	= " -intensity 64"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Type_Devices | ForEach-Object {
	$Type_Device = $_

	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

		$Algorithm = Get-Algorithm($_)
		$Command =  $Commands.$_
		
		if ($Type_Devices.count -gt 1) {
			$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Type_Device.Device_Norm)"
			$Command = "$(Get-CcminerCommandPerDevice -Command "$Command" -Devices $Type_Device.Devices) -M $($Type_Device.Devices -join ',')"
		}

		{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

		[PSCustomObject]@{
			Miner_Device= $Name
			Type		= $Type
			Device		= $Type_Device.Device
			Devices		= $Type_Device.Devices
			Path		= $Path
			Arguments	= "-S $($Pools.CryptoNight.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -U $($Pools.$Algorithm.User) -P $($Pools.$Algorithm.Pass) -http :$Port -N $($Type_Device.Device_Norm)$Command$CommonCommands"
			HashRates	= [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
			API			= "Eminer"
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