using module ..\Include.psm1

class Claymore : Miner {
    [PSCustomObject]GetHashRate ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = @{id = 1; jsonrpc = "2.0"; method = "miner_getstat1"} | ConvertTo-Json -Compress

        do {
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to connect to miner ($($this.Name)). "
                break
            }

            $HashRate_Name = [String]($Algorithm -like (Get-Algorithm ($Data.result[0] -split " - ")[1]))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($Algorithm -like "$(Get-Algorithm ($Data.result[0] -split " - ")[1])*")} #temp fix
            if (-not $HashRate_Name) {$HashRate_Name = [String]$Algorithm[0]}
            $HashRate_Value = [Double]($Data.result[2] -split ";")[0]
            if ($Algorithm -like "ethash*") {$HashRate_Value *= 1000}

            $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

            $HashRate_Name = if ($HashRate_Name) {[String]($Algorithm -notlike $HashRate_Name)}
            $HashRate_Value = [Double]($Data.result[4] -split ";")[0]
            if ($Algorithm -like "ethash*") {$HashRate_Value *= 1000}

            $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}                

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