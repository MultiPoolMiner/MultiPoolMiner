using module ..\Include.psm1

class Xgminer : Miner {
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

        $Request = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress

        do {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout

            $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

            $HashRate = if ($Data.SUMMARY.HS_5s -ne $null) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow($Multiplier, 0)}
            elseif ($Data.SUMMARY.KHS_5s -ne $null) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow($Multiplier, 1)}
            elseif ($Data.SUMMARY.MHS_5s -ne $null) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow($Multiplier, 2)}
            elseif ($Data.SUMMARY.GHS_5s -ne $null) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow($Multiplier, 3)}
            elseif ($Data.SUMMARY.THS_5s -ne $null) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow($Multiplier, 4)}
            elseif ($Data.SUMMARY.PHS_5s -ne $null) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow($Multiplier, 5)}

            if ($HashRate -ne $null) {
                $HashRates += $HashRate
                if (-not $Safe) {break}
            }

            $HashRate = if ($Data.SUMMARY.HS_av -ne $null) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow($Multiplier, 0)}
            elseif ($Data.SUMMARY.KHS_av -ne $null) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow($Multiplier, 1)}
            elseif ($Data.SUMMARY.MHS_av -ne $null) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow($Multiplier, 2)}
            elseif ($Data.SUMMARY.GHS_av -ne $null) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow($Multiplier, 3)}
            elseif ($Data.SUMMARY.THS_av -ne $null) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow($Multiplier, 4)}
            elseif ($Data.SUMMARY.PHS_av -ne $null) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow($Multiplier, 5)}

            if ($HashRate -eq $null) {$HashRates = @(); break}
            $HashRates += $HashRate
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