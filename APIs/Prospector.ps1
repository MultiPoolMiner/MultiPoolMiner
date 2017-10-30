using module ..\Include.psm1

class Prospector : Miner {
    [PSCustomObject]GetHashRate ([Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Multiplier = 1000
        $Delta = 0.05
        $Interval = 5
        $HashRates = @()
        $HashRates_Dual = @()

        $HashRate = $null
        $HashRate_Dual = $null

        do {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v0/hashrates" -UseBasicParsing -TimeoutSec $Timeout

            $Data = $Response | ConvertFrom-Json

            $HashRate = $Data.rate

            if ($HashRate -eq $null) {$HashRates = @(); break}

            $HashRates += [Double]($HashRate | Measure-Object -Sum | Select-Object -ExpandProperty Sum)

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRates_Info = $HashRates | Measure-Object -Maximum -Minimum -Average
        $HashRate = if ($HashRates_Info.Maximum - $HashRates_Info.Minimum -le $HashRates_Info.Average * $Delta) {$HashRates_Info.Maximum}

        $HashRates_Info_Dual = $HashRates_Dual | Measure-Object -Maximum -Minimum -Average
        $HashRate_Dual = if ($HashRates_Info_Dual.Maximum - $HashRates_Info_Dual.Minimum -le $HashRates_Info_Dual.Average * $Delta) {$HashRates_Info_Dual.Maximum}

        return $HashRate, $HashRates_Dual
    }
}