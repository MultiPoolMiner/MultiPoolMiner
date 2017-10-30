using module ..\Include.psm1

class Claymore : Miner {
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
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)" -UseBasicParsing -TimeoutSec $Timeout

            $Data = $Response.Content.Substring($Response.Content.IndexOf("{"), $Response.Content.LastIndexOf("}") - $Response.Content.IndexOf("{") + 1) | ConvertFrom-Json

            $HashRate = $Data.result[2].Split(";")[0]
            $HashRate_Dual = $Data.result[4].Split(";")[0]

            if ($HashRate -eq $null -or $HashRate_Dual -eq $null) {$HashRates = @(); $HashRate_Dual = @(); break}

            if ($Response.Content.Contains("ETH:")) {$HashRates += [Double]$HashRate * $Multiplier; $HashRates_Dual += [Double]$HashRate_Dual * $Multiplier}
            else {$HashRates += [Double]$HashRate; $HashRates_Dual += [Double]$HashRate_Dual}

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