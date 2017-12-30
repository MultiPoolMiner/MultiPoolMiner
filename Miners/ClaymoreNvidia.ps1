using module ..\Include.psm1

$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$Uri = "https://github.com/nanopool/Claymore-Dual-Miner/releases/download/v10.0/Claymore.s.Dual.Ethereum.Decred_Siacoin_Lbry_Pascal.AMD.NVIDIA.GPU.Miner.v10.0.zip"
$Fee = 0.98
$Port = 23333

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#Custom command to be applied to all algorithms
$CommonCommands = ""

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

$Type = "NVIDIA"
$Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {
	$Device = $_

	{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null
	
	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+"} | ForEach-Object {

		$Command = $Commands.$_
		$MainAlgorithm = $_.Split(";")[0]
		$MainAlgorithm_Norm = Get-Algorithm($MainAlgorithm)
		$SecondaryAlgorithm = $_.Split(";")[1]
		$SecondaryAlgorithm_Norm = Get-Algorithm($SecondaryAlgorithm) 
	
		if ($Devices.count -gt 1) {
			$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Device.Device_Norm)"
			$Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $($Device.Devices)) -di $($Device.Devices -join '')"
			$Index = $Device.Devices -join ','
		}

		if ($Pools.$($MainAlgorithm).Name -and -not $SecondaryAlgorithm) {
			
			[PSCustomObject]@{
				Name        = $Name
				Type		= $Type
				Device		= $Device.Device
				Path		= $Path
				Arguments	= "-mode 1 -mport $Port -epool $($Pools.$MainAlgorithm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins 1 -platform 2$Command$CommonCommands"
				HashRates	= [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * $Fee)} 
				API			= "Claymore"
				Port		= $Port
				Wrap		= $false
				URI			= $Uri
				PowerDraw	= $Stats."$($Name)_$($MainAlgorithm_Norm)_PowerDraw".Week
				ComputeUsage= $Stats."$($Name)_$($MainAlgorithm_Norm)_ComputeUsage".Week
				Pool		= $($Pools.$MainAlgorithm_Norm.Name)
				Index		= $Index			
			}
		}
		if ($Pools.$($MainAlgorithm).Name -and $Pools.$($SecondaryAlgorithm).Name) {

			[PSCustomObject]@{
				Miner_Device= $Name
				Type		= $Type
				Device		= $Device.Device
				Path		= $Path
				Arguments	= "-mode 0 -mport $Port -epool $($Pools.$MainAlgorithm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm.User) -epsw $($Pools.$MainAlgorithm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2$Command$CommonCommands"
				HashRates	= [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * $Fee); "$SecondaryAlgorithm_Norm" = ($Stats."$($Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week * $Fees)}
				API			= "Claymore"
				Port		= $Port
				Wrap		= $false
				URI			= $Uri
				PowerDraw	= $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_PowerDraw".Week
				ComputeUsage= $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_ComputeUsage".Week
				Pool		= $($Pools.$MainAlgorithm_Norm.Name)
				Index		= $Index
			}
		}
	}
	if ($Port) {$Port ++}
}
Sleep 0