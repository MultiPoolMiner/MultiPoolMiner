using module ..\Include.psm1

class Fireice : Miner {
    [PSCustomObject]GetHashRate ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = ""

        do {
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api.json" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
                try {$Data = $Response | ConvertFrom-Json -ErrorAction Stop}
                catch {$Data = $Response.Content -split "</tr>" -match "total*" -split "<td>" -replace "<[^>]*>", ""}
            }
            catch {
                Write-Warning "Failed to connect to miner ($($this.Name)). "
                break
            }

            $HashRate_Name = [String]$Algorithm[0]
            $HashRate_Value = [Double]$Data.hashrate.total[0]
            if (-not $HashRate_Value) {[Double]$HashRate_Value = $Data[1]}
            elseif (-not $HashRate_Value) {[Double]$HashRate_Value = $Data[2]}
            elseif (-not $HashRate_Value) {[Double]$HashRate_Value = $Data[3]}

            if ($HashRate_Name -and ($Algorithm -like (Get-Algorithm $HashRate_Name)).Count -eq 1) {
                $HashRate | Add-Member @{(Get-Algorithm $HashRate_Name) = [Int64]$HashRate_Value}
            }

            $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$Algorithm | ForEach-Object {$HashRate.$_ = [Int64]0}}

        return $HashRate
    }
}