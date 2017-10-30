using module ..\Include.psm1

class Wrapper : Miner {
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
            $Response = Get-Content ".\Wrapper_$($this.Port).txt" -ErrorAction Ignore

            $HashRate = $Response | ConvertFrom-Json

            if ($HashRate -eq $null) {Start-Sleep $Interval; $HashRate = Get-Content ".\Wrapper_$($this.Port).txt" | ConvertFrom-Json}

            if ($HashRate -eq $null) {$HashRates = @(); break}

            $HashRates += [Double]$HashRate

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