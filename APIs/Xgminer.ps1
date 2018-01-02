using module ..\Include.psm1

class Xgminer : Miner {
    [PSCustomObject]GetData ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $PowerDraws = @()
        $ComputeUsages = @()

        $Request = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
        $Response = ""
        $Data = ""
        
        do {
            # Read Data from hardware
            $ComputeData = [PSCustomObject]@{}
            $ComputeData = (Get-ComputeData -MinerType $this.type -Index $this.index)
            $PowerDraws += $ComputeData.PowerDraw
            $ComputeUsages += $ComputeData.ComputeUsage

            try {
                $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Log -Level "Error" "$($this.API) API failed to connect to miner ($($this.Name)). Could not read hash rates from miner."
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