using module ..\Include.psm1

class Eminer : Miner {
    [PSCustomObject]GetMinerData ([Bool]$Safe = $false) {
        $MinerData = ([Miner]$this).GetMinerData($Safe)

        if ($this.GetStatus() -ne "Running") {return $MinerData}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = ""

        do {
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/stats" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                break
            }

            $HashRate_Name = [String]$this.Algorithm[0]
            $HashRate_Value = [Double]($Data.devices.hashrate_1m | Measure-Object -Sum).Sum

            $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

            $this.Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $this.Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $this.Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$this.Algorithm | ForEach-Object {$HashRate.$_ = [Int64]0}}

        $MinerData | Add-Member HashRate $HashRate -Force
        return $MinerData
    }
}