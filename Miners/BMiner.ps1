using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-BMiner\BMiner.exe"
$Uri = "https://www.bminercontent.com/releases/bminer-v5.4.0-ae18e12-amd64.zip"

# Custom commands to be applied to all algorithms
$CommonCommands = ""

$Commands = [PSCustomObject]@{
	"equihash" = "" #Equihash
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where-Object {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {
	$Device = $_

	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name} | ForEach-Object {

		$Algorithm = Get-Algorithm($_)
		$Command = $Commands.$_

		if ($Devices.count -gt 1) {
			$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)-$($Device.Device_Norm)"
			$Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $Device.Devices) -devices $($Device.Devices -join ',')"
			$Index = $Device.Devices -join ","
		}

        [PSCustomObject]@{
			Name         = $Name
			Type         = $Device.Type
			Device       = $Device.Device
			Path         = $Path
			Arguments    = ("-api 127.0.0.1:$Port -uri $(if ($Pools.Equihash.SSL) {'stratum+ssl'}else {'stratum'})://$($Pools.$Algorithm.User):$($Pools.$Algorithm.Pass)@$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) $Command $CommonCommands").trim()
			HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
			API          = "Bminer"
			Port         = $Port
			URI          = $Uri
			PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
			ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
			Pool         = "$($Pools.$Algorithm.Name)"
			Index        = $Index
		}
	}
	if ($Port) {$Port ++}
}