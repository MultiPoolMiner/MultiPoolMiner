using module ..\Include.psm1

class Xgminer : Miner {
    [PSCustomObject]GetHashRate ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress

        do {
            try {
                $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to connect to miner ($($this.Name)). "
                break
            }

            $HashRate_Name = [String]$Algorithm[0]
            $HashRate_Value = if ($Data.SUMMARY.HS_5s) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow(1000, 0)}
            elseif ($Data.SUMMARY.KHS_5s) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow(1000, 1)}
            elseif ($Data.SUMMARY.MHS_5s) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow(1000, 2)}
            elseif ($Data.SUMMARY.GHS_5s) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow(1000, 3)}
            elseif ($Data.SUMMARY.THS_5s) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow(1000, 4)}
            elseif ($Data.SUMMARY.PHS_5s) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow(1000, 5)}

            if ($HashRate_Value) {
                $HashRates += $HashRate = [PSCustomObject]@{}

                $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

                $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

                if (-not $Safe) {break}
            }

            $HashRate_Value = if ($Data.SUMMARY.HS_av) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow(1000, 0)}
            elseif ($Data.SUMMARY.KHS_av) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow(1000, 1)}
            elseif ($Data.SUMMARY.MHS_av) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow(1000, 2)}
            elseif ($Data.SUMMARY.GHS_av) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow(1000, 3)}
            elseif ($Data.SUMMARY.THS_av) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow(1000, 4)}
            elseif ($Data.SUMMARY.PHS_av) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow(1000, 5)}

            if ($HashRate_Value) {
                $HashRates += $HashRate = [PSCustomObject]@{}

                $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

                $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}
            }

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$Algorithm | ForEach-Object {$HashRate.$_ = [Int64]0}}

        return $HashRate
    }
}