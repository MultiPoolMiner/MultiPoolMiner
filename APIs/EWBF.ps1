using module ..\Include.psm1

class Ewbf : Miner {
    [PSCustomObject]GetData ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

		$PowerDraws = @()
		$ComputeUsages = @()

        $Request = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress
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
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                break
            }

            $HashRate_Name = [String]$Algorithm[0]
            $HashRate_Value = [Double]($Data.result.sol_ps | Measure-Object -Sum).Sum
            if (-not $HashRate_Value) {$HashRate_Value = [Double]($Data.result.speed_sps | Measure-Object -Sum).Sum} #ewbf fix

            $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

            $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            $HashRate_Value = [Double]($Data.result.avg_sol_ps | Measure-Object -Sum).Sum

            if ($HashRate_Value) {
                $HashRates += $HashRate = [PSCustomObject]@{}

                $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

                $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}
            }

            Start-Sleep $Interval
		} while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$Algorithm | ForEach-Object {$HashRate.$_ = [Int64]0}}

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