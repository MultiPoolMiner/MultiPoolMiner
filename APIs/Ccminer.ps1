using module ..\Include.psm1

class Ccminer : Miner {
	[PSCustomObject]GetData ([String[]]$Algorithm, [Bool]$Safe = $false, [String]$DebugPreference = "SilentlyContinue") {
		$Server = "localhost"
		$Timeout = 10 #seconds

		$Delta = 0.05
		$Interval = 5
		$HashRates = @()

		$PowerDraws = @()
		$ComputeUsages = @()
			
		$Request = "summary"
        $Response = ""

		do {
			# Read Data from hardware
			$ComputeData = [PSCustomObject]@{}
			$ComputeData = (Get-ComputeData -MinerType $this.type -Index $this.index)
			$PowerDraws += $ComputeData.PowerDraw
			$ComputeUsages += $ComputeData.ComputeUsage

			$HashRates += $HashRate = [PSCustomObject]@{}

			try {
			    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
			    $Data = $Response -split ";" | ConvertFrom-StringData -ErrorAction Stop
			}
			catch {
				if ($Safe -and $this.Name -notmatch "PalginNvidia_.*") {
					Write-Log -Level Error "API failed to connect to miner ($($this.Name)). "
				}
			    break
			}

            if ($DebugPreference -ne "SilentlyContinue") {Write-Log -Level Debug $Response}
			
			$HashRate_Name = [String]$Data.algo
			if (-not $HashRate_Name) {$HashRate_Name = [String]($Algorithm -like "$(Get-Algorithm $Data.algo)*")} #temp fix
			$HashRate_Value = [Double]$Data.KHS * 1000

			if ($Algorithm[0] -match ".+NiceHash") {
				$HashRate_Name = "$($HashRate_Name)Nicehash"
			}

			if ($HashRate_Name -and ($Algorithm -like (Get-Algorithm $HashRate_Name)).Count -eq 1) {
			    $HashRate | Add-Member @{(Get-Algorithm $HashRate_Name) = [Int64]$HashRate_Value}
			}

			$Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

			if (-not $Safe) {break}

			Start-Sleep $Interval
		} while ($HashRates.Count -lt 6)

		$HashRate = [PSCustomObject]@{}
		$Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
		$Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$Algorithm | ForEach-Object {$HashRate.$_ = [Int]0}}

		$PowerDraws_Info = [PSCustomObject]@{}
		$PowerDraws_Info = ($PowerDraws | Measure-Object -Maximum -Minimum -Average)
		$PowerDraw = if ($PowerDraws_Info.Maximum - $PowerDraws_Info.Minimum -le $PowerDraws_Info.Average * $Delta) {$PowerDraws_Info.Maximum} else {$PowerDraws_Info.Average}

		$ComputeUsages_Info = [PSCustomObject]@{}
		$ComputeUsages_Info = ($ComputeUsages | Measure-Object -Maximum -Minimum -Average)
		$ComputeUsage = if ($ComputeUsages_Info.Maximum - $ComputeUsages_Info.Minimum -le $ComputeUsages_Info.Average * $Delta) {$ComputeUsages_Info.Maximum} else {$ComputeUsages_Info.Average}

		return [PSCustomObject]@{
			HashRate     = $HashRate
			PowerDraw    = $PowerDraw
			ComputeUsage = $ComputeUsage
            Response     = $Response
		}
	}
}