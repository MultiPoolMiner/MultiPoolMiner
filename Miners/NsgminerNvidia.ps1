using module ..\Include.psm1

$Path = ".\Bin\Nsgminer\nsgminer.exe"
$Uri = "https://github.com/ghostlander/nsgminer/releases/download/nsgminer-v0.9.3/nsgminer-win64-0.9.3.zip"

$Port = 24028

# Custom command to be applied to all algorithms
$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "neoscrypt"   = "" #
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
			$Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $Device.Devices)$($Device.Devices -join ' -d $_')"
			$Index = $Device.Devices -join ","
		}

		{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

		[PSCustomObject]@{
			Name        = $Name
			Type		= $Type
			Device		= $Device.Device
			Path		= $Path
			Arguments	= "--api-port 24028 --api-listen --$_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) --gpu-threads 1 --worksize 64 --intensity 15 --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'NVIDIA Corporation'))$Command$CommonCommands"
			HashRates	= [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
			API			= "Xgminer"
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
sleep 0