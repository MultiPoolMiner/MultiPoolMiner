using module ..\Include.psm1

$Type = "NVIDIA"
$Type_Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Threads = 4

$Path = ".\Bin\NVIDIA-Excavator_138a\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.3.8a/excavator_v1.3.8a_NVIDIA_Win64.zip"

$Port = 3456

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"blake2s"			= @() #Blake2s
	"_cryptonight"		= @() #Cryptonight, 4 threads out of memory
	"decred"			= @() #Decred
	"_daggerhashimoto"	= @() #Ethash, 4 threads out of memory
	"_equihash"			= @() #Equihash beaten by DSTM
	"_neoscrypt"		= @() #NeoScrypt, 4 threads out of memory
	"keccak"			= @() #Keccak
	"lbry"				= @() #Lbry, best
	"_lyra2rev2"		= @() #Lyra2RE2, beaten by Ccminer-Palgin_Nist5
	"pascal"			= @() #Pascal, best
	"sia"				= @() #Sia
	}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Type_Devices | ForEach-Object {
	$Type_Device = $_

	if ($Type_Devices.count -gt 1 ){
		$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Type_Device.Device_Norm)"
	}

	{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

	$CommonCommands = " -f 6 -wp $($Port + 1)"

	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name} | ForEach-Object {

		$Algorithm = Get-Algorithm($_)
		$Command = $Commands.$_
		
		try {

	        if ($Algorithm -ne "Decred" -and $Algorithm -ne "Sia") {

	            $PoolIpAddress = ([System.Net.Dns]::GetHostAddresses($Pools.$($Algorithm).Host)[0]).IPAddressToString

				[PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$($PoolIpAddress):$($Pools.$($Algorithm).Port)", "$($Pools.$($Algorithm).User):$($Pools.$($Algorithm).Pass)")})},
				[PSCustomObject]@{time = 1; commands = @($Type_Device.Devices | Foreach {[PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$_") + $Command}}) * $Threads},
				[PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools.$($Algorithm).Name)_$($Algorithm)_$($Threads)_Nvidia_$($Type_Device.Device_Norm).json" -Force -ErrorAction SilentlyContinue

	            [PSCustomObject]@{
					Miner_Device= $Name
					Type		= $Type
					Device		= $Type_Device.Device
					Devices		= $Type_Device.Devices
					Path        = $Path
	                Arguments   = "-p $Port -c $($Pools.$Algorithm.Name)_$($Algorithm)_$($Threads)_Nvidia_$($Type_Device.Device_Norm).json -na$CommonCommands"
	                HashRates   = [PSCustomObject]@{$Algorithm = $Stats."$($Name)_$($Algorithm)_HashRate".Week}
	                API         = "NiceHash"
	                Port        = $Port
	                Wrap        = $false
	                URI         = $Uri
					PowerDraw   = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
					ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
	                Pool        = $($Pools.$Algorithm.Name)
	            }
	        }
	        else {
	            $PoolIpAddress = ([System.Net.Dns]::GetHostAddresses($Pools."$($Algorithm)Nicehash".Host)[0]).IPAddressToString

	            [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$($PoolIpAddress):$($Pools."$($Algorithm)NiceHash".Port)", "$($Pools."$($Algorithm)NiceHash".User):$($Pools."$($Algorithm)NiceHash".Pass)")})},
				[PSCustomObject]@{time = 3; commands = @($Type_Device.$Devices | Foreach {[PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$_") + $Command}}) * $Threads},
				[PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json-Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools."$($Algorithm)NiceHash".Name)_$($Algorithm)_$($Threads)_Nvidia_$($Type_Device.Device_Norm).json" -Force -ErrorAction SilentlyContinue

	            [PSCustomObject]@{
					Miner_Device= $Name
					Type		= $Type
					Device		= $Type_Device.Device
					Devices		= $Type_Device.Devices
	                Path        = $Path
	                Arguments   = "-p $Port -c $($Pools."$($Algorithm)NiceHash".Name)_$($Algorithm)_$($Threads)_Nvidia_$($Type_Device.Device_Norm).json -na$CommonCommands"
	                HashRates   = [PSCustomObject]@{"$($Algorithm)NiceHash" = $Stats."$($Name)_$($Algorithm)NiceHash_HashRate".Week}
	                API         = "NiceHash"
	                Port        = $Port
	                Wrap        = $false
	                URI         = $Uri
					PowerDraw   = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
					ComputeUsage= $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
	                Pool        = $Pools."$($Algorithm)Nicehash".Name
	            }
	        }
	    }
	    catch {}
	}
	$Port+=2
}
sleep 0
