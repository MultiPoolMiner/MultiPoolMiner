using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$CommonCommands = ""
$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$Uri = "https://github.com/nanopool/Claymore-Dual-Miner/releases/download/v10.0/Claymore.s.Dual.Ethereum.Decred_Siacoin_Lbry_Pascal.AMD.NVIDIA.GPU.Miner.v10.0.zip"

$Port = 23333

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Prefix defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"ethash"				= ""
	"ethash2gb"				= ""
	"ethash;decred"			= " -dcoin dcr -dcri 130"
	"ethash;lbry"			= " -dcoin lbc -dcri 75"
	"ethash;pascal"			= " -dcoin pasc -dcri 80"
	"ethash;SiaClaymore"	= " -dcoin sc -dcri 110"
	"ethash2gb;decred"		= " -dcoin dcr -dcri 130"
	"ethash2gb;lbry"		= " -dcoin lbc -dcri 75"
	"ethash2gb;pascal"		= " -dcoin pasc -dcri 80"
	"ethash2gb;SiaClaymore"	= " -dcoin sc -dcri 110"
}

$Type_Devices | ForEach-Object {

	$Type_Device = $_

	{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null
	
	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+"} | ForEach-Object {

		$Command = $Commands.$_
		$MainAlgorithm =  $_.Split(";")[0]
		$MainAlgorithm_Norm = Get-Algorithm($MainAlgorithm)
		$SecondaryAlgorithm = $_.Split(";")[1]
		$SecondaryAlgorithm_Norm = Get-Algorithm($SecondaryAlgorithm) 
	
		if ($Type_Devices.count -gt 1) {
			$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Type_Device.Device_Norm)"
			$Command = "$(Get-CcminerCommandPerDevice -Command "$Command" -Devices $($Type_Device.Devices)) -di $($Type_Device.Devices -join '')"
		}

		if ($Pools.$($MainAlgorithm).Name -and -not $SecondaryAlgorithm) {
			
			[PSCustomObject]@{
				Miner_Device= $Name
				Type		= $Type
				Device		= $Type_Device.Device
				Devices		= $Type_Device.Devices
				Path		= $Path
				Arguments	= "-mode 1 -mport $Port -epool $($Pools.$MainAlgorithm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins 1 -platform 2$Command$CommonCommands"
				HashRates	= [PSCustomObject]@{"$MainAlgorithm" = $Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week} 
				API			= "Claymore"
				Port		= $Port
				Wrap		= $false
				URI			= $Uri
				PowerDraw	= $Stats."$($Name)_$($MainAlgorithm_Norm)_PowerDraw".Week
				ComputeUsage= $Stats."$($Name)_$($MainAlgorithm_Norm)_ComputeUsage".Week
				Pool		= $($Pools.$MainAlgorithm_Norm.Name)
			}
		}
		if ($Pools.$($MainAlgorithm).Name -and $Pools.$($SecondaryAlgorithm).Name) {

			[PSCustomObject]@{
				Miner_Device= $Name
				Type		= $Type
				Device		= $Type_Device.Device
				Devices		= $Type_Device.Devices
				Path		= $Path
				Arguments	= "-mode 0 -mport $Port -epool $($Pools.$MainAlgorithm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm.User) -epsw $($Pools.$MainAlgorithm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2$Command$CommonCommands"
				HashRates	= [PSCustomObject]@{"$MainAlgorithm" = $Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week; "$SecondaryAlgorithm_Norm" = $Stats."$($Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week}
				API			= "Claymore"
				Port		= $Port
				Wrap		= $false
				URI			= $Uri
				PowerDraw	= $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_PowerDraw".Week
				ComputeUsage= $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_ComputeUsage".Week
				Pool		= $($Pools.$MainAlgorithm.Name)
			}
		}
	}
	$Port ++
}
Sleep 0